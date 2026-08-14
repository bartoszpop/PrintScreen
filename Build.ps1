$ErrorActionPreference = 'Stop'

$compiler = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$windowsUiMetadata = "$env:WINDIR\System32\WinMetadata\Windows.UI.winmd"
$windowsDataMetadata = "$env:WINDIR\System32\WinMetadata\Windows.Data.winmd"
$windowsFoundationMetadata = "$env:WINDIR\System32\WinMetadata\Windows.Foundation.winmd"
$runtimeInterop = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\System.Runtime.WindowsRuntime.dll"
$systemRuntime = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\System.Runtime.dll"
$iconSource = "$PSScriptRoot\PrintScreen.png"
$iconFile = "$PSScriptRoot\PrintScreen.ico"

if (-not (Test-Path -LiteralPath $iconSource)) {
    throw "Icon source not found: $iconSource"
}

# Windows ICO files can contain PNG-compressed images. Resize the source to
# 256x256 and wrap it in an ICO container before compiling the executable.
Add-Type -AssemblyName System.Drawing

$sourceImage = [System.Drawing.Image]::FromFile($iconSource)
$iconBitmap = New-Object System.Drawing.Bitmap 256, 256
$graphics = [System.Drawing.Graphics]::FromImage($iconBitmap)
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.DrawImage($sourceImage, 0, 0, 256, 256)

$pngStream = New-Object System.IO.MemoryStream
$iconBitmap.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
$pngBytes = $pngStream.ToArray()

$iconStream = [System.IO.File]::Create($iconFile)
$writer = New-Object System.IO.BinaryWriter $iconStream
$writer.Write([UInt16]0)               # Reserved
$writer.Write([UInt16]1)               # ICO image type
$writer.Write([UInt16]1)               # Image count
$writer.Write([Byte]0)                  # Width: 0 means 256
$writer.Write([Byte]0)                  # Height: 0 means 256
$writer.Write([Byte]0)                  # Color palette
$writer.Write([Byte]0)                  # Reserved
$writer.Write([UInt16]1)                # Color planes
$writer.Write([UInt16]32)               # Bits per pixel
$writer.Write([UInt32]$pngBytes.Length) # Image size
$writer.Write([UInt32]22)               # Image offset
$writer.Write($pngBytes)
$writer.Dispose()
$pngStream.Dispose()
$graphics.Dispose()
$iconBitmap.Dispose()
$sourceImage.Dispose()

& $compiler /nologo /target:winexe /optimize+ /platform:anycpu `
    /out:"$PSScriptRoot\PrintScreen.exe" `
    /win32icon:"$iconFile" `
    /reference:System.dll `
    /reference:System.Drawing.dll `
    /reference:System.Windows.Forms.dll `
    /reference:"$runtimeInterop" `
    /reference:"$systemRuntime" `
    /reference:"$windowsUiMetadata" `
    /reference:"$windowsDataMetadata" `
    /reference:"$windowsFoundationMetadata" `
    "$PSScriptRoot\PrintScreen.cs"

if ($LASTEXITCODE -ne 0) {
    throw "C# compiler exited with code $LASTEXITCODE."
}

Write-Host "Built $PSScriptRoot\PrintScreen.exe"
