"""Guest cart pieces (G-03): bottom bar, order sheet with confirm step, status card.
Prices shown here are for display only; the server prices the order itself."""

import from ..core.menu { DishView }
import from ..core.orders { OrderView }
import from ..core.theme {
    button_style, card_style, pill_style, step_style, mono_style,
    INK, MUTED, BODY, GROUND, SURFACE, LINE, ACCENT, ACCENT_SOFT, SCRIM, FONT_TEXT,
    ALLERGY_FG, ALLERGY_BG, WARN_FG, WARN_BG, VEG_FG, VEG_BG, INFO_FG, INFO_BG,
    RADIUS_CARD, RADIUS_BUTTON, SP_1, SP_2, SP_3, SP_4
}
import from .guest { money }

glob MAX_NOTE = 200,
     MAX_QTY = 20,
     STEPS = ["sent", "preparing", "ready"],
     STEP_LABEL: dict[str, str] = {"sent": "Sent", "preparing": "Preparing", "ready": "Ready"};

def:pub CartBar(count: int, total: int, onOpen: any) -> JsxElement {
    <div style={{"position": "fixed", "left": "0", "right": "0", "bottom": "0", "zIndex": "20", "display": "flex", "justifyContent": "center"}}>
        <button
            onClick={lambda { onOpen(); }}
            style={{
                "width": "100%", "maxWidth": "480px", "margin": f"0 {SP_3}px {SP_3}px", "minHeight": "64px",
                "padding": f"0 {SP_4}px", "border": "none", "borderRadius": f"{RADIUS_CARD}px",
                "backgroundColor": ACCENT, "color": SURFACE, "fontFamily": FONT_TEXT, "cursor": "pointer",
                "display": "flex", "justifyContent": "space-between", "alignItems": "center"
            }}
        >
            <span style={{"textAlign": "left"}}>
                <span style={{"display": "block", "fontSize": "14px"}}>{str(count) + (" item" if count == 1 else " items")}</span>
                <span style={mono_style() | {"fontSize": "20px", "fontWeight": "600"}}>{money(total)}</span>
            </span>
            <span style={{"fontSize": "18px", "fontWeight": "600"}}>View order →</span>
        </button>
    </div>
}

def:pub CartLineRow(dish: DishView, qty: int, onAdd: any, onRemove: any) -> JsxElement {
    <div style={{"display": "flex", "alignItems": "center", "gap": f"{SP_2}px", "padding": f"{SP_2}px 0", "borderBottom": f"1px solid {LINE}"}}>
        <div style={{"flex": "1", "minWidth": "0"}}>
            <div style={{"color": INK, "fontWeight": "600"}}>{dish.name}</div>
            {if dish.sold_out {
                <div style={pill_style(ALLERGY_FG, ALLERGY_BG) | {"marginTop": "4px"}}>Sold out today. Please remove it.</div>
            } else {
                <div style={mono_style() | {"color": MUTED, "fontSize": "14px"}}>{money(dish.price * qty)}</div>
            }}
        </div>
        <button style={step_style(False)} aria-label={"Remove one " + dish.name} onClick={lambda { onRemove(dish.id); }}>−</button>
        <span style={{"minWidth": "24px", "textAlign": "center", "color": INK, "fontWeight": "600"}}>{qty}</span>
        <button style={step_style(True)} aria-label={"Add one " + dish.name} disabled={qty >= MAX_QTY or dish.sold_out} onClick={lambda { onAdd(dish.id); }}>+</button>
    </div>
}

