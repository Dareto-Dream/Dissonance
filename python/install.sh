#!/bin/bash
# Dissonance VN Editor - Installation Script

echo "========================================"
echo "Dissonance VN Editor - Setup"
echo "========================================"
echo ""

# Check Python version
echo "Checking Python version..."
python3 --version

if [ $? -ne 0 ]; then
    echo "Error: Python 3 not found!"
    echo "Please install Python 3.8 or higher"
    exit 1
fi

echo ""

# Check if pip is available
echo "Checking pip..."
python3 -m pip --version

if [ $? -ne 0 ]; then
    echo "Error: pip not found!"
    echo "Please install pip"
    exit 1
fi

echo ""

# Install pygame
echo "Installing pygame..."
python3 -m pip install pygame --break-system-packages

if [ $? -ne 0 ]; then
    echo "Warning: pygame installation may have failed"
    echo "You can try manually: pip install pygame"
else
    echo "✓ pygame installed successfully"
fi

echo ""

# Verify installation
echo "Verifying pygame installation..."
python3 -c "import pygame; print(f'Pygame {pygame.version.ver} installed')"

if [ $? -ne 0 ]; then
    echo "Error: pygame verification failed"
    exit 1
fi

echo ""
echo "========================================"
echo "Installation Complete!"
echo "========================================"
echo ""
echo "To run the editor:"
echo "  cd $(pwd)"
echo "  python3 main.py"
echo ""
echo "Quick Start:"
echo "  1. Run: python3 main.py"
echo "  2. Click 'Story Editor' in sidebar"
echo "  3. Explore sample scene"
echo "  4. Right-click to add nodes"
echo "  5. Drag to move nodes"
echo "  6. Press 'F' to frame all"
echo ""
echo "Controls:"
echo "  G - Toggle grid"
echo "  I - Toggle IDs"
echo "  F - Frame all nodes"
echo "  Ctrl+S - Save"
echo "  Ctrl+N - New node"
echo ""
echo "Documentation:"
echo "  README.md - Full documentation"
echo "  QUICK_START.md - Quick reference"
echo ""
echo "Happy creating! 🎭"
