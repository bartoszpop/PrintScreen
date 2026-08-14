# PrintScreen

A small Windows screenshot utility written in C#. It starts faster than the
original PowerShell script because it runs as a compiled executable.

When launched, the app:

- captures the complete monitor under the mouse cursor, including the taskbar;
- saves the screenshot as a PNG;
- copies the image to the Windows clipboard; and
- displays a Windows toast notification with a preview and the saved path.

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

Run the build script from PowerShell:

```powershell
.\Build.ps1
```

The script uses the C# compiler included with the Windows .NET Framework and
creates `PrintScreen.exe` in the project directory. No NuGet packages or .NET
SDK installation are required.

## Requirements

- Windows 10 or Windows 11
- .NET Framework 4.x

The application uses Windows Forms, System.Drawing, and Windows Runtime toast
notification APIs.

## Project files

- `PrintScreen.cs` — C# source code
- `Build.ps1` — compilation script
- `PrintScreen.exe` — compiled Windows application
- `PrintScreen.ps1` — original PowerShell implementation

If capturing, clipboard access, or notifications fail, the application displays
an error dialog containing the relevant message.
