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
    "User.Read.All", "Group.ReadWrite.All", "Directory.Read.All", "Device.Read.All"
)

$script:GraphAccessToken = $null
$script:HelpdeskUPN      = "helpdesk@contoso.com" # Will be updated upon sign-in

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
$form.Text = "Entra ID Group Management & Bulk Audit Tool"
$form.Size = New-Object System.Drawing.Size(900, 680)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.BackColor = $clrBackground
$form.ForeColor = $clrText
$form.Font = $fontMain

# -----------------------------------------------------------------------------
# Top Bar: Sign In & Scoped Group Picker
# -----------------------------------------------------------------------------
$lblGroup = New-Object System.Windows.Forms.Label
$lblGroup.Location = New-Object System.Drawing.Point(15, 20)
$lblGroup.Size = New-Object System.Drawing.Size(90, 23)
$lblGroup.Text = "Owned Groups:"
$form.Controls.Add($lblGroup)

$cmbGroups = New-Object System.Windows.Forms.ComboBox
$cmbGroups.Location = New-Object System.Drawing.Point(110, 17)
$cmbGroups.Size = New-Object System.Drawing.Size(350, 23)
$cmbGroups.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cmbGroups.BackColor = $clrControl
$cmbGroups.ForeColor = $clrText
$form.Controls.Add($cmbGroups)

$btnSignIn = New-Object System.Windows.Forms.Button
$btnSignIn.Location = New-Object System.Drawing.Point(475, 15)
$btnSignIn.Size = New-Object System.Drawing.Size(120, 27)
$btnSignIn.Text = "Sign In"
$btnSignIn.BackColor = $clrControl
$btnSignIn.ForeColor = $clrText
$btnSignIn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$form.Controls.Add($btnSignIn)

# -----------------------------------------------------------------------------
# Tab Control (Single Add vs Bulk & Audit)
# -----------------------------------------------------------------------------
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(15, 55)
$tabControl.Size = New-Object System.Drawing.Size(855, 340)
$tabControl.BackColor = $clrBackground

# --- Tab 1: Single Add & Disambiguation ---
$tabSingle = New-Object System.Windows.Forms.TabPage
$tabSingle.Text = "Single UPN / Device Add"
$tabSingle.BackColor = $clrPanel

$lblTarget = New-Object System.Windows.Forms.Label
$lblTarget.Location = New-Object System.Drawing.Point(20, 25)
$lblTarget.Size = New-Object System.Drawing.Size(130, 20)
$lblTarget.Text = "Target (UPN or Device):"
$tabSingle.Controls.Add($lblTarget)

$txtTarget = New-Object System.Windows.Forms.TextBox
$txtTarget.Location = New-Object System.Drawing.Point(160, 22)
$txtTarget.Size = New-Object System.Drawing.Size(300, 23)
$txtTarget.BackColor = $clrControl
$txtTarget.ForeColor = $clrText
$tabSingle.Controls.Add($txtTarget)

$rbUser = New-Object System.Windows.Forms.RadioButton
$rbUser.Location = New-Object System.Drawing.Point(480, 23)
$rbUser.Size = New-Object System.Drawing.Size(60, 20)
$rbUser.Text = "User"
$rbUser.Checked = $true
$rbUser.ForeColor = $clrText
$tabSingle.Controls.Add($rbUser)

$rbDevice = New-Object System.Windows.Forms.RadioButton
$rbDevice.Location = New-Object System.Drawing.Point(545, 23)
$rbDevice.Size = New-Object System.Drawing.Size(70, 20)
$rbDevice.Text = "Device"
$rbDevice.ForeColor = $clrText
$tabSingle.Controls.Add($rbDevice)

$btnAddSingle = New-Object System.Windows.Forms.Button
$btnAddSingle.Location = New-Object System.Drawing.Point(630, 20)
$btnAddSingle.Size = New-Object System.Drawing.Size(185, 27)
$btnAddSingle.Text = "Resolve & Add to Group"
$btnAddSingle.BackColor = $clrAccent
$btnAddSingle.ForeColor = $clrText
$btnAddSingle.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$tabSingle.Controls.Add($btnAddSingle)

