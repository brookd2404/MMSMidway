# -------------------------------------------------
# Microsoft Graph REST Authentication (Interactive PKCE)
# -------------------------------------------------
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

# 1. Generate PKCE Verifier and Challenge
$RandomBytes = New-Object byte[] 64
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($RandomBytes)
$Verifier = [Convert]::ToBase64String($RandomBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')

$Sha256 = [System.Security.Cryptography.SHA256]::Create()
$ChallengeBytes = $Sha256.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($Verifier))
$Sha256.Dispose()
$Challenge = [Convert]::ToBase64String($ChallengeBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')

# 2. Generate State for validation
$StateBytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($StateBytes)
$State = [Convert]::ToBase64String($StateBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')

# 3. Start Local TCP Listener for Redirect
$Listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$Listener.Start()
$Port = ([System.Net.IPEndPoint]$Listener.LocalEndpoint).Port
$RedirectUri = "http://localhost:$Port/"

# 4. Launch Browser for Sign-In
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

# 5. Capture Callback Response
$Client = $Listener.AcceptTcpClient()
$Stream = $Client.GetStream()
$Reader = New-Object System.IO.StreamReader($Stream)
$RequestLine = $Reader.ReadLine()

while ($true) {
    $HeaderLine = $Reader.ReadLine()
    if ([string]::IsNullOrEmpty($HeaderLine)) { break }
}

# Send basic success HTML response to browser
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

# Parse Authorization Code from Request Line
if ($RequestLine -match 'GET\s+/([^\s]*)\s+HTTP') {
    $QueryString = [Uri]::UnescapeDataString($Matches[1])
    $Query = @{}
    foreach ($Pair in ($QueryString -replace '^\?','' -split '&')) {
        $KeyValue = $Pair -split '=', 2
        if ($KeyValue.Count -eq 2) { $Query[$KeyValue[0]] = $KeyValue[1] }
    }
}

if (-not $Query.code) {
    throw "Authorization code was not returned by Microsoft Entra ID."
}

if ($Query.state -ne $State) {
    throw "State validation failed for the authentication response."
}

# 6. Exchange Authorization Code for Access & Refresh Tokens
$TokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
$TokenBody = @{
    client_id     = $ClientId
    grant_type    = "authorization_code"
    code          = $Query.code
    redirect_uri  = $RedirectUri
    code_verifier = $Verifier
    scope         = $ScopeText
}

$TokenResponse = Invoke-RestMethod `
    -Method POST `
    -Uri $TokenUri `
    -Body $TokenBody `
    -ContentType "application/x-www-form-urlencoded" `
    -UseBasicParsing

# Store tokens globally for downstream requests
$global:GraphAccessToken = [string]$TokenResponse.access_token
$global:GraphRefreshToken = [string]$TokenResponse.refresh_token

Write-Host "Successfully connected to Microsoft Graph!" -ForegroundColor Green

# Test the connection:
$Me = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me" -Headers @{ Authorization = "Bearer $global:GraphAccessToken" }
Write-Host "Connected as: $($Me.userPrincipalName)" -ForegroundColor Cyan