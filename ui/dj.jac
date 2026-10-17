"""Guest Music screen (G-05), like docs/mockups/4-guest-ai-dj.png. Live singer mode.
Stays mounted while the guest looks at the menu, so what they typed survives the 3-second refresh.
The AI only suggests: nothing is sent to the singer until the guest taps "Send to singer"."""

import from ..core.dj { ask_dj, DjReply }
import from ..core.dj_agent { SongPick }
import from ..core.music { send_song_request, RequestResult, RequestView }
import from ..core.theme {
    TAP_HEIGHT,
    button_style, card_style, pill_style, mono_style,
    INK, MUTED, BODY, GROUND, SURFACE, LINE, ACCENT, ACCENT_SOFT, FONT_TEXT, WARN_FG, WARN_BG, VEG_FG, VEG_BG,
    RADIUS_CARD, RADIUS_BUTTON, SP_1, SP_2, SP_3, SP_4,
    FS_2XL, FS_LG, FS_MD, FS_SM, FS_XL, FS_XS
}

glob MAX_WISH = 120,
     MAX_SONG = 80,
     MAX_WAITING = 2,
     BUSY = "The AI DJ is busy right now. You can type a song yourself.",
     STATUS_LOOK: dict[str, list[str]] = {
         "pending": ["Waiting", WARN_FG, WARN_BG],
         "accepted": ["Accepted", ACCENT, ACCENT_SOFT],
         "skipped": ["Skipped", MUTED, GROUND]
     };

def input_style() -> dict[str, str] {
    return {
        "width": "100%", "boxSizing": "border-box", "minHeight": "52px", "padding": f"0 {SP_3}px",
        "border": f"1px solid {LINE}", "borderRadius": f"{RADIUS_BUTTON}px", "fontFamily": FONT_TEXT,
        "fontSize": f"{FS_LG}px", "color": INK, "backgroundColor": SURFACE
    };
}

def:pub RequestRow(r: RequestView) -> JsxElement {
    look = STATUS_LOOK.get(r.status, STATUS_LOOK["pending"]);
    <div style={card_style() | {"padding": f"{SP_2}px {SP_3}px", "marginBottom": f"{SP_2}px", "display": "flex", "justifyContent": "space-between", "alignItems": "center", "gap": f"{SP_2}px"}}>
        <div style={{"minWidth": "0"}}>
            <div style={{"color": INK, "fontWeight": "600"}}>{r.song}</div>
            <div style={{"color": MUTED, "fontSize": f"{FS_SM}px"}}>{r.artist}</div>
        </div>
        <span style={pill_style(look[1], look[2]) | {"fontWeight": "600"}}>{look[0]}</span>
    </div>
}

"""Type a song yourself. Works without the AI."""
def:pub ManualRequest(working: bool, full: bool, onSend: any) -> JsxElement {
    has song: str = "",
        artist: str = "";
    async def submit {
        sent: bool = False;
        sent = await onSend(song, artist);
        if sent {
            song = "";
            artist = "";
        }
    }
    <form onSubmit={lambda (e: FormEvent) { e.preventDefault(); submit(); }} style={card_style() | {"padding": f"{SP_3}px", "marginTop": f"{SP_3}px"}}>
        <div style={{"color": INK, "fontWeight": "700", "marginBottom": f"{SP_2}px"}}>Type a song yourself</div>
        <input aria-label="Song title" placeholder="Song title" maxLength={MAX_SONG} value={song} disabled={working} style={input_style() | {"marginBottom": f"{SP_2}px"}} onChange={lambda (e: ChangeEvent) { song = e.target.value; }}/>
        <input aria-label="Artist" placeholder="Artist" maxLength={MAX_SONG} value={artist} disabled={working} style={input_style() | {"marginBottom": f"{SP_2}px"}} onChange={lambda (e: ChangeEvent) { artist = e.target.value; }}/>
        <button type="submit" disabled={working or full or song.strip() == ""} style={button_style() | {"width": "100%", "backgroundColor": INK, "opacity": "0.5" if (working or full or song.strip() == "") else "1"}}>Send to singer</button>
    </form>
}

