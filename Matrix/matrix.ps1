<#
.SYNOPSIS
    High-Performance "Matrix" Digital Rain Simulation.

.DESCRIPTION
    This script simulates the falling code effect from the movie "The Matrix" inside the Windows Console.
    
    unlike standard PowerShell scripts that use `Write-Host` (which is slow and causes flickering), 
    this script embeds C# code to access the native Windows Kernel32 API. It uses P/Invoke to call 
    `WriteConsoleOutput`, allowing for direct buffer manipulation. This results in smooth, high-FPS 
    rendering even at large window sizes.

    Features:
    - High-performance rendering engine (FastConsole class).
    - Auto-resizing support.
    - Optional Digital Clock overlay.
    - Authentic "fading" trails (White head -> Neon Glow -> Dark Body).

.PARAMETER Velocidad
    Controls the refresh rate of the loop in milliseconds. Lower is faster. 
    Default is 30ms.

.PARAMETER MostrarReloj
    Boolean ($true/$false) to toggle a digital clock overlay in the center of the screen.

.INPUTS
    None.

.OUTPUTS
    Direct Console Buffer Output.

.NOTES
    - Exit Key: Press 'F' to close the simulation cleanly.
    - Font Requirement: For best results, use a font that supports Japanese Katakana 
      (e.g., MS Gothic, NSimSun, or a Nerd Font), otherwise characters may appear as boxes.

.EXAMPLE
    .\Matrix.ps1
    # Runs the simulation with default settings.
#>

# --- KERNEL SETUP ---
[Console]::CursorVisible = $false
$Host.UI.RawUI.BackgroundColor = "Black"
try { [Console]::BufferWidth = [Console]::WindowWidth } catch {}
[Console]::Clear()

# --- AJUSTES DE USUARIO ---
$Velocidad = 30 
$MostrarReloj = $false

# --- MOTOR DE RENDERIZADO (C# / INT32) ---
$code = @"
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
using System.IO;

