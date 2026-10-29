Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

# -----------------------------------------------------------------------------
# Configuration & State Variables
# -----------------------------------------------------------------------------
$TenantId = "<YourTenantID>"
$ClientId = "<YourClientID>"
$Scopes   = @(
    "openid", "profile", "offline_access",
    "BitlockerKey.Read.All", "Device.Read.All", "Directory.Read.All",
    "DeviceManagementManagedDevices.ReadWrite.All",
    "DeviceManagementManagedDevices.PrivilegedOperations.All",
    "DeviceLocalCredential.Read.All"
)

$script:GraphAccessToken = $null
$script:CurrentDevice      = $null # Will hold the selected device object

# -----------------------------------------------------------------------------
# Color Palette (Dark Theme)
# -----------------------------------------------------------------------------
$clrBackground = [System.Drawing.Color]::FromArgb(30, 30, 30)
$clrPanel      = [System.Drawing.Color]::FromArgb(45, 45, 48)
$clrControl    = [System.Drawing.Color]::FromArgb(63, 63, 70)
$clrText       = [System.Drawing.Color]::FromArgb(241, 241, 241)
$clrAccent     = [System.Drawing.Color]::FromArgb(0, 122, 204)
$clrGreen      = [System.Drawing.Color]::FromArgb(40, 167, 69)
$fontMain      = New-Object System.Drawing.Font("Segoe UI", 9)

# -----------------------------------------------------------------------------
# Create Main Form
# -----------------------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Helpdesk Tool v1.0 - Powered by Microsoft Graph"
$form.Size = New-Object System.Drawing.Size(840, 580)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.BackColor = $clrBackground
$form.ForeColor = $clrText
$form.Font = $fontMain

# -----------------------------------------------------------------------------
# Top Controls (Search & Sign In)
# -----------------------------------------------------------------------------
$txtSearch = New-Object System.Windows.Forms.TextBox
$txtSearch.Location = New-Object System.Drawing.Point(15, 18)
$txtSearch.Size = New-Object System.Drawing.Size(430, 23)
$txtSearch.Text = "Device name, serial, or username"
$txtSearch.ForeColor = [System.Drawing.Color]::Gray
$txtSearch.BackColor = $clrControl
$txtSearch.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$form.Controls.Add($txtSearch)

$btnSignIn = New-Object System.Windows.Forms.Button
$btnSignIn.Location = New-Object System.Drawing.Point(455, 16)
$btnSignIn.Size = New-Object System.Drawing.Size(95, 27)
$btnSignIn.Text = "Sign In"
$btnSignIn.BackColor = $clrControl
$btnSignIn.ForeColor = $clrText
$btnSignIn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$form.Controls.Add($btnSignIn)

$btnSearch = New-Object System.Windows.Forms.Button
$btnSearch.Location = New-Object System.Drawing.Point(560, 16)
$btnSearch.Size = New-Object System.Drawing.Size(95, 27)
$btnSearch.Text = "Search"
$btnSearch.BackColor = $clrAccent
$btnSearch.ForeColor = $clrText
$btnSearch.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$form.Controls.Add($btnSearch)

# -----------------------------------------------------------------------------
# Device Info GroupBox (Left Top)
# -----------------------------------------------------------------------------
$grpDeviceInfo = New-Object System.Windows.Forms.GroupBox
$grpDeviceInfo.Location = New-Object System.Drawing.Point(15, 55)
$grpDeviceInfo.Size = New-Object System.Drawing.Size(540, 155)
$grpDeviceInfo.Text = "Device Info"
$grpDeviceInfo.ForeColor = $clrText

$txtDeviceInfo = New-Object System.Windows.Forms.TextBox
$txtDeviceInfo.Location = New-Object System.Drawing.Point(12, 22)
$txtDeviceInfo.Size = New-Object System.Drawing.Size(515, 120)
$txtDeviceInfo.Multiline = $true
$txtDeviceInfo.ReadOnly = $true
$txtDeviceInfo.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtDeviceInfo.BackColor = $clrPanel
$txtDeviceInfo.ForeColor = $clrText
$txtDeviceInfo.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$txtDeviceInfo.Text = "Please sign in and search for a device to begin..."
$grpDeviceInfo.Controls.Add($txtDeviceInfo)

$form.Controls.Add($grpDeviceInfo)

# -----------------------------------------------------------------------------
# Secrets / Recovery Output GroupBox (Left Bottom)
# -----------------------------------------------------------------------------
$grpSecrets = New-Object System.Windows.Forms.GroupBox
$grpSecrets.Location = New-Object System.Drawing.Point(15, 215)
$grpSecrets.Size = New-Object System.Drawing.Size(540, 115)
$grpSecrets.Text = "Secrets / Recovery Output"
$grpSecrets.ForeColor = $clrText

