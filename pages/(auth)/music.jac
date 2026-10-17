"""Music screen page (MU-01) for the singer and staff. Manager login required. Refreshes every 3 s and keeps the list on screen."""

import from "react" { useEffect }
import from "@jac/runtime" { Link }
import from ...core.music { music_queue, answer_request, QueueView, QueueItem, RequestResult }
import from ...core.theme { page_style, card_style, pill_style, INK, MUTED, GROUND, WARN_FG, WARN_BG, SP_3, SP_4 }
import from ...ui.music_screen { MusicHeader, RequestCard, ClosedNotice }

def:pub MusicPage -> JsxPage {
    has queue: QueueView | None = None,
        items: list[QueueItem] = [],
        loaded: bool = False,
        failed: bool = False,
        busy: str = "",
        message: str = "";

    async def refresh {
        fresh: QueueView | None = None;
        try {
            fresh = await music_queue();
            queue = fresh;
            items = fresh.requests;
            failed = False;
        } except Exception {
            failed = True;
        }
        loaded = True;
    }

    """Answer one request. The card leaves the list at once; the next refresh confirms it."""
    async def answer(item_id: str, accept: bool) {
        r: RequestResult | None = None;
        if busy != "" or queue is None {
            return;
        }
        busy = item_id;
        message = "";
        items = [q for q in items if q.id != item_id];
        try {
            r = await answer_request(item_id, accept);
            if not r.ok {
                message = r.message;
            }
        } except Exception {
            message = "We couldn't save that answer. Please try again.";
        }
        await refresh();
        busy = "";
    }

    useEffect(lambda {
        refresh();
        timer = setInterval(lambda { refresh(); }, 3000);
        return lambda { clearInterval(timer); };
    }, []);

    if not loaded {
        return <main style={{"minHeight": "100vh", "backgroundColor": GROUND}}><MusicHeader restaurant="" modeLabel="..."/><p style={{"color": MUTED, "padding": f"{SP_4}px"}}>Loading the music screen...</p></main>;
    }
    if queue is None or not queue.ok {
        return <main style={{"minHeight": "100vh", "backgroundColor": GROUND}}>
            <MusicHeader restaurant="" modeLabel="Off"/>
            <div style={page_style() | {"maxWidth": "560px"}}>
                <div style={card_style() | {"textAlign": "center"}}>
                    <h1 style={{"color": INK, "fontSize": "28px", "margin": "0 0 8px"}}>{queue.message if queue is not None and queue.message != "" else "We couldn't load the music screen."}</h1>
                    <p style={{"color": MUTED, "margin": "0 0 24px"}}>The music screen works as soon as your restaurant is ready.</p>
                    <Link to="/dashboard">Back to the dashboard</Link>
                </div>
            </div>
        </main>;
    }
    open_mode = queue.mode in ["singer", "both"];
    return <main style={{"minHeight": "100vh", "backgroundColor": GROUND}}>
        <MusicHeader restaurant={queue.restaurant} modeLabel={queue.mode_label}/>
        <div style={{"padding": f"{SP_4}px", "maxWidth": "760px"}}>
            {if failed {
                <p style={pill_style(WARN_FG, WARN_BG) | {"display": "block", "marginBottom": f"{SP_3}px"}}>We couldn't reach the server. Trying again...</p>
            }}
            {if message != "" {
                <p style={pill_style(WARN_FG, WARN_BG) | {"display": "block", "marginBottom": f"{SP_3}px"}}>{message}</p>
            }}
            {if not open_mode {
                <ClosedNotice modeLabel={queue.mode_label}/>
            }}
            <div style={{"color": MUTED, "fontSize": "14px", "fontWeight": "700", "letterSpacing": "0.08em", "marginBottom": f"{SP_3}px"}}>LIVE SINGER · REQUESTS (OLDEST FIRST)</div>
            {if len(items) == 0 {
                <p style={{"color": MUTED}}>No requests waiting. New requests appear here by themselves.</p>
            }}
            {for item in items {
                <RequestCard key={item.id} item={item} working={busy == item.id} onAccept={lambda { answer(item.id, True); }} onSkip={lambda { answer(item.id, False); }}/>
            }}
        </div>
    </main>;
}
