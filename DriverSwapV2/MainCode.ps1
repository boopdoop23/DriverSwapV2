Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Add Windows API for dark title bar and scrollbar control
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class DarkMode {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
    
    [DllImport("user32.dll")]
    public static extern IntPtr GetWindowLong(IntPtr hWnd, int nIndex);
    
    [DllImport("user32.dll")]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, IntPtr dwNewLong);
    
    [DllImport("user32.dll")]
    public static extern bool ShowScrollBar(IntPtr hWnd, int wBar, bool bShow);
    
    [DllImport("user32.dll")]
    public static extern int SetScrollPos(IntPtr hWnd, int nBar, int nPos, bool bRedraw);
    
    [DllImport("user32.dll")]
    public static extern int GetScrollPos(IntPtr hWnd, int nBar);
    
    public const int DWMWA_USE_IMMERSIVE_DARK_MODE_BEFORE_20H1 = 19;
    public const int DWMWA_USE_IMMERSIVE_DARK_MODE = 20;
    public const int GWL_EXSTYLE = -20;
    public const int WS_EX_LAYERED = 0x80000;
    public const int SB_VERT = 1;
    public const int SB_HORZ = 0;
    public const int SB_BOTH = 3;
}
"@

# Configuration file path
$configFile = Join-Path $PSScriptRoot "Directory.json"

# Load configuration
function Load-Config {
    if (Test-Path $configFile) {
        try {
            return Get-Content $configFile | ConvertFrom-Json
        } catch {
            return @{ ACRootPath = ""; SourceFolderPath = "" }
        }
    }
    return @{ ACRootPath = ""; SourceFolderPath = "" }
}

# Save configuration
function Save-Config($config) {
    $config | ConvertTo-Json | Set-Content $configFile
}

# Custom button creation function with rounded corners and hover effects
function Create-RoundedButton($x, $y, $width, $height, $text) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Location = New-Object System.Drawing.Point($x, $y)
    $btn.Size = New-Object System.Drawing.Size($width, $height)
    $btn.Text = $text
    $btn.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)  # Dark background
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.FlatStyle = "Flat"
    $btn.FlatAppearance.BorderSize = 2
    $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(128, 0, 128)  # Purple outline
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
    
    # Add custom properties to store original values
    $btn | Add-Member -MemberType NoteProperty -Name "OriginalX" -Value $x
    $btn | Add-Member -MemberType NoteProperty -Name "OriginalY" -Value $y
    $btn | Add-Member -MemberType NoteProperty -Name "OriginalWidth" -Value $width
    $btn | Add-Member -MemberType NoteProperty -Name "OriginalHeight" -Value $height
    
    # Add hover effects
    $btn.Add_MouseEnter({
        $this.BackColor = [System.Drawing.Color]::FromArgb(25, 25, 25)  # Darker on hover
        $this.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(80, 0, 80)  # Darker purple outline
        $this.Size = New-Object System.Drawing.Size($this.OriginalWidth + 4, $this.OriginalHeight + 2)
        $this.Location = New-Object System.Drawing.Point($this.OriginalX - 2, $this.OriginalY - 1)
    })
    
    $btn.Add_MouseLeave({
        $this.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)  # Back to original
        $this.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(128, 0, 128)  # Back to original purple
        $this.Size = New-Object System.Drawing.Size($this.OriginalWidth, $this.OriginalHeight)
        $this.Location = New-Object System.Drawing.Point($this.OriginalX, $this.OriginalY)
    })
    
    # Custom paint for rounded corners
    $btn.Add_Paint({
        param($sender, $e)
        $rect = New-Object System.Drawing.Rectangle(0, 0, $sender.Width, $sender.Height)
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $radius = 8
        
        # Create rounded rectangle path
        $path.AddArc($rect.X, $rect.Y, $radius, $radius, 180, 90)
        $path.AddArc($rect.Right - $radius, $rect.Y, $radius, $radius, 270, 90)
        $path.AddArc($rect.Right - $radius, $rect.Bottom - $radius, $radius, $radius, 0, 90)
        $path.AddArc($rect.X, $rect.Bottom - $radius, $radius, $radius, 90, 90)
        $path.CloseFigure()
        
        $sender.Region = New-Object System.Drawing.Region($path)
        $path.Dispose()
    })
    
    return $btn
}