$txtSecretOutput = New-Object System.Windows.Forms.TextBox
$txtSecretOutput.Location = New-Object System.Drawing.Point(12, 22)
$txtSecretOutput.Size = New-Object System.Drawing.Size(415, 80)
$txtSecretOutput.Multiline = $true
$txtSecretOutput.ReadOnly = $false # Editable/selectable for easy manual copying if needed
$txtSecretOutput.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtSecretOutput.BackColor = $clrPanel
$txtSecretOutput.ForeColor = $clrText
$txtSecretOutput.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$grpSecrets.Controls.Add($txtSecretOutput)

$btnCopySecret = New-Object System.Windows.Forms.Button
$btnCopySecret.Location = New-Object System.Drawing.Point(435, 22)
$btnCopySecret.Size = New-Object System.Drawing.Size(90, 80)
$btnCopySecret.Text = "Copy"
$btnCopySecret.BackColor = $clrControl
$btnCopySecret.ForeColor = $clrText
$btnCopySecret.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnCopySecret.Add_Click({
    if (-not [string]::IsNullOrWhiteSpace($txtSecretOutput.Text)) {
        [System.Windows.Forms.Clipboard]::SetText($txtSecretOutput.Text)
        [System.Windows.Forms.MessageBox]::Show("Copied to clipboard!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } else {
        [System.Windows.Forms.MessageBox]::Show("Nothing to copy.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
})
$grpSecrets.Controls.Add($btnCopySecret)

$form.Controls.Add($grpSecrets)

# -----------------------------------------------------------------------------
# Quick Actions GroupBox (Right Middle)
# -----------------------------------------------------------------------------
$grpActions = New-Object System.Windows.Forms.GroupBox
$grpActions.Location = New-Object System.Drawing.Point(565, 55)
$grpActions.Size = New-Object System.Drawing.Size(245, 275)
$grpActions.Text = "Quick Actions"
$grpActions.ForeColor = $clrText

$btnLapsKey = New-Object System.Windows.Forms.Button
$btnLapsKey.Location = New-Object System.Drawing.Point(20, 45)
$btnLapsKey.Size = New-Object System.Drawing.Size(205, 35)
$btnLapsKey.Text = "LAPS Key"
$btnLapsKey.BackColor = $clrControl
$btnLapsKey.ForeColor = $clrText
$btnLapsKey.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$grpActions.Controls.Add($btnLapsKey)

$btnBitLockerKey = New-Object System.Windows.Forms.Button
$btnBitLockerKey.Location = New-Object System.Drawing.Point(20, 105)
$btnBitLockerKey.Size = New-Object System.Drawing.Size(205, 35)
$btnBitLockerKey.Text = "BitLocker Key"
$btnBitLockerKey.BackColor = $clrControl
$btnBitLockerKey.ForeColor = $clrText
$btnBitLockerKey.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$grpActions.Controls.Add($btnBitLockerKey)

$btnSyncNow = New-Object System.Windows.Forms.Button
$btnSyncNow.Location = New-Object System.Drawing.Point(20, 165)
$btnSyncNow.Size = New-Object System.Drawing.Size(205, 35)
$btnSyncNow.Text = "Sync Now"
$btnSyncNow.BackColor = $clrControl
$btnSyncNow.ForeColor = $clrText
$btnSyncNow.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$grpActions.Controls.Add($btnSyncNow)

$form.Controls.Add($grpActions)

# -----------------------------------------------------------------------------
# Bottom DataGridView (Audit Log)
# -----------------------------------------------------------------------------
$gridLog = New-Object System.Windows.Forms.DataGridView
$gridLog.Location = New-Object System.Drawing.Point(15, 345)
$gridLog.Size = New-Object System.Drawing.Size(795, 180)
$gridLog.BackgroundColor = $clrPanel
$gridLog.ForeColor = [System.Drawing.Color]::Black
$gridLog.AllowUserToAddRows = $false
$gridLog.ReadOnly = $true
$gridLog.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
$gridLog.RowHeadersVisible = $false

$gridLog.Columns.Add("Timestamp", "Timestamp") | Out-Null
$gridLog.Columns.Add("User", "User") | Out-Null
$gridLog.Columns.Add("Action", "Action") | Out-Null
$gridLog.Columns.Add("Result", "Result") | Out-Null

$form.Controls.Add($gridLog)

# Helper function to add audit log entries
function Write-AuditLog {
    param([string]$Action, [string]$Result)
    $gridLog.Rows.Add((Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $env:USERNAME, $Action, $Result) | Out-Null
    $gridLog.FirstDisplayedScrollingRowIndex = $gridLog.Rows.Count - 1
}

# -----------------------------------------------------------------------------
# Event Handlers & API Wiring
# -----------------------------------------------------------------------------

# Placeholder Text Handling
$txtSearch.Add_Enter({
    if ($this.Text -eq "Device name, serial, or username") {
        $this.Text = ""
        $this.ForeColor = $clrText
    }
})
$txtSearch.Add_Leave({
    if ([string]::IsNullOrWhiteSpace($this.Text)) {
        $this.Text = "Device name, serial, or username"
        $this.ForeColor = [System.Drawing.Color]::Gray
    }
})

# 1. Sign In Button Event
$btnSignIn.Add_Click({
    try {
        $btnSignIn.Enabled = $false
        $txtDeviceInfo.Text = "Initializing interactive sign-in browser..."

        # PKCE Generation
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

        Start-Process -FilePath $AuthorizeUri

        $Client = $Listener.AcceptTcpClient()
        $Stream = $Client.GetStream()
        $Reader = New-Object System.IO.StreamReader($Stream)
        $RequestLine = $Reader.ReadLine()
        while ($true) {
            $HeaderLine = $Reader.ReadLine()
            if ([string]::IsNullOrEmpty($HeaderLine)) { break }
        }

        # Send response to browser
        $Html = "<html><body><h2>Authentication Complete. You can close this window.</h2></body></html>"
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

        if (-not $Query.code) { throw "Authorization code not returned." }

        # Exchange code for token
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
        $script:GraphAccessToken = [string]$TokenResponse.access_token

        $btnSignIn.Text = "Connected"
        $btnSignIn.BackColor = $clrGreen
        $txtDeviceInfo.Text = "Authentication successful! Ready to search for devices."
        Write-AuditLog "Sign In" "Success"
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Authentication failed: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        $txtDeviceInfo.Text = "Authentication failed."
        Write-AuditLog "Sign In" "Failed"
    }
    finally {
        $btnSignIn.Enabled = $true
    }
})

# 2. Search Button Event
$btnSearch.Add_Click({
    if ([string]::IsNullOrWhiteSpace($script:GraphAccessToken)) {
        [System.Windows.Forms.MessageBox]::Show("Please sign in first.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $SearchTerm = $txtSearch.Text.Trim()
    if ($SearchTerm -eq "" -or $SearchTerm -eq "Device name, serial, or username") {
        [System.Windows.Forms.MessageBox]::Show("Please enter a device name to search.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    try {
        $txtDeviceInfo.Text = "Searching Microsoft Graph..."
        $Headers = @{ Authorization = "Bearer $($script:GraphAccessToken)" }

        # Search Intune managed devices
        $Uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=contains(deviceName,'$SearchTerm')"
        $Response = Invoke-RestMethod -Method GET -Uri $Uri -Headers $Headers -UseBasicParsing

        if (-not $Response.value -or $Response.value.Count -eq 0) {
            $txtDeviceInfo.Text = "No matching managed devices found for '$SearchTerm'."
            $script:CurrentDevice = $null
            Write-AuditLog "Device Search ($SearchTerm)" "No Results"
            return
        }

        $script:CurrentDevice = $Response.value[0] # Grab first match
        
        # Also grab Entra Directory Device ID for LAPS
        $DirUri = "https://graph.microsoft.com/v1.0/devices?`$filter=startsWith(displayName,'$($script:CurrentDevice.deviceName)')"
        $DirResponse = Invoke-RestMethod -Method GET -Uri $DirUri -Headers $Headers -UseBasicParsing
        if ($DirResponse.value) {
            $script:CurrentDevice | Add-Member -NotePropertyName "directoryId" -NotePropertyValue $DirResponse.value[0].id -Force
        }

        # Format details on screen
        $infoText = @"
Device Name   : $($script:CurrentDevice.deviceName)
Model         : $($script:CurrentDevice.model)
Serial Number : $($script:CurrentDevice.serialNumber)
Managed ID    : $($script:CurrentDevice.id)
Azure AD ID   : $($script:CurrentDevice.azureAdDeviceId)
Directory ID  : $($script:CurrentDevice.directoryId)
OS Version    : $($script:CurrentDevice.osVersion)
Last Sync     : $($script:CurrentDevice.lastSyncDateTime)
"@
        $txtDeviceInfo.Text = $infoText
        Write-AuditLog "Device Search ($SearchTerm)" "Found: $($script:CurrentDevice.deviceName)"
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Search error: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        Write-AuditLog "Device Search ($SearchTerm)" "Error"
    }
})

# 3. LAPS Key Button Event (Supports both Intune and Entra device property schemas)
$btnLapsKey.Add_Click({
    # Resolve device ID from either Intune (.azureAdDeviceId) or Entra (.deviceId) property
    $targetId = $null
    if ($script:CurrentDevice) {
        if ($script:CurrentDevice.azureAdDeviceId) { 
            $targetId = $script:CurrentDevice.azureAdDeviceId 
        } elseif ($script:CurrentDevice.deviceId) { 
            $targetId = $script:CurrentDevice.deviceId 
        }
    }

    if (-not $targetId) {
        [System.Windows.Forms.MessageBox]::Show("Please search and select a valid device first.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    try {
        $Headers = @{ Authorization = "Bearer $($script:GraphAccessToken)" }
        
        # Correct Microsoft Graph REST endpoint with escaped question mark and select parameter
        $Uri = "https://graph.microsoft.com/v1.0/directory/deviceLocalCredentials/$targetId`?`$select=credentials"
        $Response = Invoke-RestMethod -Method GET -Uri $Uri -Headers $Headers -UseBasicParsing

        if ($Response -and $Response.credentials) {
            $credObj = if ($Response.credentials -is [array]) { $Response.credentials[0] } else { $Response.credentials }
            $accountName = if ($credObj.accountName) { $credObj.accountName } else { "BuiltInAdmin" }
            $rawPass = "Password property not found."

            if ($credObj.passwordBase64) {
                $bytes = [Convert]::FromBase64String($credObj.passwordBase64)
                $rawPass = [System.Text.Encoding]::UTF8.GetString($bytes)
            }

            $deviceName = if ($script:CurrentDevice.deviceName) { $script:CurrentDevice.deviceName } else { $script:CurrentDevice.displayName }
            $txtSecretOutput.Text = "Device Name  : $deviceName`r`nAccount Name : $accountName`r`nPassword     : $rawPass"
            Write-AuditLog "Get LAPS Key" "Success"
        } else {
            $txtSecretOutput.Text = "No LAPS credentials found for this device."
            Write-AuditLog "Get LAPS Key" "Not Found"
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to retrieve LAPS key: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        Write-AuditLog "Get LAPS Key" "Failed"
    }
})

# 4. BitLocker Key Button Event (Outputs to Secrets box)
$btnBitLockerKey.Add_Click({
    if (-not $script:CurrentDevice -or -not $script:CurrentDevice.azureAdDeviceId) {
        [System.Windows.Forms.MessageBox]::Show("Device is missing an Azure AD Device ID.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    try {
        $Headers = @{ Authorization = "Bearer $($script:GraphAccessToken)" }
        $ListUri = "https://graph.microsoft.com/v1.0/informationProtection/bitlocker/recoveryKeys?`$filter=deviceId eq '$($script:CurrentDevice.azureAdDeviceId)'"
        $ListResponse = Invoke-RestMethod -Method GET -Uri $ListUri -Headers $Headers -UseBasicParsing

        if (-not $ListResponse.value -or $ListResponse.value.Count -eq 0) {
            $txtSecretOutput.Text = "No BitLocker recovery keys found for this device."
            Write-AuditLog "Get BitLocker Key" "Not Found"
            return
        }

        $KeyObj = $ListResponse.value[0]
        $DetailUri = "https://graph.microsoft.com/v1.0/informationProtection/bitlocker/recoveryKeys/$($KeyObj.id)?`$select=key"
        $DetailResponse = Invoke-RestMethod -Method GET -Uri $DetailUri -Headers $Headers -UseBasicParsing

        $txtSecretOutput.Text = "Key ID       : $($KeyObj.id)`r`nRecovery Key : $($DetailResponse.key)`r`nVolume Type  : $($KeyObj.volumeType)"
        Write-AuditLog "Get BitLocker Key" "Success"
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to retrieve BitLocker key: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        Write-AuditLog "Get BitLocker Key" "Failed"
    }
})

# 5. Sync Now Button Event
$btnSyncNow.Add_Click({
    if (-not $script:CurrentDevice -or -not $script:CurrentDevice.id) {
        [System.Windows.Forms.MessageBox]::Show("Please search and select a valid device first.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    try {
        $Headers = @{ Authorization = "Bearer $($script:GraphAccessToken)" }
        $Uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$($script:CurrentDevice.id)/syncDevice"
        Invoke-RestMethod -Method POST -Uri $Uri -Headers $Headers -UseBasicParsing

        [System.Windows.Forms.MessageBox]::Show("Policy sync command successfully sent to $($script:CurrentDevice.deviceName).", "Sync Triggered", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        Write-AuditLog "Sync Policy" "Success"
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to trigger sync: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        Write-AuditLog "Sync Policy" "Failed"
    }
})

# -----------------------------------------------------------------------------
# Launch Application
# -----------------------------------------------------------------------------
[void]$form.ShowDialog()