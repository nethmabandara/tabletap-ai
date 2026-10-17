"""Tables & links page (M-06). Manager login required. Each link is built from this page's own address."""

import from "@jac/runtime" { Link }
import from ...core.restaurants { table_links, TableLinks }
import from ...core.theme { page_style, card_style, pill_style, INK, MUTED, WARN_FG, WARN_BG, SP_2, SP_3 }
import from ...ui.tables { TableCard }

def:pub TablesPage -> JsxPage {
    has links: TableLinks | None = None,
        loaded: bool = False,
        failed: bool = False,
        copied: str = "",
        message: str = "";

    async can with entry {
        result: TableLinks | None = None;
        try {
            result = await table_links();
            links = result;
        } except Exception {
            failed = True;
        }
        loaded = True;
    }

    def link_for(code: str) -> str {
        return window.location.origin + "/t/" + code;
    }

    """Copy a link. If the browser refuses (for example on a plain http address), select the text so Ctrl+C works."""
    async def copy_link(code: str) {
        message = "";
        try {
            await navigator.clipboard.writeText(link_for(code));
            copied = code;
            setTimeout(lambda { copied = ""; }, 2000);
        } except Exception {
            box: any = document.getElementById("link-" + code);
            if box {
                box.focus();
                box.select();
            }
            message = "Copy didn't work here. The link is selected: press Ctrl+C.";
        }
    }

    return <main style={page_style() | {"maxWidth": "760px"}}>
        <div style={{"marginBottom": f"{SP_3}px"}}><Link to="/dashboard">← Back to the dashboard</Link></div>
        {if not loaded {
            <p style={{"color": MUTED}}>Loading your tables...</p>
        } elif failed or links is None {
            <div style={card_style()}><h1 style={{"color": INK, "fontSize": "24px", "margin": "0"}}>We couldn't load your tables. Please refresh the page.</h1></div>
        } elif not links.ok {
            <div style={card_style() | {"textAlign": "center"}}>
                <h1 style={{"color": INK, "fontSize": "28px", "margin": "0 0 8px"}}>{links.message}</h1>
                <p style={{"color": MUTED, "margin": "0"}}>Your table links will appear here as soon as your restaurant is ready.</p>
            </div>
        } else {
            <h1 style={{"color": INK, "fontSize": "30px", "margin": "0"}}>Tables & links</h1>
            <p style={{"color": MUTED, "margin": f"4px 0 {SP_3}px"}}>{links.restaurant + " · give each table its own link or QR code"}</p>
            if message != "" {
                <p style={pill_style(WARN_FG, WARN_BG) | {"display": "block", "margin": f"0 0 {SP_3}px"}}>{message}</p>
            }
            for t in links.tables {
                <div key={t.code} style={{"marginBottom": f"{SP_2}px"}}>
                    <TableCard label={t.label} code={t.code} link={link_for(t.code)} copied={copied == t.code} onCopy={lambda { copy_link(t.code); }}/>
                </div>
            }
        }}
    </main>;
}
