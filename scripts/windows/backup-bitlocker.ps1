#Requires -RunAsAdministrator
<#
    backup-bitlocker.ps1 — saves the BitLocker recovery key of each encrypted drive

    HOW TO RUN (Windows PowerShell 5.1 as Administrator):
        powershell -ExecutionPolicy Bypass -File .\backup-bitlocker.ps1 -Export

    In the panel: Back up → Create, with the drivers, the apps and the Wi-Fi networks.
    Windows 11 often encrypts drive C: by itself ("Device encryption", BitLocker on Pro). After a BIOS update,
    a new motherboard or a hardware change, Windows can ask for the 48-digit recovery key, and without it
    the drive can't be opened. This saves the key of each drive you pick to the bitlocker folder of a
    tidywin-backup-<PC>-<date> folder, as a text file you can read or print.
    Nothing on the PC changes: encryption is not turned on or off, and no key is added or removed.
    Read through Windows' own BitLocker provider (Win32_EncryptableVolume), which also works on Windows Home.

    FILE LAYOUT
        1. Helpers
        Backup folder ............... shared with backup-drivers.ps1, backup-apps.ps1 and backup-wifi.ps1
        2. Back up
        3. Execution
#>
param(
    [switch]$Export,
    [switch]$Import,        # nothing to restore: the key is only read from the saved file
    [string]$Describe,      # the panel: writes the options of the page (with -Export) and stops
    [string]$Answers        # the panel: what was chosen there (nothing is asked)
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
        if (@($f.when | Where-Object { $_ -and "$($values[$_.field])" -ne "$($_.is)" }).Count) { continue }     # "when": one condition or a list
        switch ($f.kind) {
            'header'    { Write-Host "`n  $($f.label)" -ForegroundColor Cyan }
            'toggle'    { $values[$f.id] = Ask "$($f.label)?" $false }
            'info'      { Write-Host "  $($f.label): $($f.desc)" -ForegroundColor DarkGray }
            { $_ -in 'text', 'path' } { $values[$f.id] = "$(Read-Host "  $($f.label)")".Trim().Trim('"') }
            'checklist' { $values[$f.id] = @($f.items | Where-Object { Ask "$($f.label): $($_.label)?" $false } | ForEach-Object { $_.value }) }
            default {
                # choice and select; "Skip" leaves it as it is (a select that comes with a value has no Skip)
                $options = @(if (-not "$($f.default)") { Opt '' 'Skip' }) + @($f.options)
                $start = [Math]::Max(0, [array]::IndexOf(@($options | ForEach-Object { "$($_.value)" }), "$($f.default)"))
                $values[$f.id] = $options[(Choose "$($f.label):" @($options | ForEach-Object { $_.label }) $start)].value
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

function Write-Done([string]$Text) { Write-Host '  [OK] ' -ForegroundColor Green -NoNewline; Write-Host $Text }
function Write-Skip([string]$Text) { Write-Host "  [--] $Text" -ForegroundColor DarkGray }

# Menu driven by the ↑ ↓ arrow keys and Enter. Returns the chosen index.
function Choose([string]$Question, [string[]]$Options, [int]$Default = 0) {
    if ($script:Panel) { return [int](Request-Panel @{ type = 'choose'; question = $Question; options = @($Options); default = $Default }) }
    Write-Host "  $Question"
    for ($i = 0; $i -lt $Options.Count; $i++) { Write-Host "    $($i + 1)) $($Options[$i])" }
    while ($true) {
        $answer = "$(Read-Host "  Number [$($Default + 1)]")".Trim()
        if ($answer -eq '') { return $Default }
        $n = 0
        if ([int]::TryParse($answer, [ref]$n) -and $n -ge 1 -and $n -le $Options.Count) { return $n - 1 }
        Write-Host "  Type a number from 1 to $($Options.Count)." -ForegroundColor DarkYellow
    }
}

#endregion


#region ==================== BACKUP FOLDER ====================

# The same in the backup scripts (drivers, apps, Wi-Fi, BitLocker key): each saves its part in one
# tidywin-backup-<PC>-<date> folder, and Restore finds that folder again. The panel's pages run them
# together and show the shared fields (where to save, which backup) once.

function Format-Size([double]$Bytes) {
    if ($Bytes -ge 1GB) { return '{0:N1} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N0} MB' -f ($Bytes / 1MB) }
    return '{0:N0} KB' -f ($Bytes / 1KB)
}

# Places that survive formatting first (USB drives and other disks), then the user's folders.
# Label -> path, only the places that exist.
function Get-SavePlaces {
    $list = [ordered]@{}
    $system = $env:SystemDrive.TrimEnd('\')
    foreach ($d in Get-CimInstance Win32_LogicalDisk -Filter 'DriveType = 2 OR DriveType = 3' -ErrorAction SilentlyContinue | Where-Object { $_.DeviceID -ne $system -and $_.Size }) {
        $kind = if ($d.DriveType -eq 2) { 'USB drive' } else { 'disk' }
        $name = if ($d.VolumeName) { " $($d.VolumeName)" } else { '' }
        $list["$($d.DeviceID)\$name ($kind, $(Format-Size $d.FreeSpace) free)"] = "$($d.DeviceID)\"
    }
    $folders = [ordered]@{
        'Desktop'   = [Environment]::GetFolderPath('Desktop')
        'Documents' = [Environment]::GetFolderPath('MyDocuments')
        'Downloads' = Join-Path $env:USERPROFILE 'Downloads'
        'OneDrive'  = $env:OneDrive
    }
    foreach ($name in $folders.Keys) { if ($folders[$name] -and (Test-Path $folders[$name])) { $list[$name] = $folders[$name] } }
    return $list
}

# Back up: where to save, the first place (a USB drive or another disk, if there is one) already chosen.
# "setting": shown in Review, but not counted as something to do.
function Get-PlaceFields {
    $places = Get-SavePlaces
    @(
        New-Field 'Create' 'Place' 'select' 'Save to' 'A USB drive or another disk survives formatting. Everything goes in one tidywin-backup folder there.' "$(@($places.Values)[0])" @{
            options = @(@($places.Keys | ForEach-Object { Opt $places[$_] $_ }) + (Opt 'other' 'Another folder')); setting = $true }
        New-Field 'Create' 'Folder' 'path' 'Folder' 'Where to save.' '' @{ when = @{ field = 'Place'; is = 'other' }; required = $true; setting = $true }
    )
}

# Back up: today's backup folder in the place chosen ($null when that place doesn't exist).
function Get-BackupRoot($Values) {
    $dir = if ($Values.Place -eq 'other') { "$($Values.Folder)".Trim().Trim('"') } else { "$($Values.Place)" }
    if (-not $dir -or -not (Test-Path -LiteralPath $dir -PathType Container)) { return $null }
    Join-Path $dir ("tidywin-backup-{0}-{1}" -f $env:COMPUTERNAME, (Get-Date -Format 'yyyy-MM-dd'))
}

# Restore: the backups in the root of USB drives and other disks and in the user's folders, newest first.
function Find-Backups {
    @((Get-SavePlaces).Values | ForEach-Object {
        Get-ChildItem -LiteralPath $_ -Directory -Filter 'tidywin-backup-*' -ErrorAction SilentlyContinue
    } | Sort-Object FullName -Unique | Sort-Object LastWriteTime -Descending)
}

# What a backup has, for its name in the list: "drivers, apps, Wi-Fi".
function Get-BackupContents([string]$Root) {
    $parts = @()
    if (Test-Path -LiteralPath (Join-Path $Root 'drivers\drivers.json')) { $parts += 'drivers' }
    if (Test-Path -LiteralPath (Join-Path $Root 'apps.json')) { $parts += 'apps' }
    if (@(Get-ChildItem -LiteralPath (Join-Path $Root 'wifi') -Filter '*.xml' -File -ErrorAction SilentlyContinue).Count) { $parts += 'Wi-Fi' }
    if (@(Get-ChildItem -LiteralPath (Join-Path $Root 'bitlocker') -Filter '*.txt' -File -ErrorAction SilentlyContinue).Count) { $parts += 'BitLocker key' }
    if ($parts) { $parts -join ', ' } else { 'empty' }
}

# Restore: which backup, the newest one already chosen.
function Get-RestoreFields {
    $found = @(Find-Backups)
    @(
        New-Field 'Restore' 'Backup' 'select' 'Backup' 'Found on USB drives, other disks, Desktop, Documents, Downloads and OneDrive.' "$(if ($found) { $found[0].FullName })" @{
            options = @(@($found | ForEach-Object { Opt $_.FullName "$($_.FullName)  ·  $(Get-BackupContents $_.FullName)" }) + (Opt 'other' 'Another folder')); setting = $true }
        New-Field 'Restore' 'BackupOther' 'path' 'Folder' 'A tidywin-backup folder.' '' @{ when = @{ field = 'Backup'; is = 'other' }; required = $true; setting = $true }
    )
}

function Get-RestoreRoot($Values) {
    if ($Values.Backup -eq 'other') { "$($Values.BackupOther)".Trim().Trim('"') } else { "$($Values.Backup)" }
}

# A switch and, under it while it is on, the list to pick from, nothing checked ("Select all" on each
# group). Like the Browsers page: the switch only opens the list, the checked items are what counts
# ($Quiet), and Review lists them under the switch's name.
function New-SwitchField([string]$Tab, [string]$Id, [string]$Label, [string]$Desc, [bool]$Quiet, [hashtable]$More) {
    $m = @{ quiet = $Quiet }
    if ($More) { foreach ($k in $More.Keys) { $m[$k] = $More[$k] } }
    New-Field $Tab $Id 'toggle' $Label $Desc $false $m
}
function New-ListField([string]$Tab, [string]$Id, [string]$Group, [object[]]$Items, [object[]]$When) {
    New-Field $Tab $Id 'checklist' '' '' @() @{ items = @($Items); group = $Group; indent = $true; when = @($When) }
}
function New-ListItem([string]$Value, [string]$Label, [string]$Note, [string]$Group, [string]$Status) {
    [ordered]@{ value = $Value; label = $Label; note = $Note; group = $Group; status = $Status }
}

# Restore: the list of each backup found shows only while that backup is chosen and the switch is on.
function Get-ListWhen([string]$Backup, [string]$Switch) { @(@{ field = 'Backup'; is = $Backup }, @{ field = $Switch; is = 'True' }) }

# Restore: the index of the chosen backup among the ones found (-1: another folder, which has no list)
function Get-BackupIndex([object[]]$Found, [string]$Root) { [array]::IndexOf(@($Found | ForEach-Object { $_.FullName }), $Root) }

#endregion



#region ==================== 2. BACK UP ====================

# The encrypted drives with a drive letter: Drive (C:), Protected (BitLocker is guarding it now) and Keys
# (Id + the 48-digit key of each recovery password; a drive can have none, then there is nothing to save).
# Protector type 3 = numerical password, the recovery key Windows asks for. $null when BitLocker can't be read.
function Get-EncryptedDrives {
    try {
        $volumes = @(Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftVolumeEncryption' -ClassName Win32_EncryptableVolume -ErrorAction Stop)
    } catch { return $null }
    @(foreach ($vol in $volumes | Where-Object DriveLetter | Sort-Object DriveLetter) {
        $conversion = (Invoke-CimMethod -InputObject $vol -MethodName GetConversionStatus -ErrorAction SilentlyContinue).ConversionStatus
        if ($null -eq $conversion -or $conversion -eq 0) { continue }        # 0 = not encrypted
        $protection = (Invoke-CimMethod -InputObject $vol -MethodName GetProtectionStatus -ErrorAction SilentlyContinue).ProtectionStatus
        $ids = @((Invoke-CimMethod -InputObject $vol -MethodName GetKeyProtectors -Arguments @{ KeyProtectorType = [uint32]3 } -ErrorAction SilentlyContinue).VolumeKeyProtectorID)
        $keys = @(foreach ($id in $ids | Where-Object { $_ }) {
            $key = (Invoke-CimMethod -InputObject $vol -MethodName GetKeyProtectorNumericalPassword -Arguments @{ VolumeKeyProtectorID = $id } -ErrorAction SilentlyContinue).NumericalPassword
            if ($key) { [pscustomobject]@{ Id = $id; Key = $key } }
        })
        [pscustomobject]@{ Drive = $vol.DriveLetter; Protected = $protection -eq 1; Keys = $keys }
    })
}

# What the row says about a drive: guarded now, or encrypted with protection paused.
function Get-DriveState($Drive) {
    if (-not $Drive.Keys) { return 'Encrypted, no recovery key yet' }
    if ($Drive.Protected) { return 'Encrypted and protected' }
    return 'Encrypted, protection paused'
}

# The text file of one drive: the key, and how to use it.
function Get-KeyText($Drive) {
    $lines = @(
        "BitLocker recovery key of drive $($Drive.Drive)"
        "Saved by TidyWin on $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        ''
        'When Windows shows the BitLocker recovery screen, check that the key ID it shows starts like the one'
        'below, then type the recovery key. Anyone with this key can read the drive: keep this file safe.'
        ''
    )
    foreach ($k in $Drive.Keys) { $lines += @("Key ID:       $($k.Id)", "Recovery key: $($k.Key)", '') }
    return $lines
}

function Invoke-Export {
    Write-Loading 'Reading which drives are encrypted' 10
    $drives = Get-EncryptedDrives
    Write-Loading 'Looking for drives to save to' 70
    $fields = @(Get-PlaceFields)
    $withKeys = @($drives | Where-Object { $_.Keys })
    if ($null -eq $drives) {
        $fields += New-Field 'Create' 'BitLocker' 'info' 'BitLocker recovery key' 'Windows didn''t let TidyWin read BitLocker on this PC.' $null @{ status = 'warn' }
    } elseif (-not $drives) {
        $fields += New-Field 'Create' 'BitLocker' 'info' 'BitLocker recovery key' 'No drive on this PC is encrypted, so there is no key to save.' $null @{ status = 'ok' }
    } elseif (-not $withKeys) {
        $fields += New-Field 'Create' 'BitLocker' 'info' 'BitLocker recovery key' "$(@($drives | ForEach-Object { $_.Drive }) -join ', ') is encrypted but has no recovery key yet. Windows adds one when you sign in with a Microsoft account, or in Settings → Privacy & security → Device encryption." $null @{ status = 'warn' }
    } else {
        $fields += New-SwitchField 'Create' 'BitLocker' 'BitLocker recovery key' 'Your drive is encrypted. After a BIOS update or a hardware change Windows may ask for this key, and without it the drive can''t be opened. Nothing on the PC changes: the key is only copied to the backup.' $true @{
            badge = "$($withKeys.Count)"; warn = 'Anyone with this key can read the drive. Keep the backup on a USB drive or print it, and delete it when you no longer need it.' }
        $fields += New-ListField 'Create' 'BitLockerList' 'Drives' @($withKeys | ForEach-Object { New-ListItem $_.Drive "Drive $($_.Drive)" '' '' (Get-DriveState $_) }) @(@{ field = 'BitLocker'; is = 'True' })
        # A place on an encrypted drive: the key would be locked in with the drive it opens
        $encrypted = @($drives | ForEach-Object { "$($_.Drive)".ToUpper() })
        $i = 0
        foreach ($place in (Get-SavePlaces).Values) {
            $i++
            if ($encrypted -notcontains "$place".Substring(0, 2).ToUpper()) { continue }
            $fields += New-Field 'Create' "BitLockerPlace$i" 'info' 'This place is on an encrypted drive' "If $("$place".Substring(0, 2)) locks, a key saved on it can't be read. Pick a USB drive or another disk, or print the file afterwards." $null @{
                status = 'warn'; indent = $true; when = @(@{ field = 'Place'; is = $place }, @{ field = 'BitLocker'; is = 'True' }) }
        }
    }
    if ($Describe) { Write-OptionsPage $Describe $fields; return }

    $v = Read-Options $fields $Answers
    $picked = @(if ($v.BitLocker -eq $true) { @($v.BitLockerList) | Where-Object { $_ } })
    $chosen = @($withKeys | Where-Object { $picked -contains $_.Drive })
    if (-not $chosen) { Write-Host '  Not selected.' -ForegroundColor DarkGray; return }
    $root = Get-BackupRoot $v
    if (-not $root) { Write-Host '  The place to save was not found. Plug in the drive and try again.' -ForegroundColor Red; return }
    $dir = Join-Path $root 'bitlocker'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    foreach ($d in $chosen) {
        $file = Join-Path $dir "BitLocker recovery key $("$($d.Drive)".TrimEnd(':')).txt"
        try {
            Set-Content -LiteralPath $file -Value (Get-KeyText $d) -Encoding UTF8 -ErrorAction Stop
            Write-Done "Key of drive $($d.Drive) saved to $file"
        } catch { Write-Host "  [ERROR] Key of drive $($d.Drive): $($_.Exception.Message)" -ForegroundColor Red }
    }
    if (@($drives | ForEach-Object { "$($_.Drive)".ToUpper() }) -contains $root.Substring(0, 2).ToUpper()) {
        Write-Host "  This folder is on an encrypted drive: copy the file to a USB drive or print it, so you can read it if $($root.Substring(0, 2)) locks." -ForegroundColor Yellow
    }
    Write-Host '  Keep it safe: anyone with the key can read the drive.' -ForegroundColor DarkGray
}

#endregion


#region ==================== 3. EXECUTION ====================

if ($Import) { Write-Host '  Nothing to restore: open the file in the bitlocker folder of the backup when Windows asks for the key.' -ForegroundColor DarkGray }
else { Invoke-Export }

#endregion
