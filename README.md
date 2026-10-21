# PrintScreen

A small Windows screenshot utility written in C#. It starts faster than the
original PowerShell script because it runs as a compiled executable.

When launched, the app:

- captures the complete monitor under the mouse cursor, including the taskbar;
- saves the screenshot as a PNG;
- copies the image to the Windows clipboard; and
- displays a Windows toast notification with a preview and the saved path.

Notifications show **PrintScreen** and the program icon instead of Windows
PowerShell. Both implementations automatically register this notification
identity for the current user; administrator privileges are not required.
The executable embeds the icon, so it can still be used on its own.

Click **Edit with Paint** below the notification text to open the saved PNG
in Microsoft Paint. Clicking the notification itself still opens the image in
your default viewer. Editing does not capture another screenshot or change
the clipboard.

## Usage

Run `PrintScreen.exe`. The app has no main window or console and exits after the
screenshot has been captured.

Screenshots are saved to:

```text
%USERPROFILE%\Pictures\Screenshots
```

Files use this naming pattern:

```text
Screenshot_yyyy-MM-dd_HH-mm-ss-fff.png
```

You can assign `PrintScreen.exe` to a keyboard shortcut or use it in place of
the original `PrintScreen.ps1` script.

## Building

Install Node.js (including npm), then run from PowerShell:

```powershell
npm ci
.\Build.ps1
```

The script uses the C# compiler included with the Windows .NET Framework and
creates `PrintScreen.exe` in the project directory. No NuGet packages or .NET
SDK installation are required.

The build renders `PRTSCR.svg` using resvg and generates
one multi-resolution `PrintScreen.ico` for both the application and notifications.
It contains 16, 20, 24, 32, 48, 64, 128, and 256-pixel versions rendered directly
from the SVG and is embedded in the executable. To change the icon, edit the
SVG and rebuild. Install Helvetica Neue to use its specified typeface; otherwise
the SVG falls back to Helvetica or Arial. Node.js is needed only for building.

## Requirements

- Windows 10 or Windows 11
- .NET Framework 4.x

The application uses Windows Forms, System.Drawing, and Windows Runtime toast
notification APIs.

## Project files

- `PrintScreen.cs` — C# source code
- `Build.ps1` — compilation script
- `PrintScreen.ps1` — source PowerShell implementation
- `PRTSCR.svg` — source image for the application and notification icons
- `Build-Icons.cjs` — multi-resolution ICO generator
- `PrintScreen.ico` — application and notification icon (required beside the PowerShell script)
- `PrintScreen.exe` — compiled Windows application

The notification registration is stored at
`HKEY_CURRENT_USER\Software\Classes\AppUserModelId\BartoszPop.PrintScreen`,
and its icon is stored at `%LOCALAPPDATA%\PrintScreen\PrintScreen.ico` so Windows
can display it after the program exits. Existing notifications sent under
Windows PowerShell keep their old branding; newly captured screenshots use
the PrintScreen identity.

The app also registers `HKEY_CURRENT_USER\Software\Classes\printscreen-edit`
to handle the Paint button after it exits. Keep the executable (or the
PowerShell script) at its current location while its notifications are in use.
Running either implementation refreshes the handler to point to that copy.
Microsoft Paint must be installed; a missing screenshot or launch failure
displays an error dialog.

If capturing, clipboard access, or notifications fail, the application displays
an error dialog containing the relevant message.
