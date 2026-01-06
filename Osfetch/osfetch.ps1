#Requires -Version 5.1

<#
.SYNOPSIS
    OSFetch - Ultra-fast system information display tool for Windows
.DESCRIPTION
    A hyper-fluid alternative to winfetch/neofetch optimized for speed.
    Uses minimal WMI/CIM queries and caches results for maximum performance.
.EXAMPLE
    .\osfetch.ps1
.NOTES
    Author: kaoso
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Logo = 'windows11' # Default logo name (without .txt extension)
)

# Performance optimizations
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

# Ensure correct encoding for special characters
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Get script directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$logosPath = Join-Path $scriptPath "logos"

# Function to load logo from file
function Get-LogoFromFile {
    param([string]$logoName)
    
    $logoFile = Join-Path $logosPath "$logoName.txt"
    
    if (-not (Test-Path $logoFile)) {
        Write-Host "Logo file not found: $logoFile" -ForegroundColor Red
        Write-Host "Available logos in ${logosPath}:" -ForegroundColor Yellow
        Get-ChildItem -Path $logosPath -Filter "*.txt" | ForEach-Object {
            Write-Host "  - $($_.BaseName)" -ForegroundColor Cyan
        }
        exit 1
    }
    
    $content = Get-Content $logoFile -Raw -Encoding UTF8
    $parts = $content -split '---'
    
    if ($parts.Count -lt 2) {
        Write-Host "Invalid logo file format: $logoFile" -ForegroundColor Red
        exit 1
    }
    
    # Parse header (colors)
    $header = $parts[0].Trim() -split "`n"
    $topColor = 'White'
    $bottomColor = 'White'
    
    foreach ($line in $header) {
        if ($line -match 'TopColor=(.+)') {
            $topColor = $matches[1].Trim()
        }
        elseif ($line -match 'BottomColor=(.+)') {
            $bottomColor = $matches[1].Trim()
        }
    }
    
    # Parse logo lines
    $logoLines = ($parts[1] -split "\r?\n")
    
    return @{
        Lines = $logoLines
        TopColor = $topColor
        BottomColor = $bottomColor
    }
}

# Load selected logo
$selectedLogo = Get-LogoFromFile -logoName $Logo

# Fast system info gathering - Optimized for speed
function Get-FastSystemInfo {
    $info = @{}
    
    try {
        # Use WMI for faster queries (faster than CIM for local queries)
        $os = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
        $cs = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction Stop
        $proc = Get-WmiObject -Class Win32_Processor -ErrorAction Stop | Select-Object -First 1
        
        # Get GPU - filter out virtual adapters
        $gpus = Get-WmiObject -Class Win32_VideoController -ErrorAction Stop
        $gpu = $gpus | Where-Object { 
            $_.Name -notmatch 'Remote|Virtual|Basic|Microsoft' 
        } | Select-Object -First 1
        
        # Fallback to first GPU if no physical GPU found
        if (-not $gpu) {
            $gpu = $gpus | Select-Object -First 1
        }
        
        # OS Info
        $info.OS = $os.Caption -replace 'Microsoft ', ''
        $info.Version = $os.Version
        $info.Build = $os.BuildNumber
        
        # Computer Info
        $info.Host = $cs.Name
        $info.User = $env:USERNAME
        
        # CPU Info - Clean up processor name
        $cpuName = $proc.Name -replace '\s+', ' ' -replace '\(R\)', '' -replace '\(TM\)', '' -replace 'CPU @', '@'
        $info.CPU = $cpuName.Trim()
        $info.Cores = $proc.NumberOfLogicalProcessors
        
        # RAM Info - Fixed type casting
        $totalRAMBytes = [double]::Parse($cs.TotalPhysicalMemory)
        $freeRAMBytes = [double]::Parse($os.FreePhysicalMemory) * 1024.0  # Convert KB to Bytes
        $usedRAMBytes = $totalRAMBytes - $freeRAMBytes
        $totalRAM = [math]::Round($totalRAMBytes / 1GB, 2)
        $usedRAM = [math]::Round($usedRAMBytes / 1GB, 2)
        $ramPercent = [math]::Round(($usedRAM / $totalRAM) * 100, 0)
        $info.RAM = "$usedRAM GB / $totalRAM GB ($ramPercent%)"
        
        # GPU Info
        $info.GPU = $gpu.Name
        
        # Disk Info (only C: drive for speed)
        $disk = Get-PSDrive -Name C -PSProvider FileSystem
        $diskUsedBytes = [double]::Parse($disk.Used)
        $diskFreeBytes = [double]::Parse($disk.Free)
        $diskTotalBytes = $diskUsedBytes + $diskFreeBytes
        $diskUsed = [math]::Round($diskUsedBytes / 1GB, 2)
        $diskTotal = [math]::Round($diskTotalBytes / 1GB, 2)
        $diskPercent = [math]::Round(($diskUsed / $diskTotal) * 100, 0)
        $info.Disk = "$diskUsed GB / $diskTotal GB ($diskPercent%)"
        
        # Uptime
        $uptime = (Get-Date) - [Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)
        $uptimeStr = if ($uptime.Days -gt 0) {
            "{0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
        } elseif ($uptime.Hours -gt 0) {
            "{0}h {1}m" -f $uptime.Hours, $uptime.Minutes
        } else {
            "{0}m" -f $uptime.Minutes
        }
        $info.Uptime = $uptimeStr
        
        # Shell
        $info.Shell = "PowerShell $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
        
        # Resolution
        try {
            $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
            $width = $screen.Width
            $height = $screen.Height
            $info.Resolution = "${width}x${height}"
        } catch {
            $info.Resolution = "Unknown"
        }
        
        # Terminal
        if ($env:WT_SESSION) {
            $info.Terminal = "Windows Terminal"
        } elseif ($env:ConEmuPID) {
            $info.Terminal = "ConEmu"
        } else {
            $info.Terminal = $Host.Name
        }
        
        # Theme
        $themeReg = Get-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme -ErrorAction SilentlyContinue
        $info.Theme = if ($themeReg.AppsUseLightTheme -eq 1) { "Light" } else { "Dark" }
        
    } catch {
        Write-Host "$($colors.Red)Error gathering system info:$($colors.Reset)" -ForegroundColor Red
        Write-Host "$($colors.Yellow)$_$($colors.Reset)" -ForegroundColor Yellow
        Write-Host "$($colors.Gray)Script location: $PSCommandPath$($colors.Reset)" -ForegroundColor Gray
        exit 1
    }
    
    return $info
}

