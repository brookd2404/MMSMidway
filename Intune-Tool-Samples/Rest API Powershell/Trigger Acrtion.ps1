# -----------------------------------------------------------------------------
# Microsoft Graph REST: Auth, Device Search, & Intune Policy Sync Action
# -----------------------------------------------------------------------------
$TenantId = "<YourTenantID>"
$ClientId = "<YourClientID>"

$Scopes = @(
    "openid"
    "profile"
    "offline_access"
    "BitlockerKey.Read.All"
    "Device.Read.All"
    "Directory.Read.All"
    "GroupMember.Read.All"
    "Group.Read.All"
    "DeviceManagementManagedDevices.ReadWrite.All"
    "DeviceManagementManagedDevices.PrivilegedOperations.All"
    "DeviceManagementScripts.Read.All"
    "DeviceLocalCredential.Read.All"
)

# -----------------------------------------------------------------------------
# 1. Authentication (Interactive PKCE Loopback Redirect)
# -----------------------------------------------------------------------------
$RandomBytes = New-Object byte[] 64
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($RandomBytes)
$Verifier = [Convert]::ToBase64String($RandomBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')

$Sha256 = [System.Security.Cryptography.SHA256]::Create()
$ChallengeBytes = $Sha256.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($Verifier))
$Sha256.Dispose()
$Challenge = [Convert]::ToBase64String($ChallengeBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')

$StateBytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($StateBytes)
$State = [Convert]::ToBase64String($StateBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')

$Listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$Listener.Start()
$Port = ([System.Net.IPEndPoint]$Listener.LocalEndpoint).Port
$RedirectUri = "http://localhost:$Port/"

$ScopeText = $Scopes -join ' '
$AuthorizeUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/authorize" +
    "?client_id=$([Uri]::EscapeDataString($ClientId))" +
    "&response_type=code" +
    "&redirect_uri=$([Uri]::EscapeDataString($RedirectUri))" +
    "&response_mode=query" +
    "&scope=$([Uri]::EscapeDataString($ScopeText))" +
    "&state=$([Uri]::EscapeDataString($State))" +
    "&code_challenge=$([Uri]::EscapeDataString($Challenge))" +
    "&code_challenge_method=S256" +
    "&prompt=select_account"

Write-Host "Opening browser for Microsoft Entra ID authentication..." -ForegroundColor Cyan
Start-Process -FilePath $AuthorizeUri

$Client = $Listener.AcceptTcpClient()
$Stream = $Client.GetStream()
$Reader = New-Object System.IO.StreamReader($Stream)
$RequestLine = $Reader.ReadLine()

while ($true) {
    $HeaderLine = $Reader.ReadLine()
    if ([string]::IsNullOrEmpty($HeaderLine)) { break }
}

$Html = @"
<!doctype html>
<html>
<head><meta charset="utf-8"><title>Authentication Complete</title></head>
<body style="font-family:Segoe UI,Arial,sans-serif;margin:40px;">
<h2>Authentication Complete</h2>
<p>You can close this browser window and return to PowerShell.</p>
</body>
</html>
"@

$HtmlBytes = [System.Text.Encoding]::UTF8.GetBytes($Html)
$Writer = [System.IO.StreamWriter]::new($Stream, [System.Text.Encoding]::ASCII, 1024, $true)
$Writer.NewLine = "`r`n"
$Writer.WriteLine("HTTP/1.1 200 OK")
$Writer.WriteLine("Content-Type: text/html; charset=utf-8")
$Writer.WriteLine("Content-Length: $($HtmlBytes.Length)")
$Writer.WriteLine("Connection: close")
$Writer.WriteLine("")
$Writer.Flush()
$Stream.Write($HtmlBytes, 0, $HtmlBytes.Length)
$Stream.Flush()
$Writer.Dispose()
$Reader.Dispose()
$Stream.Dispose()
$Client.Close()
$Listener.Stop()

if ($RequestLine -match 'GET\s+/([^\s]*)\s+HTTP') {
    $QueryString = [Uri]::UnescapeDataString($Matches[1])
    $Query = @{}
    foreach ($Pair in ($QueryString -replace '^\?','' -split '&')) {
        $KeyValue = $Pair -split '=', 2
        if ($KeyValue.Count -eq 2) { $Query[$KeyValue[0]] = $KeyValue[1] }
    }
}

if (-not $Query.code) { throw "Authorization code was not returned by Microsoft Entra ID." }
if ($Query.state -ne $State) { throw "State validation failed for the authentication response." }

$TokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
$TokenBody = @{
    client_id     = $ClientId
    grant_type    = "authorization_code"
    code          = $Query.code
    redirect_uri  = $RedirectUri
    code_verifier = $Verifier
    scope         = $ScopeText
}

$TokenResponse = Invoke-RestMethod -Method POST -Uri $TokenUri -Body $TokenBody -ContentType "application/x-www-form-urlencoded" -UseBasicParsing
$global:GraphAccessToken = [string]$TokenResponse.access_token

Write-Host "Successfully connected to Microsoft Graph!`n" -ForegroundColor Green

# -----------------------------------------------------------------------------
# 2. Helper Functions for Device Search & Policy Sync Action
# -----------------------------------------------------------------------------

function Find-GraphManagedDevice {
    param([Parameter(Mandatory)][string]$DeviceName)

    # Search Intune managed devices endpoint
    $Uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=contains(deviceName,'$DeviceName')"
    $Headers = @{ Authorization = "Bearer $global:GraphAccessToken" }

    try {
        $Response = Invoke-RestMethod -Method GET -Uri $Uri -Headers $Headers -UseBasicParsing
        return $Response.value
    }
    catch {
        Write-Error "Failed to search for device: $($_.Exception.Message)"
        return $null
    }
}

function Invoke-IntuneDeviceSync {
    param([Parameter(Mandatory)][string]$ManagedDeviceId)

    $Headers = @{ Authorization = "Bearer $global:GraphAccessToken" }
    
    # Intune managed device remote action: syncDevice
    $Uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$ManagedDeviceId/syncDevice"
    
    try {
        # This action returns an HTTP 204 (No Content) on success
        Invoke-RestMethod -Method POST -Uri $Uri -Headers $Headers -UseBasicParsing
        return $true
    }
    catch {
        Write-Error "Failed to execute policy sync: $($_.Exception.Message)"
        return $false
    }
}

# -----------------------------------------------------------------------------
# 3. Execution Example
# -----------------------------------------------------------------------------
$SearchTarget = Read-Host "Enter computer name to search for"
Write-Host "Searching Intune managed devices for '$SearchTarget'..." -ForegroundColor Cyan

$Devices = Find-GraphManagedDevice -DeviceName $SearchTarget

if (-not $Devices) {
    Write-Host "No matching managed devices found." -ForegroundColor Yellow
} else {
    foreach ($Dev in $Devices) {
        Write-Host "`n----------------------------------------" -ForegroundColor DarkGray
        Write-Host "Device Name  : $($Dev.deviceName)" -ForegroundColor Cyan
        Write-Host "Managed ID   : $($Dev.id)"
        Write-Host "Serial Number: $($Dev.serialNumber)"
        Write-Host "OS Version   : $($Dev.osVersion)"

        $Confirmation = Read-Host "Do you want to trigger a policy sync for this device? (y/n)"
        if ($Confirmation -eq 'y') {
            Write-Host "Triggering Intune policy sync..." -ForegroundColor Yellow
            $Success = Invoke-IntuneDeviceSync -ManagedDeviceId $Dev.id
            
            if ($Success) {
                Write-Host "Success! Policy sync command sent to device." -ForegroundColor Green
            } else {
                Write-Host "Sync command failed." -ForegroundColor Red
            }
        } else {
            Write-Host "Skipped sync for this device." -ForegroundColor DarkGray
        }
    }
}