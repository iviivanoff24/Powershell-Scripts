# Pomodoro Matrix V17 - parametrizado y seguro
[CmdletBinding()]
param(
    [int]$TrabajoMinutos = 25,
    [int]$DescansoMinutos = 5,
    [int]$Sesiones = 4,
    [int]$VelocidadMs = 30
)

$TrabajoMinutos = [Math]::Max(1, $TrabajoMinutos)
$DescansoMinutos = [Math]::Max(1, $DescansoMinutos)
$Sesiones = [Math]::Max(1, $Sesiones)
$VelocidadMs = [Math]::Max(1, $VelocidadMs)

$origFg = [Console]::ForegroundColor
$origBg = [Console]::BackgroundColor
$origCursor = [Console]::CursorVisible

# --- 1. PREPARACIÓN DEL SISTEMA ---

# CONTROLES RÁPIDOS
# m: mostrar/ocultar lluvia   p: pausar/reanudar
# f: saltar sesión actual     c: cerrar programa

function Reset-ConsoleState {
    try {
        [Console]::ResetColor()
        [Console]::ForegroundColor = $origFg
        [Console]::BackgroundColor = $origBg
        [Console]::CursorVisible = $origCursor
        if ([Console]::BufferWidth -ne [Console]::WindowWidth) {
            try { [Console]::BufferWidth = [Console]::WindowWidth } catch {}
        }
    } catch {}
    [Console]::Clear() # Usamos el método .NET que es más rápido y seguro aquí
}

# Función Segura para el Flash (Evita que se quede rojo)
function Invoke-Flash {
    param($ColorName)
    try {
        $c = [System.ConsoleColor]::$ColorName
        for ($i=0; $i -lt 3; $i++) {
            [Console]::BackgroundColor = $c
            [Console]::Clear()
            Start-Sleep -Milliseconds 50
            [Console]::BackgroundColor = "Black"
            [Console]::Clear()
            Start-Sleep -Milliseconds 50
        }
    } finally {
        # PASE LO QUE PASE, TERMINAR EN NEGRO
        [Console]::BackgroundColor = "Black"
        [Console]::Clear()
    }
}

[Console]::CursorVisible = $false
$Host.UI.RawUI.BackgroundColor = "Black"
try { [Console]::BufferWidth = [Console]::WindowWidth } catch {}
[Console]::Clear()

# --- 2. MOTOR GRÁFICO (C#) ---
$code = @"
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
using System.IO;

public static class FastConsole {
    [DllImport("Kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    static extern SafeFileHandle CreateFile(
        string fileName, [MarshalAs(UnmanagedType.U4)] uint fileAccess, [MarshalAs(UnmanagedType.U4)] uint fileShare, 
        IntPtr securityAttributes, [MarshalAs(UnmanagedType.U4)] uint creationDisposition, [MarshalAs(UnmanagedType.U4)] uint flags, IntPtr template);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool WriteConsoleOutput(
        SafeFileHandle hConsoleOutput, CharInfo[] lpBuffer, Coord dwBufferSize, Coord dwBufferCoord, ref SmallRect lpWriteRegion);

    [StructLayout(LayoutKind.Sequential)]
    public struct Coord { public short X; public short Y; public Coord(short x, short y) { X = x; Y = y; } }

    [StructLayout(LayoutKind.Explicit)]
    public struct CharUnion { [FieldOffset(0)] public char UnicodeChar; [FieldOffset(0)] public byte AsciiChar; }

    [StructLayout(LayoutKind.Explicit)]
    public struct CharInfo { [FieldOffset(0)] public CharUnion Char; [FieldOffset(2)] public short Attributes; }

    [StructLayout(LayoutKind.Sequential)]
    public struct SmallRect { public short Left; public short Top; public short Right; public short Bottom; }

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
        SmallRect rect = new SmallRect() { Left = 0, Top = 0, Right = (short)(w - 1), Bottom = (short)(h - 1) };
        WriteConsoleOutput(hConsole, buf, new Coord((short)w, (short)h), new Coord(0, 0), ref rect);
    }
}
"@
try { Add-Type -TypeDefinition $code } catch {}
[FastConsole]::Init()

