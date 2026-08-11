function Get-Gui {
    <#
    .SYNOPSIS
        Assembles and runs the graphical wrapper managing all worker modules.
    #>

    $DefaultFontFace          = "Segoe UI"
    $DefaultTxtbxWidth        = 250  # original value = 290
    $DefaultLblWidth          = 80  # original value = 120
    $DefaultLblHeight         = 20  # original value = 25
    $GroupboxLblWidth         = 200
    $GroupboxChkBoxWidth      = 20
    $GroupboxChkBoxHeight     = 20
    $GroupboxTxtbxHeight      = 20
    $GroupboxControlsPadding  = 0
    $GroupboxCol1XValue       = 10
    $GroupboxCol2XValue       = ($GroupboxCol1XValue + $GroupboxChkBoxWidth)
    $GroupboxColYStart        = 30
    $GroupboxSelectAllBtnY    = 0
    $GroupboxBtnWidth         = 150
    $GroupboxBtnHeight        = 30
    $GlobalFont               = New-Object System.Drawing.Font($DefaultFontFace, 8.5)
    $TxtboxFontStyle           = New-Object System.Drawing.Font($DefaultFontFace, 9)
    $DefaultLblSize           = New-Object System.Drawing.Size($DefaultLblWidth, $DefaultLblHeight)


    # Load required .NET GUI and Interaction assemblies explicitly
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName Microsoft.VisualBasic


    # Global high-DPI scaling configuration safety fix
    [System.Windows.Forms.Application]::EnableVisualStyles()


    # Form Base Shell
    $MainForm                 = New-Object System.Windows.Forms.Form
    $MainForm.Text            = "PowerShell Triage Interface"
    $MainForm.Size            = New-Object System.Drawing.Size(700, 575)  # width x height (original value: `950, 750`)
    $MainForm.StartPosition   = "CenterScreen"
    $MainForm.FormBorderStyle = "Sizable"
    $MainForm.MaximizeBox     = $false
    $MainForm.BackColor       = [System.Drawing.Color]::FromArgb(245, 246, 248)


    # Define label and text boxes for source and destination directories
    $LblUserName           = New-Object System.Windows.Forms.Label
    $LblUserName.Text      = "User Name:"
    $LblUserName.Location  = New-Object System.Drawing.Point(10, 15)  # (x, y) position
    $LblUserName.Size      = $DefaultLblSize
    $LblUserName.Font      = $GlobalFont
    $LblUserName.ForeColor = [System.Drawing.Color]::Black
    $LblUserName.TextAlign = "MiddleLeft"
    $MainForm.Controls.Add($LblUserName)


    $TxtboxUserName             = New-Object System.Windows.Forms.TextBox
    $TxtboxUserName.Location    = New-Object System.Drawing.Point(90, 15)  # (x, y) position
    $TxtboxUserName.Width       = $DefaultTxtbxWidth
    $TxtboxUserName.Font        = $TxtboxFontStyle
    $TxtboxUserName.BackColor   = [System.Drawing.Color]::White
    $TxtboxUserName.ForeColor   = [System.Drawing.Color]::Black
    $TxtboxUserName.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $TxtboxUserName.Multiline   = $false
    $MainForm.Controls.Add($TxtboxUserName)


    $LblAgency           = New-Object System.Windows.Forms.Label
    $LblAgency.Text      = "Agency:"
    $LblAgency.Location  = New-Object System.Drawing.Point(10, 50)  # (x, y) position
    $LblAgency.Size      = $DefaultLblSize
    $LblAgency.Font      = $GlobalFont
    $LblAgency.ForeColor = [System.Drawing.Color]::Black
    $LblAgency.TextAlign = "MiddleLeft"
    $MainForm.Controls.Add($LblAgency)


    $TxtboxAgency             = New-Object System.Windows.Forms.TextBox
    $TxtboxAgency.Location    = New-Object System.Drawing.Point(90, 50)  # (x, y) position
    $TxtboxAgency.Width       = $DefaultTxtbxWidth
    $TxtboxAgency.Font        = $TxtboxFontStyle
    $TxtboxAgency.BackColor   = [System.Drawing.Color]::White
    $TxtboxAgency.ForeColor   = [System.Drawing.Color]::Black
    $TxtboxAgency.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $TxtboxAgency.Multiline   = $false
    $MainForm.Controls.Add($TxtboxAgency)


    $LblCaseNumber           = New-Object System.Windows.Forms.Label
    $LblCaseNumber.Text      = "Case Number:"
    $LblCaseNumber.Location  = New-Object System.Drawing.Point(10, 85)  # (x, y) position
    $LblCaseNumber.Size      = $DefaultLblSize
    $LblCaseNumber.Font      = $GlobalFont
    $LblCaseNumber.ForeColor = [System.Drawing.Color]::Black
    $LblCaseNumber.TextAlign = "MiddleLeft"
    $MainForm.Controls.Add($LblCaseNumber)


    $TxtboxCaseNumber             = New-Object System.Windows.Forms.TextBox
    $TxtboxCaseNumber.Location    = New-Object System.Drawing.Point(90, 85)  # (x, y) position
    $TxtboxCaseNumber.Width       = $DefaultTxtbxWidth
    $TxtboxCaseNumber.Font        = $TxtboxFontStyle
    $TxtboxCaseNumber.BackColor   = [System.Drawing.Color]::White
    $TxtboxCaseNumber.ForeColor   = [System.Drawing.Color]::Black
    $TxtboxCaseNumber.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $TxtboxCaseNumber.Multiline   = $false
    $MainForm.Controls.Add($TxtboxCaseNumber)


    $GroupboxModules          = New-Object System.Windows.Forms.GroupBox
    $GroupboxModules.Text     = "SELECT MODULES TO RUN"
    $GroupboxModules.Location = New-Object System.Drawing.Point(10, 120)  # (x, y) position (original value: `10, 125`)
    $GroupboxModules.Size     = New-Object System.Drawing.Size(330, 395)  # width x height (original value: `410, 395`)
    $MainForm.Controls.Add($GroupboxModules)


    $GroupboxOptions          = New-Object System.Windows.Forms.GroupBox
    $GroupboxOptions.Text     = "OTHER OPTIONS"
    $GroupboxOptions.Location = New-Object System.Drawing.Point(360, 10)  # (x, y) position (original value: `440, 10`)
    $GroupboxOptions.Size     = New-Object System.Drawing.Size(275, 370)  # width x height (original value: `410, 370`)
    $MainForm.Controls.Add($GroupboxOptions)


    $ModulesChecklist = @(
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

    $ModulesChkBoxes = [System.Collections.Generic.List[System.Windows.Forms.CheckBox]]::new()

    for ($I = 0; $I -lt $ModulesChecklist.Count; $I++) {
        $Item = $ModulesChecklist[$I]

        # Initialize Independent Text Label (Columns 2 & 4)
        $TextLbl           = New-Object System.Windows.Forms.Label
        $TextLbl.Text      = $Item.Label
        $TextLbl.Font      = $GlobalFont
        $TextLbl.ForeColor = [System.Drawing.Color]::FromArgb(40, 40, 40)

        # Measure out text metrics using raw engine parameters
        $ProposedSize     = New-Object System.Drawing.Size($GroupboxLblWidth, 0)
        $MeasuredSize     = [System.Windows.Forms.TextRenderer]::MeasureText($Item.Label, $GlobalFont, $ProposedSize, [System.Windows.Forms.TextFormatFlags]::WordBreak)
        $CalculatedHeight = [Math]::Max($MeasuredSize.Height, $GroupboxTxtbxHeight)
        $TextLbl.Size     = New-Object System.Drawing.Size($GroupboxLblWidth, $CalculatedHeight)

        # Initialize Independent CheckBox Control (Column 1)
        $ChkBox      = New-Object System.Windows.Forms.CheckBox
        $ChkBox.Tag  = $Item.Name
        $ChkBox.Size = New-Object System.Drawing.Size($GroupboxChkBoxWidth, $GroupboxChkBoxHeight) # Strictly constrained to the square box frame asset

        $ChkBox.Location   = New-Object System.Drawing.Point($GroupboxCol1XValue, $GroupboxColYStart)
        $ChkBox.CheckAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $TextLbl.Location  = New-Object System.Drawing.Point($GroupboxCol2XValue, $GroupboxColYStart)
        $TextLbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

        $GroupboxModules.Controls.Add($ChkBox)
        $GroupboxModules.Controls.Add($TextLbl)

        # Advance Left pipeline coordinate tracker
        $GroupboxColYStart += $CalculatedHeight + $GroupboxControlsPadding

        $TextLbl.add_Click({
                param($Sender, $e)
                $AssociatedBox = $ModulesChkBoxes | Where-Object { $_.Tag -eq $Sender.Tag }
                if ($AssociatedBox) { $AssociatedBox.Checked = !$AssociatedBox.Checked }
            })
        $TextLbl.Tag = $Item.Name  # Store key mapping reference link
        $ModulesChkBoxes.Add($ChkBox)
    }

    $GroupboxSelectAllBtnY = ($GroupboxColYStart + $GroupboxControlsPadding + 10)

    $BtnSelectAllModules                            = New-Object System.Windows.Forms.Button
    $BtnSelectAllModules.Text                       = "Select All Modules"
    $BtnSelectAllModules.Font                       = $GlobalFont
    $BtnSelectAllModules.Width                      = $GroupboxBtnWidth
    $BtnSelectAllModules.Height                     = $GroupboxBtnHeight
    $BtnSelectAllModules.Padding                    = New-Object System.Windows.Forms.Padding(3)
    $BtnSelectAllModules.Location                   = New-Object Drawing.Point($GroupboxCol1XValue, $GroupboxSelectAllBtnY)  # (x, y) position
    $BtnSelectAllModules.FlatAppearance.BorderSize  = 1
    $BtnSelectAllModules.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $BtnSelectAllModules.BackColor                  = [System.Drawing.Color]::FromArgb(34, 139, 34)  # Soft green accent color
    $BtnSelectAllModules.Forecolor                  = [System.Drawing.Color]::White
    $BtnSelectAllModules.FlatStyle                  = [System.Windows.Forms.FlatStyle]::Flat
    $BtnSelectAllModules.add_Click({
        foreach ($ChkBox in $ModulesChkBoxes) {
            $ChkBox.Checked = $true
        }
    })
    $GroupboxModules.Controls.Add($BtnSelectAllModules)


    $BtnClearAllModules                            = New-Object System.Windows.Forms.Button
    $BtnClearAllModules.Text                       = "Deselect All Modules"
    $BtnClearAllModules.Font                       = $GlobalFont
    $BtnClearAllModules.Width                      = $GroupboxBtnWidth
    $BtnClearAllModules.Height                     = $GroupboxBtnHeight
    $BtnClearAllModules.Padding                    = New-Object System.Windows.Forms.Padding(3)
    $BtnClearAllModules.Location                   = New-Object Drawing.Point($GroupboxCol1XValue, ($GroupboxSelectAllBtnY + $GroupboxBtnHeight + 10))
    $BtnClearAllModules.FlatAppearance.BorderSize  = 1
    $BtnClearAllModules.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $BtnClearAllModules.BackColor                  = [System.Drawing.Color]::White
    $BtnClearAllModules.Forecolor                  = [System.Drawing.Color]::black
    $BtnClearAllModules.FlatStyle                  = [System.Windows.Forms.FlatStyle]::Flat
    $BtnClearAllModules.add_Click({
        foreach ($ChkBox in $ModulesChkBoxes) {
            $ChkBox.Checked = $false
        }
    })
    $GroupboxModules.Controls.Add($BtnClearAllModules)


    $OtherOptionsCheckList = @(
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

    $OptionsChkBoxes = [System.Collections.Generic.List[System.Windows.Forms.CheckBox]]::new()

    # Reset the value of this variable.
    $GroupboxColYStart = 30

    for ($I = 0; $I -lt $OtherOptionsCheckList.Count; $I++) {
        $Item = $OtherOptionsCheckList[$I]

        # Initialize independent text label for column 2
        $TextLbl           = New-Object System.Windows.Forms.Label
        $TextLbl.Text      = $Item.Label
        $TextLbl.Font      = $GlobalFont
        $TextLbl.ForeColor = [System.Drawing.Color]::FromArgb(40, 40, 40)

        # Measure out text metrics using raw engine parameters
        $ProposedSize     = New-Object System.Drawing.Size($GroupboxLblWidth, 0)
        $MeasuredSize     = [System.Windows.Forms.TextRenderer]::MeasureText($Item.Label, $GlobalFont, $ProposedSize, [System.Windows.Forms.TextFormatFlags]::WordBreak)
        $CalculatedHeight = [Math]::Max($MeasuredSize.Height, $GroupboxTxtbxHeight)
        $TextLbl.Size     = New-Object System.Drawing.Size($GroupboxLblWidth, $CalculatedHeight)

        # Initialize independent checkbox control column 1
        $ChkBox            = New-Object System.Windows.Forms.CheckBox
        $ChkBox.Tag        = $Item.Name
        $ChkBox.Size       = New-Object System.Drawing.Size($GroupboxChkBoxWidth, $GroupboxChkBoxHeight)  # Strictly constrained to the square box frame asset
        $ChkBox.Location   = New-Object System.Drawing.Point($GroupboxCol1XValue, $GroupboxColYStart)
        $ChkBox.CheckAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $TextLbl.Location  = New-Object System.Drawing.Point($GroupboxCol2XValue, $GroupboxColYStart)
        $TextLbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

        $GroupboxOptions.Controls.Add($ChkBox)
        $GroupboxOptions.Controls.Add($TextLbl)

        # Advance Left pipeline coordinate tracker
        $GroupboxColYStart += $CalculatedHeight + $GroupboxControlsPadding

        $TextLbl.add_Click({
                param($Sender, $e)
                $AssociatedBox = $OptionsChkBoxes | Where-Object { $_.Tag -eq $Sender.Tag }
                if ($AssociatedBox) { $AssociatedBox.Checked = !$AssociatedBox.Checked }
            })
        $TextLbl.Tag = $Item.Name  # Store key mapping reference link
        $OptionsChkBoxes.Add($ChkBox)
    }

    $GroupboxSelectAllBtnY = ($GroupboxColYStart + $GroupboxControlsPadding + 10)

    $BtnSelectAllOptions                            = New-Object System.Windows.Forms.Button
    $BtnSelectAllOptions.Text                       = "Select All Options"
    $BtnSelectAllOptions.Font                       = $GlobalFont
    $BtnSelectAllOptions.Width                      = $GroupboxBtnWidth
    $BtnSelectAllOptions.Height                     = $GroupboxBtnHeight
    $BtnSelectAllOptions.Padding                    = New-Object System.Windows.Forms.Padding(3)
    $BtnSelectAllOptions.Location                   = New-Object Drawing.Point($GroupboxCol1XValue, $GroupboxSelectAllBtnY)  # (x, y) position
    $BtnSelectAllOptions.FlatAppearance.BorderSize  = 1
    $BtnSelectAllOptions.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $BtnSelectAllOptions.BackColor                  = [System.Drawing.Color]::FromArgb(34, 139, 34)  # Soft green accent color
    $BtnSelectAllOptions.Forecolor                  = [System.Drawing.Color]::White
    $BtnSelectAllOptions.FlatStyle                  = [System.Windows.Forms.FlatStyle]::Flat
    $BtnSelectAllOptions.add_Click({
        foreach ($ChkBox in $OptionsChkBoxes) {
            $ChkBox.Checked = $true
        }
    })
    $GroupboxOptions.Controls.Add($BtnSelectAllOptions)


    $BtnClearAllOptions                            = New-Object System.Windows.Forms.Button
    $BtnClearAllOptions.Text                       = "Deselect All Options"
    $BtnClearAllOptions.Font                       = $GlobalFont
    $BtnClearAllOptions.Width                      = $GroupboxBtnWidth
    $BtnClearAllOptions.Height                     = $GroupboxBtnHeight
    $BtnClearAllOptions.Padding                    = New-Object System.Windows.Forms.Padding(3)
    $BtnClearAllOptions.Location                   = New-Object Drawing.Point($GroupboxCol1XValue, ($GroupboxSelectAllBtnY + $GroupboxBtnHeight + 10))
    $BtnClearAllOptions.FlatAppearance.BorderSize  = 1
    $BtnClearAllOptions.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $BtnClearAllOptions.BackColor                  = [System.Drawing.Color]::White
    $BtnClearAllOptions.Forecolor                  = [System.Drawing.Color]::black
    $BtnClearAllOptions.FlatStyle                  = [System.Windows.Forms.FlatStyle]::Flat
    $BtnClearAllOptions.add_Click({
        foreach ($ChkBox in $OptionsChkBoxes) {
            $ChkBox.Checked = $false
        }
    })
    $GroupboxOptions.Controls.Add($BtnClearAllOptions)


    # Define a button for initiating the files only report
    $BtnStartTriage                            = New-Object System.Windows.Forms.Button
    $BtnStartTriage.Name                       = "btnFilesReport"
    $BtnStartTriage.Text                       = "Start Triage"
    $BtnStartTriage.Font                       = $GlobalFont
    $BtnStartTriage.Width                      = $GroupboxBtnWidth
    $BtnStartTriage.Height                     = $GroupboxBtnHeight
    $BtnStartTriage.Padding                    = New-Object System.Windows.Forms.Padding(3)
    $BtnStartTriage.FlatStyle                  = [System.Windows.Forms.FlatStyle]::Flat
    $BtnStartTriage.Location                   = New-Object System.Drawing.Point(360, 410)  # (x, y) position
    $BtnStartTriage.FlatAppearance.BorderSize  = 1
    $BtnStartTriage.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $BtnStartTriage.BackColor                  = "#17a589"
    $BtnStartTriage.Forecolor                  = "#dddddd"
    # $BtnStartTriage.Add_Click({

            # $User = $TxtboxUserName.Text
            # $Agency = $TxtboxAgency.Text
            # $CaseNumber = $TxtboxCaseNumber.Text
            # $DriveList = $tbDrivesList.Text
            # $KeyWordsDrivesList = $TbKeyWordsDrivesList.Text

            # Export-FilesReport -CaseFolderName $caseFolderName -User $User -Agency $Agency -CaseNumber $caseNumber -ComputerName $ComputerName -Ipv4 $ipv4 -Ipv6 $ipv6 -Device $cbOne.Checked -UserData $cbTwo.Checked -Network $cbThree.Checked -Process $cbFour.Checked -System $cbFive.Checked -Prefetch $cbSix.Checked -EventLogs $cbSeven.Checked -Firewall $cbEight.Checked -BitLocker $cbNine.Checked -CaptureProcesses $cbGetProcesses.Checked -GetRam $cbGetRam.Checked -Edd $cbEdd.Checked -Hives $cbRegHives.Checked -CopyPrefetch $cbPrefetch.Checked -GetNTUserDat $cbNTUserDat.Checked -ListFiles $cbListFiles.Checked -DriveList $DriveList -KeyWordSearch $cbKeyWordSearch.Checked -KeyWordsDriveList $KeyWordsDrivesList -CopySrum $cbSruDb.Checked -GetFileHashes $cbHashFiles.Checked -MakeArchive $cbArchive.Checked

        #     $Form.Close()
        #     return

        # })
    # Add the button
    $MainForm.Controls.Add($BtnStartTriage)


    $BtnQuit                            = New-Object Windows.Forms.Button
    $BtnQuit.Text                       = "Quit"
    $BtnQuit.Font                       = $GlobalFont
    $BtnQuit.Width                      = $GroupboxBtnWidth
    $BtnQuit.Height                     = $GroupboxBtnHeight
    $BtnQuit.Padding                    = New-Object System.Windows.Forms.Padding(3)
    $BtnQuit.FlatStyle                  = [System.Windows.Forms.FlatStyle]::Flat
    $BtnQuit.Location                   = New-Object System.Drawing.Point(360, 450)  # (x, y) position
    $BtnQuit.FlatAppearance.BorderSize  = 1
    $BtnQuit.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $BtnQuit.BackColor                  = "#c0392b"
    $BtnQuit.Forecolor                  = "#dddddd"
    $BtnQuit.Add_Click({
            $MainForm.Close()
            return
        })

    $MainForm.Controls.Add($BtnQuit)


    $MainForm.Add_Shown({ $MainForm.Activate() })


    # Display the form
    [void]$MainForm.ShowDialog()
}

