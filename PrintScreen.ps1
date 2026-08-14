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

# Enable per-monitor DPI awareness before accessing screen coordinates.
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class DpiAwareness
{
    [DllImport("user32.dll")]
    public static extern bool SetProcessDpiAwarenessContext(IntPtr dpiContext);
}
"@

# DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = -4
[DpiAwareness]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

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
</toast>
"@

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($toastXml)

$toast = New-Object Windows.UI.Notifications.ToastNotification $xml

# Reuse the same identity so repeated screenshots replace the previous toast
# instead of waiting in the notification queue.
$toast.Tag = 'Screenshot'
$toast.Group = 'PrintScreen'

$appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
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