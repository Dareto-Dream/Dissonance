"""
UI Theme Configuration

Centralized color scheme and styling for the editor.
"""

class Theme:
    """Color theme and styling constants."""
    
    def __init__(self):
        # Background colors
        self.bg_dark = (20, 20, 25)
        self.bg_medium = (30, 30, 35)
        self.bg_light = (45, 45, 55)
        self.bg_hover = (60, 60, 70)
        self.bg_active = (70, 70, 90)
        
        # Text colors
        self.text_primary = (220, 220, 220)
        self.text_secondary = (160, 160, 170)
        self.text_disabled = (100, 100, 110)
        self.text_highlight = (180, 200, 255)
        
        # Status/State colors
        self.error_red = (255, 100, 100)
        self.warning_yellow = (255, 200, 80)
        self.success_green = (100, 220, 140)
        self.info_blue = (80, 140, 255)
        
        # Accent colors
        self.accent_blue = (80, 140, 255)
        self.accent_green = (100, 220, 140)
        self.accent_red = (255, 100, 100)
        self.accent_yellow = (255, 200, 80)
        self.accent_purple = (180, 120, 255)
        
        # UI element colors
        self.border = (80, 80, 100)
        self.border_focus = (120, 140, 200)
        self.button_normal = (50, 50, 60)
        self.button_hover = (70, 70, 85)
        self.button_pressed = (40, 40, 50)
        
        # Node type colors (for story editor)
        self.node_dialogue = (80, 140, 200)
        self.node_narration = (120, 100, 180)
        self.node_action = (100, 180, 120)
        self.node_choice = (200, 140, 80)
        self.node_condition = (200, 120, 180)
        self.node_jump = (140, 140, 140)
        self.node_game = (255, 120, 80)
        self.node_end = (180, 80, 80)
        
        # Grid and guides
        self.grid_line = (40, 40, 50)
        self.grid_major = (60, 60, 70)
        self.guide_line = (100, 150, 255, 128)
        
        # Effects
        self.shadow = (0, 0, 0, 60)
        self.overlay_dark = (0, 0, 0, 180)
        self.overlay_light = (255, 255, 255, 40)