# Auto-locate Assetto Corsa installation
function Find-AssettoCorsaPath {
    $commonPaths = @(
        "C:\Program Files (x86)\Steam\steamapps\common\assettocorsa",
        "C:\Program Files\Steam\steamapps\common\assettocorsa",
        "D:\Steam\steamapps\common\assettocorsa",
        "E:\Steam\steamapps\common\assettocorsa",
        "C:\SteamLibrary\steamapps\common\assettocorsa",
        "D:\SteamLibrary\steamapps\common\assettocorsa"
    )
    
    # Check registry for Steam installation path
    try {
        $steamPath = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -Name "InstallPath" -ErrorAction SilentlyContinue
        if ($steamPath) {
            $steamACPath = Join-Path $steamPath.InstallPath "steamapps\common\assettocorsa"
            if (Test-Path (Join-Path $steamACPath "acs.exe")) {
                return $steamACPath
            }
        }
    } catch {}
    
    # Check common paths
    foreach ($path in $commonPaths) {
        if (Test-Path (Join-Path $path "acs.exe")) {
            return $path
        }
    }
    
    return $null
}

# Main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Assetto Corsa Driver Swap Tool"
$form.Size = New-Object System.Drawing.Size(600, 675)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.Icon = [System.Drawing.SystemIcons]::Application
$form.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 32)
$form.ForeColor = [System.Drawing.Color]::White

# Set application icon
try {
    $iconPath = Join-Path $PSScriptRoot "Icon.ico"
    if (Test-Path $iconPath) {
        $form.Icon = New-Object System.Drawing.Icon($iconPath)
        # Also set as window icon in taskbar
        $form.ShowIcon = $true
    }
} catch {
    # Continue without icon if there's an issue
    Write-Host "Could not load icon: $iconPath"
}

# Apply dark title bar immediately when form is created and again when shown
$form.Add_HandleCreated({
    try {
        $darkValue = 1
        [DarkMode]::DwmSetWindowAttribute($form.Handle, 20, [ref]$darkValue, 4)
    } catch {
        # Fallback for older Windows versions
        try {
            [DarkMode]::DwmSetWindowAttribute($form.Handle, 19, [ref]$darkValue, 4)
        } catch {}
    }
})

# Also apply when shown to ensure it sticks
$form.Add_Shown({
    try {
        $darkValue = 1
        [DarkMode]::DwmSetWindowAttribute($form.Handle, 20, [ref]$darkValue, 4)
    } catch {
        # Fallback for older Windows versions
        try {
            [DarkMode]::DwmSetWindowAttribute($form.Handle, 19, [ref]$darkValue, 4)
        } catch {}
    }
    
    # Force a refresh to ensure dark theme is applied
    $form.Refresh()
})

# Load config
$config = Load-Config



# AC Root Path Section
$lblACPath = New-Object System.Windows.Forms.Label
$lblACPath.Location = New-Object System.Drawing.Point(10, 10)
$lblACPath.Size = New-Object System.Drawing.Size(150, 20)
$lblACPath.Text = "Assetto Corsa Path:"
$lblACPath.BackColor = [System.Drawing.Color]::Transparent
$lblACPath.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($lblACPath)

$txtACPath = New-Object System.Windows.Forms.TextBox
$txtACPath.Location = New-Object System.Drawing.Point(10, 35)
$txtACPath.Size = New-Object System.Drawing.Size(450, 20)
$txtACPath.ReadOnly = $false
$txtACPath.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
$txtACPath.ForeColor = [System.Drawing.Color]::White
$txtACPath.BorderStyle = "FixedSingle"
$form.Controls.Add($txtACPath)

$btnBrowseAC = Create-RoundedButton 470 33 100 25 "Browse..."
$form.Controls.Add($btnBrowseAC)