# Disambiguation / Status Grid for Single Add
$gridDisambiguation = New-Object System.Windows.Forms.DataGridView
$gridDisambiguation.Location = New-Object System.Drawing.Point(20, 65)
$gridDisambiguation.Size = New-Object System.Drawing.Size(795, 230)
$gridDisambiguation.BackgroundColor = $clrBackground
$gridDisambiguation.ForeColor = [System.Drawing.Color]::Black
$gridDisambiguation.AllowUserToAddRows = $false
$gridDisambiguation.ReadOnly = $true
$gridDisambiguation.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
$gridDisambiguation.RowHeadersVisible = $false
$tabSingle.Controls.Add($gridDisambiguation)

$tabControl.Controls.Add($tabSingle)

# --- Tab 2: Bulk CSV & Audit ---
$tabBulk = New-Object System.Windows.Forms.TabPage
$tabBulk.Text = "Bulk CSV & Audit"
$tabBulk.BackColor = $clrPanel

$btnLoadCsv = New-Object System.Windows.Forms.Button
$btnLoadCsv.Location = New-Object System.Drawing.Point(20, 15)
$btnLoadCsv.Size = New-Object System.Drawing.Size(140, 27)
$btnLoadCsv.Text = "Load Sample CSV"
$btnLoadCsv.BackColor = $clrControl
$btnLoadCsv.ForeColor = $clrText
$btnLoadCsv.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$tabBulk.Controls.Add($btnLoadCsv)

$btnProcessBulk = New-Object System.Windows.Forms.Button
$btnProcessBulk.Location = New-Object System.Drawing.Point(175, 15)
$btnProcessBulk.Size = New-Object System.Drawing.Size(160, 27)
$btnProcessBulk.Text = "Confirm & Bulk Add"
$btnProcessBulk.BackColor = $clrAccent
$btnProcessBulk.ForeColor = $clrText
$btnProcessBulk.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$tabBulk.Controls.Add($btnProcessBulk)

# Bulk Preview & Edit Grid (Editable so user can fix the intentionally bad row)
$gridBulk = New-Object System.Windows.Forms.DataGridView
$gridBulk.Location = New-Object System.Drawing.Point(20, 55)
$gridBulk.Size = New-Object System.Drawing.Size(795, 235)
$gridBulk.BackgroundColor = $clrBackground
$gridBulk.ForeColor = [System.Drawing.Color]::Black
$gridBulk.AllowUserToAddRows = $true
$gridBulk.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
$tabBulk.Controls.Add($gridBulk)

$tabControl.Controls.Add($tabBulk)
$form.Controls.Add($tabControl)

# -----------------------------------------------------------------------------
# Bottom Section: Local Audit Log Preview
# -----------------------------------------------------------------------------
$grpAudit = New-Object System.Windows.Forms.GroupBox
$grpAudit.Location = New-Object System.Drawing.Point(15, 405)
$grpAudit.Size = New-Object System.Drawing.Size(855, 225)
$grpAudit.Text = "Audit Log Preview (Helpdesk UPN & Timestamp Stamped)"
$grpAudit.ForeColor = $clrText

$gridAudit = New-Object System.Windows.Forms.DataGridView
$gridAudit.Location = New-Object System.Drawing.Point(15, 25)
$gridAudit.Size = New-Object System.Drawing.Size(825, 185)
$gridAudit.BackgroundColor = $clrPanel
$gridAudit.ForeColor = [System.Drawing.Color]::Black
$gridAudit.AllowUserToAddRows = $false
$gridAudit.ReadOnly = $true
$gridAudit.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
$gridAudit.RowHeadersVisible = $false