# --- 3. LOGICA RELOJ DE ARENA ---
function Render-Hourglass {
    param($buffer, $w, $h, $total, $elapsed, $colorFrame, $colorSand)
    
    $pct = 1 - ($elapsed / $total); if ($pct -lt 0) { $pct = 0 }
    $cx = [math]::Floor($w / 2); $cy = [math]::Floor($h / 2)
    
    $framePixels = @(
        @{x=0;y=-4;c='+'}, @{x=1;y=-4;c='-'}, @{x=2;y=-4;c='-'}, @{x=3;y=-4;c='-'}, @{x=4;y=-4;c='-'}, @{x=5;y=-4;c='-'}, @{x=6;y=-4;c='-'}, @{x=7;y=-4;c='-'}, @{x=8;y=-4;c='+'},
        @{x=1;y=-3;c='\'}, @{x=7;y=-3;c='/'}, @{x=2;y=-2;c='\'}, @{x=6;y=-2;c='/'}, @{x=3;y=-1;c='\'}, @{x=5;y=-1;c='/'},
        @{x=3;y=0;c='/'},  @{x=5;y=0;c='\'},
        @{x=2;y=1;c='/'},  @{x=6;y=1;c='\'}, @{x=1;y=2;c='/'},  @{x=7;y=2;c='\'},
        @{x=0;y=3;c='+'}, @{x=1;y=3;c='-'}, @{x=2;y=3;c='-'}, @{x=3;y=3;c='-'}, @{x=4;y=3;c='-'}, @{x=5;y=3;c='-'}, @{x=6;y=3;c='-'}, @{x=7;y=3;c='-'}, @{x=8;y=3;c='+'}
    )
    foreach ($p in $framePixels) {
        $idx = (($cy + $p.y) * $w) + ($cx - 4 + $p.x)
        if ($idx -ge 0 -and $idx -lt $buffer.Length) { $buffer[$idx] = $colorFrame + [int][char]$p.c }
    }
    $sandChar = [int][char]'.'
    if ($pct -gt 0.8) { 2..6 | ForEach { $idx=(($cy-3)*$w)+($cx-4+$_); $buffer[$idx]=$colorSand+$sandChar } }
    if ($pct -gt 0.5) { 3..5 | ForEach { $idx=(($cy-2)*$w)+($cx-4+$_); $buffer[$idx]=$colorSand+$sandChar } }
    if ($pct -gt 0.1) { $idx=(($cy-1)*$w)+($cx); $buffer[$idx]=$colorSand+$sandChar }
    if ($pct -lt 0.8) { 2..6 | ForEach { $idx=(($cy+2)*$w)+($cx-4+$_); $buffer[$idx]=$colorSand+$sandChar } }
    if ($pct -lt 0.5) { 3..5 | ForEach { $idx=(($cy+1)*$w)+($cx-4+$_); $buffer[$idx]=$colorSand+$sandChar } }
    if ($pct -lt 0.1) { $idx=(($cy+0)*$w)+($cx); $buffer[$idx]=$colorSand+$sandChar }
}

# --- 4. BUCLE PRINCIPAL ---
function Run-Timer {
    param(
        [int]$Minutes,
        [string]$Title,
        [int]$FrameMs = $VelocidadMs
    )
    $TotalSec = $Minutes * 60; if ($TotalSec -le 0) { $TotalSec = 1 }
    $frameDelay = [Math]::Max(1, $FrameMs)
    
    # Asegurar negrura antes de empezar
    [Console]::BackgroundColor = "Black"
    [Console]::Clear()

    $w = [Console]::WindowWidth; $h = [Console]::WindowHeight
    $rand = [System.Random]::new()
    $chars = 0x30A0..0x30FF + 0x21..0x7E | ForEach-Object { [int]$_ }
    
    $drops = New-Object int[] $w; $len = New-Object int[] $w
    for ($i=0; $i -lt $w; $i++) { $drops[$i] = -1 * $rand.Next(1, 100); $len[$i] = $rand.Next(5, 15) }
    $buffer = New-Object int[] ($w * $h)

    $cHead = 0x000F * 65536; $cGlow = 0x000A * 65536; $cBody = 0x0002 * 65536; $cEmpty = 0x0000
    $cClockFrame = 0x000F * 65536; $cClockSand = 0x000E * 65536 
    
    $ShowRain = $true
    $Paused = $false
    $LastT = Get-Date; $Elapsed = 0
    $frameTimer = [System.Diagnostics.Stopwatch]::StartNew()

    [Console]::CursorVisible = $false

    try {
        while ($Elapsed -lt $TotalSec) {
            $frameTimer.Restart()
            # --- INPUT ---
            if ([Console]::KeyAvailable) {
                $k = [Console]::ReadKey($true)
                if ($k.KeyChar -eq 'm') { $ShowRain = -not $ShowRain; $buffer = New-Object int[] ($w * $h) }
                if ($k.KeyChar -eq 'p') { $Paused = -not $Paused }
                if ($k.KeyChar -eq 'f') { break } # Saltar Sesión
                if ($k.KeyChar -eq 'c') { return "STOP" } # Salir Programa
            }

            # --- TIEMPO ---
            $Now = Get-Date
            if (-not $Paused) { $Elapsed += ($Now - $LastT).TotalSeconds }
            $LastT = $Now
            $Rem = $TotalSec - $Elapsed; if ($Rem -lt 0) { $Rem = 0 }
            $TStr = "{0:mm}:{0:ss}" -f (New-TimeSpan -Seconds $Rem)
            
            # --- REDIMENSIÓN ---
            if ($w -ne [Console]::WindowWidth -or $h -ne [Console]::WindowHeight) {
                $w = [Console]::WindowWidth; $h = [Console]::WindowHeight
                if ($w -gt 0 -and $h -gt 0) {
                    try { [Console]::BufferWidth = $w; [Console]::BufferHeight = $h } catch {}
                    $buffer = New-Object int[] ($w * $h)
                    $drops = New-Object int[] $w; $len = New-Object int[] $w
                    for($i=0;$i-lt $w;$i++){$drops[$i]=-1*$rand.Next(1,100);$len[$i]=$rand.Next(5,15)}
                }
            }

            # --- RENDERIZADO ---
            $size = $buffer.Length

            if ($ShowRain) {
                for ($x = 0; $x -lt $w; $x++) {
                    $y = $drops[$x]; $l = $len[$x]
                    if ($y -ge 0 -and $y -lt $h) { $idx=$y*$w+$x; if($idx -lt $size){ $buffer[$idx] = $cHead + $chars[$rand.Next($chars.Count)] } }
                    $yPrev = $y - 1
                    if ($yPrev -ge 0 -and $yPrev -lt $h) { $idx=$yPrev*$w+$x; if($idx -lt $size){ $buffer[$idx] = $cGlow + $chars[$rand.Next($chars.Count)] } }
                    for ($j = 2; $j -lt $l; $j++) {
                        $yBody = $y - $j
                        if ($yBody -ge 0 -and $yBody -lt $h) {
                            $idx = $yBody*$w+$x
                            if($idx -lt $size) {
                                if ($rand.Next(0, 10) -gt 8) { $buffer[$idx] = $cBody + $chars[$rand.Next($chars.Count)] }
                                else { $charOnly = $buffer[$idx] -band 0xFFFF; $buffer[$idx] = $cBody + $charOnly }
                            }
                        }
                    }
                    $yTail = $y - $l
                    if ($yTail -ge 0 -and $yTail -lt $h) { $idx=$yTail*$w+$x; if($idx -lt $size){ $buffer[$idx] = $cEmpty + 32 } }
                    $drops[$x]++
                    if (($drops[$x] - $len[$x]) -ge $h) { $drops[$x] = -1 * $rand.Next(1, 50); $len[$x] = $rand.Next(5, 20) }
                }
            } else { [Array]::Clear($buffer, 0, $size) }

            # HUD
            $hudText = " $TStr | $Title "
            if ($Paused) { $hudText = " PAUSADO " }
            for ($k = 0; $k -lt $hudText.Length; $k++) {
                $idx = $k; if ($idx -lt $size) { $buffer[$idx] = (0x000F * 65536) + [int][char]$hudText[$k] }
            }
            $helpText = " [M] Lluvia  [P] Pausa  [F] Saltar  [C] Salir "
            $startHelp = ($w * ($h - 1))
            for ($k = 0; $k -lt $helpText.Length; $k++) {
                $idx = $startHelp + $k; if ($idx -lt $size) { $buffer[$idx] = (0x0008 * 65536) + [int][char]$helpText[$k] }
            }

            Render-Hourglass -buffer $buffer -w $w -h $h -total $TotalSec -elapsed $Elapsed -colorFrame $cClockFrame -colorSand $cClockSand
            [FastConsole]::Render($w, $h, $buffer)
            $elapsedFrame = $frameTimer.ElapsedMilliseconds
            $sleep = [Math]::Max(0, $frameDelay - $elapsedFrame)
            if ($sleep -gt 0) { Start-Sleep -Milliseconds $sleep }
        }
    } finally { [Console]::CursorVisible = $true }
    
    return "OK"
}

# --- 5. INPUT SEGURO ---
function Get-SafeInput {
    param ($Msg, $Def)
    try {
        Write-Host "$Msg " -NoNewline -ForegroundColor Cyan
        Write-Host "[$Def]: " -NoNewline -ForegroundColor DarkGray
        $v = Read-Host
        if ([string]::IsNullOrWhiteSpace($v)) { return $Def }
        return [int]$v
    } catch { return $Def }
}

# --- 6. LANZAMIENTO ---
$Host.UI.RawUI.WindowTitle = "Pomodoro Matrix V17"
Reset-ConsoleState

Write-Host "--- Matrixmodoro ---" -ForegroundColor Cyan
$W = Get-SafeInput "Min Trabajo" $TrabajoMinutos
$S = Get-SafeInput "Sesiones" $Sesiones
$B = Get-SafeInput "Min Descanso" $DescansoMinutos

try {
    for ($i = 1; $i -le [int]$S; $i++) {
        $Result = Run-Timer -Minutes $W -Title "TRABAJO $i"
        if ($Result -eq "STOP") { break }

        # --- FLASH ROJO SEGURO ---
        Invoke-Flash -ColorName "DarkRed"

        if ($i -lt [int]$S) { 
            $Result = Run-Timer -Minutes $B -Title "DESCANSO"
            if ($Result -eq "STOP") { break }

            # --- FLASH AZUL SEGURO ---
            Invoke-Flash -ColorName "DarkBlue"
        }
    }
} finally {
    Reset-ConsoleState
    Write-Host "Sistema finalizado."
}