# Auto-locate AC path with first-startup prompt
if ($config.ACRootPath -and (Test-Path (Join-Path $config.ACRootPath "acs.exe"))) {
    $txtACPath.Text = $config.ACRootPath
} else {
    $autoPath = Find-AssettoCorsaPath
    if ($autoPath) {
        $txtACPath.Text = $autoPath
        $config.ACRootPath = $autoPath
        Save-Config $config
    } else {
        # Show first-startup message if AC root not found
        $form.Add_Shown({
            [System.Windows.Forms.MessageBox]::Show(
                "DriverSwap couldn't find your Assetto Corsa root folder automatically.`n`nPlease use the Browse button below to select your AC installation folder.`n`nThis is typically located at:`n- Steam\steamapps\common\assettocorsa\`n- Or your custom Steam library location", 
                "Assetto Corsa Not Found", 
                "OK", 
                "Information"
            )
        })
    }
}



# Driver Selection Section
$lblDrivers = New-Object System.Windows.Forms.Label
$lblDrivers.Location = New-Object System.Drawing.Point(10, 70)
$lblDrivers.Size = New-Object System.Drawing.Size(200, 20)
$lblDrivers.Text = "Select Drivers to Replace:"
$lblDrivers.BackColor = [System.Drawing.Color]::Transparent
$lblDrivers.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($lblDrivers)



# Buttons for Select All/Deselect All/Refresh
$btnSelectAll = Create-RoundedButton 10 95 80 25 "Select All"
$form.Controls.Add($btnSelectAll)

$btnSelectNone = Create-RoundedButton 100 95 90 25 "Deselect All"
$form.Controls.Add($btnSelectNone)

$btnRefresh = Create-RoundedButton 200 95 80 25 "Refresh"
$form.Controls.Add($btnRefresh)

# Container panel for drivers list to hide scrollbar
$driversPanel = New-Object System.Windows.Forms.Panel
$driversPanel.Location = New-Object System.Drawing.Point(10, 150)
$driversPanel.Size = New-Object System.Drawing.Size(560, 180)
$driversPanel.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
$driversPanel.BorderStyle = "FixedSingle"

# CheckedListBox for drivers - wider to push scrollbar outside visible area
$listDrivers = New-Object System.Windows.Forms.CheckedListBox
$listDrivers.Location = New-Object System.Drawing.Point(0, 0)
$listDrivers.Size = New-Object System.Drawing.Size(580, 180)  # 20px wider to hide scrollbar
$listDrivers.CheckOnClick = $true
$listDrivers.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
$listDrivers.ForeColor = [System.Drawing.Color]::White
$listDrivers.BorderStyle = "None"
$listDrivers.ScrollAlwaysVisible = $false
$listDrivers.IntegralHeight = $false

$driversPanel.Controls.Add($listDrivers)
$form.Controls.Add($driversPanel)

# Source File Section
$lblSource = New-Object System.Windows.Forms.Label
$lblSource.Location = New-Object System.Drawing.Point(10, 340)
$lblSource.Size = New-Object System.Drawing.Size(200, 20)
$lblSource.Text = "Source Driver (File or Folder):"
$lblSource.BackColor = [System.Drawing.Color]::Transparent
$lblSource.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($lblSource)

$txtSourceFile = New-Object System.Windows.Forms.TextBox
$txtSourceFile.Location = New-Object System.Drawing.Point(10, 365)
$txtSourceFile.Size = New-Object System.Drawing.Size(450, 20)
$txtSourceFile.ReadOnly = $false
$txtSourceFile.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
$txtSourceFile.ForeColor = [System.Drawing.Color]::White
$txtSourceFile.BorderStyle = "FixedSingle"
$form.Controls.Add($txtSourceFile)

# Source driver selection list
$lblSourceDriver = New-Object System.Windows.Forms.Label
$lblSourceDriver.Location = New-Object System.Drawing.Point(10, 395)
$lblSourceDriver.Size = New-Object System.Drawing.Size(200, 20)
$lblSourceDriver.Text = "Select Source Driver (only one):"
$lblSourceDriver.BackColor = [System.Drawing.Color]::Transparent
$lblSourceDriver.ForeColor = [System.Drawing.Color]::FromArgb(200, 150, 255)
$form.Controls.Add($lblSourceDriver)

