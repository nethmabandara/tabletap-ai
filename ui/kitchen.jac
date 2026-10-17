"""Kitchen board pieces (K-01, K-02): header, columns, order cards, sold-out switches."""

import from ..core.menu { SectionView }
import from ..core.orders { OrderView }
import from ..core.theme {
    pill_style, mono_style, button_style, card_style,
    INK, MUTED, GROUND, SURFACE, LINE, ACCENT, ACCENT_SOFT, FONT_TEXT,
    WARN_FG, WARN_BG, VEG_FG, VEG_BG, INFO_FG, INFO_BG, ALLERGY_FG, ALLERGY_BG,
    RADIUS_CARD, RADIUS_BUTTON, SP_1, SP_2, SP_3, SP_4
}
import from .guest { money }

def:pub ago(minutes: int) -> str {
    if minutes < 1 {
        return "just now";
    }
    return str(minutes) + " min ago";
}

def:pub KitchenHeader(restaurant: str, showDishes: bool, onToggle: any) -> JsxElement {
    <div style={{
        "backgroundColor": INK, "color": SURFACE, "padding": f"{SP_3}px {SP_4}px",
        "display": "flex", "justifyContent": "space-between", "alignItems": "center"
    }}>
        <div>
            <h1 style={{"margin": "0", "fontSize": "28px"}}>Kitchen board</h1>
            <div style={{"color": LINE}}>{restaurant + " · oldest orders first"}</div>
        </div>
        <button
            onClick={lambda { onToggle(); }}
            style={{
                "minHeight": "44px", "padding": f"0 {SP_3}px", "borderRadius": f"{RADIUS_BUTTON}px",
                "border": f"1px solid {MUTED}", "backgroundColor": INK, "color": SURFACE,
                "fontFamily": FONT_TEXT, "fontSize": "16px", "fontWeight": "600", "cursor": "pointer"
            }}
        >
            {"Back to orders" if showDishes else "Sold-out dishes"}
        </button>
    </div>
}

"""clearMode: '' (no button), 'ask' (Clear table button) or 'confirm' (are you sure?). Only on a ready card of a table whose orders are all ready."""
def:pub OrderCard(
    order: OrderView, accent: str, working: bool, onMove: any,
    clearMode: str, clearing: bool, onAskClear: any, onKeep: any, onClear: any
) -> JsxElement {
    next_status = "preparing" if order.status == "sent" else ("ready" if order.status == "preparing" else "");
    <div style={{
        "backgroundColor": SURFACE, "borderRadius": f"{RADIUS_CARD}px", "borderTop": f"6px solid {accent}",
        "padding": f"{SP_3}px {SP_4}px {SP_4}px", "marginBottom": f"{SP_3}px"
    }}>
        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "baseline"}}>
            <span style={{"color": INK, "fontSize": "24px", "fontWeight": "700"}}>{order.table}</span>
            <span style={mono_style() | {"color": MUTED, "fontSize": "14px"}}>{ago(order.minutes_ago)}</span>
        </div>
        {for (i, it) in enumerate(order.items) {
            <div key={str(i)} style={{"color": INK, "fontSize": "17px", "marginTop": f"{SP_1}px"}}>{str(it.qty) + " × " + it.name}</div>
        }}
        {if order.allergy_note != "" {
            <div style={{
                "backgroundColor": ALLERGY_BG, "color": ALLERGY_FG, "fontWeight": "600",
                "borderRadius": f"{RADIUS_BUTTON}px", "padding": f"{SP_2}px", "marginTop": f"{SP_2}px"
            }}>{order.allergy_note}</div>
        }}
        {if order.preference_note != "" {
            <div style={{
                "backgroundColor": WARN_BG, "color": WARN_FG, "fontWeight": "600",
                "borderRadius": f"{RADIUS_BUTTON}px", "padding": f"{SP_2}px", "marginTop": f"{SP_1}px"
            }}>{order.preference_note}</div>
        }}
        {if order.status == "sent" {
            <button
                style={button_style() | {"width": "100%", "marginTop": f"{SP_2}px", "backgroundColor": INK, "opacity": "0.5" if working else "1"}}
                disabled={working}
                onClick={lambda { onMove(order.id, next_status); }}
            >Start preparing</button>
        } elif order.status == "preparing" {
            <button
                style={button_style() | {"width": "100%", "marginTop": f"{SP_2}px", "opacity": "0.5" if working else "1"}}
                disabled={working}
                onClick={lambda { onMove(order.id, next_status); }}
            >Mark ready</button>
        } else {
            <div style={{"color": VEG_FG, "fontWeight": "600", "marginTop": f"{SP_2}px"}}>Waiting for pickup</div>
        }}
        {if clearMode == "ask" {
            <button
                style={button_style(False) | {"width": "100%", "marginTop": f"{SP_2}px"}}
                onClick={lambda { onAskClear(order.table_code); }}
            >Clear table</button>
        }}
        {if clearMode == "confirm" {
            <div style={{"marginTop": f"{SP_2}px", "padding": f"{SP_2}px", "backgroundColor": ACCENT_SOFT, "borderRadius": f"{RADIUS_BUTTON}px"}}>
                <div style={{"color": INK, "fontWeight": "600", "marginBottom": f"{SP_2}px"}}>{"Clear " + order.table + "? Guests will no longer see these orders."}</div>
                <div style={{"display": "flex", "gap": f"{SP_1}px"}}>
                    <button style={button_style(False) | {"flex": "1"}} disabled={clearing} onClick={lambda { onKeep(); }}>Keep</button>
                    <button style={button_style() | {"flex": "1", "opacity": "0.5" if clearing else "1"}} disabled={clearing} onClick={lambda { onClear(order.table_code); }}>{"Clearing..." if clearing else "Yes, clear"}</button>
                </div>
            </div>
        }}
    </div>
}

