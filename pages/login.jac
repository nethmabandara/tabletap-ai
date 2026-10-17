"""Manager login and sign-up (M-01)."""

import from "@jac/runtime" { SignupResult, jacLogin, jacSignup, useNavigate }
import from ..core.theme {
    page_style, card_style, button_style, pill_style, INK, MUTED, LINE, SURFACE, BODY,
    ACCENT, ACCENT_SOFT, ALLERGY_FG, ALLERGY_BG, FONT_TEXT, RADIUS_BUTTON
}

def:pub LoginPage -> JsxPage {
    has username: str = "",
        password: str = "",
        busy: bool = False,
        message: str = "";
    nav = useNavigate();

    async def log_in {
        ok: bool = False;
        busy = True;
        message = "";
        try {
            ok = await jacLogin(username, password);
            if ok {
                nav("/dashboard");
            } else {
                message = "Wrong username or password.";
            }
        } except Exception {
            message = "Something went wrong. Please try again.";
        }
        busy = False;
    }

    async def sign_up {
        result: SignupResult | None = None;
        ok: bool = False;
        busy = True;
        message = "";
        try {
            result = await jacSignup(username, password);
            if not result.success {
                message = "Could not sign up. That username may already be taken.";
            } else {
                ok = await jacLogin(username, password);
                if ok {
                    nav("/dashboard");
                } else {
                    message = "Account created, but log in failed. Please log in.";
                }
            }
        } except Exception {
            message = "Something went wrong. Please try again.";
        }
        busy = False;
    }

    field = {
        "width": "100%", "boxSizing": "border-box", "minHeight": "44px", "padding": "0 12px",
        "border": f"1px solid {LINE}", "borderRadius": f"{RADIUS_BUTTON}px",
        "fontFamily": FONT_TEXT, "fontSize": "16px", "color": INK, "backgroundColor": SURFACE
    };
    can_submit = (not busy) and username.strip() != "" and password != "";

    return <main style={page_style() | {"maxWidth": "420px"}}>
        <form
            style={card_style()}
            onSubmit={lambda (e: FormEvent) { e.preventDefault(); log_in(); }}
        >
            <span style={pill_style(ACCENT, ACCENT_SOFT)}>TableTap AI</span>
            <h1 style={{"color": INK, "fontSize": "28px", "margin": "16px 0 4px"}}>Manager login</h1>
            <p style={{"color": MUTED, "margin": "0 0 24px"}}>Log in or create an account for your restaurant.</p>
            <label style={{"color": BODY, "fontSize": "14px"}}>Username</label>
            <input
                style={field | {"margin": "4px 0 16px"}}
                value={username}
                onChange={lambda (e: ChangeEvent) { username = e.target.value; }}
                autoComplete="username"
            />
            <label style={{"color": BODY, "fontSize": "14px"}}>Password</label>
            <input
                style={field | {"margin": "4px 0 16px"}}
                type="password"
                value={password}
                onChange={lambda (e: ChangeEvent) { password = e.target.value; }}
                autoComplete="current-password"
            />
            {if message != "" {
                <p style={pill_style(ALLERGY_FG, ALLERGY_BG) | {"display": "block", "margin": "0 0 16px"}}>{message}</p>
            }}
            <div style={{"display": "flex", "gap": "12px"}}>
                <button type="submit" disabled={not can_submit} style={button_style() | {"flex": "1", "opacity": "1" if can_submit else "0.5"}}>
                    {"Please wait..." if busy else "Log in"}
                </button>
                <button type="button" disabled={not can_submit} onClick={lambda { sign_up(); }} style={button_style(False) | {"flex": "1", "opacity": "1" if can_submit else "0.5"}}>
                    Sign up
                </button>
            </div>
        </form>
    </main>;
}