# Container panel for source drivers list to hide scrollbar
$sourcePanel = New-Object System.Windows.Forms.Panel
$sourcePanel.Location = New-Object System.Drawing.Point(10, 420)
$sourcePanel.Size = New-Object System.Drawing.Size(560, 120)
$sourcePanel.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
$sourcePanel.BorderStyle = "FixedSingle"

$listSourceDrivers = New-Object System.Windows.Forms.CheckedListBox
$listSourceDrivers.Location = New-Object System.Drawing.Point(0, 0)
$listSourceDrivers.Size = New-Object System.Drawing.Size(580, 120)  # 20px wider to hide scrollbar
$listSourceDrivers.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
$listSourceDrivers.ForeColor = [System.Drawing.Color]::White
$listSourceDrivers.BorderStyle = "None"
$listSourceDrivers.ScrollAlwaysVisible = $false
$listSourceDrivers.IntegralHeight = $false
$listSourceDrivers.CheckOnClick = $true

$sourcePanel.Controls.Add($listSourceDrivers)
$form.Controls.Add($sourcePanel)

# Add event handler to ensure only one source driver is selected
$listSourceDrivers.Add_ItemCheck({
    param($sender, $e)
    # If checking an item, uncheck all others
    if ($e.NewValue -eq "Checked") {
        for ($i = 0; $i -lt $sender.Items.Count; $i++) {
            if ($i -ne $e.Index) {
                $sender.SetItemChecked($i, $false)
            }
        }
    }
})

$btnBrowseSource = Create-RoundedButton 470 363 100 25 "Browse..."
$form.Controls.Add($btnBrowseSource)

# Status label positioned above driver list, below buttons
$lblProgress = New-Object System.Windows.Forms.Label
$lblProgress.Location = New-Object System.Drawing.Point(10, 125)
$lblProgress.Size = New-Object System.Drawing.Size(560, 20)
$lblProgress.Text = "Ready"
$lblProgress.BackColor = [System.Drawing.Color]::Transparent
$lblProgress.ForeColor = [System.Drawing.Color]::FromArgb(200, 150, 255)
$form.Controls.Add($lblProgress)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 565)
$progressBar.Size = New-Object System.Drawing.Size(560, 15)
$progressBar.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
$progressBar.ForeColor = [System.Drawing.Color]::FromArgb(128, 0, 128)
$form.Controls.Add($progressBar)

# Results TextBox removed as requested - keeping only progress bar

# Action Buttons with special styling - positioned below progress bar with proper margins
$btnSwap = Create-RoundedButton 400 590 100 30 "Swap Drivers"
$btnSwap.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnSwap)

# Exit button with different color scheme
$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Location = New-Object System.Drawing.Point(510, 590)
$btnExit.Size = New-Object System.Drawing.Size(60, 30)
$btnExit.Text = "Exit"
$btnExit.BackColor = [System.Drawing.Color]::FromArgb(64, 64, 64)
$btnExit.ForeColor = [System.Drawing.Color]::White
$btnExit.FlatStyle = "Flat"
$btnExit.FlatAppearance.BorderSize = 0
$btnExit.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)

# Add custom properties for exit button hover
$btnExit | Add-Member -MemberType NoteProperty -Name "OriginalX" -Value 510
$btnExit | Add-Member -MemberType NoteProperty -Name "OriginalY" -Value 590
$btnExit | Add-Member -MemberType NoteProperty -Name "OriginalWidth" -Value 60
$btnExit | Add-Member -MemberType NoteProperty -Name "OriginalHeight" -Value 30

# Add hover effects for exit button
$btnExit.Add_MouseEnter({
    $this.BackColor = [System.Drawing.Color]::FromArgb(96, 96, 96)
    $this.Size = New-Object System.Drawing.Size($this.OriginalWidth + 2, $this.OriginalHeight + 1)
    $this.Location = New-Object System.Drawing.Point($this.OriginalX - 1, $this.OriginalY)
})

