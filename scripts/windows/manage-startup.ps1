#Requires -RunAsAdministrator
<#
    manage-startup.ps1 — picks which programs start by themselves with Windows

    HOW TO RUN (Windows PowerShell 5.1 as Administrator):
        powershell -ExecutionPolicy Bypass -File .\manage-startup.ps1

    Lists the programs that open by themselves when you sign in: the Run keys of the registry (yours and
    every user's) and the Startup folders. Two lists:
        Don't start with Windows ...... the ones that start now; the checked ones stop starting
        Start with Windows again ...... the ones turned off (here or in Task Manager); the checked ones start again
    It works like Task Manager → Startup apps and writes to the same place (StartupApproved), so both
    always agree. Nothing is deleted or uninstalled: the program still opens when you open it.
    Not listed: Windows Security (left alone, like everywhere in TidyWin) and Microsoft Store apps, which
    have their own switches in Settings → Apps → Startup.
    Undo: open this page again and check the program under "Start with Windows again". Safe to run more than once.

    FILE LAYOUT
        1. Helpers ................... prompts, reading the startup programs
        2. Steps
        3. Execution
#>
param(
    [string]$Describe,   # for the panel: writes the options of the page to this file and stops
    [string]$Answers     # for the panel: what was chosen there (nothing is asked)
)

$ErrorActionPreference = 'Continue'


#region ==================== PANEL ====================

# Run from the TidyWin panel ($env:TIDYWIN_PANEL = 1): the questions show up in the panel window. Each one
# goes out as a line "##TIDYWIN {json}" and the answer comes back as one JSON line on the standard input.
# Write-Host lines carry their color ([char]1 + color + [char]2 + text) so the panel can show it.
$script:Panel = $env:TIDYWIN_PANEL -eq '1'
$script:PanelLine = ''

function Write-PanelHost {
    param([Parameter(Position = 0, ValueFromRemainingArguments = $true)][object[]]$Object, [switch]$NoNewline,
          [object]$Separator = ' ', [ConsoleColor]$ForegroundColor, [ConsoleColor]$BackgroundColor)
    $text  = (@($Object) | ForEach-Object { "$_" }) -join "$Separator"
    $color = if ($PSBoundParameters.ContainsKey('ForegroundColor')) { "$ForegroundColor" } else { '' }
    $parts = @($text -split "`r?`n")
    for ($i = 0; $i -lt $parts.Count; $i++) {
        $script:PanelLine += [string][char]1 + $color + [char]2 + $parts[$i]
        if ($i -lt $parts.Count - 1 -or -not $NoNewline) { [Console]::Out.WriteLine($script:PanelLine); $script:PanelLine = '' }
    }
}

# Sends a question to the panel and returns the answer ($null when it was cancelled).
function Request-Panel([hashtable]$Request) {
    if ($script:PanelLine) { [Console]::Out.WriteLine($script:PanelLine); $script:PanelLine = '' }
    [Console]::Out.WriteLine('##TIDYWIN ' + (ConvertTo-Json $Request -Compress -Depth 6))
    $line = [Console]::In.ReadLine()
    if ($null -eq $line) { exit 1 }                       # the panel was closed
    return (ConvertFrom-Json $line.Trim([char]0xFEFF)).value
}

# While the panel reads the page (-Describe): what is being read now and how far (0-100; none = unknown),
# shown in the bar under its loading ring. Does nothing otherwise.
function Write-Loading([string]$Text, $Percent) {
    if (-not $script:Panel -or -not $Describe) { return }
    [Console]::Out.WriteLine('##TIDYWIN ' + (ConvertTo-Json @{ type = 'progress'; text = $Text; value = $Percent } -Compress))
}

if ($script:Panel) {
    function Write-Host {
        param([Parameter(Position = 0, ValueFromRemainingArguments = $true)][object[]]$Object, [switch]$NoNewline,
              [object]$Separator = ' ', [ConsoleColor]$ForegroundColor, [ConsoleColor]$BackgroundColor)
        Write-PanelHost @PSBoundParameters
    }
    # Typed answers: a "press Enter" pause, a folder, a file or text
    function Read-Host([Parameter(Position = 0)][object]$Prompt) {
        $q = "$Prompt".Trim()
        $type = if ($q -match '(?i)press Enter') { 'wait' } elseif ($q -match '(?i)^folder') { 'folder' } elseif ($q -match '(?i)\.json file') { 'file' } else { 'text' }
        return "$(Request-Panel @{ type = $type; question = $q })"
    }
}

# --- Options of a page in the panel (the same in every script). A field: tab, id, kind (toggle, choice,
# select, checklist, text, header), label, desc, default and more (options, items, warn, when...).
# -Describe writes the fields for the panel's page; Read-Options brings back what was chosen: the panel's
# answers file, or asked here when the script runs on its own. Nothing comes selected.
function Opt($Value, [string]$Label) { [ordered]@{ value = $Value; label = $Label } }

function New-Field([string]$Tab, [string]$Id, [string]$Kind, [string]$Label, [string]$Desc, $Default, [hashtable]$More) {
    $f = [ordered]@{ tab = $Tab; id = $Id; kind = $Kind; label = $Label; desc = $Desc; default = $Default }
    if ($More) { foreach ($k in $More.Keys) { $f[$k] = $More[$k] } }
    return $f
}

function Write-OptionsPage([string]$Path, [object[]]$Fields, [string[]]$Notes) {
    $page = [ordered]@{ tabs = @($Fields | ForEach-Object { $_.tab } | Select-Object -Unique); notes = @($Notes | Where-Object { $_ }); fields = @($Fields | Where-Object { $_ }) }
    [IO.File]::WriteAllText($Path, (ConvertTo-Json $page -Depth 10), (New-Object Text.UTF8Encoding $false))
}

function Read-Options([object[]]$Fields, [string]$AnswersFile) {
    $values = @{}
    foreach ($f in $Fields) { if ($f.kind -ne 'header') { $values[$f.id] = $f.default } }
    if ($AnswersFile) {
        $json = [IO.File]::ReadAllText($AnswersFile) | ConvertFrom-Json
        foreach ($prop in $json.PSObject.Properties) { $values[$prop.Name] = $prop.Value }
        return $values
    }
    foreach ($f in $Fields) {
        if ($f.when -and "$($values[$f.when.field])" -ne "$($f.when.is)") { continue }
        switch ($f.kind) {
            'header'    { Write-Host "`n  $($f.label)" -ForegroundColor Cyan }
            'toggle'    { $values[$f.id] = Ask "$($f.label)?" $false }
            'info'      { Write-Host "  $($f.label): $($f.desc)" -ForegroundColor DarkGray }
            { $_ -in 'text', 'path' } { $values[$f.id] = "$(Read-Host "  $($f.label)")".Trim().Trim('"') }
            'checklist' { $values[$f.id] = @($f.items | Where-Object { Ask "$($f.label): $($_.label)?" $false } | ForEach-Object { $_.value }) }
            default {
                # choice and select; "Skip" leaves it as it is
                $options = @(Opt '' 'Skip') + @($f.options)
                $values[$f.id] = $options[(Choose "$($f.label):" @($options | ForEach-Object { $_.label }) 0)].value
            }
        }
    }
    return $values
}

# Yes / No (scripts that ask more define their own, the same)
function Ask([string]$Question, [bool]$Default) {
    return (Choose $Question @('Yes', 'No') $(if ($Default) { 0 } else { 1 })) -eq 0
}

#endregion

#region ==================== 1. HELPERS ====================


function Write-Step([string]$Text) { Write-Host "`n▸ $Text" -ForegroundColor Cyan }

# Menu driven by the ↑ ↓ arrow keys and Enter. Returns the chosen index.
# The "use the arrows" hint is shown only on the first menu.
function Choose([string]$Question, [string[]]$Options, [int]$Default = 0) {
    if ($script:Panel) { return [int](Request-Panel @{ type = 'choose'; question = $Question; options = @($Options); default = $Default }) }
    Write-Host "  $Question"
    $arrows = ($Host.Name -eq 'ConsoleHost') -and -not [Console]::IsInputRedirected
    if (-not $arrows) {
        # No real console (e.g. PowerShell ISE): numbered menu instead
        for ($i = 0; $i -lt $Options.Count; $i++) { Write-Host "    $($i + 1)) $($Options[$i])" }
        while ($true) {
            $answer = "$(Read-Host "  Number [$($Default + 1)]")".Trim()
            if ($answer -eq '') { return $Default }
            $n = 0
            if ([int]::TryParse($answer, [ref]$n) -and $n -ge 1 -and $n -le $Options.Count) { return $n - 1 }
            Write-Host "  Type a number from 1 to $($Options.Count)." -ForegroundColor DarkYellow
        }
    }
    if (-not $script:ArrowHintShown) {
        Write-Host '  (use the arrows ↑ ↓ and Enter)' -ForegroundColor DarkGray
        $script:ArrowHintShown = $true
    }
    foreach ($o in $Options) { Write-Host '' }                # reserve the menu lines
    $top = [Console]::CursorTop - $Options.Count
    $selected = $Default
    [Console]::CursorVisible = $false
    try {
        while ($true) {
            for ($i = 0; $i -lt $Options.Count; $i++) {
                [Console]::SetCursorPosition(0, $top + $i)
                $marker = if ($i -eq $selected) { '  > ' } else { '    ' }
                $line = ($marker + $Options[$i]).PadRight([Console]::WindowWidth - 1)
                if ($i -eq $selected) { Write-Host $line -ForegroundColor Cyan -NoNewline } else { Write-Host $line -NoNewline }
            }
            $key = [Console]::ReadKey($true).Key
            if     ($key -eq 'UpArrow')   { $selected = ($selected - 1 + $Options.Count) % $Options.Count }
            elseif ($key -eq 'DownArrow') { $selected = ($selected + 1) % $Options.Count }
            elseif ($key -eq 'Enter')     { break }
        }
    } finally {
        [Console]::SetCursorPosition(0, $top + $Options.Count)
        [Console]::CursorVisible = $true
    }
    return $selected
}

# Yes/no question shown as a "Yes / No" menu (same as Choose). The default comes selected.
function Ask([string]$Question, [bool]$Default) {
    return (Choose $Question @('Yes', 'No') $(if ($Default) { 0 } else { 1 })) -eq 0
}

# Result line: [OK] text / [WARNING] text / [ERROR] text
function Write-Result([ValidateSet('OK', 'WARN', 'ERROR')][string]$Status, [string]$Text) {
    $label, $color = switch ($Status) {
        'OK'    { '[OK]', 'Green' }
        'WARN'  { '[WARNING]', 'Yellow' }
        'ERROR' { '[ERROR]', 'Red' }
    }
    Write-Host "  $label " -ForegroundColor $color -NoNewline
    Write-Host $Text
}

# Where programs register to start with Windows, and where Windows keeps the on/off switch of each one
# (the StartupApproved key Task Manager uses). "Everyone": programs set up for every user of the PC.
$ApprovedKey = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
$StartupSources = @(
    @{ Kind = 'Run';    Where = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run';             Approved = "HKCU:\$ApprovedKey\Run";           Everyone = $false }
    @{ Kind = 'Run';    Where = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run';             Approved = "HKLM:\$ApprovedKey\Run";           Everyone = $true }
    @{ Kind = 'Run';    Where = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKLM:\$ApprovedKey\Run32";         Everyone = $true }
    @{ Kind = 'Folder'; Where = [Environment]::GetFolderPath('Startup');                           Approved = "HKCU:\$ApprovedKey\StartupFolder"; Everyone = $false }
    @{ Kind = 'Folder'; Where = [Environment]::GetFolderPath('CommonStartup');                     Approved = "HKLM:\$ApprovedKey\StartupFolder"; Everyone = $true }
)

# Left alone: Windows Security's icon (TidyWin never touches Windows Defender)
$KeepStartup = @('SecurityHealth', 'WindowsDefender')

# Makers whose startup programs come with a driver: turning them off can stop extras like touchpad
# gestures, audio effects or keyboard hotkeys, so the row says so.
$DriverMakers = 'Realtek|Intel|NVIDIA|Advanced Micro Devices|AMD|Synaptics|ELAN|Dolby|Waves|Conexant|Logitech|Razer|Corsair|ASUSTeK|Lenovo|HP Inc|Hewlett|Dell|Acer|MSI|Micro-Star|SteelSeries'

# The program file a startup command opens: the quoted path, or everything up to ".exe".
function Get-CommandFile([string]$Command) {
    $c = [Environment]::ExpandEnvironmentVariables($Command).Trim()
    if ($c -match '^"([^"]+)"') { return $Matches[1] }
    if ($c -match '^(.+?\.exe)\b') { return $Matches[1] }
    return ($c -split '\s+')[0]
}

# On or off, from the switch of StartupApproved: no value = on; the first byte odd = turned off, and the
# 8 bytes after the first 4 are when (a FILETIME, 0 when Windows didn't save it).
function Get-StartupSwitch([string]$Approved, [string]$Name) {
    $bytes = (Get-ItemProperty -Path $Approved -Name $Name -ErrorAction SilentlyContinue).$Name
    if (-not ($bytes -is [byte[]]) -or $bytes.Count -lt 1) { return [pscustomobject]@{ On = $true; Since = $null } }
    $since = $null
    if ($bytes.Count -ge 12) {
        $time = [BitConverter]::ToInt64($bytes, 4)
        if ($time -gt 0) { try { $since = [DateTime]::FromFileTime($time) } catch { } }
    }
    [pscustomobject]@{ On = ($bytes[0] % 2) -eq 0; Since = $since }
}

# Every startup program: Id (source number|name), Name, Command, File, Maker, Everyone, Approved, On, Since.
function Get-StartupPrograms {
    $shell = New-Object -ComObject WScript.Shell
    for ($i = 0; $i -lt $StartupSources.Count; $i++) {
        $src = $StartupSources[$i]
        $entries = @()
        if ($src.Kind -eq 'Run') {
            $key = Get-Item -LiteralPath $src.Where -ErrorAction SilentlyContinue
            if (-not $key) { continue }
            foreach ($name in $key.GetValueNames()) {
                if (-not $name) { continue }
                $command = "$($key.GetValue($name))"
                if ($command) { $entries += [pscustomobject]@{ Name = $name; Value = $name; Command = $command; File = (Get-CommandFile $command) } }
            }
        } else {
            if (-not $src.Where -or -not (Test-Path -LiteralPath $src.Where)) { continue }
            foreach ($file in Get-ChildItem -LiteralPath $src.Where -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' }) {
                $target = $file.FullName
                $command = $file.FullName
                if ($file.Extension -eq '.lnk') {
                    try { $link = $shell.CreateShortcut($file.FullName); if ($link.TargetPath) { $target = $link.TargetPath; $command = "`"$($link.TargetPath)`" $($link.Arguments)".Trim() } } catch { }
                }
                $entries += [pscustomobject]@{ Name = $file.BaseName; Value = $file.Name; Command = $command; File = $target }
            }
        }
        foreach ($e in $entries) {
            if ($KeepStartup -contains $e.Value) { continue }
            $info = $null
            if ($e.File -and (Test-Path -LiteralPath $e.File -PathType Leaf)) { try { $info = (Get-Item -LiteralPath $e.File).VersionInfo } catch { } }
            $switch = Get-StartupSwitch $src.Approved $e.Value
            [pscustomobject]@{
                Id = "$i|$($e.Value)"; Name = $e.Name; Value = $e.Value; Command = $e.Command; File = $e.File
                Exists = [bool]($e.File -and (Test-Path -LiteralPath $e.File -PathType Leaf))
                Maker = $(if ($info) { "$($info.CompanyName)".Trim() } else { '' })
                What  = $(if ($info) { "$($info.FileDescription)".Trim() } else { '' })
                Everyone = $src.Everyone; Approved = $src.Approved; On = $switch.On; Since = $switch.Since
            }
        }
    }
}

# One row of a list: the maker and what it is, a tooltip with what exactly starts, and a warning when
# turning it off can take something away.
function New-StartupItem($Program) {
    $note = @($Program.What, $Program.Maker | Where-Object { $_ -and $_ -ne $Program.Name } | Select-Object -Unique) -join ' · '
    $item = [ordered]@{
        value = $Program.Id; label = $Program.Name; note = $note
        group = $(if ($Program.Everyone) { 'For everyone on this PC' } else { 'For you' })
        statusTip = "What starts`n$($Program.Command)"
    }
    if (-not $Program.Exists) {
        $item.status = 'Program not found'; $item.statusBrush = 'Warn'
        $item.statusTip = "The program is not on this PC anymore`nTurning it off is safe. It was: $($Program.Command)"
    } elseif ($Program.Maker -match $DriverMakers -or $Program.File -like "$env:SystemRoot\System32\DriverStore\*") {
        $item.warn = 'Comes with a driver. Turning it off can stop extras like touchpad gestures, audio effects or keyboard keys.'
    } elseif ($Program.File -like "$env:SystemRoot\*") {
        $item.warn = 'Part of Windows. Turn it off only if you know what it does.'
    }
    if (-not $Program.On -and $Program.Since) { $item.status = "Off since $($Program.Since.ToString('d'))"; $item.statusBrush = 'Fg2' }
    return $item
}


if ($PSVersionTable.PSEdition -ne 'Desktop') {
    Write-Warning 'Run it in Windows PowerShell 5.1 (powershell.exe), not in PowerShell 7 (pwsh).'
    return
}

#endregion


#region ==================== 2. STEPS ====================

# The same bytes Task Manager writes: 02 = on; 03 + the time it was turned off = off.
function Set-StartupSwitch($Program, [bool]$On) {
    if (-not (Test-Path $Program.Approved)) { New-Item -Path $Program.Approved -Force | Out-Null }
    $bytes = New-Object byte[] 12
    if ($On) { $bytes[0] = 2 }
    else {
        $bytes[0] = 3
        [BitConverter]::GetBytes([DateTime]::Now.ToFileTime()).CopyTo($bytes, 4)
    }
    New-ItemProperty -Path $Program.Approved -Name $Program.Value -Value $bytes -PropertyType Binary -Force | Out-Null
}

# Turns the checked programs off or back on, reading each one again first (one already like that is
# reported, not rewritten). One that fails is reported and the next one goes on.
function Set-StartupPrograms([string[]]$Ids, [bool]$On, $Programs) {
    foreach ($id in $Ids) {
        $prog = $Programs | Where-Object Id -eq $id | Select-Object -First 1
        if (-not $prog) { Write-Result 'WARN' "Not found anymore, skipped: $(($id -split '\|', 2)[1])"; continue }
        if ($prog.On -eq $On) { Write-Host "  [--] $($prog.Name): $(if ($On) { 'already starts' } else { 'already off' })" -ForegroundColor DarkGray; continue }
        try {
            Set-StartupSwitch $prog $On
            Write-Result 'OK' "$($prog.Name): $(if ($On) { 'starts with Windows again' } else { 'won''t start with Windows' })"
        } catch { Write-Result 'ERROR' "$($prog.Name): $($_.Exception.Message)" }
    }
}

#endregion


#region ==================== 3. EXECUTION ====================

if (-not $script:Panel) { Write-Host "`nManage-Startup" -ForegroundColor Green }   # in the panel the page already has the title

Write-Loading 'Reading the programs that start with Windows'
$programs = @(Get-StartupPrograms | Sort-Object Name)
# "For you" first, then "For everyone" (Sort-Object is not stable, so the two groups are put together by hand)
$programs = @($programs | Where-Object { -not $_.Everyone }) + @($programs | Where-Object { $_.Everyone })
$starting = @($programs | Where-Object On)
$stopped  = @($programs | Where-Object { -not $_.On })

$T = 'Startup apps'
$fields = @()
if ($starting) {
    $fields += New-Field $T 'TurnOff' 'checklist' 'Don''t start with Windows' "These $($starting.Count) start by themselves when you sign in. Check the ones to stop. They stay installed and open normally when you open them." @() @{
        items = @($starting | ForEach-Object { New-StartupItem $_ }) }
} else {
    $fields += New-Field $T 'TurnOffNone' 'info' 'Don''t start with Windows' 'No program starts by itself with Windows right now.' $null @{ status = 'ok' }
}
if ($stopped) {
    $fields += New-Field $T 'TurnOn' 'checklist' 'Start with Windows again' 'These are turned off, here or in Task Manager. Check the ones that should start by themselves again.' @() @{
        items = @($stopped | ForEach-Object { New-StartupItem $_ }) }
}
$notes = @(
    'This is the same switch as Task Manager → Startup apps. Nothing is deleted, and you can turn any of them back on here.'
    'Some programs turn this back on by themselves when they update, or when you change it in their own settings.'
    'Microsoft Store apps are not listed: they have their own switches in Settings → Apps → Startup.'
)
if ($Describe) { Write-OptionsPage $Describe $fields $notes; return }

$v = Read-Options $fields $Answers
$off = @(@($v.TurnOff) | Where-Object { $_ })
$on  = @(@($v.TurnOn) | Where-Object { $_ })
if (-not $off -and -not $on) { Write-Host 'Nothing was selected, so nothing was changed.'; return }

if ($off) { Write-Step "Turning off $($off.Count) program(s)"; Set-StartupPrograms $off $false $programs }
if ($on)  { Write-Step "Turning on $($on.Count) program(s)";   Set-StartupPrograms $on $true $programs }

Write-Host "`nDone. It takes effect the next time you sign in." -ForegroundColor Green
Write-Host '  To undo: open this page again and check them under "Start with Windows again".' -ForegroundColor DarkGray

#endregion
