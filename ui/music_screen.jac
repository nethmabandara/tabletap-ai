"""Music screen pieces for the singer and music staff (MU-01), like docs/mockups/6-music-screen.png.
Live singer requests only for now: oldest first, with Accept and Skip."""

import from ..core.music { QueueItem }
import from ..core.theme {
    button_style, card_style, pill_style, mono_style,
    INK, MUTED, BODY, SURFACE, LINE, ACCENT, ACCENT_SOFT, FONT_TEXT, WARN_FG, WARN_BG,
    RADIUS_CARD, RADIUS_BUTTON, SP_1, SP_2, SP_3, SP_4
}

def:pub MusicHeader(restaurant: str, modeLabel: str) -> JsxElement {
    <div style={{"backgroundColor": INK, "color": SURFACE, "padding": f"{SP_3}px {SP_4}px", "display": "flex", "justifyContent": "space-between", "alignItems": "center", "flexWrap": "wrap", "gap": f"{SP_2}px"}}>
        <div>
            <h1 style={{"margin": "0", "fontSize": "28px"}}>Music screen</h1>
            <div style={{"color": LINE}}>{(restaurant + " · " if restaurant else "") + "for the singer and music staff"}</div>
        </div>
        <span style={pill_style(SURFACE, ACCENT) | {"fontWeight": "700", "padding": "8px 16px", "fontSize": "15px"}}>{"Mode: " + modeLabel}</span>
    </div>
}

def:pub RequestCard(item: QueueItem, working: bool, onAccept: any, onSkip: any) -> JsxElement {
    <div style={card_style() | {"padding": f"{SP_3}px {SP_4}px", "marginBottom": f"{SP_3}px"}}>
        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "baseline", "gap": f"{SP_2}px"}}>
            <span style={{"color": INK, "fontSize": "26px", "fontWeight": "700"}}>{item.song}</span>
            <span style={{"color": INK, "fontSize": "20px", "fontWeight": "700", "whiteSpace": "nowrap"}}>{item.table}</span>
        </div>
        <div style={{"color": MUTED, "fontSize": "17px"}}>{item.artist}</div>
        <div style={mono_style() | {"color": MUTED, "fontSize": "13px", "marginTop": "2px"}}>{("just now" if item.minutes_ago < 1 else str(item.minutes_ago) + " min ago")}</div>
        {if item.message != "" {
            <div style={{"color": INK, "fontSize": "18px", "margin": f"{SP_2}px 0 0"}}>{"\"" + item.message + "\""}</div>
        }}
        {if item.wish != "" {
            <div style={{"color": ACCENT, "margin": f"{SP_1}px 0 0"}}>{"Guest asked: \"" + item.wish + "\""}</div>
        }}
        <div style={{"display": "flex", "gap": f"{SP_2}px", "marginTop": f"{SP_3}px"}}>
            <button style={button_style(False) | {"flex": "1", "minHeight": "56px", "fontSize": "18px", "opacity": "0.5" if working else "1"}} disabled={working} onClick={lambda { onSkip(); }}>Skip</button>
            <button style={button_style() | {"flex": "2", "minHeight": "56px", "fontSize": "18px", "opacity": "0.5" if working else "1"}} disabled={working} onClick={lambda { onAccept(); }}>Accept</button>
        </div>
    </div>
}

def:pub ClosedNotice(modeLabel: str) -> JsxElement {
    <p style={pill_style(WARN_FG, WARN_BG) | {"display": "block", "margin": f"0 0 {SP_3}px"}}>
        {"Guests can't send song requests right now (mode: " + modeLabel + "). Requests appear here when the mode is Live singer."}
    </p>
}
