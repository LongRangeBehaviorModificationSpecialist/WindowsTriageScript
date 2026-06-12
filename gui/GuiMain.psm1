function Get-Gui {
    <#
    .SYNOPSIS
        Assembles and runs the graphical wrapper managing all worker modules.
    #>

    $defaultFontFace         = "Segoe UI"
    $defaultTbWidth          = 250  # original value = 290
    $defaultLblWidth         = 80  # original value = 120
    $defaultLblHeight        = 20  # original value = 25
    $groupboxLblWidth        = 200
    $groupboxChkBoxWidth     = 20
    $groupboxChkBoxHeight    = 20
    $groupboxTextBoxHeight   = 20
    $groupboxControlsPadding = 0
    $groupboxCol1XValue      = 10
    $groupboxCol2XValue      = ($groupboxCol1XValue + $groupboxChkBoxWidth)
    $groupboxColumnYStart    = 30
    $groupboxSelectAllBtnY   = 0
    $groupboxBtnWidth        = 150
    $groupboxBtnHeight       = 30
    $globalFont              = New-Object System.Drawing.Font($defaultFontFace, 8.5)
    $tbFontStyle             = New-Object System.Drawing.Font($defaultFontFace, 9)
    $defaultLblSize          = New-Object System.Drawing.Size($defaultLblWidth, $defaultLblHeight)


    # Load required .NET GUI and Interaction assemblies explicitly
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName Microsoft.VisualBasic


    # Global high-DPI scaling configuration safety fix
    [System.Windows.Forms.Application]::EnableVisualStyles()


    # Form Base Shell
    $mainForm = New-Object System.Windows.Forms.Form
    $mainForm.Text = "PowerShell Triage Interface"
    $mainForm.Size = New-Object System.Drawing.Size(700, 575)  # width x height (original value: `950, 750`)
    $mainForm.StartPosition = "CenterScreen"
    $mainForm.FormBorderStyle = "Sizable"
    $mainForm.MaximizeBox = $false
    $mainForm.BackColor = [System.Drawing.Color]::FromArgb(245, 246, 248)


    # Define label and text boxes for source and destination directories
    $lblUserName = New-Object System.Windows.Forms.Label
    $lblUserName.Text = "User Name:"
    $lblUserName.Location = New-Object System.Drawing.Point(10, 15)  # (x, y) position
    $lblUserName.Size = $defaultLblSize
    $lblUserName.Font = $globalFont
    $lblUserName.ForeColor = [System.Drawing.Color]::Black
    $lblUserName.TextAlign = "MiddleLeft"
    $mainForm.Controls.Add($lblUserName)


    $tbUserName = New-Object System.Windows.Forms.TextBox
    $tbUserName.Location = New-Object System.Drawing.Point(90, 15)  # (x, y) position
    $tbUserName.Width = $defaultTbWidth
    $tbUserName.Font = $tbFontStyle
    $tbUserName.BackColor = [System.Drawing.Color]::White
    $tbUserName.ForeColor = [System.Drawing.Color]::Black
    $tbUserName.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $tbUserName.Multiline = $false
    $mainForm.Controls.Add($tbUserName)


    $lblAgency = New-Object System.Windows.Forms.Label
    $lblAgency.Text = "Agency:"
    $lblAgency.Location = New-Object System.Drawing.Point(10, 50)  # (x, y) position
    $lblAgency.Size = $defaultLblSize
    $lblAgency.Font = $globalFont
    $lblAgency.ForeColor = [System.Drawing.Color]::Black
    $lblAgency.TextAlign = "MiddleLeft"
    $mainForm.Controls.Add($lblAgency)


    $tbAgency = New-Object System.Windows.Forms.TextBox
    $tbAgency.Location = New-Object System.Drawing.Point(90, 50)  # (x, y) position
    $tbAgency.Width = $defaultTbWidth
    $tbAgency.Font = $tbFontStyle
    $tbAgency.BackColor = [System.Drawing.Color]::White
    $tbAgency.ForeColor = [System.Drawing.Color]::Black
    $tbAgency.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $tbAgency.Multiline = $false
    $mainForm.Controls.Add($tbAgency)


    $lblCaseNumber = New-Object System.Windows.Forms.Label
    $lblCaseNumber.Text = "Case Number:"
    $lblCaseNumber.Location = New-Object System.Drawing.Point(10, 85)  # (x, y) position
    $lblCaseNumber.Size = $defaultLblSize
    $lblCaseNumber.Font = $globalFont
    $lblCaseNumber.ForeColor = [System.Drawing.Color]::Black
    $lblCaseNumber.TextAlign = "MiddleLeft"
    $mainForm.Controls.Add($lblCaseNumber)


    $tbCaseNumber = New-Object System.Windows.Forms.TextBox
    $tbCaseNumber.Location = New-Object System.Drawing.Point(90, 85)  # (x, y) position
    $tbCaseNumber.Width = $defaultTbWidth
    $tbCaseNumber.Font = $tbFontStyle
    $tbCaseNumber.BackColor = [System.Drawing.Color]::White
    $tbCaseNumber.ForeColor = [System.Drawing.Color]::Black
    $tbCaseNumber.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $tbCaseNumber.Multiline = $false
    $mainForm.Controls.Add($tbCaseNumber)


    $groupboxModules = New-Object System.Windows.Forms.GroupBox
    $groupboxModules.Text = "SELECT MODULES TO RUN"
    $groupboxModules.Location = New-Object System.Drawing.Point(10, 120)  # (x, y) position (original value: `10, 125`)
    $groupboxModules.Size = New-Object System.Drawing.Size(330, 395)  # width x height (original value: `410, 395`)
    $mainForm.Controls.Add($groupboxModules)


    $groupboxOptions = New-Object System.Windows.Forms.GroupBox
    $groupboxOptions.Text = "OTHER OPTIONS"
    $groupboxOptions.Location = New-Object System.Drawing.Point(360, 10)  # (x, y) position (original value: `440, 10`)
    $groupboxOptions.Size = New-Object System.Drawing.Size(275, 370)  # width x height (original value: `410, 370`)
    $mainForm.Controls.Add($groupboxOptions)


    $modulesCheckList = @(
        @{ Name = "DeviceData"; Label = "Get Device Data" }
        @{ Name = "UserData"; Label = "Parse User(s) Data" }
        @{ Name = "NetworkData"; Label = "Network Connection Data" }
        @{ Name = "ProcessData"; Label = "Get Process Data" }
        @{ Name = "SystemData"; Label = "Get System Data" }
        @{ Name = "PrefetchData"; Label = "Prefetch Info" }
        @{ Name = "EventLogData"; Label = "EventLog Info" }
        @{ Name = "FirewallData"; Label = "Firewall Info" }
        @{ Name = "EncryptionData"; Label = "BitLocker Data" }
        @{ Name = "InternetData"; Label = "Internet Usage Data" }
    )

    $modsCheckBoxes = [System.Collections.Generic.List[System.Windows.Forms.CheckBox]]::new()

    for ($i = 0; $i -lt $modulesCheckList.Count; $i++) {
        $item = $modulesCheckList[$i]

        # Initialize Independent Text Label (Columns 2 & 4)
        $textLabel = New-Object System.Windows.Forms.Label
        $textLabel.Text = $item.Label
        $textLabel.Font = $globalFont
        $textLabel.ForeColor = [System.Drawing.Color]::FromArgb(40, 40, 40)

        # Measure out text metrics using raw engine parameters
        $proposedSize = New-Object System.Drawing.Size($groupboxLblWidth, 0)
        $measuredSize = [System.Windows.Forms.TextRenderer]::MeasureText($item.Label, $globalFont, $proposedSize, [System.Windows.Forms.TextFormatFlags]::WordBreak)
        $calculatedHeight = [Math]::Max($measuredSize.Height, $groupboxTextBoxHeight)
        $textLabel.Size = New-Object System.Drawing.Size($groupboxLblWidth, $calculatedHeight)

        # Initialize Independent CheckBox Control (Column 1)
        $chkBox = New-Object System.Windows.Forms.CheckBox
        $chkBox.Tag = $item.Name
        $chkBox.Size = New-Object System.Drawing.Size($groupboxChkBoxWidth, $groupboxChkBoxHeight) # Strictly constrained to the square box frame asset

        $chkBox.Location = New-Object System.Drawing.Point($groupboxCol1XValue, $groupboxColumnYStart)
        $chkBox.CheckAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $textLabel.Location = New-Object System.Drawing.Point($groupboxCol2XValue, $groupboxColumnYStart)
        $textLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

        $groupboxModules.Controls.Add($chkBox)
        $groupboxModules.Controls.Add($textLabel)

        # Advance Left pipeline coordinate tracker
        $groupboxColumnYStart += $calculatedHeight + $groupboxControlsPadding

        $textLabel.add_Click({
                param($sender, $e)
                $associatedBox = $modsCheckBoxes | Where-Object { $_.Tag -eq $sender.Tag }
                if ($associatedBox) { $associatedBox.Checked = !$associatedBox.Checked }
            })
        $textLabel.Tag = $item.Name  # Store key mapping reference link
        $modsCheckBoxes.Add($chkBox)
    }

    $groupboxSelectAllBtnY = ($groupboxColumnYStart + $groupboxControlsPadding + 10)

    $btnSelectAllModules = New-Object System.Windows.Forms.Button
    $btnSelectAllModules.Text = "Select All Modules"
    $btnSelectAllModules.Font = $globalFont
    $btnSelectAllModules.Width = $groupboxBtnWidth
    $btnSelectAllModules.Height = $groupboxBtnHeight
    $btnSelectAllModules.Padding = New-Object System.Windows.Forms.Padding(3)
    $btnSelectAllModules.Location = New-Object Drawing.Point($groupboxCol1XValue, $groupboxSelectAllBtnY)  # (x, y) position
    $btnSelectAllModules.FlatAppearance.BorderSize = 1
    $btnSelectAllModules.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $btnSelectAllModules.BackColor = [System.Drawing.Color]::FromArgb(34, 139, 34)  # Soft green accent color
    $btnSelectAllModules.Forecolor = [System.Drawing.Color]::White
    $btnSelectAllModules.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnSelectAllModules.add_Click({ foreach ($cb in $modsCheckBoxes) { $cb.Checked = $true } })
    $groupboxModules.Controls.Add($btnSelectAllModules)


    $btnClearAllModules = New-Object System.Windows.Forms.Button
    $btnClearAllModules.Text = "Deselect All Modules"
    $btnClearAllModules.Font = $globalFont
    $btnClearAllModules.Width = $groupboxBtnWidth
    $btnClearAllModules.Height = $groupboxBtnHeight
    $btnClearAllModules.Padding = New-Object System.Windows.Forms.Padding(3)
    $btnClearAllModules.Location = New-Object Drawing.Point($groupboxCol1XValue, ($groupboxSelectAllBtnY + $groupboxBtnHeight + 10))  # (x, y) position
    $btnClearAllModules.FlatAppearance.BorderSize = 1
    $btnClearAllModules.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $btnClearAllModules.BackColor = [System.Drawing.Color]::White
    $btnClearAllModules.Forecolor = [System.Drawing.Color]::black
    $btnClearAllModules.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnClearAllModules.add_Click({ foreach ($cb in $modsCheckBoxes) { $cb.Checked = $false } })
    $groupboxModules.Controls.Add($btnClearAllModules)


    $otherOptionsCheckList = @(
        @{ Name = "RunEDD"; Label = "Run Encrypted Disk Detector" }
        @{ Name = "CaptureProcesses"; Label = "Collect Running Processes" }
        @{ Name = "CaptureRAM"; Label = "Collect Computer RAM" }
        @{ Name = "CopyRegHives"; Label = "Copy Registry Hives" }
        @{ Name = "CopyPrefetch"; Label = "Copy Prefetch files" }
        @{ Name = "CopyNTUser"; Label = "Copy NTUSER.DAT file(s)" }
        @{ Name = "ListAllFiles"; Label = "Gather list of ALL files" }
        @{ Name = "CopySRUDB"; Label = "Copy SRUDB.dat file" }
        @{ Name = "CreateArchive"; Label = "Create Case Archive" }
    )

    $optionsCheckBoxes = [System.Collections.Generic.List[System.Windows.Forms.CheckBox]]::new()

    # Reset the value of this variable.
    $groupboxColumnYStart = 30

    for ($i = 0; $i -lt $otherOptionsCheckList.Count; $i++) {
        $item = $otherOptionsCheckList[$i]

        # Initialize independent text label for column 2
        $textLabel = New-Object System.Windows.Forms.Label
        $textLabel.Text = $item.Label
        $textLabel.Font = $globalFont
        $textLabel.ForeColor = [System.Drawing.Color]::FromArgb(40, 40, 40)

        # Measure out text metrics using raw engine parameters
        $proposedSize = New-Object System.Drawing.Size($groupboxLblWidth, 0)
        $measuredSize = [System.Windows.Forms.TextRenderer]::MeasureText($item.Label, $globalFont, $proposedSize, [System.Windows.Forms.TextFormatFlags]::WordBreak)
        $calculatedHeight = [Math]::Max($measuredSize.Height, $groupboxTextBoxHeight)
        $textLabel.Size = New-Object System.Drawing.Size($groupboxLblWidth, $calculatedHeight)

        # Initialize independent checkbox control column 1
        $chkBox = New-Object System.Windows.Forms.CheckBox
        $chkBox.Tag = $item.Name
        $chkBox.Size = New-Object System.Drawing.Size($groupboxChkBoxwidth, $groupboxChkBoxHeight) # Strictly constrained to the square box frame asset

        $chkBox.Location = New-Object System.Drawing.Point($groupboxCol1XValue, $groupboxColumnYStart)
        $chkBox.CheckAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $textLabel.Location = New-Object System.Drawing.Point($groupboxCol2XValue, $groupboxColumnYStart)
        $textLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

        $groupboxOptions.Controls.Add($chkBox)
        $groupboxOptions.Controls.Add($textLabel)

        # Advance Left pipeline coordinate tracker
        $groupboxColumnYStart += $calculatedHeight + $groupboxControlsPadding

        $textLabel.add_Click({
                param($sender, $e)
                $associatedBox = $optionsCheckBoxes | Where-Object { $_.Tag -eq $sender.Tag }
                if ($associatedBox) { $associatedBox.Checked = !$associatedBox.Checked }
            })
        $textLabel.Tag = $item.Name  # Store key mapping reference link
        $optionsCheckBoxes.Add($chkBox)
    }

    $groupboxSelectAllBtnY = ($groupboxColumnYStart + $groupboxControlsPadding + 10)

    $btnSelectAllOptions = New-Object System.Windows.Forms.Button
    $btnSelectAllOptions.Text = "Select All Options"
    $btnSelectAllOptions.Font = $globalFont
    $btnSelectAllOptions.Width = $groupboxBtnWidth
    $btnSelectAllOptions.Height = $groupboxBtnHeight
    $btnSelectAllOptions.Padding = New-Object System.Windows.Forms.Padding(3)
    $btnSelectAllOptions.Location = New-Object Drawing.Point($groupboxCol1XValue, $groupboxSelectAllBtnY)  # (x, y) position
    $btnSelectAllOptions.FlatAppearance.BorderSize = 1
    $btnSelectAllOptions.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $btnSelectAllOptions.BackColor = [System.Drawing.Color]::FromArgb(34, 139, 34)  # Soft green accent color
    $btnSelectAllOptions.Forecolor = [System.Drawing.Color]::White
    $btnSelectAllOptions.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnSelectAllOptions.add_Click({ foreach ($cb in $optionsCheckBoxes) { $cb.Checked = $true } })
    $groupboxOptions.Controls.Add($btnSelectAllOptions)


    $btnClearAllOptions = New-Object System.Windows.Forms.Button
    $btnClearAllOptions.Text = "Deselect All Options"
    $btnClearAllOptions.Font = $globalFont
    $btnClearAllOptions.Width = $groupboxBtnWidth
    $btnClearAllOptions.Height = $groupboxBtnHeight
    $btnClearAllOptions.Padding = New-Object System.Windows.Forms.Padding(3)
    $btnClearAllOptions.Location = New-Object Drawing.Point($groupboxCol1XValue, ($groupboxSelectAllBtnY + $groupboxBtnHeight + 10))  # (x, y) position
    $btnClearAllOptions.FlatAppearance.BorderSize = 1
    $btnClearAllOptions.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $btnClearAllOptions.BackColor = [System.Drawing.Color]::White
    $btnClearAllOptions.Forecolor = [System.Drawing.Color]::black
    $btnClearAllOptions.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnClearAllOptions.add_Click({ foreach ($cb in $optionsCheckBoxes) { $cb.Checked = $false } })
    $groupboxOptions.Controls.Add($btnClearAllOptions)


    # Define a button for initiating the files only report
    $btnStartTriage = New-Object System.Windows.Forms.Button
    $btnStartTriage.Name = "btnFilesReport"
    $btnStartTriage.Text = "Start Triage"
    $btnStartTriage.Font = $globalFont
    $btnStartTriage.Width = $groupboxBtnWidth
    $btnStartTriage.Height = $groupboxBtnHeight
    $btnStartTriage.Padding = New-Object System.Windows.Forms.Padding(3)
    $btnStartTriage.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnStartTriage.Location = New-Object System.Drawing.Point(360, 410)  # (x, y) position
    $btnStartTriage.FlatAppearance.BorderSize = 1
    $btnStartTriage.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $btnStartTriage.BackColor = "#17a589"
    $btnStartTriage.Forecolor = "#dddddd"
    # $btnStartTriage.Add_Click({

            # $User = $tbUserName.Text
            # $Agency = $tbAgency.Text
            # $caseNumber = $tbCaseNumber.Text
            # $DriveList = $tbDrivesList.Text
            # $KeyWordsDrivesList = $tbKeyWordsDrivesList.Text

            # Export-FilesReport -CaseFolderName $caseFolderName -User $User -Agency $Agency -CaseNumber $caseNumber -ComputerName $computerName -Ipv4 $ipv4 -Ipv6 $ipv6 -Device $cbOne.Checked -UserData $cbTwo.Checked -Network $cbThree.Checked -Process $cbFour.Checked -System $cbFive.Checked -Prefetch $cbSix.Checked -EventLogs $cbSeven.Checked -Firewall $cbEight.Checked -BitLocker $cbNine.Checked -CaptureProcesses $cbGetProcesses.Checked -GetRam $cbGetRam.Checked -Edd $cbEdd.Checked -Hives $cbRegHives.Checked -CopyPrefetch $cbPrefetch.Checked -GetNTUserDat $cbNTUserDat.Checked -ListFiles $cbListFiles.Checked -DriveList $DriveList -KeyWordSearch $cbKeyWordSearch.Checked -KeyWordsDriveList $KeyWordsDrivesList -CopySrum $cbSruDb.Checked -GetFileHashes $cbHashFiles.Checked -MakeArchive $cbArchive.Checked

        #     $Form.Close()
        #     return

        # })
    # Add the button
    $mainForm.Controls.Add($btnStartTriage)


    $btnQuit = New-Object Windows.Forms.Button
    $btnQuit.Text = "Quit"
    $btnQuit.Font = $globalFont
    $btnQuit.Width = $groupboxBtnWidth
    $btnQuit.Height = $groupboxBtnHeight
    $btnQuit.Padding = New-Object System.Windows.Forms.Padding(3)
    $btnQuit.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnQuit.Location = New-Object System.Drawing.Point(360, 450)  # (x, y) position
    $btnQuit.FlatAppearance.BorderSize = 1
    $btnQuit.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $btnQuit.BackColor = "#c0392b"
    $btnQuit.Forecolor = "#dddddd"
    $btnQuit.Add_Click({

            $mainForm.Close()
            return

        })

    $mainForm.Controls.Add($btnQuit)


    $mainForm.Add_Shown({ $mainForm.Activate() })


    # Display the form
    [void]$mainForm.ShowDialog()
}

