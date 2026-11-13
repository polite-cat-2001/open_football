# Two small OpenFootball windows for local LAN testing: the top-left one is the
# usual host, the bottom-right the client.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_two_instances.ps1 [width] [height]
#
# The project asks for a maximized window (window/size/mode=2) and Godot applies
# that after the command line, so the size and the placement are forced on the
# real window once it exists.
param(
    [int]$Width = 800,
    [int]$Height = 500,
    [string]$Godot = "C:\Users\Egor\Desktop\Godot\Godot_v4.7.2-stable_win64.exe"
)

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class GameWindow {
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after,
      int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int cmd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
Add-Type -AssemblyName System.Windows.Forms

$project = Split-Path -Parent $PSScriptRoot
$area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$gap = 16
$slots = @(
    @{ X = $area.X + $gap; Y = $area.Y + $gap },
    @{ X = $area.Right - $Width - $gap; Y = $area.Bottom - $Height - $gap }
)

foreach ($slot in $slots) {
    $process = Start-Process -FilePath $Godot -PassThru -ArgumentList @("--path", $project)

    # Wait for the real window (the splash/first frames may not have one yet).
    $handle = [IntPtr]::Zero
    for ($attempt = 0; $attempt -lt 100 -and $handle -eq [IntPtr]::Zero; $attempt++) {
        Start-Sleep -Milliseconds 100
        $process.Refresh()
        $handle = $process.MainWindowHandle
    }
    if ($handle -eq [IntPtr]::Zero) {
        "instance pid $($process.Id): no window appeared"
        continue
    }

    # SW_RESTORE clears the project's maximized state, then place and size it.
    [GameWindow]::ShowWindow($handle, 9) | Out-Null
    [GameWindow]::SetWindowPos($handle, [IntPtr]::Zero, $slot.X, $slot.Y, $Width, $Height, 0x0044) | Out-Null
    $rect = New-Object GameWindow+RECT
    [GameWindow]::GetWindowRect($handle, [ref]$rect) | Out-Null
    "instance pid $($process.Id) at $($rect.Left),$($rect.Top) ($($rect.Right - $rect.Left)x$($rect.Bottom - $rect.Top))"
}