public static class FastConsole {
    [DllImport("Kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    static extern SafeFileHandle CreateFile(
        string fileName, 
        [MarshalAs(UnmanagedType.U4)] uint fileAccess, 
        [MarshalAs(UnmanagedType.U4)] uint fileShare, 
        IntPtr securityAttributes, 
        [MarshalAs(UnmanagedType.U4)] uint creationDisposition, 
        [MarshalAs(UnmanagedType.U4)] uint flags, 
        IntPtr template);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool WriteConsoleOutput(
        SafeFileHandle hConsoleOutput, 
        CharInfo[] lpBuffer, 
        Coord dwBufferSize, 
        Coord dwBufferCoord, 
        ref SmallRect lpWriteRegion);

    [StructLayout(LayoutKind.Sequential)]
    public struct Coord {
        public short X; public short Y;
        public Coord(short x, short y) { X = x; Y = y; }
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct CharUnion {
        [FieldOffset(0)] public char UnicodeChar;
        [FieldOffset(0)] public byte AsciiChar;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct CharInfo {
        [FieldOffset(0)] public CharUnion Char;
        [FieldOffset(2)] public short Attributes;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct SmallRect {
        public short Left; public short Top; public short Right; public short Bottom;
    }

    static SafeFileHandle hConsole;

    public static void Init() {
        hConsole = CreateFile("CONOUT$", 0x40000000, 2, IntPtr.Zero, 3, 0, IntPtr.Zero);
    }

    public static void Render(int w, int h, int[] data) {
        if (hConsole == null || hConsole.IsInvalid) Init();
        if (data == null || w <= 0 || h <= 0) return;

        CharInfo[] buf = new CharInfo[w * h];
        int len = Math.Min(buf.Length, data.Length);

        for (int i = 0; i < len; i++) {
            buf[i].Char.UnicodeChar = (char)(data[i] & 0xFFFF);
            buf[i].Attributes = (short)(data[i] >> 16);
        }

        SmallRect rect = new SmallRect() { Left = 0, Top = 0, Right = (short)w, Bottom = (short)h };
        WriteConsoleOutput(hConsole, buf, new Coord((short)w, (short)h), new Coord(0, 0), ref rect);
    }
}
"@

try { Add-Type -TypeDefinition $code } catch {}
[FastConsole]::Init()

# --- INICIALIZACIÓN ---
function Reset-Matrix {
    param($width, $height)
    $Global:drops = New-Object int[] $width
    $Global:len = New-Object int[] $width
    $Global:buffer = New-Object int[] ($width * $height)
    
    for ($i=0; $i -lt $width; $i++) { 
        $Global:drops[$i] = -1 * $rand.Next(1, 100)
        $Global:len[$i] = $rand.Next(5, 15) 
    }
}

$w = [Console]::WindowWidth
$h = [Console]::WindowHeight
$rand = [System.Random]::new()

Reset-Matrix $w $h

# COLORES
$cHead  = 0x000F * 65536 # Blanco
$cGlow  = 0x000A * 65536 # Verde Neón
$cBody  = 0x0002 * 65536 # Verde Oscuro
$cEmpty = 0x0000 * 65536 # Negro
$cBorder= 0x000A * 65536 # Verde Neón (Marco Reloj)
$cText  = 0x000F * 65536 # Blanco (Texto Reloj)

# --- CONFIGURACIÓN RELOJ (MODO ASCII SEGURO) ---
# Usamos caracteres simples (+, -, |) que funcionan en TODOS los ordenadores.
# Así evitamos que salgan T, P, Q u cosas raras.
$bCorner = '+' 
$bHor    = '-' 
$bVer    = '|'

# Caracteres Matrix
$chars = 0x30A0..0x30FF + 0x21..0x7E | ForEach-Object { [int]$_ }

# --- BUCLE PRINCIPAL ---
while ($true) {
    # 1. DETECTOR DE SALIDA
    if ([Console]::KeyAvailable) {
        $keyInfo = [Console]::ReadKey($true)
        if ($keyInfo.KeyChar -eq 'f' -or $keyInfo.KeyChar -eq 'F') { break }
    }

    # 2. DETECTOR DE REDIMENSIÓN
    if ($w -ne [Console]::WindowWidth -or $h -ne [Console]::WindowHeight) {
        Start-Sleep -Milliseconds 100 
        $newW = [Console]::WindowWidth; $newH = [Console]::WindowHeight
        if ($newW -gt 0 -and $newH -gt 0) {
            $w = $newW; $h = $newH
            try { [Console]::BufferWidth = $w; [Console]::BufferHeight = $h } catch {}
            Reset-Matrix $w $h
            Clear-Host
        }
        continue
    }

    # 3. CÁLCULO DE LLUVIA
    $size = $buffer.Length
    for ($x = 0; $x -lt $w; $x++) {
        $y = $drops[$x]
        $l = $len[$x]
        
        if ($y -ge 0 -and $y -lt $h) {
            $idx = ($y * $w) + $x
            if ($idx -lt $size) { $buffer[$idx] = $cHead + $chars[$rand.Next($chars.Count)] }
        }
        $yPrev = $y - 1
        if ($yPrev -ge 0 -and $yPrev -lt $h) {
            $idx = ($yPrev * $w) + $x
            if ($idx -lt $size) { $buffer[$idx] = $cGlow + $chars[$rand.Next($chars.Count)] }
        }
        for ($j = 2; $j -lt $l; $j++) {
             $yBody = $y - $j
             if ($yBody -ge 0 -and $yBody -lt $h) {
                $idx = ($yBody * $w) + $x
                if ($idx -lt $size) {
                    if ($rand.Next(0, 10) -gt 8) { $buffer[$idx] = $cBody + $chars[$rand.Next($chars.Count)] } 
                    else { $charOnly = $buffer[$idx] -band 0xFFFF; $buffer[$idx] = $cBody + $charOnly }
                }
            }
        }
        $yTail = $y - $l
        if ($yTail -ge 0 -and $yTail -lt $h) {
            $idx = ($yTail * $w) + $x
            if ($idx -lt $size) { $buffer[$idx] = $cEmpty + 32 }
        }
        $drops[$x]++
        if (($drops[$x] - $len[$x]) -ge $h) {
            $drops[$x] = -1 * $rand.Next(1, 50); $len[$x] = $rand.Next(5, 20)
        }
    }

    # 4. INYECTAR RELOJ (ASCII SEGURO)
    if ($MostrarReloj) {
        $timeStr = " " + (Get-Date).ToString("HH:mm") + " "
        
        # Construcción: +-----+
        $topLine = "$bCorner" + ("$bHor" * $timeStr.Length) + "$bCorner"
        $midLine = "$bVer" + $timeStr + "$bVer"
        $botLine = "$bCorner" + ("$bHor" * $timeStr.Length) + "$bCorner"
        
        $boxWidth = $topLine.Length
        $startX = [math]::Floor(($w / 2) - ($boxWidth / 2))
        $startY = 1 

        $lines = @($topLine, $midLine, $botLine)
        
        for ($r = 0; $r -lt 3; $r++) {
            $lineStr = $lines[$r]
            for ($c = 0; $c -lt $lineStr.Length; $c++) {
                $pX = $startX + $c
                $pY = $startY + $r
                $idx = ($pY * $w) + $pX
                
                if ($idx -ge 0 -and $idx -lt $size) {
                    $char = [int][char]$lineStr[$c]
                    
                    # Fila del medio y no es borde -> Texto Blanco
                    if ($r -eq 1 -and $c -gt 0 -and $c -lt ($lineStr.Length - 1)) {
                        $buffer[$idx] = $cText + $char
                    } else {
                        # Bordes -> Verde Neón
                        $buffer[$idx] = $cBorder + $char
                    }
                }
            }
        }
    }

    # 5. RENDERIZADO
    [FastConsole]::Render($w, $h, $buffer)
    Start-Sleep -Milliseconds $Velocidad
}

# --- RESTAURACIÓN ---
[Console]::ResetColor()
[Console]::ForegroundColor = "White"
[Console]::BackgroundColor = "Black"
[Console]::CursorVisible = $true
Clear-Host