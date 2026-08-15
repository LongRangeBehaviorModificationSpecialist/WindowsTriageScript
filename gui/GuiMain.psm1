function Get-Gui {
    <#
    .SYNOPSIS
        Assembles and runs the graphical wrapper managing all worker modules.
    #>

    $DefaultFontFace = "Segoe UI"
    $DefaultTxtbxW   = 250  # original value = 290
    $DefaultLblW     = 80  # original value = 120
    $DefaultLblH     = 20  # original value = 25
    $GpBxLblW        = 200
    $GpBxChkBoxW     = 20
    $GpBxChkBoxH     = 20
    $GpBxTxtbxH      = 20
    $GpBxControlPad  = 0
    $GpBxCol1XValue  = 10
    $GpBxCol2XValue  = ($GpBxCol1XValue + $GpBxChkBoxW)
    $GpBxColYStart   = 30
    $GpBxSelAllBtnY  = 0
    $GpBxBtnW        = 150
    $GpBxBtnH        = 30
    $GlobalFont      = New-Object System.Drawing.Font($DefaultFontFace, 8.5)
    $TxtboxFontStyle = New-Object System.Drawing.Font($DefaultFontFace, 9)
    $DefaultLblSize  = New-Object System.Drawing.Size($DefaultLblW, $DefaultLblH)


    # Load required .NET GUI and Interaction assemblies explicitly
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName Microsoft.VisualBasic


    # Global high-DPI scaling configuration safety fix
    [System.Windows.Forms.Application]::EnableVisualStyles()


    # Form Base Shell
    $MainForm                 = New-Object System.Windows.Forms.Form
    $MainForm.Text            = "PowerShell Triage Interface"
    $MainForm.Size            = New-Object System.Drawing.Size(700, 575)
    $MainForm.StartPosition   = "CenterScreen"
    $MainForm.FormBorderStyle = "Sizable"
    $MainForm.MaximizeBox     = $false
    $MainForm.BackColor       = [System.Drawing.Color]::FromArgb(245, 246, 248)
    $MainForm.TopMost         = $false


    # Define label and text boxes for source and destination directories
    $LblUserName           = New-Object System.Windows.Forms.Label
    $LblUserName.Text      = "User Name:"
    $LblUserName.Location  = New-Object System.Drawing.Point(10, 15)
    $LblUserName.Size      = $DefaultLblSize
    $LblUserName.Font      = $GlobalFont
    $LblUserName.ForeColor = [System.Drawing.Color]::Black
    $LblUserName.TextAlign = "MiddleLeft"
    $MainForm.Controls.Add($LblUserName)


    $TxtboxUserName             = New-Object System.Windows.Forms.TextBox
    $TxtboxUserName.Location    = New-Object System.Drawing.Point(90, 15)
    $TxtboxUserName.Width       = $DefaultTxtbxW
    $TxtboxUserName.Font        = $TxtboxFontStyle
    $TxtboxUserName.BackColor   = [System.Drawing.Color]::White
    $TxtboxUserName.ForeColor   = [System.Drawing.Color]::Black
    $TxtboxUserName.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $TxtboxUserName.Multiline   = $false
    $MainForm.Controls.Add($TxtboxUserName)


    $LblAgency           = New-Object System.Windows.Forms.Label
    $LblAgency.Text      = "Agency:"
    $LblAgency.Location  = New-Object System.Drawing.Point(10, 50)
    $LblAgency.Size      = $DefaultLblSize
    $LblAgency.Font      = $GlobalFont
    $LblAgency.ForeColor = [System.Drawing.Color]::Black
    $LblAgency.TextAlign = "MiddleLeft"
    $MainForm.Controls.Add($LblAgency)


    $TxtboxAgency             = New-Object System.Windows.Forms.TextBox
    $TxtboxAgency.Location    = New-Object System.Drawing.Point(90, 50)
    $TxtboxAgency.Width       = $DefaultTxtbxW
    $TxtboxAgency.Font        = $TxtboxFontStyle
    $TxtboxAgency.BackColor   = [System.Drawing.Color]::White
    $TxtboxAgency.ForeColor   = [System.Drawing.Color]::Black
    $TxtboxAgency.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $TxtboxAgency.Multiline   = $false
    $MainForm.Controls.Add($TxtboxAgency)


    $LblCaseNumber           = New-Object System.Windows.Forms.Label
    $LblCaseNumber.Text      = "Case Number:"
    $LblCaseNumber.Location  = New-Object System.Drawing.Point(10, 85)
    $LblCaseNumber.Size      = $DefaultLblSize
    $LblCaseNumber.Font      = $GlobalFont
    $LblCaseNumber.ForeColor = [System.Drawing.Color]::Black
    $LblCaseNumber.TextAlign = "MiddleLeft"
    $MainForm.Controls.Add($LblCaseNumber)


    $TxtboxCaseNumber             = New-Object System.Windows.Forms.TextBox
    $TxtboxCaseNumber.Location    = New-Object System.Drawing.Point(90, 85)
    $TxtboxCaseNumber.Width       = $DefaultTxtbxW
    $TxtboxCaseNumber.Font        = $TxtboxFontStyle
    $TxtboxCaseNumber.BackColor   = [System.Drawing.Color]::White
    $TxtboxCaseNumber.ForeColor   = [System.Drawing.Color]::Black
    $TxtboxCaseNumber.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $TxtboxCaseNumber.Multiline   = $false
    $MainForm.Controls.Add($TxtboxCaseNumber)


    $GpBxModules          = New-Object System.Windows.Forms.GroupBox
    $GpBxModules.Text     = "Sel MODULES TO RUN"
    $GpBxModules.Location = New-Object System.Drawing.Point(10, 120)
    $GpBxModules.Size     = New-Object System.Drawing.Size(330, 395)
    $MainForm.Controls.Add($GpBxModules)


    $GpBxOpts          = New-Object System.Windows.Forms.GroupBox
    $GpBxOpts.Text     = "OTHER Opts"
    $GpBxOpts.Location = New-Object System.Drawing.Point(360, 10)
    $GpBxOpts.Size     = New-Object System.Drawing.Size(275, 370)
    $MainForm.Controls.Add($GpBxOpts)


    $ModulesChkLst = @(
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

    for ($I = 0; $I -lt $ModulesChkLst.Count; $I++) {
        $Item = $ModulesChkLst[$I]

        # Initialize Independent Text Label (Columns 2 & 4)
        $TextLbl           = New-Object System.Windows.Forms.Label
        $TextLbl.Text      = $Item.Label
        $TextLbl.Font      = $GlobalFont
        $TextLbl.ForeColor = [System.Drawing.Color]::FromArgb(40, 40, 40)

        # Measure out text metrics using raw engine parameters
        $ProposedSize = New-Object System.Drawing.Size($GpBxLblW, 0)
        $MeasuredSize = [System.Windows.Forms.TextRenderer]::MeasureText($Item.Label, $GlobalFont, $ProposedSize, [System.Windows.Forms.TextFormatFlags]::WordBreak)
        $CalculatedH  = [Math]::Max($MeasuredSize.H, $GpBxTxtbxH)
        $TextLbl.Size = New-Object System.Drawing.Size($GpBxLblW, $CalculatedH)

        # Initialize Independent CheckBox Control (Column 1)
        # Strictly constrained to the square box frame asset
        $ChkBox      = New-Object System.Windows.Forms.CheckBox
        $ChkBox.Tag  = $Item.Name
        $ChkBox.Size = New-Object System.Drawing.Size($GpBxChkBoxW, $GpBxChkBoxH)

        $ChkBox.Location   = New-Object System.Drawing.Point($GpBxCol1XValue, $GpBxColYStart)
        $ChkBox.CheckAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $TextLbl.Location  = New-Object System.Drawing.Point($GpBxCol2XValue, $GpBxColYStart)
        $TextLbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

        $GpBxModules.Controls.Add($ChkBox)
        $GpBxModules.Controls.Add($TextLbl)

        # Advance Left pipeline coordinate tracker
        $GpBxColYStart += $CalculatedH + $GpBxControlPad

        $TextLbl.add_Click({
                param($Sender, $e)
                $AssociatedBox = $ModulesChkBoxes | Where-Object { $_.Tag -eq $Sender.Tag }
                if ($AssociatedBox) { $AssociatedBox.Checked = !$AssociatedBox.Checked }
            })
        # Store key mapping reference link
        $TextLbl.Tag = $Item.Name
        $ModulesChkBoxes.Add($ChkBox)
    }

    $GpBxSelAllBtnY = ($GpBxColYStart + $GpBxControlPad + 10)

    $BtnSelAllModules                            = New-Object System.Windows.Forms.Button
    $BtnSelAllModules.Text                       = "Sel All Modules"
    $BtnSelAllModules.Font                       = $GlobalFont
    $BtnSelAllModules.Width                      = $GpBxBtnW
    $BtnSelAllModules.Height                     = $GpBxBtnH
    $BtnSelAllModules.Padding                    = New-Object System.Windows.Forms.Padding(3)
    $BtnSelAllModules.Location                   = New-Object Drawing.Point($GpBxCol1XValue, $GpBxSelAllBtnY)
    $BtnSelAllModules.FlatAppearance.BorderSize  = 1
    $BtnSelAllModules.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $BtnSelAllModules.BackColor                  = [System.Drawing.Color]::FromArgb(34, 139, 34)
    $BtnSelAllModules.Forecolor                  = [System.Drawing.Color]::White
    $BtnSelAllModules.FlatStyle                  = [System.Windows.Forms.FlatStyle]::Flat
    $BtnSelAllModules.add_Click({
        foreach ($ChkBox in $ModulesChkBoxes) {
            $ChkBox.Checked = $true
        }
    })
    $GpBxModules.Controls.Add($BtnSelAllModules)


    $BtnClearAllModules                            = New-Object System.Windows.Forms.Button
    $BtnClearAllModules.Text                       = "DeSel All Modules"
    $BtnClearAllModules.Font                       = $GlobalFont
    $BtnClearAllModules.Width                      = $GpBxBtnW
    $BtnClearAllModules.Height                     = $GpBxBtnH
    $BtnClearAllModules.Padding                    = New-Object System.Windows.Forms.Padding(3)
    $BtnClearAllModules.Location                   = New-Object Drawing.Point($GpBxCol1XValue, ($GpBxSelAllBtnY + $GpBxBtnH + 10))
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
    $GpBxModules.Controls.Add($BtnClearAllModules)


    $OtherOptsChkLst = @(
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

    $OptsChkBoxes = [System.Collections.Generic.List[System.Windows.Forms.CheckBox]]::new()

    # Reset the value of this variable.
    $GpBxColYStart = 30

    for ($I = 0; $I -lt $OtherOptsChkLst.Count; $I++) {
        $Item = $OtherOptsChkLst[$I]

        # Initialize independent text label for column 2
        $TextLbl           = New-Object System.Windows.Forms.Label
        $TextLbl.Text      = $Item.Label
        $TextLbl.Font      = $GlobalFont
        $TextLbl.ForeColor = [System.Drawing.Color]::FromArgb(40, 40, 40)

        # Measure out text metrics using raw engine parameters
        $ProposedSize     = New-Object System.Drawing.Size($GpBxLblW, 0)
        $MeasuredSize     = [System.Windows.Forms.TextRenderer]::MeasureText($Item.Label, $GlobalFont, $ProposedSize, [System.Windows.Forms.TextFormatFlags]::WordBreak)
        $CalculatedH      = [Math]::Max($MeasuredSize.H, $GpBxTxtbxH)
        $TextLbl.Size     = New-Object System.Drawing.Size($GpBxLblW, $CalculatedH)

        # Initialize independent checkbox control column 1
        # Strictly constrained to the square box frame asset
        $ChkBox            = New-Object System.Windows.Forms.CheckBox
        $ChkBox.Tag        = $Item.Name
        $ChkBox.Size       = New-Object System.Drawing.Size($GpBxChkBoxW, $GpBxChkBoxH)
        $ChkBox.Location   = New-Object System.Drawing.Point($GpBxCol1XValue, $GpBxColYStart)
        $ChkBox.CheckAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $TextLbl.Location  = New-Object System.Drawing.Point($GpBxCol2XValue, $GpBxColYStart)
        $TextLbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

        $GpBxOpts.Controls.Add($ChkBox)
        $GpBxOpts.Controls.Add($TextLbl)

        # Advance Left pipeline coordinate tracker
        $GpBxColYStart += $CalculatedH + $GpBxControlPad

        $TextLbl.add_Click({
                param($Sender, $e)
                $AssociatedBox = $OptsChkBoxes | Where-Object { $_.Tag -eq $Sender.Tag }
                if ($AssociatedBox) { $AssociatedBox.Checked = !$AssociatedBox.Checked }
            })
        # Store key mapping reference link
        $TextLbl.Tag = $Item.Name
        $OptsChkBoxes.Add($ChkBox)
    }

    $GpBxSelAllBtnY = ($GpBxColYStart + $GpBxControlPad + 10)

    $BtnSelAllOpts                            = New-Object System.Windows.Forms.Button
    $BtnSelAllOpts.Text                       = "Sel All Opts"
    $BtnSelAllOpts.Font                       = $GlobalFont
    $BtnSelAllOpts.Width                      = $GpBxBtnW
    $BtnSelAllOpts.Height                     = $GpBxBtnH
    $BtnSelAllOpts.Padding                    = New-Object System.Windows.Forms.Padding(3)
    $BtnSelAllOpts.Location                   = New-Object Drawing.Point($GpBxCol1XValue, $GpBxSelAllBtnY)
    $BtnSelAllOpts.FlatAppearance.BorderSize  = 1
    $BtnSelAllOpts.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $BtnSelAllOpts.BackColor                  = [System.Drawing.Color]::FromArgb(34, 139, 34)
    $BtnSelAllOpts.Forecolor                  = [System.Drawing.Color]::White
    $BtnSelAllOpts.FlatStyle                  = [System.Windows.Forms.FlatStyle]::Flat
    $BtnSelAllOpts.add_Click({
        foreach ($ChkBox in $OptsChkBoxes) {
            $ChkBox.Checked = $true
        }
    })
    $GpBxOpts.Controls.Add($BtnSelAllOpts)


    $BtnClearAllOpts                            = New-Object System.Windows.Forms.Button
    $BtnClearAllOpts.Text                       = "DeSel All Opts"
    $BtnClearAllOpts.Font                       = $GlobalFont
    $BtnClearAllOpts.Width                      = $GpBxBtnW
    $BtnClearAllOpts.Height                     = $GpBxBtnH
    $BtnClearAllOpts.Padding                    = New-Object System.Windows.Forms.Padding(3)
    $BtnClearAllOpts.Location                   = New-Object Drawing.Point($GpBxCol1XValue, ($GpBxSelAllBtnY + $GpBxBtnH + 10))
    $BtnClearAllOpts.FlatAppearance.BorderSize  = 1
    $BtnClearAllOpts.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $BtnClearAllOpts.BackColor                  = [System.Drawing.Color]::White
    $BtnClearAllOpts.Forecolor                  = [System.Drawing.Color]::black
    $BtnClearAllOpts.FlatStyle                  = [System.Windows.Forms.FlatStyle]::Flat
    $BtnClearAllOpts.add_Click({
        foreach ($ChkBox in $OptsChkBoxes) {
            $ChkBox.Checked = $false
        }
    })
    $GpBxOpts.Controls.Add($BtnClearAllOpts)


    # Define a button for initiating the files only report
    $BtnStartTriage                            = New-Object System.Windows.Forms.Button
    $BtnStartTriage.Name                       = "btnFilesReport"
    $BtnStartTriage.Text                       = "Start Triage"
    $BtnStartTriage.Font                       = $GlobalFont
    $BtnStartTriage.Width                      = $GpBxBtnW
    $BtnStartTriage.Height                     = $GpBxBtnH
    $BtnStartTriage.Padding                    = New-Object System.Windows.Forms.Padding(3)
    $BtnStartTriage.FlatStyle                  = [System.Windows.Forms.FlatStyle]::Flat
    $BtnStartTriage.Location                   = New-Object System.Drawing.Point(360, 410)
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

        # Export-FilesReport -CaseFolderName $CaseFolderName -User $User -Agency $Agency -CaseNumber $CaseNumber -ComputerName $ComputerName -Ipv4 $Ipv4 -Ipv6 $Ipv6 -Device $CbOne.Checked -UserData $CbTwo.Checked -Network $CbThree.Checked -Process $CbFour.Checked -System $CbFive.Checked -Prefetch $CbSix.Checked -EventLogs $CbSeven.Checked -Firewall $CbEight.Checked -BitLocker $CbNine.Checked -CaptureProcesses $CbGetProcesses.Checked -GetRam $CbGetRam.Checked -Edd $CbEdd.Checked -Hives $CbRegHives.Checked -CopyPrefetch $CbPrefetch.Checked -GetNTUserDat $CbNTUserDat.Checked -ListFiles $CbListFiles.Checked -DriveList $DriveList -KeyWordSearch $CbKeyWordSearch.Checked -KeyWordsDriveList $KeyWordsDrivesList -CopySrum $CbSruDb.Checked -GetFileHashes $CbHashFiles.Checked -MakeArchive $CbArchive.Checked

        #     $Form.Close()
        #     return

        # })
    # Add the button
    $MainForm.Controls.Add($BtnStartTriage)


    $BtnQuit                            = New-Object Windows.Forms.Button
    $BtnQuit.Text                       = "Quit"
    $BtnQuit.Font                       = $GlobalFont
    $BtnQuit.Width                      = $GpBxBtnW
    $BtnQuit.Height                     = $GpBxBtnH
    $BtnQuit.Padding                    = New-Object System.Windows.Forms.Padding(3)
    $BtnQuit.FlatStyle                  = [System.Windows.Forms.FlatStyle]::Flat
    $BtnQuit.Location                   = New-Object System.Drawing.Point(360, 450)
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