def:pub OrderSheet(
    lines: list[DishView], cart: dict[str, int], total: int, note: str, sending: bool, message: str,
    onNote: any, onAdd: any, onRemove: any, onClose: any, onSend: any
) -> JsxElement {
    has confirming: bool = False;
    blocked = len([d for d in lines if d.sold_out]) > 0;
    field = {
        "width": "100%", "boxSizing": "border-box", "minHeight": "72px", "padding": f"{SP_2}px",
        "border": f"1px solid {LINE}", "borderRadius": f"{RADIUS_BUTTON}px", "fontFamily": FONT_TEXT,
        "fontSize": "16px", "color": INK, "backgroundColor": SURFACE
    };
    <div style={{"position": "fixed", "inset": "0", "zIndex": "30", "backgroundColor": SCRIM, "display": "flex", "alignItems": "flex-end", "justifyContent": "center"}}>
        <div style={{
            "width": "100%", "maxWidth": "480px", "maxHeight": "90vh", "overflowY": "auto", "boxSizing": "border-box",
            "backgroundColor": SURFACE, "borderRadius": f"{RADIUS_CARD}px {RADIUS_CARD}px 0 0", "padding": f"{SP_4}px {SP_3}px"
        }}>
            <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center"}}>
                <h2 style={{"color": INK, "fontSize": "22px", "margin": "0"}}>{"Send this order?" if confirming else "Your order"}</h2>
                <button style={button_style(False) | {"minHeight": "44px", "padding": f"0 {SP_3}px"}} disabled={sending} onClick={lambda { onClose(); }}>Close</button>
            </div>
            {for d in lines {
                <CartLineRow key={d.id} dish={d} qty={cart[d.id]} onAdd={onAdd} onRemove={onRemove}/>
            }}
            <div style={{"display": "flex", "justifyContent": "space-between", "padding": f"{SP_3}px 0", "color": INK, "fontWeight": "600"}}>
                <span>Total</span>
                <span style={mono_style()}>{money(total)}</span>
            </div>
            <label style={{"color": BODY, "fontSize": "14px"}}>Allergies or notes for the kitchen (optional)</label>
            <textarea
                style={field | {"margin": f"{SP_1}px 0"}}
                value={note}
                maxLength={MAX_NOTE}
                disabled={sending}
                onChange={lambda (e: ChangeEvent) { onNote(e.target.value); }}
            />
            <div style={{"color": MUTED, "fontSize": "13px", "textAlign": "right"}}>{str(len(note)) + " / " + str(MAX_NOTE)}</div>
            {if message != "" {
                <p style={pill_style(ALLERGY_FG, ALLERGY_BG) | {"display": "block", "margin": f"{SP_2}px 0"}}>{message}</p>
            }}
            {if blocked {
                <p style={pill_style(WARN_FG, WARN_BG) | {"display": "block", "margin": f"{SP_2}px 0"}}>A dish in your order is sold out. Please remove it to continue.</p>
            }}
            {if confirming {
                <div style={{"display": "flex", "gap": f"{SP_2}px", "marginTop": f"{SP_2}px"}}>
                    <button style={button_style(False) | {"flex": "1"}} disabled={sending} onClick={lambda { confirming = False; }}>Back</button>
                    <button style={button_style() | {"flex": "2", "opacity": "0.5" if sending else "1"}} disabled={sending or blocked} onClick={lambda { onSend(); }}>
                        {"Sending..." if sending else "Confirm & send"}
                    </button>
                </div>
            } else {
                <button style={button_style() | {"width": "100%", "marginTop": f"{SP_2}px", "opacity": "0.5" if blocked else "1"}} disabled={blocked or len(lines) == 0} onClick={lambda { confirming = True; }}>
                    Send order
                </button>
            }}
        </div>
    </div>
}

def:pub StatusCard(order: OrderView) -> JsxElement {
    here = STEPS.index(order.status) if order.status in STEPS else 0;
    <div style={card_style() | {"padding": f"{SP_3}px", "marginTop": f"{SP_2}px"}}>
        <div style={{"display": "flex", "justifyContent": "space-between", "color": INK, "fontWeight": "600"}}>
            <span>{"Your order · " + str(len(order.items)) + (" dish" if len(order.items) == 1 else " dishes")}</span>
            <span style={mono_style() | {"color": MUTED, "fontWeight": "400"}}>{money(order.total)}</span>
        </div>
        <div style={{"display": "flex", "gap": f"{SP_1}px", "marginTop": f"{SP_2}px"}}>
            {for (i, step) in enumerate(STEPS) {
                <span key={step} style={pill_style(
                    ACCENT if i == here else MUTED, ACCENT_SOFT if i == here else GROUND
                ) | {"flex": "1", "textAlign": "center", "fontWeight": "600" if i == here else "400"}}>{STEP_LABEL[step]}</span>
            }}
        </div>
    </div>
}
