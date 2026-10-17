"""TableTap AI theme: every colour, font, radius and spacing lives here.

Pages and ui/ files never write hex values; they call these tokens/helpers.
Style guide: docs/04-ui-ux.md.
"""

# Colours (ink/muted/body text, ground/surface/line layout, accent brand)
glob INK = "#14161A",
     MUTED = "#5B616B",
     BODY = "#3D434C",
     GROUND = "#F4F5F7",
     SURFACE = "#FFFFFF",
     LINE = "#E3E5E8",
     ACCENT = "#0F766E",
     ACCENT_SOFT = "#E6F2F1";

# Tag colours: text on background
glob WARN_FG = "#92400E",
     WARN_BG = "#FEF3C7",
     VEG_FG = "#166534",
     VEG_BG = "#DCFCE7",
     ALLERGY_FG = "#9F1239",
     ALLERGY_BG = "#FFE4E6",
     INFO_FG = "#075985",
     INFO_BG = "#E0F2FE";

# Fonts
glob FONT_TEXT = "'Geist', system-ui, sans-serif",
     FONT_MONO = "'Geist Mono', ui-monospace, monospace",
     FONTS_URL = "https://fonts.googleapis.com/css2?family=Geist:wght@400;500;600;700&family=Geist+Mono:wght@400;500&display=swap";

# Shape (px) and spacing steps (px, 8-point scale)
glob RADIUS_CARD = 16,
     RADIUS_BUTTON = 12,
     RADIUS_PILL = 999,
     SP_1 = 8,
     SP_2 = 12,
     SP_3 = 16,
     SP_4 = 24,
     SP_5 = 32;

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
        "padding": f"{SP_4}px"
    };
}

def button_style(primary: bool = True) -> dict[str, str] {
    return {
        "minHeight": "44px",
        "padding": f"0 {SP_4}px",
        "borderRadius": f"{RADIUS_BUTTON}px",
        "border": "none" if primary else f"1px solid {LINE}",
        "backgroundColor": ACCENT if primary else SURFACE,
        "color": SURFACE if primary else INK,
        "fontFamily": FONT_TEXT,
        "fontSize": "16px",
        "fontWeight": "600",
        "cursor": "pointer"
    };
}

def pill_style(fg: str, bg: str) -> dict[str, str] {
    return {
        "display": "inline-block",
        "padding": "4px 12px",
        "borderRadius": f"{RADIUS_PILL}px",
        "backgroundColor": bg,
        "color": fg,
        "fontSize": "13px",
        "fontWeight": "500"
    };
}

def mono_style -> dict[str, str] {
    return {"fontFamily": FONT_MONO};
}

def chip_style(active: bool) -> dict[str, str] {
    return {
        "flex": "0 0 auto",
        "minHeight": "44px",
        "padding": f"0 {SP_3}px",
        "borderRadius": f"{RADIUS_PILL}px",
        "border": "none",
        "backgroundColor": INK if active else GROUND,
        "color": SURFACE if active else BODY,
        "fontFamily": FONT_TEXT,
        "fontSize": "16px",
        "fontWeight": "500",
        "cursor": "pointer"
    };
}
