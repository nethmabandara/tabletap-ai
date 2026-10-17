"""Home page: placeholder until the real screens are built."""

import from ..core.theme {
    page_style, card_style, button_style, pill_style, mono_style,
    INK, MUTED, ACCENT_SOFT, ACCENT, FONT_TEXT
}

def:pub Home -> JsxPage {
    <main style={page_style() | {"maxWidth": "640px"}}>
        <div style={card_style() | {"textAlign": "center"}}>
            <span style={pill_style(ACCENT, ACCENT_SOFT)}>AI Hackathon 2026</span>
            <h1 style={{"color": INK, "fontFamily": FONT_TEXT, "fontSize": "36px", "margin": "16px 0 8px"}}>
                TableTap AI
            </h1>
            <p style={{"color": MUTED, "fontSize": "18px", "margin": "0 0 24px"}}>
                An AI waiter, a live kitchen board and an AI DJ for your restaurant.
            </p>
            <p style={mono_style() | {"color": MUTED, "fontSize": "13px", "margin": "0 0 24px"}}>
                Set up · coming soon
            </p>
            <button style={button_style()} disabled={True}>Get started</button>
        </div>
    </main>
}