$btnExit.Add_MouseLeave({
    $this.BackColor = [System.Drawing.Color]::FromArgb(64, 64, 64)
    $this.Size = New-Object System.Drawing.Size($this.OriginalWidth, $this.OriginalHeight)
    $this.Location = New-Object System.Drawing.Point($this.OriginalX, $this.OriginalY)
})

# Custom paint for rounded exit button
$btnExit.Add_Paint({
    param($sender, $e)
    $rect = New-Object System.Drawing.Rectangle(0, 0, $sender.Width, $sender.Height)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $radius = 8
    
    $path.AddArc($rect.X, $rect.Y, $radius, $radius, 180, 90)
    $path.AddArc($rect.Right - $radius, $rect.Y, $radius, $radius, 270, 90)
    $path.AddArc($rect.Right - $radius, $rect.Bottom - $radius, $radius, $radius, 0, 90)
    $path.AddArc($rect.X, $rect.Bottom - $radius, $radius, $radius, 90, 90)
    $path.CloseFigure()
    
    $sender.Region = New-Object System.Drawing.Region($path)
    $path.Dispose()
})

$form.Controls.Add($btnExit)

# Global variables for driver data
$script:driverFiles = @()

# Function to load drivers
function Load-Drivers {
    $listDrivers.Items.Clear()
    $script:driverFiles = @()
    
    if (-not $txtACPath.Text) {
        $lblProgress.Text = "Please select Assetto Corsa path first"
        return
    }
    
    $driverPath = Join-Path $txtACPath.Text "content\driver"
    if (-not (Test-Path $driverPath)) {
        $lblProgress.Text = "Driver folder not found in AC installation"
        return
    }
    
    $kn5Files = Get-ChildItem -Path $driverPath -Filter "*.kn5"
    
    if ($kn5Files.Count -eq 0) {
        $lblProgress.Text = "No KN5 files found in driver folder"
        return
    }
    
    foreach ($file in $kn5Files) {
        $listDrivers.Items.Add($file.Name)
        $script:driverFiles += $file.FullName
    }
    
    $lblProgress.Text = "Found $($kn5Files.Count) driver files"
}

# Function to load source drivers from selected folder
function Load-SourceDrivers($folderPath) {
    $listSourceDrivers.Items.Clear()
    $sourceDriverFiles = @()
    
    if (-not $folderPath -or -not (Test-Path $folderPath)) {
        return
    }
    
    $kn5Files = Get-ChildItem -Path $folderPath -Filter "*.kn5"
    
    if ($kn5Files.Count -eq 0) {
        return
    }
    
    foreach ($file in $kn5Files) {
        $listSourceDrivers.Items.Add($file.Name)
        $sourceDriverFiles += $file.FullName
    }
    
    return $sourceDriverFiles
}

# Event handlers
$btnBrowseAC.Add_Click({
    # Use modern file dialog for AC root selection (dark UI) - select acs.exe specifically
    $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $fileDialog.Filter = "Assetto Corsa Executable (acs.exe)|acs.exe|All Files (*.*)|*.*"
    $fileDialog.Title = "Select acs.exe from your Assetto Corsa installation"
    $fileDialog.FileName = "acs.exe"
    $fileDialog.CheckFileExists = $true
    $fileDialog.CheckPathExists = $true
    $fileDialog.Multiselect = $false
    
    if ($fileDialog.ShowDialog() -eq "OK") {
        if ([System.IO.Path]::GetFileName($fileDialog.FileName) -eq "acs.exe") {
            $selectedPath = [System.IO.Path]::GetDirectoryName($fileDialog.FileName)
            $txtACPath.Text = $selectedPath
            $config = Load-Config
            $config.ACRootPath = $selectedPath
            Save-Config $config
            Load-Drivers
        } else {
            [System.Windows.Forms.MessageBox]::Show("Please select the acs.exe file from your Assetto Corsa installation.", "Error", "OK", "Error")
        }
    }
})

$btnRefresh.Add_Click({
    Load-Drivers
})