def:pub OrderColumn(
    title: str, orders: list[OrderView], accent: str, soft: str, busy: str, onMove: any,
    clearIds: list[str], confirmCode: str, clearing: bool, onAskClear: any, onKeep: any, onClear: any
) -> JsxElement {
    <div>
        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "marginBottom": f"{SP_2}px"}}>
            <h2 style={{"margin": "0", "fontSize": "20px", "color": INK}}>{title}</h2>
            <span style={pill_style(accent, soft) | {"fontWeight": "600"}}>{len(orders)}</span>
        </div>
        {for o in orders {
            <OrderCard
                key={o.id} order={o} accent={accent} working={busy == o.id} onMove={onMove}
                clearMode={("" if o.id not in clearIds else ("confirm" if confirmCode == o.table_code else "ask"))}
                clearing={clearing} onAskClear={onAskClear} onKeep={onKeep} onClear={onClear}
            />
        }}
    </div>
}

def:pub SoldOutPanel(sections: list[SectionView], busy: str, onToggle: any) -> JsxElement {
    <div style={card_style() | {"padding": f"{SP_3}px {SP_4}px"}}>
        <h2 style={{"margin": f"0 0 {SP_1}px", "color": INK, "fontSize": "20px"}}>Sold-out dishes</h2>
        <p style={{"margin": f"0 0 {SP_3}px", "color": MUTED}}>Switch a dish on when it runs out. Guests see it greyed out and cannot order it.</p>
        {for sec in sections {
            <div key={sec.name}>
                <h3 style={{"color": MUTED, "fontSize": "14px", "textTransform": "uppercase", "letterSpacing": "0.08em", "margin": f"{SP_3}px 0 {SP_1}px"}}>{sec.name}</h3>
                {for d in sec.dishes {
                    <div key={d.id} style={{"display": "flex", "alignItems": "center", "justifyContent": "space-between", "padding": f"{SP_1}px 0", "borderBottom": f"1px solid {LINE}"}}>
                        <div>
                            <span style={{"color": INK, "opacity": "0.55" if d.sold_out else "1"}}>{d.name}</span>
                            <span style={mono_style() | {"color": MUTED, "marginLeft": f"{SP_2}px", "fontSize": "14px"}}>{money(d.price)}</span>
                        </div>
                        <button
                            role="switch"
                            aria-checked={d.sold_out}
                            aria-label={"Sold out: " + d.name}
                            disabled={busy == d.id}
                            onClick={lambda { onToggle(d.id, not d.sold_out); }}
                            style={{
                                "minHeight": "44px", "minWidth": "120px", "padding": f"0 {SP_3}px", "borderRadius": f"{RADIUS_BUTTON}px",
                                "border": f"1px solid {LINE}", "fontFamily": FONT_TEXT, "fontSize": "15px", "fontWeight": "600", "cursor": "pointer",
                                "backgroundColor": ALLERGY_BG if d.sold_out else ACCENT_SOFT,
                                "color": ALLERGY_FG if d.sold_out else ACCENT
                            }}
                        >{"Sold out" if d.sold_out else "Available"}</button>
                    </div>
                }}
            </div>
        }}
    </div>
}
