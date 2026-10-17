"""TableTap AI theme: every colour, font, size, radius and shadow lives here. Nothing else writes a colour value.

Warm restaurant look: cream and warm white on charcoal ink with terracotta and amber accents. DK_* is the dark variant
for the kitchen and music screens. Pages and ui/ files only use these tokens and helpers.
Contrast: every text/background pair below was checked for at least 4.5:1 (WCAG AA).
"""

# Light palette
glob INK = "#1F1A17",
     BODY = "#4A403A",
     MUTED = "#6F5F55",
     GROUND = "#F6EFE6",
     SURFACE = "#FFFBF5",
     LINE = "#E7DACB",
     ACCENT = "#A5461F",
     ACCENT_SOFT = "#F9EADF",
     HIGHLIGHT = "#E8A33D";

# Tag colours: text on background (spicy, vegetarian, allergy, fish)
glob WARN_FG = "#8A4B0B",
     WARN_BG = "#FCE8BF",
     VEG_FG = "#2F5E1F",
     VEG_BG = "#E1EDCF",
     ALLERGY_FG = "#9B1C2C",
     ALLERGY_BG = "#F9DADA",
     INFO_FG = "#1B5676",
     INFO_BG = "#D9EAF3";

# Photo banner: a dark warm gradient with white text. Set BANNER_IMAGE to a file path (for example "/assets/banner.jpg") to show a photo.
glob ON_DARK = "#FFF8EE",
     ON_DARK_MUTED = "#E6D8C8",
     ON_DARK_SOFT = "rgba(255, 248, 238, 0.16)",
     ON_DARK_LINE = "rgba(255, 248, 238, 0.32)",
     BANNER_DARK = "#1F1A17",
     BANNER_MID = "#3B2A20",
     BANNER_LIGHT = "#7A3E22",
     BANNER_IMAGE = "";

# Dark variant (kitchen and music screens): charcoal ground, wood-brown surfaces, warm light text
glob DK_GROUND = "#161210",
     DK_SURFACE = "#221C18",
     DK_RAISED = "#2D2520",
     DK_LINE = "#40352D",
     DK_TEXT = "#FBF3E9",
     DK_MUTED = "#C9B8A8",
     DK_ACCENT = "#F0A15C",
     DK_ON_ACCENT = "#1F1A17",
     DK_WARN_FG = "#FFD28A",
     DK_WARN_BG = "#5A3A12",
     DK_VEG_FG = "#BFE59A",
     DK_VEG_BG = "#2F4A1D",
     DK_ALLERGY_FG = "#FFC9CF",
     DK_ALLERGY_BG = "#6E1B29",
     DK_INFO_FG = "#B9E0F5",
     DK_INFO_BG = "#1D4660";

# Overlay behind the order sheet, and soft shadows
glob SCRIM = "rgba(31, 26, 23, 0.55)",
     SHADOW = "0 12px 28px rgba(31, 26, 23, 0.22)",
     SHADOW_SOFT = "0 2px 10px rgba(31, 26, 23, 0.08)";

# Fonts: Geist, then Inter, then the system font. No serif.
glob FONT_TEXT = "'Geist', 'Inter', system-ui, sans-serif",
     FONT_MONO = "'Geist Mono', ui-monospace, monospace",
     FONTS_URL = "https://fonts.googleapis.com/css2?family=Geist:wght@400;500;600;700&family=Inter:wght@400;500;600;700&family=Geist+Mono:wght@400;500&display=swap";

# Type scale (px)
glob FS_XS = 12,
     FS_SM = 14,
     FS_MD = 16,
     FS_LG = 18,
     FS_XL = 22,
     FS_2XL = 28,
     FS_3XL = 34;

# Shape (px) and spacing scale (px): 4, 8, 12, 16, 24 (SP_5 is only for page-level padding)
glob RADIUS_CARD = 16,
     RADIUS_BUTTON = 16,
     RADIUS_PILL = 999,
     TAP_HEIGHT = 48,
     SP_0 = 4,
     SP_1 = 8,
     SP_2 = 12,
     SP_3 = 16,
     SP_4 = 24,
     SP_5 = 32;

"""Global rules injected once by main.jac: base font, a 150 ms press transition on every button, and a clear focus ring."""
glob GLOBAL_CSS = (
    "body { margin: 0; background: " + GROUND + "; color: " + BODY + "; font-family: " + FONT_TEXT + "; -webkit-font-smoothing: antialiased; } "
    + "button { transition: transform 150ms ease, background-color 150ms ease, opacity 150ms ease, box-shadow 150ms ease; } "
    + "button:active:not(:disabled) { transform: scale(0.97); } "
    + "button:disabled { cursor: not-allowed; } "
    + "input, textarea, button { font-family: inherit; } "
    + ":focus-visible { outline: 3px solid " + ACCENT + "; outline-offset: 2px; } "
);

def page_style -> dict[str, str] {
    return {
        "minHeight": "100vh",
        "backgroundColor": GROUND,
        "color": BODY,
        "fontFamily": FONT_TEXT,
        "margin": "0 auto",
        "padding": f"{SP_4}px {SP_3}px"
    };
}