# Format output - Beautiful display with logo on the left
function Show-SystemInfo {
    param($info, $logoData)
    
    # Clear screen for clean display
    Clear-Host
    
    $logo = $logoData.Lines
    $topColor = $logoData.TopColor
    $bottomColor = $logoData.BottomColor
    
    # Calculate logo width (use first non-empty line)
    $logoWidth = 33
    
    Write-Host ""
    
    # Info lines array
    $infoLines = @(
        @{ Label = "OS"; Value = $info.OS; Color = "Cyan" },
        @{ Label = "Build"; Value = $info.Build; Color = "Cyan" },
        @{ Label = "Kernel"; Value = $info.Version; Color = "Cyan" },
        @{ Label = "Uptime"; Value = $info.Uptime; Color = "Cyan" },
        @{ Label = "Shell"; Value = $info.Shell; Color = "Cyan" },
        @{ Label = "Terminal"; Value = $info.Terminal; Color = "Cyan" },
        @{ Label = "Theme"; Value = $info.Theme; Color = "Cyan" },
        @{ Label = "Resolution"; Value = $info.Resolution; Color = "Cyan" },
        @{ Label = ""; Value = ""; Color = "White" },
        @{ Label = "CPU"; Value = $info.CPU; Color = "Yellow" },
        @{ Label = "Cores"; Value = $info.Cores; Color = "Yellow" },
        @{ Label = "GPU"; Value = $info.GPU; Color = "Yellow" },
        @{ Label = "Memory"; Value = $info.RAM; Color = "Yellow" },
        @{ Label = "Disk (C:)"; Value = $info.Disk; Color = "Yellow" }
    )

    # Calculate total lines needed (2 for header + info lines)
    $totalLines = [Math]::Max($logo.Count, $infoLines.Count + 2)
    
    # Display logo and info side by side
    for ($i = 0; $i -lt $totalLines; $i++) {
        # Print logo line
        Write-Host "  " -NoNewline
        
        if ($i -lt $logo.Count -and $logo[$i]) {
            $logoLine = $logo[$i]
            # Pad logo line to fixed width
            if ($logoLine.Length -lt $logoWidth) {
                $logoLine = $logoLine + (" " * ($logoWidth - $logoLine.Length))
            }
            
            # Determine color based on position
            $color = if ($i -lt 6) { $topColor } else { $bottomColor }
            Write-Host $logoLine -ForegroundColor $color -NoNewline
        } else {
            Write-Host (" " * $logoWidth) -NoNewline
        }
        
        # Spacer
        Write-Host "  " -NoNewline

        # Print info line or header
        if ($i -eq 0) {
            # Header
            Write-Host $($info.User) -ForegroundColor Cyan -NoNewline
            Write-Host "@" -ForegroundColor White -NoNewline
            Write-Host $($info.Host) -ForegroundColor Blue
        }
        elseif ($i -eq 1) {
            # Separator
            Write-Host ("-" * ($info.User.Length + $info.Host.Length + 1)) -ForegroundColor DarkGray
        }
        elseif (($i - 2) -lt $infoLines.Count) {
            # Info Item
            $infoItem = $infoLines[$i - 2]
            if ($infoItem.Label) {
                Write-Host ($infoItem.Label.PadRight(16)) -ForegroundColor $infoItem.Color -NoNewline
                Write-Host $infoItem.Value
            } else {
                Write-Host ""
            }
        } else {
            Write-Host ""
        }
    }
    
    Write-Host ""
    
    # Color palette
    Write-Host (" " * ($logoWidth + 4)) -NoNewline
    Write-Host "###" -ForegroundColor Red -NoNewline
    Write-Host "###" -ForegroundColor Yellow -NoNewline
    Write-Host "###" -ForegroundColor Green -NoNewline
    Write-Host "###" -ForegroundColor Cyan -NoNewline
    Write-Host "###" -ForegroundColor Blue -NoNewline
    Write-Host "###" -ForegroundColor Magenta -NoNewline
    Write-Host "###" -ForegroundColor White -NoNewline
    Write-Host "###" -ForegroundColor DarkGray
    Write-Host ""
}

# Main execution
try {
    # Add Windows Forms assembly for screen resolution (fast load)
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    
    # Measure execution time
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    # Get system info
    $systemInfo = Get-FastSystemInfo
    
    # Display
    Show-SystemInfo -info $systemInfo -logoData $selectedLogo
    
    # Show execution time
    $stopwatch.Stop()
    $elapsed = if ($stopwatch.ElapsedMilliseconds -lt 1000) {
        "$($stopwatch.ElapsedMilliseconds)ms"
    } else {
        "{0:F2}s" -f ($stopwatch.ElapsedMilliseconds / 1000)
    }
    Write-Host "  +-- Executed in $elapsed`n" -ForegroundColor DarkGray
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
