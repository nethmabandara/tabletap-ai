"""Guest table page. S-01: only the 'Menu coming soon' state; the menu is G-01."""

import from "@jac/runtime" { useParams }
import from ...core.menu { table_status }
import from ...core.theme { page_style, card_style, pill_style, INK, MUTED, ACCENT, ACCENT_SOFT }

def:pub TablePage -> JsxPage {
    has status: str = "loading";
    params = useParams();
    code: str = params["code"];

    can with [code] entry {
        async def load() {
            status = await table_status(code);
        }
        load();
    }

    <main style={page_style() | {"maxWidth": "480px"}}>
        <div style={card_style() | {"textAlign": "center"}}>
            <span style={pill_style(ACCENT, ACCENT_SOFT)}>TableTap AI</span>
            <h1 style={{"color": INK, "fontSize": "28px", "margin": "16px 0 8px"}}>
                {"Menu coming soon" if status == "coming_soon" else "Welcome"}
            </h1>
            <p style={{"color": MUTED, "margin": "0"}}>
                {"" if status == "loading" else ("The restaurant is getting ready." if status == "coming_soon" else "Your table is ready.")}
            </p>
        </div>
    </main>
}
