<#
.SYNOPSIS
    Captures the monitor under the mouse cursor.

.DESCRIPTION
    Takes a screenshot of the complete monitor containing the mouse cursor,
    including the taskbar.

    The screenshot is:
      - saved as a PNG
      - copied to the clipboard
      - displayed in a Windows toast notification
#>

param(
    [string]$EditUri
)

$ErrorActionPreference = 'Stop'

if ($PSBoundParameters.ContainsKey('EditUri')) {
    try {
        $action = [Uri]::new($EditUri, [UriKind]::Absolute)
        if ($action.Scheme -ne 'printscreen-edit') {
            throw 'Invalid PrintScreen editing URI.'
        }
        $image = [Uri]::new($EditUri.Substring('printscreen-edit:'.Length), [UriKind]::Absolute)
        if (-not $image.IsFile -or $image.IsUnc -or $image.Query -or $image.Fragment) {
            throw 'Invalid PrintScreen editing URI.'
        }
        $file = $image.LocalPath
        if ([IO.Path]::GetExtension($file) -ine '.png') {
            throw 'Only PNG screenshots can be edited.'
        }
        if (-not [IO.File]::Exists($file)) {
            throw "The screenshot no longer exists: $file"
        }
        $paint = Join-Path ([Environment]::GetFolderPath('System')) 'mspaint.exe'
        if (-not [IO.File]::Exists($paint)) {
            $paint = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\mspaint.exe'
        }
        if (-not [IO.File]::Exists($paint)) {
            throw 'Microsoft Paint is not installed.'
        }
        Start-Process -FilePath $paint -ArgumentList "`"$file`""
    }
    catch {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message, 'PrintScreen',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    return
}

# Enable per-monitor DPI awareness before accessing screen coordinates.
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class DpiAwareness
{
    [DllImport("user32.dll")]
    public static extern bool SetProcessDpiAwarenessContext(IntPtr dpiContext);

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    public static extern int SetCurrentProcessExplicitAppUserModelID(string appId);
}
"@

# DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = -4
[DpiAwareness]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# Register the same per-user notification identity as the compiled application.
$appId = 'BartoszPop.PrintScreen'
$iconFolder = Join-Path $env:LOCALAPPDATA 'PrintScreen'
$iconPath = Join-Path $iconFolder 'PrintScreen.ico'
New-Item -ItemType Directory -Force -Path $iconFolder | Out-Null
Copy-Item -LiteralPath "$PSScriptRoot\PrintScreen.ico" -Destination $iconPath -Force

$identityKey = "HKCU:\Software\Classes\AppUserModelId\$appId"
New-Item -Path $identityKey -Force | Out-Null
New-ItemProperty -Path $identityKey -Name DisplayName -Value 'PrintScreen' -PropertyType String -Force | Out-Null
New-ItemProperty -Path $identityKey -Name IconUri -Value $iconPath -PropertyType String -Force | Out-Null

$protocolKey = 'HKCU:\Software\Classes\printscreen-edit'
New-Item -Path $protocolKey -Force | Out-Null
Set-Item -LiteralPath $protocolKey -Value 'URL:PrintScreen Edit with Paint'
New-ItemProperty -Path $protocolKey -Name 'URL Protocol' -Value '' -PropertyType String -Force | Out-Null
$commandKey = Join-Path $protocolKey 'shell\open\command'
New-Item -Path $commandKey -Force | Out-Null
$hostExe = Join-Path $PSHOME 'powershell.exe'
if (-not (Test-Path -LiteralPath $hostExe)) {
    $hostExe = Join-Path $PSHOME 'pwsh.exe'
}
$command = "`"$hostExe`" -NoProfile -Sta -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`" -EditUri `"%1`""
Set-Item -LiteralPath $commandKey -Value $command

[System.Runtime.InteropServices.Marshal]::ThrowExceptionForHR(
    [DpiAwareness]::SetCurrentProcessExplicitAppUserModelID($appId)
)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

$folder = "$env:USERPROFILE\Pictures\Screenshots"

New-Item -ItemType Directory -Force -Path $folder | Out-Null

# ---------------------------------------------------------------------------
# Determine monitor under mouse cursor
# ---------------------------------------------------------------------------

$cursor = [System.Windows.Forms.Cursor]::Position
$screen = [System.Windows.Forms.Screen]::FromPoint($cursor)

# Bounds includes the entire monitor, including the taskbar.
$bounds = $screen.Bounds

# ---------------------------------------------------------------------------
# Capture monitor
# ---------------------------------------------------------------------------

$bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height

$graphics = [System.Drawing.Graphics]::FromImage($bitmap)

$graphics.CopyFromScreen(
    $bounds.X,
    $bounds.Y,
    0,
    0,
    $bounds.Size
)

# ---------------------------------------------------------------------------
# Save screenshot
# ---------------------------------------------------------------------------

$filename = "Screenshot_{0:yyyy-MM-dd_HH-mm-ss-fff}.png" -f (Get-Date)
$file = Join-Path $folder $filename

$bitmap.Save(
    $file,
    [System.Drawing.Imaging.ImageFormat]::Png
)

# ---------------------------------------------------------------------------
# Copy screenshot to clipboard
# ---------------------------------------------------------------------------

[System.Windows.Forms.Clipboard]::SetImage($bitmap)

$graphics.Dispose()
$bitmap.Dispose()

# ---------------------------------------------------------------------------
# Show Windows toast notification
# ---------------------------------------------------------------------------

# Load Windows Runtime notification classes.
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
[Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] > $null

# Convert path to a file URI understood by the toast notification.
$imageUri = [System.Uri]::new($file).AbsoluteUri

# Escape XML-sensitive characters.
$escapedFile = [System.Security.SecurityElement]::Escape($file)
$escapedImageUri = [System.Security.SecurityElement]::Escape($imageUri)
$escapedEditUri = [System.Security.SecurityElement]::Escape("printscreen-edit:$imageUri")

$toastXml = @"
<toast activationType="protocol" launch="$escapedImageUri">
    <visual>
        <binding template="ToastGeneric">
            <text>Screenshot saved</text>
            <text>$escapedFile</text>
            <image
                placement="hero"
                src="$escapedImageUri" />
        </binding>
    </visual>
    <actions>
        <action content="Edit with Paint"
                activationType="protocol"
                arguments="$escapedEditUri" />
    </actions>
</toast>
"@

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($toastXml)

$toast = New-Object Windows.UI.Notifications.ToastNotification $xml

# Reuse the same identity so repeated screenshots replace the previous toast
# instead of waiting in the notification queue.
$toast.Tag = 'Screenshot'
$toast.Group = 'PrintScreen'

$group = 'PrintScreen'

$history = [Windows.UI.Notifications.ToastNotificationManager]::History
$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId)

# Capture and remove only notifications that already exist.
$previousToasts = @(
    $history.GetHistory($appId) |
        Where-Object { $_.Group -eq $group }
)

foreach ($previousToast in $previousToasts) {
    $history.Remove(
        $previousToast.Tag,
        $previousToast.Group,
        $appId
    )
}

# This unique tag cannot be affected by the removals above.
$toast.Tag = [Guid]::NewGuid().ToString()
$toast.Group = $group

$notifier.Show($toast)