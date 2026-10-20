using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Security;
using System.Windows.Forms;
using Microsoft.Win32;
using Windows.Data.Xml.Dom;
using Windows.UI.Notifications;

internal static class Program
{
    private static readonly IntPtr PerMonitorAwareV2 = new IntPtr(-4);
    private const string ToastGroup = "PrintScreen";
    private const string AppId = "BartoszPop.PrintScreen";
    private const string EditProtocol = "printscreen-edit";

    [DllImport("user32.dll")]
    private static extern bool SetProcessDpiAwarenessContext(IntPtr value);

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern int SetCurrentProcessExplicitAppUserModelID(string appId);

    [STAThread]
    private static void Main(string[] args)
    {
        try
        {
            if (args.Length != 0)
            {
                if (args.Length != 1)
                    throw new ArgumentException("Expected one screenshot editing URI.");

                EditWithPaint(args[0]);
                return;
            }

            SetProcessDpiAwarenessContext(PerMonitorAwareV2);
            RegisterNotificationIdentity();

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

    private static void RegisterNotificationIdentity()
    {
        string iconFolder = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "PrintScreen");
        Directory.CreateDirectory(iconFolder);
        string iconPath = Path.Combine(iconFolder, "PrintScreen.ico");

        // Keep the notification icon available after the executable exits or moves.
        using (Stream source = typeof(Program).Assembly.GetManifestResourceStream("PrintScreen.ico"))
        {
            if (source == null)
                throw new InvalidOperationException("The embedded PrintScreen icon is missing.");

            using (FileStream destination = File.Create(iconPath))
                source.CopyTo(destination);
        }

        using (RegistryKey key = Registry.CurrentUser.CreateSubKey(
            @"Software\Classes\AppUserModelId\" + AppId))
        {
            key.SetValue("DisplayName", "PrintScreen", RegistryValueKind.String);
            key.SetValue("IconUri", iconPath, RegistryValueKind.String);
        }

        using (RegistryKey key = Registry.CurrentUser.CreateSubKey(
            @"Software\Classes\" + EditProtocol))
        {
            key.SetValue("", "URL:PrintScreen Edit with Paint");
            key.SetValue("URL Protocol", "");
            using (RegistryKey command = key.CreateSubKey(@"shell\open\command"))
                command.SetValue("", "\"" + typeof(Program).Assembly.Location + "\" \"%1\"");
        }

        Marshal.ThrowExceptionForHR(SetCurrentProcessExplicitAppUserModelID(AppId));
    }

    private static void EditWithPaint(string argument)
    {
        Uri action;
        Uri image;
        if (!Uri.TryCreate(argument, UriKind.Absolute, out action) ||
            action.Scheme != EditProtocol ||
            !Uri.TryCreate(argument.Substring(EditProtocol.Length + 1), UriKind.Absolute, out image) ||
            !image.IsFile || image.IsUnc ||
            !string.IsNullOrEmpty(image.Query) || !string.IsNullOrEmpty(image.Fragment))
            throw new ArgumentException("Invalid PrintScreen editing URI.");

        string file = image.LocalPath;
        if (!string.Equals(Path.GetExtension(file), ".png", StringComparison.OrdinalIgnoreCase))
            throw new ArgumentException("Only PNG screenshots can be edited.");
        if (!File.Exists(file))
            throw new FileNotFoundException("The screenshot no longer exists.", file);

        string paint = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.System), "mspaint.exe");
        if (!File.Exists(paint))
            paint = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                @"Microsoft\WindowsApps\mspaint.exe");
        if (!File.Exists(paint))
            throw new FileNotFoundException("Microsoft Paint is not installed.", paint);

        Process.Start(new ProcessStartInfo(paint, "\"" + file + "\"") { UseShellExecute = true });
    }

    private static string CreateToastXml(string file)
    {
        string imageUri = new Uri(file).AbsoluteUri;
        string escapedFile = SecurityElement.Escape(file);
        string escapedImageUri = SecurityElement.Escape(imageUri);
        string escapedEditUri = SecurityElement.Escape(EditProtocol + ":" + imageUri);
        return
            "<toast activationType=\"protocol\" launch=\"" + escapedImageUri + "\">" +
            "<visual><binding template=\"ToastGeneric\">" +
            "<text>Screenshot saved</text>" +
            "<text>" + escapedFile + "</text>" +
            "<image placement=\"hero\" src=\"" + escapedImageUri + "\" />" +
            "</binding></visual>" +
            "<actions><action content=\"Edit with Paint\" activationType=\"protocol\" " +
            "arguments=\"" + escapedEditUri + "\" /></actions></toast>";
    }

    private static void ShowToast(string file)
    {
        var xml = new XmlDocument();
        xml.LoadXml(CreateToastXml(file));

        var history = ToastNotificationManager.History;
        foreach (ToastNotification previous in history.GetHistory(AppId))
        {
            if (previous.Group == ToastGroup)
                history.Remove(previous.Tag, previous.Group, AppId);
        }

        var toast = new ToastNotification(xml);
        toast.Tag = Guid.NewGuid().ToString();
        toast.Group = ToastGroup;
        ToastNotificationManager.CreateToastNotifier(AppId).Show(toast);
    }
}