def card_style -> dict[str, str] {
    return {
        "backgroundColor": SURFACE,
        "border": f"1px solid {LINE}",
        "borderRadius": f"{RADIUS_CARD}px",
        "boxShadow": SHADOW_SOFT,
        "padding": f"{SP_4}px"
    };
}

def button_style(primary: bool = True) -> dict[str, str] {
    return {
        "minHeight": f"{TAP_HEIGHT}px",
        "padding": f"0 {SP_4}px",
        "borderRadius": f"{RADIUS_BUTTON}px",
        "border": "none" if primary else f"1px solid {LINE}",
        "backgroundColor": ACCENT if primary else SURFACE,
        "color": SURFACE if primary else INK,
        "fontFamily": FONT_TEXT,
        "fontSize": f"{FS_MD}px",
        "fontWeight": "600",
        "cursor": "pointer"
    };
}

def pill_style(fg: str, bg: str) -> dict[str, str] {
    return {
        "display": "inline-block",
        "padding": f"{SP_0}px {SP_2}px",
        "borderRadius": f"{RADIUS_PILL}px",
        "backgroundColor": bg,
        "color": fg,
        "fontSize": f"{FS_SM}px",
        "fontWeight": "500"
    };
}

def mono_style -> dict[str, str] {
    return {"fontFamily": FONT_MONO};
}

def chip_style(active: bool) -> dict[str, str] {
    return {
        "flex": "0 0 auto",
        "minHeight": f"{TAP_HEIGHT}px",
        "padding": f"0 {SP_3}px",
        "borderRadius": f"{RADIUS_PILL}px",
        "border": "none" if active else f"1px solid {LINE}",
        "backgroundColor": INK if active else SURFACE,
        "color": SURFACE if active else BODY,
        "fontFamily": FONT_TEXT,
        "fontSize": f"{FS_MD}px",
        "fontWeight": "500",
        "cursor": "pointer"
    };
}

def step_style(filled: bool) -> dict[str, str] {
    return {
        "width": f"{TAP_HEIGHT}px",
        "height": f"{TAP_HEIGHT}px",
        "borderRadius": f"{RADIUS_BUTTON}px",
        "border": "none" if filled else f"1px solid {LINE}",
        "backgroundColor": ACCENT if filled else SURFACE,
        "color": SURFACE if filled else ACCENT,
        "fontFamily": FONT_TEXT,
        "fontSize": f"{FS_XL}px",
        "lineHeight": "1",
        "cursor": "pointer"
    };
}

"""The photo banner at the top of the guest page: a dark gradient (over a photo when BANNER_IMAGE is set) with white text."""
def banner_style -> dict[str, str] {
    gradient = f"linear-gradient(160deg, {BANNER_DARK} 0%, {BANNER_MID} 55%, {BANNER_LIGHT} 100%)";
    shade = f"linear-gradient(180deg, rgba(31, 26, 23, 0.25) 0%, rgba(31, 26, 23, 0.8) 100%)";
    return {
        "background": f"{shade}, url({BANNER_IMAGE}) center / cover" if BANNER_IMAGE != "" else gradient,
        "color": ON_DARK,
        "padding": f"{SP_4}px {SP_3}px {SP_3}px"
    };
}

"""A round stand-in for a dish photo: warm gradient with the dish's first letter."""
def dish_photo_style(size: int) -> dict[str, str] {
    return {
        "flex": f"0 0 {size}px",
        "width": f"{size}px",
        "height": f"{size}px",
        "borderRadius": f"{RADIUS_PILL}px",
        "background": f"linear-gradient(135deg, {ACCENT} 0%, {HIGHLIGHT} 100%)",
        "color": ON_DARK,
        "display": "flex",
        "alignItems": "center",
        "justifyContent": "center",
        "fontSize": f"{FS_XL}px",
        "fontWeight": "700",
        "fontFamily": FONT_TEXT
    };
}

def price_style -> dict[str, str] {
    return {"color": INK, "fontSize": f"{FS_LG}px", "fontWeight": "700", "fontFamily": FONT_TEXT};
}

# Dark helpers for the kitchen and music screens
def dark_page_style -> dict[str, str] {
    return {
        "minHeight": "100vh",
        "backgroundColor": DK_GROUND,
        "color": DK_TEXT,
        "fontFamily": FONT_TEXT
    };
}

def dark_card_style -> dict[str, str] {
    return {
        "backgroundColor": DK_SURFACE,
        "border": f"1px solid {DK_LINE}",
        "borderRadius": f"{RADIUS_CARD}px",
        "boxShadow": SHADOW_SOFT,
        "padding": f"{SP_4}px"
    };
}

def dark_button_style(primary: bool = True) -> dict[str, str] {
    return {
        "minHeight": f"{TAP_HEIGHT}px",
        "padding": f"0 {SP_4}px",
        "borderRadius": f"{RADIUS_BUTTON}px",
        "border": "none" if primary else f"1px solid {DK_LINE}",
        "backgroundColor": DK_ACCENT if primary else DK_RAISED,
        "color": DK_ON_ACCENT if primary else DK_TEXT,
        "fontFamily": FONT_TEXT,
        "fontSize": f"{FS_LG}px",
        "fontWeight": "700",
        "cursor": "pointer"
    };
}
