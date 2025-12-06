"""
Sidebar Navigation Component

Provides module selection UI for the main editor.
"""

import pygame
import pygame.freetype


class Sidebar:
    """Vertical sidebar with module buttons."""
    
    def __init__(self, theme):
        self.theme = theme
        self.font = pygame.freetype.SysFont("Arial", 14)
        self.title_font = pygame.freetype.SysFont("Arial", 16, bold=True)
        
        self.button_height = 40
        self.button_padding = 5
        self.hover_index = None
    
    def draw(self, surface, rect, module_names, active_module):
        """Draw sidebar with module buttons."""
        # Background
        pygame.draw.rect(surface, self.theme.bg_medium, rect)
        
        # Title area
        title_rect = pygame.Rect(rect.x, rect.y, rect.width, 60)
        pygame.draw.rect(surface, self.theme.bg_dark, title_rect)
        
        # Title text
        title_surf, _ = self.title_font.render("Dissonance", self.theme.text_primary)
        title_x = rect.x + (rect.width - title_surf.get_width()) // 2
        surface.blit(title_surf, (title_x, rect.y + 12))
        
        subtitle_surf, _ = self.font.render("VN Editor", self.theme.text_secondary)
        subtitle_x = rect.x + (rect.width - subtitle_surf.get_width()) // 2
        surface.blit(subtitle_surf, (subtitle_x, rect.y + 34))
        
        # Separator
        pygame.draw.line(
            surface,
            self.theme.border,
            (rect.x, rect.y + 60),
            (rect.x + rect.width, rect.y + 60),
            1
        )
        
        # Module buttons
        y = rect.y + 70
        mouse_pos = pygame.mouse.get_pos()
        
        for i, module_name in enumerate(module_names):
            button_rect = pygame.Rect(
                rect.x + self.button_padding,
                y,
                rect.width - self.button_padding * 2,
                self.button_height
            )
            
            # Check hover
            is_hover = button_rect.collidepoint(mouse_pos)
            is_active = module_name == active_module
            
            # Button background
            if is_active:
                bg_color = self.theme.bg_active
            elif is_hover:
                bg_color = self.theme.bg_hover
            else:
                bg_color = self.theme.bg_light
            
            pygame.draw.rect(surface, bg_color, button_rect, border_radius=4)
            
            # Active indicator
            if is_active:
                indicator_rect = pygame.Rect(
                    rect.x + 2,
                    y + 5,
                    3,
                    self.button_height - 10
                )
                pygame.draw.rect(surface, self.theme.accent_blue, indicator_rect)
            
            # Button text
            text_color = self.theme.text_primary if (is_active or is_hover) else self.theme.text_secondary
            text_surf, _ = self.font.render(module_name, text_color)
            text_x = button_rect.x + 12
            text_y = button_rect.y + (button_rect.height - text_surf.get_height()) // 2
            surface.blit(text_surf, (text_x, text_y))
            
            y += self.button_height + self.button_padding
        
        # Footer info
        footer_y = rect.y + rect.height - 40
        pygame.draw.line(
            surface,
            self.theme.border,
            (rect.x, footer_y),
            (rect.x + rect.width, footer_y),
            1
        )
        
        version_surf, _ = self.font.render("v1.0.0", self.theme.text_disabled)
        version_x = rect.x + (rect.width - version_surf.get_width()) // 2
        surface.blit(version_surf, (version_x, footer_y + 12))
    
    def handle_click(self, pos, module_names):
        """Check if click is on a module button and return the module name."""
        # Title area takes up first 70 pixels
        if pos[1] < 70:
            return None
        
        # Calculate which button was clicked
        button_y = 70
        button_idx = (pos[1] - button_y) // (self.button_height + self.button_padding)
        
        if 0 <= button_idx < len(module_names):
            return module_names[button_idx]
        return None
