"""Menu Setup screen pieces (M-02): header, upload card, photo progress, agent steps. See docs/mockups/1-manager-menu-setup.png.
The photo upload cannot use the normal bridge (it only sends JSON), so post_photos sends FormData to the function URL
with the same base URL and login token the bridge uses.
"""

import from "@jac/runtime" { Link }
import from ..core.menu_draft { SetupResult, DraftView }
import from ..core.theme {
    button_style, card_style, pill_style, mono_style,
    INK, MUTED, BODY, GROUND, SURFACE, LINE, ACCENT, ACCENT_SOFT, FONT_TEXT, WARN_FG, WARN_BG, VEG_FG,
    RADIUS_CARD, RADIUS_BUTTON, SP_1, SP_2, SP_3, SP_4
}

glob MAX_PHOTOS = 3,
     MAX_MB = 10;

"""Send the chosen photos. Returns {'ok', 'message', 'failed'}; never raises."""
async def:pub post_photos(files: list[any]) -> dict[str, any] {
    answer: dict[str, any] = {"ok": False, "message": "We couldn't send your photos. Please try again.", "failed": []};
    try {
        form: any = new(FormData);  # jac:ignore[E1053]
        for f in files {
            form.append("files", f);
        }
        token = localStorage.getItem("jac_token") or "";
        base = globalThis.__JAC_API_BASE_URL__ or "";
        resp = await fetch(base + "/function/read_menu_photos", {"method": "POST", "headers": {"Authorization": "Bearer " + token}, "body": form});
        if resp.status == 401 {
            answer["message"] = "Please log in again.";
            return answer;
        }
        body: any = await resp.json();
        result: any = (body.data.result if (body and body.data) else None);
        if result {
            answer = {"ok": result.ok, "message": result.message or "", "failed": result.failed_photos or []};
        }
    } except Exception {
        console.error("Menu photo upload failed");
    }
    return answer;
}

"""Quick check before uploading. The server checks again, so this only saves time. '' means fine."""
def:pub check_picked(files: list[any]) -> str {
    if len(files) > MAX_PHOTOS {
        return f"You can read up to {MAX_PHOTOS} photos at a time. Please choose fewer photos.";
    }
    for (i, f) in enumerate(files) {
        if f.size > MAX_MB * 1024 * 1024 {
            return f"Photo {i + 1} is too big. Each photo can be up to {MAX_MB} MB.";
        }
        if f.type != "image/jpeg" and f.type != "image/png" {
            return f"Photo {i + 1} must be a JPG or PNG picture.";
        }
    }
    return "";
}

def:pub SetupHeader(restaurant: str) -> JsxElement {
    <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "padding": f"{SP_3}px {SP_4}px", "backgroundColor": SURFACE, "borderBottom": f"1px solid {LINE}", "flexWrap": "wrap", "gap": f"{SP_2}px"}}>
        <div style={{"display": "flex", "alignItems": "center", "gap": f"{SP_2}px"}}>
            <span style={{"width": "44px", "height": "44px", "borderRadius": f"{RADIUS_BUTTON}px", "backgroundColor": ACCENT, "color": SURFACE, "display": "flex", "alignItems": "center", "justifyContent": "center", "fontSize": "22px", "fontWeight": "700"}}>T</span>
            <div>
                <div style={{"color": INK, "fontSize": "20px", "fontWeight": "700"}}>TableTap AI</div>
                <div style={{"color": MUTED, "fontSize": "14px"}}>{(restaurant + " · " if restaurant else "") + "Manager"}</div>
            </div>
        </div>
        <div style={{"display": "flex", "gap": f"{SP_3}px", "alignItems": "center"}}>
            <span style={pill_style(ACCENT, ACCENT_SOFT) | {"fontSize": "16px", "padding": "8px 16px", "fontWeight": "600"}}>Menu</span>
            <Link to="/kitchen" style={{"color": BODY, "fontSize": "16px", "textDecoration": "none"}}>Kitchen board</Link>
            <Link to="/dashboard" style={{"color": BODY, "fontSize": "16px", "textDecoration": "none"}}>Dashboard</Link>
        </div>
    </div>
}

