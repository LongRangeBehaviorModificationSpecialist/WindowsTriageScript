function Get-Gui {
    <#
    .SYNOPSIS
        Assembles and runs the graphical wrapper managing all worker modules.
    #>

    $default_font_face         = "Segoe UI"
    $default_txtbx_width       = 250  # original value = 290
    $default_lbl_width         = 80  # original value = 120
    $default_lbl_height        = 20  # original value = 25
    $groupbox_lbl_width        = 200
    $groupbox_chk_box_width    = 20
    $groupbox_chk_box_height   = 20
    $groupbox_txtbx_height     = 20
    $groupbox_controls_padding = 0
    $groupbox_col_1_x_value    = 10
    $groupbox_col_2_x_value    = ($groupbox_col_1_x_value + $groupbox_chk_box_width)
    $groupbox_col_y_start      = 30
    $groupbox_select_all_btn_y = 0
    $groupbox_btn_width        = 150
    $groupbox_btn_height       = 30
    $global_font               = New-Object System.Drawing.Font($default_font_face, 8.5)
    $txtbx_font_style          = New-Object System.Drawing.Font($default_font_face, 9)
    $default_lbl_size          = New-Object System.Drawing.Size($default_lbl_width, $default_lbl_height)


    # Load required .NET GUI and Interaction assemblies explicitly
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName Microsoft.VisualBasic


    # Global high-DPI scaling configuration safety fix
    [System.Windows.Forms.Application]::EnableVisualStyles()


    # Form Base Shell
    $main_form                 = New-Object System.Windows.Forms.Form
    $main_form.Text            = "PowerShell Triage Interface"
    $main_form.Size            = New-Object System.Drawing.Size(700, 575)  # width x height (original value: `950, 750`)
    $main_form.StartPosition   = "CenterScreen"
    $main_form.FormBorderStyle = "Sizable"
    $main_form.MaximizeBox     = $false
    $main_form.BackColor       = [System.Drawing.Color]::FromArgb(245, 246, 248)


    # Define label and text boxes for source and destination directories
    $lbl_user_name           = New-Object System.Windows.Forms.Label
    $lbl_user_name.Text      = "User Name:"
    $lbl_user_name.Location  = New-Object System.Drawing.Point(10, 15)  # (x, y) position
    $lbl_user_name.Size      = $default_lbl_size
    $lbl_user_name.Font      = $global_font
    $lbl_user_name.ForeColor = [System.Drawing.Color]::Black
    $lbl_user_name.TextAlign = "MiddleLeft"
    $main_form.Controls.Add($lbl_user_name)


    $txtbx_user_name             = New-Object System.Windows.Forms.TextBox
    $txtbx_user_name.Location    = New-Object System.Drawing.Point(90, 15)  # (x, y) position
    $txtbx_user_name.Width       = $default_txtbx_width
    $txtbx_user_name.Font        = $txtbx_font_style
    $txtbx_user_name.BackColor   = [System.Drawing.Color]::White
    $txtbx_user_name.ForeColor   = [System.Drawing.Color]::Black
    $txtbx_user_name.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $txtbx_user_name.Multiline   = $false
    $main_form.Controls.Add($txtbx_user_name)


    $lbl_agency           = New-Object System.Windows.Forms.Label
    $lbl_agency.Text      = "Agency:"
    $lbl_agency.Location  = New-Object System.Drawing.Point(10, 50)  # (x, y) position
    $lbl_agency.Size      = $default_lbl_size
    $lbl_agency.Font      = $global_font
    $lbl_agency.ForeColor = [System.Drawing.Color]::Black
    $lbl_agency.TextAlign = "MiddleLeft"
    $main_form.Controls.Add($lbl_agency)


    $txtbx_agency             = New-Object System.Windows.Forms.TextBox
    $txtbx_agency.Location    = New-Object System.Drawing.Point(90, 50)  # (x, y) position
    $txtbx_agency.Width       = $default_txtbx_width
    $txtbx_agency.Font        = $txtbx_font_style
    $txtbx_agency.BackColor   = [System.Drawing.Color]::White
    $txtbx_agency.ForeColor   = [System.Drawing.Color]::Black
    $txtbx_agency.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $txtbx_agency.Multiline   = $false
    $main_form.Controls.Add($txtbx_agency)


    $lbl_case_number           = New-Object System.Windows.Forms.Label
    $lbl_case_number.Text      = "Case Number:"
    $lbl_case_number.Location  = New-Object System.Drawing.Point(10, 85)  # (x, y) position
    $lbl_case_number.Size      = $default_lbl_size
    $lbl_case_number.Font      = $global_font
    $lbl_case_number.ForeColor = [System.Drawing.Color]::Black
    $lbl_case_number.TextAlign = "MiddleLeft"
    $main_form.Controls.Add($lbl_case_number)


    $txtbx_case_number             = New-Object System.Windows.Forms.TextBox
    $txtbx_case_number.Location    = New-Object System.Drawing.Point(90, 85)  # (x, y) position
    $txtbx_case_number.Width       = $default_txtbx_width
    $txtbx_case_number.Font        = $txtbx_font_style
    $txtbx_case_number.BackColor   = [System.Drawing.Color]::White
    $txtbx_case_number.ForeColor   = [System.Drawing.Color]::Black
    $txtbx_case_number.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $txtbx_case_number.Multiline   = $false
    $main_form.Controls.Add($txtbx_case_number)


    $groupbox_modules          = New-Object System.Windows.Forms.GroupBox
    $groupbox_modules.Text     = "SELECT MODULES TO RUN"
    $groupbox_modules.Location = New-Object System.Drawing.Point(10, 120)  # (x, y) position (original value: `10, 125`)
    $groupbox_modules.Size     = New-Object System.Drawing.Size(330, 395)  # width x height (original value: `410, 395`)
    $main_form.Controls.Add($groupbox_modules)


    $groupbox_options          = New-Object System.Windows.Forms.GroupBox
    $groupbox_options.Text     = "OTHER OPTIONS"
    $groupbox_options.Location = New-Object System.Drawing.Point(360, 10)  # (x, y) position (original value: `440, 10`)
    $groupbox_options.Size     = New-Object System.Drawing.Size(275, 370)  # width x height (original value: `410, 370`)
    $main_form.Controls.Add($groupbox_options)


    $modules_checklist = @(
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

    $modules_chk_boxes = [System.Collections.Generic.List[System.Windows.Forms.CheckBox]]::new()

    for ($i = 0; $i -lt $modules_checklist.Count; $i++) {
        $item = $modules_checklist[$i]

        # Initialize Independent Text Label (Columns 2 & 4)
        $text_lbl           = New-Object System.Windows.Forms.Label
        $text_lbl.Text      = $item.Label
        $text_lbl.Font      = $global_font
        $text_lbl.ForeColor = [System.Drawing.Color]::FromArgb(40, 40, 40)

        # Measure out text metrics using raw engine parameters
        $proposed_size     = New-Object System.Drawing.Size($groupbox_lbl_width, 0)
        $measured_size     = [System.Windows.Forms.TextRenderer]::MeasureText($item.Label, $global_font, $proposed_size, [System.Windows.Forms.TextFormatFlags]::WordBreak)
        $calculated_height = [Math]::Max($measured_size.Height, $groupbox_txtbx_height)
        $text_lbl.Size     = New-Object System.Drawing.Size($groupbox_lbl_width, $calculated_height)

        # Initialize Independent CheckBox Control (Column 1)
        $chk_box      = New-Object System.Windows.Forms.CheckBox
        $chk_box.Tag  = $item.Name
        $chk_box.Size = New-Object System.Drawing.Size($groupbox_chk_box_width, $groupbox_chk_box_height) # Strictly constrained to the square box frame asset

        $chk_box.Location   = New-Object System.Drawing.Point($groupbox_col_1_x_value, $groupbox_col_y_start)
        $chk_box.CheckAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $text_lbl.Location  = New-Object System.Drawing.Point($groupbox_col_2_x_value, $groupbox_col_y_start)
        $text_lbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

        $groupbox_modules.Controls.Add($chk_box)
        $groupbox_modules.Controls.Add($text_lbl)

        # Advance Left pipeline coordinate tracker
        $groupbox_col_y_start += $calculated_height + $groupbox_controls_padding

        $text_lbl.add_Click({
                param($sender, $e)
                $associated_box = $modules_chk_boxes | Where-Object { $_.Tag -eq $sender.Tag }
                if ($associated_box) { $associated_box.Checked = !$associated_box.Checked }
            })
        $text_lbl.Tag = $item.Name  # Store key mapping reference link
        $modules_chk_boxes.Add($chk_box)
    }

    $groupbox_select_all_btn_y = ($groupbox_col_y_start + $groupbox_controls_padding + 10)

    $btn_select_all_modules                            = New-Object System.Windows.Forms.Button
    $btn_select_all_modules.Text                       = "Select All Modules"
    $btn_select_all_modules.Font                       = $global_font
    $btn_select_all_modules.Width                      = $groupbox_btn_width
    $btn_select_all_modules.Height                     = $groupbox_btn_height
    $btn_select_all_modules.Padding                    = New-Object System.Windows.Forms.Padding(3)
    $btn_select_all_modules.Location                   = New-Object Drawing.Point($groupbox_col_1_x_value, $groupbox_select_all_btn_y)  # (x, y) position
    $btn_select_all_modules.FlatAppearance.BorderSize  = 1
    $btn_select_all_modules.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $btn_select_all_modules.BackColor                  = [System.Drawing.Color]::FromArgb(34, 139, 34)  # Soft green accent color
    $btn_select_all_modules.Forecolor                  = [System.Drawing.Color]::White
    $btn_select_all_modules.FlatStyle                  = [System.Windows.Forms.FlatStyle]::Flat
    $btn_select_all_modules.add_Click({
        foreach ($chk_box in $modules_chk_boxes) {
            $chk_box.Checked = $true
        }
    })
    $groupbox_modules.Controls.Add($btn_select_all_modules)


    $btn_clear_all_modules                            = New-Object System.Windows.Forms.Button
    $btn_clear_all_modules.Text                       = "Deselect All Modules"
    $btn_clear_all_modules.Font                       = $global_font
    $btn_clear_all_modules.Width                      = $groupbox_btn_width
    $btn_clear_all_modules.Height                     = $groupbox_btn_height
    $btn_clear_all_modules.Padding                    = New-Object System.Windows.Forms.Padding(3)
    $btn_clear_all_modules.Location                   = New-Object Drawing.Point($groupbox_col_1_x_value, ($groupbox_select_all_btn_y + $groupbox_btn_height + 10))
    $btn_clear_all_modules.FlatAppearance.BorderSize  = 1
    $btn_clear_all_modules.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $btn_clear_all_modules.BackColor                  = [System.Drawing.Color]::White
    $btn_clear_all_modules.Forecolor                  = [System.Drawing.Color]::black
    $btn_clear_all_modules.FlatStyle                  = [System.Windows.Forms.FlatStyle]::Flat
    $btn_clear_all_modules.add_Click({
        foreach ($chk_box in $modules_chk_boxes) {
            $chk_box.Checked = $false
        }
    })
    $groupbox_modules.Controls.Add($btn_clear_all_modules)


    $other_options_checkList = @(
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

    $options_chk_boxes = [System.Collections.Generic.List[System.Windows.Forms.CheckBox]]::new()

    # Reset the value of this variable.
    $groupbox_col_y_start = 30

    for ($i = 0; $i -lt $other_options_checkList.Count; $i++) {
        $item = $other_options_checkList[$i]

        # Initialize independent text label for column 2
        $text_lbl           = New-Object System.Windows.Forms.Label
        $text_lbl.Text      = $item.Label
        $text_lbl.Font      = $global_font
        $text_lbl.ForeColor = [System.Drawing.Color]::FromArgb(40, 40, 40)

        # Measure out text metrics using raw engine parameters
        $proposed_size     = New-Object System.Drawing.Size($groupbox_lbl_width, 0)
        $measured_size     = [System.Windows.Forms.TextRenderer]::MeasureText($item.Label, $global_font, $proposed_size, [System.Windows.Forms.TextFormatFlags]::WordBreak)
        $calculated_height = [Math]::Max($measured_size.Height, $groupbox_txtbx_height)
        $text_lbl.Size     = New-Object System.Drawing.Size($groupbox_lbl_width, $calculated_height)

        # Initialize independent checkbox control column 1
        $chk_box            = New-Object System.Windows.Forms.CheckBox
        $chk_box.Tag        = $item.Name
        $chk_box.Size       = New-Object System.Drawing.Size($groupbox_chk_box_width, $groupbox_chk_box_height) # Strictly constrained to the square box frame asset
        $chk_box.Location   = New-Object System.Drawing.Point($groupbox_col_1_x_value, $groupbox_col_y_start)
        $chk_box.CheckAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $text_lbl.Location  = New-Object System.Drawing.Point($groupbox_col_2_x_value, $groupbox_col_y_start)
        $text_lbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

        $groupbox_options.Controls.Add($chk_box)
        $groupbox_options.Controls.Add($text_lbl)

        # Advance Left pipeline coordinate tracker
        $groupbox_col_y_start += $calculated_height + $groupbox_controls_padding

        $text_lbl.add_Click({
                param($sender, $e)
                $associated_box = $options_chk_boxes | Where-Object { $_.Tag -eq $sender.Tag }
                if ($associated_box) { $associated_box.Checked = !$associated_box.Checked }
            })
        $text_lbl.Tag = $item.Name  # Store key mapping reference link
        $options_chk_boxes.Add($chk_box)
    }

    $groupbox_select_all_btn_y = ($groupbox_col_y_start + $groupbox_controls_padding + 10)

    $btn_select_all_options                            = New-Object System.Windows.Forms.Button
    $btn_select_all_options.Text                       = "Select All Options"
    $btn_select_all_options.Font                       = $global_font
    $btn_select_all_options.Width                      = $groupbox_btn_width
    $btn_select_all_options.Height                     = $groupbox_btn_height
    $btn_select_all_options.Padding                    = New-Object System.Windows.Forms.Padding(3)
    $btn_select_all_options.Location                   = New-Object Drawing.Point($groupbox_col_1_x_value, $groupbox_select_all_btn_y)  # (x, y) position
    $btn_select_all_options.FlatAppearance.BorderSize  = 1
    $btn_select_all_options.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $btn_select_all_options.BackColor                  = [System.Drawing.Color]::FromArgb(34, 139, 34)  # Soft green accent color
    $btn_select_all_options.Forecolor                  = [System.Drawing.Color]::White
    $btn_select_all_options.FlatStyle                  = [System.Windows.Forms.FlatStyle]::Flat
    $btn_select_all_options.add_Click({
        foreach ($chk_box in $options_chk_boxes) {
            $chk_box.Checked = $true
        }
    })
    $gubox_options.Controls.Add($button_select_all_options)


    $btn_clear_all_options                            = New-Object System.Windows.Forms.Button
    $btn_clear_all_options.Text                       = "Deselect All Options"
    $btn_clear_all_options.Font                       = $global_font
    $btn_clear_all_options.Width                      = $groupbox_btn_width
    $btn_clear_all_options.Height                     = $groupbox_btn_height
    $btn_clear_all_options.Padding                    = New-Object System.Windows.Forms.Padding(3)
    $btn_clear_all_options.Location                   = New-Object Drawing.Point($groupbox_col_1_x_value, ($groupbox_select_all_btn_y + $groupbox_btn_height + 10))
    $btn_clear_all_options.FlatAppearance.BorderSize  = 1
    $btn_clear_all_options.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $btn_clear_all_options.BackColor                  = [System.Drawing.Color]::White
    $btn_clear_all_options.Forecolor                  = [System.Drawing.Color]::black
    $btn_clear_all_options.FlatStyle                  = [System.Windows.Forms.FlatStyle]::Flat
    $btn_clear_all_options.add_Click({
        foreach ($chk_box in $options_chk_boxes) {
            $chk_box.Checked = $false
        }
    })
    $groupbox_options.Controls.Add($btn_clear_all_options)


    # Define a button for initiating the files only report
    $btn_start_triage                            = New-Object System.Windows.Forms.Button
    $btn_start_triage.Name                       = "btnFilesReport"
    $btn_start_triage.Text                       = "Start Triage"
    $btn_start_triage.Font                       = $global_font
    $btn_start_triage.Width                      = $groupbox_btn_width
    $btn_start_triage.Height                     = $groupbox_btn_height
    $btn_start_triage.Padding                    = New-Object System.Windows.Forms.Padding(3)
    $btn_start_triage.FlatStyle                  = [System.Windows.Forms.FlatStyle]::Flat
    $btn_start_triage.Location                   = New-Object System.Drawing.Point(360, 410)  # (x, y) position
    $btn_start_triage.FlatAppearance.BorderSize  = 1
    $btn_start_triage.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $btn_start_triage.BackColor                  = "#17a589"
    $btn_start_triage.Forecolor                  = "#dddddd"
    # $btn_start_triage.Add_Click({

            # $User = $txtbx_user_name.Text
            # $Agency = $txtbx_agency.Text
            # $caseNumber = $txtbx_case_number.Text
            # $DriveList = $tbDrivesList.Text
            # $KeyWordsDrivesList = $tbKeyWordsDrivesList.Text

            # Export-FilesReport -CaseFolderName $caseFolderName -User $User -Agency $Agency -CaseNumber $caseNumber -ComputerName $computer_name -Ipv4 $ipv4 -Ipv6 $ipv6 -Device $cbOne.Checked -UserData $cbTwo.Checked -Network $cbThree.Checked -Process $cbFour.Checked -System $cbFive.Checked -Prefetch $cbSix.Checked -EventLogs $cbSeven.Checked -Firewall $cbEight.Checked -BitLocker $cbNine.Checked -CaptureProcesses $cbGetProcesses.Checked -GetRam $cbGetRam.Checked -Edd $cbEdd.Checked -Hives $cbRegHives.Checked -CopyPrefetch $cbPrefetch.Checked -GetNTUserDat $cbNTUserDat.Checked -ListFiles $cbListFiles.Checked -DriveList $DriveList -KeyWordSearch $cbKeyWordSearch.Checked -KeyWordsDriveList $KeyWordsDrivesList -CopySrum $cbSruDb.Checked -GetFileHashes $cbHashFiles.Checked -MakeArchive $cbArchive.Checked

        #     $Form.Close()
        #     return

        # })
    # Add the button
    $main_form.Controls.Add($btn_start_triage)


    $btn_quit                            = New-Object Windows.Forms.Button
    $btn_quit.Text                       = "Quit"
    $btn_quit.Font                       = $global_font
    $btn_quit.Width                      = $groupbox_btn_width
    $btn_quit.Height                     = $groupbox_btn_height
    $btn_quit.Padding                    = New-Object System.Windows.Forms.Padding(3)
    $btn_quit.FlatStyle                  = [System.Windows.Forms.FlatStyle]::Flat
    $btn_quit.Location                   = New-Object System.Drawing.Point(360, 450)  # (x, y) position
    $btn_quit.FlatAppearance.BorderSize  = 1
    $btn_quit.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $btn_quit.BackColor                  = "#c0392b"
    $btn_quit.Forecolor                  = "#dddddd"
    $btn_quit.Add_Click({
            $main_form.Close()
            return
        })

    $main_form.Controls.Add($btn_quit)


    $main_form.Add_Shown({ $main_form.Activate() })


    # Display the form
    [void]$main_form.ShowDialog()
}