def:pub PickCard(pick: SongPick, steps: list[str], busy: bool, full: bool, sending: bool, onAnother: any, onSend: any) -> JsxElement {
    <div style={card_style() | {"padding": f"{SP_3}px", "marginTop": f"{SP_3}px", "opacity": "0.6" if busy else "1"}}>
        <div style={{"color": ACCENT, "fontSize": f"{FS_SM}px", "fontWeight": "700", "letterSpacing": "0.08em"}}>REQUEST FOR THE SINGER</div>
        <div style={{"color": INK, "fontSize": f"{FS_2XL}px", "fontWeight": "700", "margin": f"{SP_1}px 0"}}>{pick.song}</div>
        <div style={{"color": MUTED}}>{pick.artist}</div>
        {if pick.message != "" {
            <div style={{"color": BODY, "margin": f"{SP_2}px 0"}}>{"Message: \"" + pick.message + "\""}</div>
        }}
        <div style={{"display": "flex", "gap": f"{SP_2}px", "marginTop": f"{SP_2}px"}}>
            <button style={button_style(False) | {"flex": "1", "opacity": "0.5" if busy else "1"}} disabled={busy} onClick={lambda { onAnother(); }}>Try another</button>
            <button style={button_style() | {"flex": "1", "backgroundColor": INK, "opacity": "0.5" if (busy or full) else "1"}} disabled={busy or full} onClick={lambda { onSend(); }}>{"Sending..." if sending else "Send to singer"}</button>
        </div>
        <div style={{"marginTop": f"{SP_3}px", "borderTop": f"1px solid {LINE}", "paddingTop": f"{SP_2}px"}}>
            <div style={{"color": ACCENT, "fontWeight": "700", "fontSize": f"{FS_SM}px"}}>What I checked</div>
            {for (i, s) in enumerate(steps) {
                <div key={str(i)} style={mono_style() | {"color": BODY, "fontSize": f"{FS_SM}px", "padding": "2px 0"}}>{"✓ " + s}</div>
            }}
        </div>
    </div>
}