$btnSelectAll.Add_Click({
    for ($i = 0; $i -lt $listDrivers.Items.Count; $i++) {
        $listDrivers.SetItemChecked($i, $true)
    }
})

$btnSelectNone.Add_Click({
    for ($i = 0; $i -lt $listDrivers.Items.Count; $i++) {
        $listDrivers.SetItemChecked($i, $false)
    }
})

$btnBrowseSource.Add_Click({
    # Use modern file dialog for source selection - always scan folder for KN5 files
    $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $fileDialog.Filter = "KN5 Files (*.kn5)|*.kn5|All Files (*.*)|*.*"
    $fileDialog.Title = "Select Source Driver KN5 File"
    $fileDialog.CheckFileExists = $true
    $fileDialog.CheckPathExists = $true
    $fileDialog.Multiselect = $false
    
    if ($fileDialog.ShowDialog() -eq "OK") {
        $selectedFile = $fileDialog.FileName
        
        # Always scan the folder containing the selected file for all KN5 files (files only, not directories)
        $selectedPath = [System.IO.Path]::GetDirectoryName($selectedFile)
        $kn5Files = Get-ChildItem -Path $selectedPath -Filter "*.kn5" -File
        
        if ($kn5Files.Count -gt 0) {
            $txtSourceFile.Text = $selectedPath
            
            # Clear and populate source drivers list
            $listSourceDrivers.Items.Clear()
            $script:sourceDriverFiles = @()
            
            foreach ($file in $kn5Files) {
                $listSourceDrivers.Items.Add($file.Name)
                $script:sourceDriverFiles += $file.FullName
            }
            
            # Auto-select the first driver if there's only one
            if ($kn5Files.Count -eq 1) {
                $listSourceDrivers.SetItemChecked(0, $true)
            }
            
            # Save source folder path to config
            $config = Load-Config
            $config.SourceFolderPath = $selectedPath
            Save-Config $config
        } else {
            [System.Windows.Forms.MessageBox]::Show("No KN5 files found in the selected folder.", "Warning", "OK", "Warning")
        }
    }
})

