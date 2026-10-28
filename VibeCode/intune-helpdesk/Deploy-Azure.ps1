#Requires -Version 5.1
<#
.SYNOPSIS
Builds and deploys the Intune frontend to Azure Static Web Apps.
.EXAMPLE
.\Deploy-Azure.ps1 -SubscriptionId 'subscription-id' -ResourceGroupName 'rg-intune-helpdesk' -AppName 'intune-helpdesk-demo'
.NOTES
Requires Node.js LTS, Azure CLI, SWA CLI, and an existing Azure CLI login.
Reads Vite production configuration, including .env.local. No API is deployed.
Does not change the Entra application registration or grant permissions.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [guid] $SubscriptionId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroupName,

    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9-]{0,58}[a-zA-Z0-9]$')]
    [string] $AppName,

    [string] $Location = 'eastus2',

    [ValidateSet('Free', 'Standard')]
    [string] $Sku = 'Free',

    [string] $EntraClientId,

    [string] $EntraTenantId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Checked {
    param(
        [Parameter(Mandatory)][string] $Command,
        [Parameter(Mandatory)][string[]] $Arguments
    )
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Command failed with exit code $LASTEXITCODE. Deployment stopped."
    }
}

if (-not $PSCmdlet.ShouldProcess(
    "$ResourceGroupName/$AppName in subscription $SubscriptionId",
    "Build frontend, create or reuse Azure resources, and publish to production ($Sku SKU)"
)) {
    return
}

foreach ($command in @('node', 'npm', 'az', 'swa')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Required command '$command' is missing. See LOCAL_AND_AZURE_SETUP.md for prerequisites."
    }
}

$environmentNames = @(
    'VITE_ENTRA_CLIENT_ID',
    'VITE_ENTRA_TENANT_ID',
    'VITE_ENTRA_REDIRECT_URI',
    'SWA_CLI_DEPLOYMENT_TOKEN'
)
$savedEnvironment = @{}
foreach ($name in $environmentNames) {
    $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

Push-Location $PSScriptRoot
try {
    $null = Invoke-Checked az @(
        'account', 'show', '--subscription', "$SubscriptionId", '--only-show-errors', '--output', 'json'
    )

    Invoke-Checked npm @('ci')

    if ($EntraClientId) { $env:VITE_ENTRA_CLIENT_ID = $EntraClientId }
    if ($EntraTenantId) { $env:VITE_ENTRA_TENANT_ID = $EntraTenantId }

    $configurationJson = Invoke-Checked node @(
        '-e',
        "const e=require('vite').loadEnv('production',process.cwd()); console.log(JSON.stringify({clientId:process.env.VITE_ENTRA_CLIENT_ID||e.VITE_ENTRA_CLIENT_ID,tenantId:process.env.VITE_ENTRA_TENANT_ID||e.VITE_ENTRA_TENANT_ID}));"
    )
    $configuration = $configurationJson | ConvertFrom-Json
    foreach ($property in @('clientId', 'tenantId')) {
        $value = $configuration.PSObject.Properties[$property]
        $parsed = [guid]::Empty
        if (-not $value -or -not [guid]::TryParse([string] $value.Value, [ref] $parsed) -or $parsed -eq [guid]::Empty) {
            throw "A valid Entra $property GUID is required. Set it in .env.local or use the EntraClientId/EntraTenantId parameters."
        }
    }
    $env:VITE_ENTRA_CLIENT_ID = $configuration.clientId
    $env:VITE_ENTRA_TENANT_ID = $configuration.tenantId
    # Use the deployed browser origin, never a local redirect URI from .env.local.
    $env:VITE_ENTRA_REDIRECT_URI = '/'

    Invoke-Checked npm @('exec', '--', 'tsc', '--noEmit')
    Invoke-Checked npm @('test', '--', '--runInBand')
    Invoke-Checked npm @('run', 'build')
    $dist = Join-Path $PSScriptRoot 'dist'
    foreach ($file in @('index.html', 'staticwebapp.config.json')) {
        if (-not (Test-Path (Join-Path $dist $file) -PathType Leaf)) {
            throw "Build output is missing $file. Deployment stopped."
        }
    }

    $groupExists = Invoke-Checked az @(
        'group', 'exists', '--name', $ResourceGroupName,
        '--subscription', "$SubscriptionId", '--only-show-errors', '--output', 'tsv'
    )
    if ("$groupExists".Trim() -eq 'false') {
        $null = Invoke-Checked az @(
            'group', 'create', '--name', $ResourceGroupName, '--location', $Location,
            '--subscription', "$SubscriptionId", '--only-show-errors', '--output', 'json'
        )
    } elseif ("$groupExists".Trim() -ne 'true') {
        throw 'Could not determine whether the resource group exists.'
    }

    $appsJson = Invoke-Checked az @(
        'staticwebapp', 'list', '--resource-group', $ResourceGroupName,
        '--subscription', "$SubscriptionId", '--only-show-errors', '--output', 'json'
    )
    $apps = $appsJson | ConvertFrom-Json
    $app = @($apps | Where-Object { $_.name -eq $AppName })
    if ($app.Count -eq 0) {
        $null = Invoke-Checked az @(
            'staticwebapp', 'create', '--name', $AppName, '--resource-group', $ResourceGroupName,
            '--location', $Location, '--sku', $Sku,
            '--subscription', "$SubscriptionId", '--only-show-errors', '--output', 'json'
        )
    } else {
        Write-Host 'Reusing the existing Static Web App without changing its SKU or location.'
    }

    $hostname = Invoke-Checked az @(
        'staticwebapp', 'show', '--name', $AppName, '--resource-group', $ResourceGroupName,
        '--subscription', "$SubscriptionId", '--query', 'defaultHostname',
        '--only-show-errors', '--output', 'tsv'
    )
    if ([string]::IsNullOrWhiteSpace("$hostname")) {
        throw 'Azure did not return the Static Web App hostname.'
    }
    $url = "https://$("$hostname".Trim())/"
    Write-Host "Entra SPA redirect URI to add (keep your localhost URI too): $url"

    $deploymentToken = Invoke-Checked az @(
        'staticwebapp', 'secrets', 'list', '--name', $AppName, '--resource-group', $ResourceGroupName,
        '--subscription', "$SubscriptionId", '--query', 'properties.apiKey',
        '--only-show-errors', '--output', 'tsv'
    )
    if ([string]::IsNullOrWhiteSpace("$deploymentToken")) {
        throw 'Azure did not return a deployment token.'
    }
    $env:SWA_CLI_DEPLOYMENT_TOKEN = "$deploymentToken".Trim()
    $deploymentToken = $null
    Invoke-Checked swa @('deploy', $dist, '--env', 'production')

    $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 60
    if ($response.StatusCode -ne 200 -or $response.Content -notmatch 'Intune Helpdesk') {
        throw "Deployment completed, but the app page could not be verified at $url. Check Azure deployment status."
    }
    Write-Host "App page is responding: $url"
    Write-Host 'Verify sign-in and device access in the browser after adding the Entra redirect URI.'
    Write-Host 'Requires delegated DeviceManagementManagedDevices.Read.All with admin consent and Intune RBAC access.'
    Write-Host 'Sync/wipe require DeviceManagementManagedDevices.PrivilegedOperations.All and Intune RBAC; recovery requires BitlockerKey.Read.All and an authorized Entra role.'
} finally {
    foreach ($name in $environmentNames) {
        [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process')
    }
    Pop-Location
}