"""One tile per chosen photo, ticking off as each finishes."""
def:pub PhotoTile(number: int, name: str, status: str) -> JsxElement {
    label = {"waiting": "waiting", "reading": "reading...", "done": "✓ read", "failed": "! couldn't read"}.get(status, "");
    <div style={{"flex": "1", "minWidth": "0", "backgroundColor": INK, "color": SURFACE, "borderRadius": f"{RADIUS_BUTTON}px", "padding": f"{SP_2}px", "minHeight": "120px", "display": "flex", "flexDirection": "column", "justifyContent": "flex-end"}}>
        <div style={{"fontSize": "13px", "overflow": "hidden", "textOverflow": "ellipsis", "whiteSpace": "nowrap"}}>{"Photo " + str(number)}</div>
        <div style={{"fontSize": "12px", "overflow": "hidden", "textOverflow": "ellipsis", "whiteSpace": "nowrap", "color": LINE}}>{name}</div>
        <div style={mono_style() | {"fontSize": "13px", "marginTop": f"{SP_1}px", "color": (WARN_BG if status == "failed" else LINE)}}>{label}</div>
    </div>
}

def:pub UploadCard(
    names: list[str], statuses: list[str], reading: bool, input_key: int, error: str,
    onPick: any, onRead: any
) -> JsxElement {
    <div style={card_style() | {"padding": f"{SP_4}px"}}>
        <div style={{"color": ACCENT, "fontSize": "14px", "fontWeight": "700", "letterSpacing": "0.08em"}}>MENU SETUP AGENT</div>
        <h2 style={{"color": INK, "fontSize": "32px", "lineHeight": "1.15", "margin": f"{SP_1}px 0 {SP_2}px"}}>Turn your paper menu into a smart menu</h2>
        <p style={{"color": MUTED, "margin": f"0 0 {SP_3}px", "fontSize": "17px"}}>Upload photos of your menu (JPG or PNG, up to {MAX_PHOTOS} photos, {MAX_MB} MB each). The agent reads every dish and price, then adds what the paper doesn't say.</p>
        <div style={{"border": f"2px dashed {LINE}", "borderRadius": f"{RADIUS_CARD}px", "padding": f"{SP_3}px", "backgroundColor": GROUND}}>
            {if len(names) > 0 {
                <div style={{"display": "flex", "gap": f"{SP_2}px", "marginBottom": f"{SP_2}px"}}>
                    {for (i, n) in enumerate(names) {
                        <PhotoTile key={str(i)} number={i + 1} name={n} status={statuses[i] if i < len(statuses) else "waiting"}/>
                    }}
                </div>
                <div style={{"color": BODY, "marginBottom": f"{SP_1}px"}}>{str(len(names)) + (" photo selected" if len(names) == 1 else " photos selected")}</div>
            }}
            <input key={str(input_key)} type="file" multiple={True} accept="image/jpeg,image/png" disabled={reading} onChange={lambda (e: ChangeEvent) { onPick(e); }}/>
        </div>
        {if error != "" {
            <p style={pill_style(WARN_FG, WARN_BG) | {"display": "block", "margin": f"{SP_3}px 0 0"}}>{error}</p>
        }}
        <button
            style={button_style() | {"width": "100%", "marginTop": f"{SP_3}px", "minHeight": "56px", "fontSize": "20px", "opacity": "0.5" if (reading or len(names) == 0) else "1"}}
            disabled={reading or len(names) == 0}
            onClick={lambda { onRead(); }}
        >{("Reading " + str(len(names)) + (" photo..." if len(names) == 1 else " photos...")) if reading else "Read my menu"}</button>
    </div>
}

def:pub StepsCard(steps: list[str]) -> JsxElement {
    <div style={card_style() | {"padding": f"{SP_3}px {SP_4}px", "marginTop": f"{SP_3}px"}}>
        <div style={{"color": INK, "fontWeight": "700", "marginBottom": f"{SP_2}px"}}>Agent steps</div>
        {if len(steps) == 0 {
            <div style={{"color": MUTED}}>The agent's steps appear here after it reads your photos.</div>
        }}
        {for (i, s) in enumerate(steps) {
            <div key={str(i)} style={mono_style() | {"fontSize": "15px", "padding": "4px 0", "color": (WARN_FG if ("check" in s or "Couldn't" in s) else BODY)}}>
                {("! " if ("check" in s and "No dishes" not in s) or "Couldn't" in s else "✓ ") + s}
            </div>
        }}
    </div>
}
