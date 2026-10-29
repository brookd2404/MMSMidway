Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

# -----------------------------------------------------------------------------
# Color Palette (Dark Theme)
# -----------------------------------------------------------------------------
$clrBackground = [System.Drawing.Color]::FromArgb(30, 30, 30)
$clrPanel      = [System.Drawing.Color]::FromArgb(45, 45, 48)
$clrControl    = [System.Drawing.Color]::FromArgb(63, 63, 70)
$clrText       = [System.Drawing.Color]::FromArgb(241, 241, 241)
$clrAccent     = [System.Drawing.Color]::FromArgb(0, 122, 204)
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
# Add placeholder clear behavior
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
# Device Info GroupBox (Left Middle)
# -----------------------------------------------------------------------------
$grpDeviceInfo = New-Object System.Windows.Forms.GroupBox
$grpDeviceInfo.Location = New-Object System.Drawing.Point(15, 55)
$grpDeviceInfo.Size = New-Object System.Drawing.Size(540, 275)
$grpDeviceInfo.Text = "Device Info"
$grpDeviceInfo.ForeColor = $clrText

$txtDeviceInfo = New-Object System.Windows.Forms.TextBox
$txtDeviceInfo.Location = New-Object System.Drawing.Point(15, 25)
$txtDeviceInfo.Size = New-Object System.Drawing.Size(510, 235)
$txtDeviceInfo.Multiline = $true
$txtDeviceInfo.ReadOnly = $true
$txtDeviceInfo.BackColor = $clrPanel
$txtDeviceInfo.ForeColor = $clrText
$txtDeviceInfo.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$grpDeviceInfo.Controls.Add($txtDeviceInfo)

$form.Controls.Add($grpDeviceInfo)

# -----------------------------------------------------------------------------
# Quick Actions GroupBox (Right Middle - 3 buttons requested)
# -----------------------------------------------------------------------------
$grpActions = New-Object System.Windows.Forms.GroupBox
$grpActions.Location = New-Object System.Drawing.Point(565, 55)
$grpActions.Size = New-Object System.Drawing.Size(245, 275)
$grpActions.Text = "Quick Actions"
$grpActions.ForeColor = $clrText

$btnLapsKey = New-Object System.Windows.Forms.Button
$btnLapsKey.Location = New-Object System.Drawing.Point(20, 35)
$btnLapsKey.Size = New-Object System.Drawing.Size(205, 32)
$btnLapsKey.Text = "LAPS Key"
$btnLapsKey.BackColor = $clrControl
$btnLapsKey.ForeColor = $clrText
$btnLapsKey.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$grpActions.Controls.Add($btnLapsKey)

$btnBitLockerKey = New-Object System.Windows.Forms.Button
$btnBitLockerKey.Location = New-Object System.Drawing.Point(20, 80)
$btnBitLockerKey.Size = New-Object System.Drawing.Size(205, 32)
$btnBitLockerKey.Text = "BitLocker Key"
$btnBitLockerKey.BackColor = $clrControl
$btnBitLockerKey.ForeColor = $clrText
$btnBitLockerKey.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$grpActions.Controls.Add($btnBitLockerKey)

$btnSyncNow = New-Object System.Windows.Forms.Button
$btnSyncNow.Location = New-Object System.Drawing.Point(20, 125)
$btnSyncNow.Size = New-Object System.Drawing.Size(205, 32)
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

# Add Columns matching reference image
$gridLog.Columns.Add("Timestamp", "Timestamp") | Out-Null
$gridLog.Columns.Add("User", "User") | Out-Null
$gridLog.Columns.Add("Action", "Action") | Out-Null
$gridLog.Columns.Add("Result", "Result") | Out-Null

# Add a sample placeholder row
$gridLog.Rows.Add((Get-Date -Format "yyyy-MM-dd HH:mm:ss"), "$env:USERNAME", "Application Initialized", "Success") | Out-Null

$form.Controls.Add($gridLog)

# -----------------------------------------------------------------------------
# Show Form Dialog
# -----------------------------------------------------------------------------
[void]$form.ShowDialog()