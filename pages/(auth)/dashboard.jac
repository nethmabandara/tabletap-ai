"""Manager dashboard (M-01). Opening it claims the demo restaurant for this manager (S-01)."""

import from "@jac/runtime" { jacLogout, useNavigate }
import from ...core.menu { claim_demo_restaurant, my_restaurant_name }
import from ...core.theme { page_style, card_style, button_style, pill_style, INK, MUTED, ACCENT, ACCENT_SOFT, WARN_FG, WARN_BG }

def:pub Dashboard -> JsxPage {
    has name: str = "",
        loaded: bool = False,
        failed: bool = False;
    nav = useNavigate();

    async can with entry {
        try {
            await claim_demo_restaurant();
            name = await my_restaurant_name();
            loaded = True;
        } except Exception {
            failed = True;
        }
    }

    def log_out {
        jacLogout();
        nav("/login");
    }

    return <main style={page_style() | {"maxWidth": "640px"}}>
        <div style={card_style()}>
            <span style={pill_style(ACCENT, ACCENT_SOFT)}>Manager dashboard</span>
            <h1 style={{"color": INK, "fontSize": "28px", "margin": "16px 0 8px"}}>
                {"We couldn't load your restaurant." if failed else (name if name else ("Set up your restaurant" if loaded else "Opening your restaurant..."))}
            </h1>
            <p style={{"color": MUTED, "margin": "0 0 24px"}}>{"The demo restaurant is already taken. Setting up your own restaurant is coming soon." if loaded and not name else "Your menu, kitchen board and music screen will appear here."}</p>
            {if loaded and not name {
                <p style={pill_style(WARN_FG, WARN_BG) | {"display": "block", "margin": "0 0 16px"}}>Set up your restaurant first to use the kitchen board.</p>
            }}
            <div style={{"display": "flex", "gap": "12px", "flexWrap": "wrap"}}>
                <button
                    style={button_style() | {"opacity": "1" if name else "0.5"}}
                    disabled={not name}
                    onClick={lambda { nav("/kitchen"); }}
                >Kitchen board</button>
                <button style={button_style(False)} onClick={lambda { log_out(); }}>Log out</button>
            </div>
        </div>
    </main>;
}
