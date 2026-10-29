[← back to README](../README.md)

# Windows

In the [TidyWin panel](../README.md#quick-start): **Set up → Windows**. From a local copy:

```powershell
.\scripts\windows\configure-windows.ps1
```

Every option shows on one page, in tabs. **Nothing comes selected**: only what you turn on or pick is applied, the rest stays as it is. **Review** lists what will change; nothing changes before **Apply**.

## Automatic
| Feature | What it does |
|---|---|
| Restore point | Creates a restore point before any change. |
| Review | Lists everything that will change, by tab, before you apply. |
| Fault tolerant | If a step fails, it warns and moves on to the next one. |
| Detailed log | One line per setting: `[OK]` changed now, `[--]` it already was like that. At the end, a summary with how many changed, were already set or failed. |
| Log file | Everything shown while applying, plus your answers, is saved to `TidyWin log <date>.txt` on the Desktop. No user or PC name in it, so it can be sent when asking for help. |

## Privacy and cleanup
| Feature | What it does |
|---|---|
| Telemetry | Turns off the telemetry service and collection tasks, and applies the policies for minimum diagnostics, no ads, no activity history and no Bing in search. Turns off the Settings → Privacy switches too: app launch tracking (Start stops listing your most used apps), the language list shared with websites, typing and handwriting data, online speech recognition (voice typing with Win+H needs it in many languages) and account notifications in Start. Turns off Widgets. The page shows whether it is already off, or only partly (after a big Windows update, for example). |
| Suggestions | Turns off suggestions, ads and silent app installs (Candy Crush etc.). |
| Apps to remove | A checklist with only the apps on this PC. **Checked**: rarely used ones (Clipchamp, Copilot, Bing, Solitaire, LinkedIn, Teams, new Outlook, Paint 3D...). **Unchecked**: ones some people use (Phone Link, Sticky Notes, Clock, Media Player, OneNote, Snipping Tool) and Xbox (Xbox app, Game Bar, Xbox sign-in, Gaming Services: Game Pass games and games with Xbox sign-in stop working). Removing the Snipping Tool frees the Print Screen key for ShareX; removing Xbox apps turns off Game DVR. Removed for every user and for new accounts. |
| OneDrive | Uninstalls OneDrive and keeps it from coming back. |
| Edge | Edge policies: no telemetry, background mode, sidebar, Copilot or shopping. |
| Recall | Windows 11: removes Recall and stops it from being turned on (official policies). Only exists on Copilot+ PCs. |
| AI features | Windows 11: pick which to turn off, by official policy: Click to Do (Copilot+ PCs), the AI in Notepad and the AI in Paint (Cocreator, Image Creator, generative fill). The Copilot app has no policy for Pro, so it is removed in the Apps tab. |
| Edge shortcut | Deletes the Edge desktop shortcut and stops Edge updates from creating it again. |
| Windows Security | Turns on blocking of potentially unwanted apps and downloads, and hides unimportant notifications. |
| Device apps | Doesn't download manufacturer apps and icons when devices are connected (drivers still come). |
| WPBT | Stops Windows from running programs the motherboard firmware provides at boot (how Armoury Crate, Vantage and similar install themselves). A Windows registry setting only: the BIOS is not changed, and a fresh install allows it again. To stop it for good, turn off the matching BIOS option (e.g. ASUS "Armoury Crate", Lenovo "Vantage"). Some anti-theft software (Computrace) uses WPBT too. |
| Hide areas | Hides "Account protection" and "Device security" in Windows Security (Microsoft account nags). |
| No Store apps in the background | Apps from the Microsoft Store stop running after you close them (policy `LetAppsRunInBackground` = Force Deny), which saves battery and data. Programs installed from a website are not affected. Store apps like WhatsApp, Phone Link and Teams only show notifications while they are open; the page warns about it. |

## Personalization
| Feature | What it does |
|---|---|
| Theme | Light or dark. Turns off Windows Spotlight and applies the theme's wallpaper. |
| Screen | For each monitor: resolution, refresh rate and scale, from the ones the monitor supports, with the recommended and current ones marked. Nothing picked: nothing changes. After a resolution or refresh change, Enter keeps it; otherwise it goes back by itself in 15 seconds. |
| Taskbar | Icons centered or on the left. |
| Combine taskbar buttons | Always (the Windows default), when the taskbar is full, or never: each window gets its own button with its name. The page shows the current choice. Windows 10, and Windows 11 23H2 or newer. Applies to every screen. |
| Desktop icons | Check which to show: This PC, your user folder, Recycle Bin, Network, Control Panel. The ones already on the Desktop say so, and unchecked ones stay as they are. The icons TidyWin turned on are listed in `%ProgramData%\TidyWin\desktop-icons.json`, so Undo hides only those. |
| No transparency | Start, the taskbar and some windows become solid instead of see-through. |
| No animations | Windows open, close, minimize and maximize at once, without fading or sliding, and the taskbar stops animating. The same switch as Settings → Accessibility → Visual effects → Animation effects. |
| Search | Hidden, icon only or search box. |
| Task View | Show or hide the button. |
| No pins | Removes every pinned icon from the taskbar. |
| No Start ads | Unpins only the ad shortcuts from Start (LinkedIn, Spotify, TikTok, Solitaire, Candy Crush...); everything else pinned stays. |
| Extensions | Shows file extensions. |
| No frequent folders | Hides frequent folders in Quick access. |
| No recent files | Hides recent files in File Explorer. |
| Hidden files | Shows hidden files and folders. |
| No "new app" prompt | After installing an app, Windows no longer asks "How do you want to open this file?": files keep opening with the app you use now. Open with still changes it. Group Policy `NoNewAppAlert`. |
| No folder discovery | Large folders open faster. Resets custom folder views. |
| No Home/Gallery | Removes Home and Gallery from File Explorer, which then opens in "This PC". |
| Classic menu | Windows 11: the full right-click menu, without "Show more options". |
| No Snap | Turns off "Snap windows": no snapping to the screen edges and no Snap layouts. |

## System
| Feature | What it does |
|---|---|
| Rename this PC | Shows the current name (a new install gets one like `DESKTOP-7F3K2QJ`) and takes a new one: up to 15 letters, numbers and hyphens, checked as you type. It is the name other devices see on the network and in Bluetooth. Takes effect after restarting. The first name TidyWin replaced is saved to `%ProgramData%\TidyWin\pc-name.json`, and Undo gives it back. Hidden on PCs in a company domain. |
| Storage Sense | Turns on Storage Sense: once a month Windows deletes temporary files apps don't use and files that have been in the Recycle Bin for more than 30 days (those are deleted for good, the page warns). The Downloads folder and OneDrive files are never touched. Already on: the page says so and nothing changes, so your own choices stay. Turned off by a policy: the page says so. |
| Long paths | Allows paths longer than 260 characters. |
| End task | Adds "End task" when right-clicking an app on the taskbar. |
| Win+V history | Turns on clipboard history. |
| No acceleration | Turns off mouse acceleration. |
| No Sticky Keys | Turns off the Sticky Keys shortcut (Shift 5 times). |
| No Fast Startup | "Shut down" really shuts down instead of hibernating part of Windows. Startup is a few seconds slower. |
| Verbose blue screen | Shows the technical error details on the blue screen. |

## Power
| Feature | What it does |
|---|---|
| Power mode | Windows 11: best power efficiency, balanced or best performance, like Settings → System → Power. Best performance makes the PC faster and the fans louder (and the battery last less). Windows keeps one mode for plugged in and one for battery, and only lets programs change the one in use now: on a laptop, the other one says to plug in or unplug the charger and open the page again. Only offered with the Balanced power plan, the one Windows uses by default. |
| No hibernation | Only shown when hibernation is on. Turns it off with `powercfg /hibernate off`: `hiberfil.sys` is deleted (often several GB on C:), and Fast Startup and the Hibernate option go away too. Sleep keeps working. On laptops, an empty battery shuts the PC down instead of hibernating. While it is on, the hibernation times are hidden. |
| Screen, sleep and hibernation | Choose when to turn off the screen, sleep and hibernate, plugged in and (laptops) on battery, from 1 minute to never. Each one shows the current value; the ones you leave empty stay as they are. Hibernation is only asked if it is turned on. Applies to the active power plan, like Settings → System → Power. |

## Network
| Feature | What it does |
|---|---|
| DNS | Sets IPv4 and IPv6 DNS manually, with DNS over HTTPS (automatic template) on Windows 11. |
| Adapters | *Every network adapter* comes on: every Wi-Fi and Ethernet adapter, connected or not. Turn it off to pick them from a list (with their model and whether they are connected); none picked leaves the DNS as it is. |
| DNS over HTTPS address | Windows 11. Optional: for servers Windows doesn't know (NextDNS, AdGuard, Control D…), their `https://` address is added to Windows' table of DoH servers, so they are encrypted too. It only goes to those servers: Cloudflare, Google and Quad9 always keep their own address, so you can mix them (1.1.1.1 with 8.8.8.8, or with a NextDNS address). With two unknown servers the log warns that they must be from the same provider. The servers TidyWin adds are listed in `%ProgramData%\TidyWin\doh-servers.json`, and *DNS back to automatic* in Revert removes them. |

## Misc
| Feature | What it does |
|---|---|
| Battery % | Shows the battery percentage on the taskbar (laptops only). |
| Thin border | Shrinks the invisible window resize area. |
| No Music in Quick access | Unpins the Music folder from Quick access (the folder stays). |
| C: folders | Hides `inetpub` and deletes `PerfLogs`. |
| Num Lock | Num Lock on when Windows starts, sign-in screen included. It is also turned on right away: Windows saves your Num Lock state when you sign out or shut down, so it has to be on then. |
| Sudo | Turns on `sudo` in the terminal. |

## Updates

In the [TidyWin panel](../README.md#quick-start): **Set up → Updates**. From a local copy:

```powershell
.\scripts\windows\configure-updates.ps1
```

The page shows how Windows Update is set up now and three modes, nothing picked:

| Mode | What it does |
|---|---|
| Normal | The Windows default: removes what the other two modes set and turns the services back on. |
| Security only | Security and quality fixes keep coming every month. The yearly feature update (a new version of Windows, like 24H2 → 25H2) waits 365 days, the most Windows allows. Windows Update for Business policy (`DeferFeatureUpdates`): Pro, Enterprise and Education; Windows Home ignores it. |
| Off | **Not safe**, shown in red on the page. Sets the `NoAutoUpdate` policy and disables and stops the Windows Update, Update Orchestrator and Windows Update Medic services (Windows may protect the last one). Their startup types are saved first to `%ProgramData%\TidyWin\updates.json`, and Normal puts them back. Microsoft Store downloads can fail while it is off. |

Apart from the mode, **Drivers** picks where drivers come from. **Not from Windows Update** sets the `ExcludeWUDriversInQualityUpdate` policy (Pro, Enterprise and Education), so Windows stops replacing the drivers you installed, like the video card one. Windows and security updates keep coming, and you update the drivers from the manufacturer. **From Windows Update** removes the policy. Normal leaves this as it is.

## Startup apps

In the [TidyWin panel](../README.md#quick-start): **Maintenance → Startup apps**. From a local copy:

```powershell
.\scripts\windows\manage-startup.ps1
```

Lists the programs that start by themselves when you sign in: the `Run` keys of the registry and the Startup folders, yours and the ones for everyone on the PC. Nothing comes checked.

| List | What it does |
|---|---|
| Don't start with Windows | The programs that start now, with their maker. The checked ones stop starting by themselves. They stay installed and open normally when you open them. An ⓘ shows exactly what starts. Rows that come with a driver (Realtek, Synaptics, NVIDIA...) warn that extras like touchpad gestures or audio effects can stop; rows from Windows warn too; a program no longer on the PC says so. |
| Start with Windows again | The ones turned off, here or in Task Manager, with the date. The checked ones start again. This is the undo. |

It is the same switch as Task Manager → Startup apps (the `StartupApproved` key), so both always agree. Nothing is deleted. Windows Security's icon is not listed (TidyWin never touches Defender), and Microsoft Store apps have their own switches in Settings → Apps → Startup. Some programs turn this back on when they update. Takes effect at the next sign-in.

## Cleanup

In the [TidyWin panel](../README.md#quick-start): **Maintenance → Disk space**. From a local copy:

```powershell
.\scripts\windows\clean-windows.ps1
```

Measures each item and shows a switch for each one with its size, all off. Only what you turn on is deleted; at the end it shows how much space was freed.

| Item | Default | What it deletes |
|---|---|---|
| Your temporary files | Yes | The %TEMP% folder. |
| Windows temporary files | Yes | C:\Windows\Temp. |
| Windows Update downloads | Yes | Updates already installed. Skipped while an update is installing or waiting for a restart. |
| Delivery Optimization cache | Yes | Update copies kept to share with other PCs. |
| Error reports and memory dumps | Yes | App crash reports and blue screen dumps. |
| Thumbnail and icon cache | No | Rebuilt by Windows; File Explorer restarts. |
| Recycle Bin | No | Everything in it, on every drive. |
| Old Windows components | No | Old system files left by updates (DISM). Can take minutes. Skipped while an update is pending. |
| Windows.old | No | The previous Windows installation, if present. No going back after it. |

## Repair

In the [TidyWin panel](../README.md#quick-start): **Maintenance → Fix Windows**. From a local copy:

```powershell
.\scripts\windows\repair-windows.ps1
```

For when Windows acts strange. Creates a restore point, checks the Windows image with DISM and repairs it from Windows Update only if it is damaged, runs `sfc /scannow`, and checks the disk online. Each step is a switch, all off, plus one to schedule the disk fix at the next restart and one to go on if Windows can't create the restore point. Only Windows' own tools; your files, apps and settings are not touched. Takes 10 to 30 minutes.

## Network reset

In the [TidyWin panel](../README.md#quick-start): **Maintenance → Internet connection**.

For "connected, no internet", sites that don't open or a connection that keeps dropping. The page shows the network adapters (connected or not, and the DNS set by hand that will be kept) and how far to go, nothing picked:

| Option | What it does |
|---|---|
| Quick | Clears the DNS and ARP caches and gets a new IP from the router. No restart. |
| Full | Also resets Winsock and TCP/IP (IPv4 and IPv6). Needs a restart, which a switch can do at the end. On a PC with a manual IP, the TCP/IP reset is skipped so the IP is not erased. |

Full: DNS servers set by hand and DNS over HTTPS are saved to `%ProgramData%\TidyWin\network-reset` first and put back right after the reset. Not used: Settings' *Network reset* (it removes the adapters and VPNs) and proxy resets. The connection drops for a few seconds; the internet is tested at the end.

## Firewall

In the [TidyWin panel](../README.md#quick-start): **Maintenance → Firewall**. From a local copy:

```powershell
.\scripts\windows\manage-firewall.ps1
```

One tab per task, nothing selected:

| Tab | What it does |
|---|---|
| Delete rules | The apps that added rules to the Windows Firewall (games, torrent and remote control apps, for example), one row per app, without Windows' own rules. Each row has how many rules the app has, in yellow next to its name, and one line on what they allow ("Open to other devices, even on public Wi-Fi"); apps no longer installed say so. **Every rule of each checked app is deleted for good**; the app stays installed, and if it needs a rule again Windows asks for permission. |
| Block an app | Pick an `.exe`: a rule in the `TidyWin` group stops it from using the internet, on any network. It shows up in *Delete rules* as *Blocked from the internet by TidyWin*, to undo it. |
| Networks | A card at the top explains each choice in color and when it fits (not sure: Public). Then each connected network, with its type now highlighted next to its name, as **Home** (your printer and other devices can see this PC) or **Public** (hidden, anywhere else). *Extra protection on public Wi-Fi*: no app receives connections on public networks, not even the allowed ones; browsing, games and calls keep working. *Turn the firewall back on* shows up only when it is off somewhere. |
| Backup | Puts one of the saved copies back: every rule as it was then, deleted ones included. The other choices are not applied. |

Before any change every rule is saved with `netsh advfirewall export` to `%ProgramData%\TidyWin\firewall`, and the last 5 copies are kept. If the backup fails, nothing is changed.
## Revert

In the [TidyWin panel](../README.md#quick-start): **Undo → Windows**. From a local copy:

```powershell
.\scripts\windows\revert-configure-windows.ps1
```

| Feature | What it does |
|---|---|
| Revert | A page with one switch per subject, all off: only what you turn on is undone. Covers telemetry, policies, suggestions, border, Snap windows, DNS, Game DVR, the Print Screen key, the Start ad shortcuts (when the app is installed), Recall, the AI features, Edge (including the shortcut policy), Windows Security areas, WPBT, hibernation (when it is off), Fast Startup, Num Lock, Home/Gallery, Music in Quick access, classic right-click menu, folder discovery, the "new app installed" prompt, devices, blue screen, `inetpub`, update sharing, Store apps in the background, transparency, animations, and, when TidyWin changed them, the Desktop icons it added, Storage Sense and the old PC name. |
| Not reverted | Removed apps (Xbox and Snipping Tool included; reinstall from the Microsoft Store), OneDrive, screen resolution, refresh rate and scale, screen and sleep times, power mode, theme, taskbar (alignment and combining), extensions, hidden files and battery (undo through Settings, or pick them again on the Windows page). |
