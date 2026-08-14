using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Security;
using System.Windows.Forms;
using Windows.Data.Xml.Dom;
using Windows.UI.Notifications;

internal static class Program
{
    private static readonly IntPtr PerMonitorAwareV2 = new IntPtr(-4);
    private const string ToastGroup = "PrintScreen";
    private const string PowerShellAppId =
        @"{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe";

    [DllImport("user32.dll")]
    private static extern bool SetProcessDpiAwarenessContext(IntPtr value);

    [STAThread]
    private static void Main()
    {
        try
        {
            SetProcessDpiAwarenessContext(PerMonitorAwareV2);

            string folder = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.MyPictures),
                "Screenshots");
            Directory.CreateDirectory(folder);

            Rectangle bounds = Screen.FromPoint(Cursor.Position).Bounds;
            string file = Path.Combine(
                folder,
                "Screenshot_" + DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss-fff") + ".png");

            using (var bitmap = new Bitmap(bounds.Width, bounds.Height))
            {
                using (Graphics graphics = Graphics.FromImage(bitmap))
                {
                    graphics.CopyFromScreen(bounds.X, bounds.Y, 0, 0, bounds.Size);
                }

                bitmap.Save(file, ImageFormat.Png);
                Clipboard.SetImage(bitmap);
            }

            ShowToast(file);
        }
        catch (Exception exception)
        {
            MessageBox.Show(
                exception.Message,
                "PrintScreen",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
    }

    private static void ShowToast(string file)
    {
        string imageUri = new Uri(file).AbsoluteUri;
        string escapedFile = SecurityElement.Escape(file);
        string escapedImageUri = SecurityElement.Escape(imageUri);
        string toastXml =
            "<toast activationType=\"protocol\" launch=\"" + escapedImageUri + "\">" +
            "<visual><binding template=\"ToastGeneric\">" +
            "<text>Screenshot saved</text>" +
            "<text>" + escapedFile + "</text>" +
            "<image placement=\"hero\" src=\"" + escapedImageUri + "\" />" +
            "</binding></visual></toast>";

        var xml = new XmlDocument();
        xml.LoadXml(toastXml);

        var history = ToastNotificationManager.History;
        foreach (ToastNotification previous in history.GetHistory(PowerShellAppId))
        {
            if (previous.Group == ToastGroup)
                history.Remove(previous.Tag, previous.Group, PowerShellAppId);
        }

        var toast = new ToastNotification(xml);
        toast.Tag = Guid.NewGuid().ToString();
        toast.Group = ToastGroup;
        ToastNotificationManager.CreateToastNotifier(PowerShellAppId).Show(toast);
    }
}