$gridAudit.Columns.Add("Timestamp", "Timestamp") | Out-Null
$gridAudit.Columns.Add("HelpdeskUPN", "Helpdesk UPN") | Out-Null
$gridAudit.Columns.Add("Target", "Target / UPN / Device") | Out-Null
$gridAudit.Columns.Add("GroupName", "Group") | Out-Null
$gridAudit.Columns.Add("Result", "Result") | Out-Null

$grpAudit.Controls.Add($gridAudit)
$form.Controls.Add($grpAudit)

# Helper function to add audit log entries
function Write-AuditLog {
    param([string]$Target, [string]$GroupName, [string]$Result)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $gridAudit.Rows.Add($timestamp, $script:HelpdeskUPN, $Target, $GroupName, $Result) | Out-Null
    $gridAudit.FirstDisplayedScrollingRowIndex = $gridAudit.Rows.Count - 1
}

# -----------------------------------------------------------------------------
# Event Handlers & API Wiring
# -----------------------------------------------------------------------------

# 1. Sign In & Load Owned Groups
$btnSignIn.Add_Click({
    try {
        $btnSignIn.Enabled = $false

        # PKCE Authentication Flow
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

        # Get signed-in user UPN
        $MeResponse = Invoke-RestMethod -Method GET -Uri "https://graph.microsoft.com/v1.0/me" -Headers @{ Authorization = "Bearer $($script:GraphAccessToken)" } -UseBasicParsing
        $script:HelpdeskUPN = $MeResponse.userPrincipalName

        # Load ONLY owned groups (Scoped Picker)
        $GroupsResponse = Invoke-RestMethod -Method GET -Uri "https://graph.microsoft.com/v1.0/me/ownedObjects/microsoft.graph.group" -Headers @{ Authorization = "Bearer $($script:GraphAccessToken)" } -UseBasicParsing
        
        $cmbGroups.Items.Clear()
        foreach ($grp in $GroupsResponse.value) {
            $cmbGroups.Items.Add([PSCustomObject]@{ Name = $grp.displayName; Id = $grp.id })
        }
        $cmbGroups.DisplayMember = "Name"
        $cmbGroups.ValueMember = "Id"
        if ($cmbGroups.Items.Count -gt 0) { $cmbGroups.SelectedIndex = 0 }

        $btnSignIn.Text = "Connected"
        $btnSignIn.BackColor = $clrGreen
        [System.Windows.Forms.MessageBox]::Show("Signed in as $($script:HelpdeskUPN). Loaded owned groups successfully.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Sign-in failed: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        $btnSignIn.Enabled = $true
    }
})

# 2. Single Add & Disambiguation Logic
$btnAddSingle.Add_Click({
    if ([string]::IsNullOrWhiteSpace($script:GraphAccessToken) -or -not $cmbGroups.SelectedItem) {
        [System.Windows.Forms.MessageBox]::Show("Please sign in and select a group first.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $targetValue = $txtTarget.Text.Trim()
    $selectedGroup = $cmbGroups.SelectedItem
    $headers = @{ Authorization = "Bearer $($script:GraphAccessToken)" }

    try {
        $objectId = $null

        if ($rbUser.Checked) {
            # Single UPN Resolve
            $userUri = "https://graph.microsoft.com/v1.0/users/$targetValue"
            $userResp = Invoke-RestMethod -Method GET -Uri $userUri -Headers $headers -UseBasicParsing
            $objectId = $userResp.id
        } else {
            # Device Search with Disambiguation Grid
            $devUri = "https://graph.microsoft.com/v1.0/devices?`$filter=startsWith(displayName,'$targetValue')"
            $devResp = Invoke-RestMethod -Method GET -Uri $devUri -Headers $headers -UseBasicParsing

            if (-not $devResp.value -or $devResp.value.Count -eq 0) {
                Write-AuditLog $targetValue $selectedGroup.Name "Not Found"
                [System.Windows.Forms.MessageBox]::Show("Device not found.", "Result", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                return
            }

            if ($devResp.value.Count -gt 1) {
                # Populate Disambiguation Grid
                $gridDisambiguation.DataSource = $devResp.value | Select-Object displayName, deviceId, id, operatingSystem
                [System.Windows.Forms.MessageBox]::Show("Multiple matches found. Review the disambiguation grid.", "Disambiguation Required", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                return
            } else {
                $objectId = $devResp.value[0].id
            }
        }

        # Two-step Object ID resolve -> Add to group
        if ($objectId) {
            $addUri = "https://graph.microsoft.com/v1.0/groups/$($selectedGroup.Id)/members/`$ref"
            $body = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$objectId" } | ConvertTo-Json
            
            Invoke-RestMethod -Method POST -Uri $addUri -Headers $headers -Body $body -ContentType "application/json" -UseBasicParsing
            
            Write-AuditLog $targetValue $selectedGroup.Name "Success"
            [System.Windows.Forms.MessageBox]::Show("Successfully added $targetValue to $($selectedGroup.Name)!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }
    catch {
        Write-AuditLog $targetValue $selectedGroup.Name "Failed"
        [System.Windows.Forms.MessageBox]::Show("Operation failed: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

# 3. Bulk CSV & Editable Preview with Intentionally Bad Row
$btnLoadCsv.Add_Click({
    $dt = New-Object System.Data.DataTable
    $dt.Columns.Add("Type", [string])
    $dt.Columns.Add("Target", [string])
    $dt.Columns.Add("Status", [string])

    # Populate with sample data, including an intentionally bad row ("bad-row-here")
    $dt.Rows.Add("User", "jsmith@contoso.com", "Ready") | Out-Null
    $dt.Rows.Add("Device", "DESKTOP-4XR21", "Ready") | Out-Null
    $dt.Rows.Add("User", "bad-row-here", "Ready") | Out-Null # Intentionally bad row to fix

    $gridBulk.DataSource = $dt
})

# Process Bulk Add with Live Per-Row Status
$btnProcessBulk.Add_Click({
    if ([string]::IsNullOrWhiteSpace($script:GraphAccessToken) -or -not $cmbGroups.SelectedItem) {
        [System.Windows.Forms.MessageBox]::Show("Please sign in and select a group first.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $selectedGroup = $cmbGroups.SelectedItem
    $headers = @{ Authorization = "Bearer $($script:GraphAccessToken)" }

    foreach ($row in $gridBulk.Rows) {
        if ($row.IsNewRow) { continue }
        $type = $row.Cells["Type"].Value
        $target = $row.Cells["Target"].Value

        if ([string]::IsNullOrWhiteSpace($target)) { continue }

        try {
            $objectId = $null
            if ($type -eq "User") {
                $resp = Invoke-RestMethod -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$target" -Headers $headers -UseBasicParsing
                $objectId = $resp.id
            } else {
                $resp = Invoke-RestMethod -Method GET -Uri "https://graph.microsoft.com/v1.0/devices?`$filter=displayName eq '$target'" -Headers $headers -UseBasicParsing
                if ($resp.value) { $objectId = $resp.value[0].id }
            }

            if ($objectId) {
                $addUri = "https://graph.microsoft.com/v1.0/groups/$($selectedGroup.Id)/members/`$ref"
                $body = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$objectId" } | ConvertTo-Json
                Invoke-RestMethod -Method POST -Uri $addUri -Headers $headers -Body $body -ContentType "application/json" -UseBasicParsing

                $row.Cells["Status"].Value = "Success"
                Write-AuditLog $target $selectedGroup.Name "Success"
            } else {
                throw "Object not found"
            }
        }
        catch {
            $row.Cells["Status"].Value = "Not Found / Failed"
            Write-AuditLog $target $selectedGroup.Name "Not Found"
        }
    }
    [System.Windows.Forms.MessageBox]::Show("Bulk processing complete!", "Finished", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

# -----------------------------------------------------------------------------
# Launch Application
# -----------------------------------------------------------------------------
[void]$form.ShowDialog()