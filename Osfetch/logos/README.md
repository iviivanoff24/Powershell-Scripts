# OSFetch Logos

This folder contains ASCII art logos for the OSFetch tool.

## Logo File Format

Each logo file is a `.txt` file with the following structure:

```
TopColor=ColorName
BottomColor=ColorName
---
[ASCII art lines here - exactly 13 lines]
```

### Available Colors

- Red
- Blue
- Cyan
- Green
- Yellow
- Magenta
- White
- DarkGray
- DarkBlue
- DarkGreen
- DarkCyan
- DarkRed
- DarkMagenta
- DarkYellow
- Gray

## Creating a New Logo

1. Create a new `.txt` file in this folder (e.g., `mylogo.txt`)
2. Add the header with color definitions:
   ```
   TopColor=Cyan
   BottomColor=Blue
   ---
   ```
3. Add your ASCII art (must be exactly 13 lines)
4. Save the file
5. Use it with: `.\osfetch.ps1 -Logo mylogo`

## Example Logo File

```
TopColor=Green
BottomColor=Yellow
---
                              
       /\         /\          
      /  \       /  \         
     /    \     /    \        
    /      \   /      \       
   /        \ /        \      
                              
        MY CUSTOM LOGO        
                              
     [ Your ASCII Art ]       
                              
    ====================      
                              
```

## Tips

- Keep each line the same width (30 characters recommended)
- Use exactly 13 lines to maintain alignment
- Test your logo: `.\osfetch.ps1 -Logo yourlogoname`
- Use simple ASCII characters for better compatibility
- Unicode blocks (█) work great for Windows logos

## Current Logos

- **windows11** - Modern Windows 11 style (4 squares)
- **windows10** - Classic Windows perspective box
- **windows** - Windows classic flag style
- **simple** - Simple smiley face design
- **minimal** - Text-based "Win" logo
