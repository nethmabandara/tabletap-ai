"""Home page: the front door. Managers go to sign up / log in; judges and guests can try the demo table."""

import from "@jac/runtime" { Link, useNavigate }
import from ..core.theme {
    page_style, card_style, button_style, pill_style,
    INK, MUTED, BODY, ACCENT_SOFT, ACCENT, FONT_TEXT, FS_SM, FS_MD, FS_LG, FS_3XL, SP_1, SP_2, SP_3, SP_4
}

def:pub Home -> JsxPage {
    nav = useNavigate();
    <main style={page_style() | {"maxWidth": "640px"}}>
        <div style={card_style() | {"textAlign": "center"}}>
            <span style={pill_style(ACCENT, ACCENT_SOFT)}>AI Hackathon 2026</span>
            <h1 style={{"color": INK, "fontFamily": FONT_TEXT, "fontSize": f"{FS_3XL}px", "margin": f"{SP_3}px 0 {SP_1}px"}}>
                TableTap AI
            </h1>
            <p style={{"color": BODY, "fontSize": f"{FS_LG}px", "fontWeight": "500", "margin": f"0 0 {SP_2}px"}}>
                Sign up as a manager, or try the demo table as a guest.
            </p>
            <p style={{"color": MUTED, "fontSize": f"{FS_MD}px", "margin": f"0 0 {SP_4}px"}}>
                An AI waiter, a live kitchen board and an AI DJ for your restaurant.
            </p>
            <button style={button_style() | {"width": "100%"}} onClick={lambda { nav("/login"); }}>Get started</button>
            <div style={{"marginTop": f"{SP_3}px"}}>
                <Link to="/t/t5" style={{"color": ACCENT, "fontSize": f"{FS_SM}px", "fontWeight": "600"}}>Try the guest view (Table 5)</Link>
            </div>
        </div>
    </main>
}