$btnSwap.Add_Click({
    # Validation
    if (-not $txtACPath.Text) {
        [System.Windows.Forms.MessageBox]::Show("Please select Assetto Corsa path first.", "Error", "OK", "Error")
        return
    }
    
    if (-not $txtSourceFile.Text) {
        [System.Windows.Forms.MessageBox]::Show("Please select a source driver folder.", "Error", "OK", "Error")
        return
    }
    
    if (-not (Test-Path $txtSourceFile.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Source folder does not exist.", "Error", "OK", "Error")
        return
    }
    
    # Check if exactly one source driver is selected
    $checkedSourceCount = 0
    $selectedSourceIndex = -1
    for ($i = 0; $i -lt $listSourceDrivers.Items.Count; $i++) {
        if ($listSourceDrivers.GetItemChecked($i)) {
            $checkedSourceCount++
            $selectedSourceIndex = $i
        }
    }
    
    if ($checkedSourceCount -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select exactly one source driver from the list.", "Error", "OK", "Error")
        return
    }
    
    if ($checkedSourceCount -gt 1) {
        [System.Windows.Forms.MessageBox]::Show("Please select only one source driver. Multiple drivers selected.", "Error", "OK", "Error")
        return
    }
    
    # Get selected drivers
    $selectedDrivers = @()
    for ($i = 0; $i -lt $listDrivers.Items.Count; $i++) {
        if ($listDrivers.GetItemChecked($i)) {
            $selectedDrivers += @{
                Name = $listDrivers.Items[$i]
                Path = $script:driverFiles[$i]
            }
        }
    }
    
    if ($selectedDrivers.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one driver to replace.", "Error", "OK", "Error")
        return
    }
    
    # Get selected source driver
    $selectedSourceDriver = $script:sourceDriverFiles[$selectedSourceIndex]
    $sourceDriverName = $listSourceDrivers.Items[$selectedSourceIndex]
    
    # Handle single file vs folder source
    $isSourceFile = [System.IO.File]::Exists($txtSourceFile.Text)
    if ($isSourceFile) {
        $selectedSourceDriver = $txtSourceFile.Text
        $sourceDriverName = [System.IO.Path]::GetFileName($txtSourceFile.Text)
    }
    
    # Confirm operation
    $confirmMessage = "Replace $($selectedDrivers.Count) driver(s) with:`n$sourceDriverName`nFrom: $($txtSourceFile.Text)`n`nSelected drivers:`n"
    foreach ($driver in $selectedDrivers) {
        $confirmMessage += "- $($driver.Name)`n"
    }
    
    $result = [System.Windows.Forms.MessageBox]::Show($confirmMessage, "Confirm Swap", "YesNo", "Question")
    if ($result -ne "Yes") {
        return
    }
    
    # Perform swap
    $progressBar.Maximum = $selectedDrivers.Count
    $progressBar.Value = 0
    $successCount = 0
    $errorCount = 0
    $errorMessages = @()
    
    foreach ($driver in $selectedDrivers) {
        $lblProgress.Text = "Replacing: $($driver.Name)"
        $form.Refresh()
        
        try {
            Copy-Item -Path $selectedSourceDriver -Destination $driver.Path -Force
            $successCount++
        } catch {
            $errorMessages += "Failed to replace: $($driver.Name) - $($_.Exception.Message)"
            $errorCount++
        }
        
        $progressBar.Value++
    }
    
    $lblProgress.Text = "Complete: $successCount successful, $errorCount failed"
    
    # Show detailed results
    $resultMessage = "Operation complete!`n`nSuccessful: $successCount`nFailed: $errorCount"
    
    if ($errorCount -gt 0) {
        $resultMessage += "`n`nErrors:`n"
        foreach ($error in $errorMessages) {
            $resultMessage += "- $error`n"
        }
        $resultMessage += "`nThis might be due to:`n- Files being in use by Assetto Corsa`n- Insufficient permissions (try running as administrator)`n- Antivirus software blocking the operation"
    }
    
    [System.Windows.Forms.MessageBox]::Show($resultMessage, "Results", "OK", "Information")
})

$btnExit.Add_Click({
    $form.Close()
})

# Add event handlers for manual path entry
$txtACPath.Add_TextChanged({
    if ($txtACPath.Text -and (Test-Path (Join-Path $txtACPath.Text "acs.exe"))) {
        $config.ACRootPath = $txtACPath.Text
        Save-Config $config
        Load-Drivers
    }
})

$txtSourceFile.Add_TextChanged({
    if ($txtSourceFile.Text -and (Test-Path $txtSourceFile.Text)) {
        $config.SourceFolderPath = $txtSourceFile.Text
        Save-Config $config
        
        # Check if it's a file or folder and handle accordingly
        if ([System.IO.File]::Exists($txtSourceFile.Text)) {
            # Single file
            $listSourceDrivers.Items.Clear()
            $listSourceDrivers.Items.Add([System.IO.Path]::GetFileName($txtSourceFile.Text))
            $listSourceDrivers.SetItemChecked(0, $true)
            $script:sourceDriverFiles = @($txtSourceFile.Text)
        } elseif ([System.IO.Directory]::Exists($txtSourceFile.Text)) {
            # Folder - load all KN5 files
            $kn5Files = Get-ChildItem -Path $txtSourceFile.Text -Filter "*.kn5" -File
            $listSourceDrivers.Items.Clear()
            $script:sourceDriverFiles = @()
            
            foreach ($file in $kn5Files) {
                $listSourceDrivers.Items.Add($file.Name)
                $script:sourceDriverFiles += $file.FullName
            }
        }
    }
})

# Initial load
if ($txtACPath.Text) {
    Load-Drivers
}

# Load saved source folder after all controls are created
if ($config.SourceFolderPath -and (Test-Path $config.SourceFolderPath)) {
    $txtSourceFile.Text = $config.SourceFolderPath
    # This will trigger the TextChanged event which will load the drivers
}

# Show form
$form.ShowDialog()
