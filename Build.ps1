$ErrorActionPreference = 'Stop'

$compiler = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$windowsUiMetadata = "$env:WINDIR\System32\WinMetadata\Windows.UI.winmd"
$windowsDataMetadata = "$env:WINDIR\System32\WinMetadata\Windows.Data.winmd"
$windowsFoundationMetadata = "$env:WINDIR\System32\WinMetadata\Windows.Foundation.winmd"
$runtimeInterop = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\System.Runtime.WindowsRuntime.dll"
$systemRuntime = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\System.Runtime.dll"

& $compiler /nologo /target:winexe /optimize+ /platform:anycpu `
    /out:"$PSScriptRoot\PrintScreen.exe" `
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
