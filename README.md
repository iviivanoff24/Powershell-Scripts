# PowerShell Scripts & Projects

A collection of high-performance PowerShell scripts and utilities for Windows.

---

## 📋 Projects

### 1. Matrix Digital Rain
**Location:** `Matrix/matrix.ps1`

A digital rain simulation inspired by the movie "The Matrix" with smooth, high-FPS rendering.

![Matrix Demo](.img/matrix.png)

**Features:**
- High-performance rendering using native Windows API (via embedded C#)
- Auto-resizing support
- Optional digital clock overlay
- Authentic fading trails (white head, neon glow, dark body)
- Clean exit with 'F' key

**Usage:**
```powershell
cd Matrix
pwsh ./matrix.ps1

# With parameters
pwsh ./matrix.ps1 -Velocidad 50 -MostrarReloj $true
```

**Parameters:**
- `-Velocidad <ms>`: Set refresh rate (default: 30)
- `-MostrarReloj $true|$false`: Show digital clock overlay

---

### 2. Pomodoro Timer with Matrix Effect
**Location:** `Pomodoro - Matrix/pomodoro.ps1`

A Pomodoro timer with Matrix-style visual effects and robust console management.

![Pomodoro Demo](.img/pomodoro.png)

**Features:**
- Pomodoro timer with Matrix-style visuals
- Red screen flash for breaks (buffer always resets to black)
- Cleans up console state between sessions

**Usage:**
```powershell
cd "Pomodoro - Matrix"
pwsh ./pomodoro.ps1
```

---

## 📦 More Projects Coming Soon

This repository will be updated with additional PowerShell scripts and utilities.

---

## 🚀 Getting Started

### Prerequisites
- **Windows** (PowerShell 5.1 or later)
- Recommended: Use a console font that supports Japanese Katakana (e.g., MS Gothic, NSimSun, or a Nerd Font) for Matrix scripts

### Installation

1. **Clone the Repository**
   ```powershell
   git clone https://github.com/yourusername/powershell-scripts.git
   cd powershell-scripts
   ```

2. **Navigate to a Project**
   ```powershell
   cd Matrix
   # or
   cd "Pomodoro - Matrix"
   ```

3. **Run the Script**
   ```powershell
   pwsh ./script-name.ps1
   # or
   powershell ./script-name.ps1
   ```

### General Notes
- All scripts are self-contained and require no external dependencies
- For Matrix-based scripts, use console fonts that support Japanese Katakana for best visuals
- Press **F** to exit Matrix simulations

---

## 🔧 Advanced: Run Scripts from Anywhere

If you want to run these scripts from any location in PowerShell, you have two options:

### Option 1: Add to System PATH

1. **Get the repository path:**
   ```powershell
   # Navigate to your cloned repository
   cd "C:\path\to\powershell-scripts"
   pwd  # Copy this path
   ```

2. **Add to PATH (User Level):**
   ```powershell
   # Replace with your actual path
   $repoPath = "C:\path\to\powershell-scripts"
   
   # Add to user PATH
   $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
   [Environment]::SetEnvironmentVariable("Path", "$currentPath;$repoPath\Matrix;$repoPath\Pomodoro - Matrix", "User")
   ```

3. **Restart PowerShell** and run from anywhere:
   ```powershell
   matrix.ps1
   pomodoro.ps1
   ```

### Option 2: Create PowerShell Aliases (Recommended)

1. **Open your PowerShell profile:**
   ```powershell
   notepad $PROFILE
   # If file doesn't exist, create it first:
   # New-Item -Path $PROFILE -Type File -Force
   ```

2. **Add these functions to your profile:**
   ```powershell
   # Matrix Script
   function Start-Matrix {
       param(
           [int]$Velocidad = 30,
           [bool]$MostrarReloj = $false
       )
       & "C:\path\to\powershell-scripts\Matrix\matrix.ps1" -Velocidad $Velocidad -MostrarReloj $MostrarReloj
   }
   Set-Alias -Name matrix -Value Start-Matrix
   
   # Pomodoro Script
   function Start-Pomodoro {
       & "C:\path\to\powershell-scripts\Pomodoro - Matrix\pomodoro.ps1"
   }
   Set-Alias -Name pomodoro -Value Start-Pomodoro
   ```

3. **Save and reload your profile:**
   ```powershell
   . $PROFILE
   ```

4. **Now run from anywhere:**
   ```powershell
   matrix
   matrix -Velocidad 50 -MostrarReloj $true
   pomodoro
   ```

---

## License
MIT
