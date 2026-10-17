"""AI waiter screen (G-04), like docs/mockups/3-guest-ai-waiter.png.

Stays mounted while the guest looks at the menu, so what they typed and the plan are kept.
The server only suggests: nothing is ordered until "Confirm & send".
"""

import from "react" { useEffect }
import from ..core.agents { WaiterPlan, ChatTurn }
import from ..core.waiter { ask_waiter }
import from ..core.orders { place_order, OrderLine, PlaceResult }
import from ..core.theme {
    TAP_HEIGHT,
    button_style, card_style, pill_style, mono_style,
    INK, MUTED, BODY, GROUND, SURFACE, LINE, ACCENT, VEG_FG, WARN_FG, WARN_BG, ALLERGY_FG, ALLERGY_BG,
    FONT_TEXT, RADIUS_CARD, RADIUS_BUTTON, SP_1, SP_2, SP_3, SP_4,
    FS_LG, FS_MD, FS_SM, FS_XL, FS_XS
}
import from .guest { money, NotePills }

glob BUSY = "The AI waiter is busy right now. You can still add dishes from the menu.",
     SEND_FAILED = "We couldn't send your order. Please try again.",
     MAX_MESSAGE = 500,
     BOX_MIN = 48,
     BOX_MAX = 144;

def plan_text(plan: WaiterPlan) -> str {
    return "Suggested: " + ", ".join([str(i.qty) + " x " + i.dish_name for i in plan.items]) + ". Total " + money(plan.total);
}

def:pub StepsCard(steps: list[str], working: bool) -> JsxElement {
    <div style={card_style() | {"padding": f"{SP_3}px", "marginTop": f"{SP_3}px"}}>
        <div style={{"color": ACCENT, "fontWeight": "700", "marginBottom": f"{SP_1}px"}}>
            {"Checking the menu..." if working else "What I checked"}
        </div>
        {if not working {
            for (i, st) in enumerate(steps) {
                <div key={str(i)} style={mono_style() | {"color": BODY, "fontSize": f"{FS_SM}px", "padding": "3px 0"}}>{"✓ " + st}</div>
            }
        }}
    </div>
}

def:pub PlanCard(plan: WaiterPlan, busy: bool, onChange: any, onConfirm: any, sending: bool) -> JsxElement {
    <div style={card_style() | {"padding": f"{SP_3}px", "marginTop": f"{SP_3}px", "opacity": "0.6" if busy else "1"}}>
        <p style={{"color": INK, "fontSize": f"{FS_LG}px", "margin": f"0 0 {SP_2}px"}}>{plan.summary}</p>
        {for i in plan.items {
            <div key={i.dish_id} style={{"padding": f"{SP_1}px 0", "borderBottom": f"1px solid {LINE}"}}>
                <div style={{"display": "flex", "justifyContent": "space-between", "color": INK, "fontSize": f"{FS_LG}px"}}>
                    <span>
                        {i.dish_name}
                        {if i.is_veg {
                            <span style={{"color": VEG_FG}}>{" · veg"}</span>
                        }}
                        {if i.qty > 1 {
                            <span>{" × " + str(i.qty)}</span>
                        }}
                    </span>
                    <span style={mono_style()}>{str(i.price * i.qty)}</span>
                </div>
                <div style={{"color": MUTED, "fontSize": f"{FS_SM}px"}}>{i.reason}</div>
            </div>
        }}
        <div style={{"display": "flex", "justifyContent": "space-between", "padding": f"{SP_2}px 0", "color": INK, "fontWeight": "700"}}>
            <span>Total</span>
            <span style={mono_style()}>{money(plan.total)}</span>
        </div>
        {for (n, w) in enumerate(plan.warnings) {
            <p key={str(n)} style={pill_style(WARN_FG, WARN_BG) | {"display": "block", "margin": f"0 0 {SP_1}px"}}>{w}</p>
        }}
        <NotePills allergy={plan.allergy_note} preference={plan.preference_note}/>
        <div style={{"display": "flex", "gap": f"{SP_2}px", "marginTop": f"{SP_3}px"}}>
            <button style={button_style(False) | {"flex": "1", "opacity": "0.5" if busy else "1"}} disabled={busy} onClick={lambda { onChange(); }}>Change</button>
            <button
                style={button_style() | {"flex": "2", "opacity": "0.5" if (busy or len(plan.items) == 0) else "1"}}
                disabled={busy or len(plan.items) == 0}
                onClick={lambda { onConfirm(); }}
            >{"Sending..." if sending else "Confirm & send"}</button>
        </div>
    </div>
}