def:pub DjScreen(code: str, table: str, requests: list[RequestView], onBack: any, onSent: any) -> JsxElement {
    has wish: str = "",
        pick: SongPick | None = None,
        steps: list[str] = [],
        shown: list[str] = [],
        working: bool = False,
        sending: bool = False,
        manual: bool = False,
        error: str = "",
        notice: str = "";

    """Ask the AI DJ. another=True keeps the wish and sends the titles already shown, so it picks a different song."""
    async def ask(another: bool) {
        reply: DjReply | None = None;
        text = wish.strip();
        if working or sending or text == "" {
            return;
        }
        working = True;
        error = "";
        notice = "";
        titles = shown if another else [];
        try {
            reply = await ask_dj(code, text, titles);
            if reply.ok {
                pick = reply.pick[0];
                steps = reply.steps;
                shown = (titles + [reply.pick[0].song])[-5:];
                manual = False;
            } else {
                error = reply.message;
                manual = "busy right now" in reply.message;
            }
        } except Exception {
            error = BUSY;
            manual = True;
        }
        working = False;
    }

    """Send a request to the singer. Returns True if it was sent."""
    async def send_request(song: str, artist: str, message: str) -> bool {
        r: RequestResult | None = None;
        if sending {
            return False;
        }
        sending = True;
        error = "";
        notice = "";
        sent = False;
        try {
            r = await send_song_request(code, song, artist, message, wish.strip());
            if r.ok {
                sent = True;
                notice = r.message;
                pick = None;
                steps = [];
                onSent();
            } else {
                error = r.message;
            }
        } except Exception {
            error = "We couldn't send your request. Please try again.";
        }
        sending = False;
        return sent;
    }

    async def send_pick {
        sent: bool = False;
        if pick is not None {
            sent = await send_request(pick.song, pick.artist, pick.message);
        }
    }

    async def send_manual(song: str, artist: str) -> bool {
        ok: bool = False;
        ok = await send_request(song, artist, "");
        return ok;
    }

    waiting = len([r for r in requests if r.status == "pending"]);
    full = waiting >= MAX_WAITING;
    busy = working or sending;
    return <div style={{"maxWidth": "480px", "margin": "0 auto", "minHeight": "100vh", "backgroundColor": GROUND, "fontFamily": FONT_TEXT}}>
        <div style={{"display": "flex", "alignItems": "center", "gap": f"{SP_3}px", "padding": f"{SP_3}px", "backgroundColor": SURFACE, "borderBottom": f"1px solid {LINE}"}}>
            <button aria-label="Back to the menu" onClick={lambda { onBack(); }} style={button_style(False) | {"width": f"{TAP_HEIGHT}px", "padding": "0", "fontSize": f"{FS_XL}px"}}>←</button>
            <div>
                <div style={{"color": INK, "fontSize": f"{FS_XL}px", "fontWeight": "700"}}>Music</div>
                <div style={{"color": MUTED, "fontSize": f"{FS_MD}px"}}>{table + " · AI DJ"}</div>
            </div>
        </div>
        <div style={{"padding": f"{SP_3}px"}}>
            <div style={card_style() | {"padding": f"{SP_3}px"}}>
                <div style={{"color": INK, "fontSize": f"{FS_XL}px", "fontWeight": "700", "marginBottom": f"{SP_2}px"}}>What would you like to hear?</div>
                <input
                    aria-label="What would you like to hear?" placeholder="For example: something romantic, old Sinhala"
                    maxLength={MAX_WISH} value={wish} disabled={busy} style={input_style()}
                    onChange={lambda (e: ChangeEvent) { wish = e.target.value; }}
                />
                <div style={{"textAlign": "right", "fontSize": f"{FS_XS}px", "color": MUTED, "margin": f"4px 0 {SP_2}px"}}>{str(len(wish)) + " / " + str(MAX_WISH)}</div>
                <button
                    style={button_style() | {"width": "100%", "minHeight": "56px", "fontSize": f"{FS_LG}px", "opacity": "0.5" if (busy or wish.strip() == "") else "1"}}
                    disabled={busy or wish.strip() == ""} onClick={lambda { ask(False); }}
                >{"Asking the DJ..." if working else "Ask the AI DJ"}</button>
            </div>
            {if error != "" {
                <p style={pill_style(WARN_FG, WARN_BG) | {"display": "block", "margin": f"{SP_3}px 0 0"}}>{error}</p>
            }}
            {if notice != "" {
                <p style={pill_style(VEG_FG, VEG_BG) | {"display": "block", "margin": f"{SP_3}px 0 0"}}>{notice}</p>
            }}
            {if pick is not None {
                <PickCard pick={pick} steps={steps} busy={busy} full={full} sending={sending} onAnother={lambda { ask(True); }} onSend={send_pick}/>
            }}
            {if manual {
                <ManualRequest working={busy} full={full} onSend={send_manual}/>
            }}
            <div style={{"color": MUTED, "fontSize": f"{FS_SM}px", "fontWeight": "700", "letterSpacing": "0.08em", "margin": f"{SP_4}px 0 {SP_2}px"}}>YOUR REQUESTS</div>
            {if len(requests) == 0 {
                <div style={{"color": MUTED}}>Nothing sent yet.</div>
            }}
            {for r in requests {
                <RequestRow key={r.id} r={r}/>
            }}
            <div style={{"color": MUTED, "fontSize": f"{FS_SM}px", "marginTop": f"{SP_2}px"}}>{"Up to " + str(MAX_WAITING) + " requests waiting per table."}</div>
        </div>
    </div>;
}