def:pub WaiterScreen(code: str, table: str, onBack: any, onSent: any) -> JsxElement {
    has text: str = "",
        pending: str = "",
        history: list[ChatTurn] = [],
        plan: WaiterPlan | None = None,
        working: bool = False,
        sending: bool = False,
        error: str = "";

    async def ask {
        result: WaiterPlan | None = None;
        message = text.strip();
        if working or sending or message == "" {
            return;
        }
        working = True;
        error = "";
        pending = message;
        try {
            result = await ask_waiter(code, message, history);
            if result.ok {
                plan = result;
                history = history + [ChatTurn(role="guest", text=message), ChatTurn(role="waiter", text=plan_text(result))];
                text = "";
            } else {
                error = BUSY;
            }
        } except Exception {
            error = BUSY;
        }
        pending = "";
        working = False;
    }

    async def confirm {
        result: PlaceResult | None = None;
        if sending or working or plan is None or len(plan.items) == 0 {
            return;
        }
        sending = True;
        error = "";
        try {
            items = [OrderLine(dish_id=i.dish_id, qty=i.qty) for i in plan.items];
            result = await place_order(code, items, plan.allergy_note, True, plan.preference_note);
            if result.ok {
                plan = None;
                history = [];
                text = "";
                onSent(result.message);
            } else {
                error = result.message;
            }
        } except Exception {
            error = SEND_FAILED;
        }
        sending = False;
    }

    def focus_input {
        el: any = document.getElementById("waiter-input");
        if el {
            el.focus();
        }
    }

    # Grow the box with the text: 1 line up to 5 lines, then it scrolls inside.
    can with [text] entry {
        el: any = document.getElementById("waiter-input");
        if el {
            el.style.height = "auto";
            el.style.height = str(max(BOX_MIN, min(el.scrollHeight, BOX_MAX))) + "px";
        }
    }

    guest_lines = [t.text for t in history if t.role == "guest"] + ([pending] if pending != "" else []);
    busy = working or sending;
    return <div style={{"maxWidth": "480px", "margin": "0 auto", "minHeight": "100vh", "backgroundColor": GROUND, "fontFamily": FONT_TEXT}}>
        <div style={{"display": "flex", "alignItems": "center", "gap": f"{SP_3}px", "padding": f"{SP_3}px", "backgroundColor": SURFACE, "borderBottom": f"1px solid {LINE}"}}>
            <button aria-label="Back to the menu" onClick={lambda { onBack(); }} style={button_style(False) | {"width": f"{TAP_HEIGHT}px", "padding": "0", "fontSize": f"{FS_XL}px"}}>←</button>
            <div>
                <div style={{"color": INK, "fontSize": f"{FS_XL}px", "fontWeight": "700"}}>AI waiter</div>
                <div style={{"color": MUTED, "fontSize": f"{FS_MD}px"}}>{table + " · nothing is ordered until you confirm"}</div>
            </div>
        </div>
        <div style={{"padding": f"{SP_3}px {SP_3}px 240px"}}>
            {if len(guest_lines) == 0 and plan is None {
                <p style={{"color": MUTED, "textAlign": "center", "marginTop": f"{SP_4}px"}}>Tell us how many you are, any diets or allergies, and your budget.</p>
            }}
            {for (n, line) in enumerate(guest_lines) {
                <div key={str(n)} style={{"display": "flex", "justifyContent": "flex-end", "marginTop": f"{SP_2}px"}}>
                    <div style={{"backgroundColor": INK, "color": SURFACE, "borderRadius": "20px", "padding": f"{SP_2}px {SP_3}px", "maxWidth": "85%", "fontSize": f"{FS_LG}px"}}>{line}</div>
                </div>
            }}
            {if working {
                <StepsCard steps={[]} working={True}/>
            } elif plan is not None {
                <StepsCard steps={plan.steps} working={False}/>
            }}
            {if error != "" {
                <p style={pill_style(ALLERGY_FG, ALLERGY_BG) | {"display": "block", "margin": f"{SP_3}px 0 0"}}>{error}</p>
            }}
            {if plan is not None {
                <PlanCard plan={plan} busy={busy} sending={sending} onChange={focus_input} onConfirm={confirm}/>
            }}
        </div>
        <div style={{"position": "fixed", "left": "0", "right": "0", "bottom": "0", "display": "flex", "justifyContent": "center", "zIndex": "20"}}>
            <form
                onSubmit={lambda (e: FormEvent) { e.preventDefault(); ask(); }}
                style={{"width": "100%", "maxWidth": "480px", "boxSizing": "border-box", "display": "flex", "alignItems": "flex-end", "gap": f"{SP_2}px", "padding": f"{SP_3}px", "backgroundColor": SURFACE, "borderTop": f"1px solid {LINE}"}}
            >
                <div style={{"flex": "1", "minWidth": "0"}}>
                    <textarea
                        id="waiter-input"
                        rows={1}
                        value={text}
                        maxLength={MAX_MESSAGE}
                        disabled={busy}
                        placeholder={"Ask for changes..." if plan is not None else "Tell the waiter what you need..."}
                        onChange={lambda (e: ChangeEvent) { text = e.target.value; }}
                        style={{
                            "display": "block", "width": "100%", "boxSizing": "border-box", "resize": "none",
                            "minHeight": f"{BOX_MIN}px", "maxHeight": f"{BOX_MAX}px", "overflowY": "auto",
                            "padding": f"{SP_2}px {SP_3}px", "lineHeight": "24px", "border": f"1px solid {LINE}",
                            "borderRadius": f"{RADIUS_BUTTON}px", "fontFamily": FONT_TEXT, "fontSize": f"{FS_MD}px",
                            "color": INK, "backgroundColor": SURFACE
                        }}
                    />
                    <div style={{"textAlign": "right", "fontSize": f"{FS_XS}px", "marginTop": "4px", "color": WARN_FG if len(text) >= 450 else MUTED}}>
                        {str(len(text)) + " / " + str(MAX_MESSAGE)}
                    </div>
                </div>
                <button
                    type="submit"
                    aria-label="Send"
                    disabled={busy or text.strip() == ""}
                    style={{"width": "56px", "height": f"{BOX_MIN}px", "marginBottom": "20px", "border": "none", "borderRadius": f"{RADIUS_BUTTON}px", "backgroundColor": INK, "color": SURFACE, "fontSize": f"{FS_XL}px", "cursor": "pointer", "opacity": "0.5" if (busy or text.strip() == "") else "1"}}
                >↑</button>
            </form>
        </div>
    </div>;
}
