"""Menu setup page (M-02, M-03). Manager login required.
This page owns only the photo upload. The draft table is its own component with its own state, so the
1-second photo progress poll (which only updates `progress`) can never wipe the table or anything typed in it."""

import from "react" { useEffect }
import from "@jac/runtime" { Link }
import from ...core.menu { my_restaurant_name }
import from ...core.menu_setup { menu_read_progress, ProgressView }
import from ...core.theme { page_style, card_style, INK, MUTED, GROUND, SP_4 }
import from ...ui.menu_setup { SetupHeader, UploadCard, StepsCard, post_photos, check_picked }
import from ...ui.draft_panel { DraftPanel }

def:pub MenuSetupPage -> JsxPage {
    has restaurant: str = "",
        loaded: bool = False,
        steps: list[str] = [],
        files: list[any] = [],
        input_key: int = 0,
        reading: bool = False,
        progress: ProgressView | None = None,
        final_status: list[str] = [],
        pick_error: str = "",
        read_message: str = "",
        reload: int = 0;

    async can with entry {
        try {
            restaurant = await my_restaurant_name();
        } except Exception {
            console.error("could not load the restaurant name");
        }
        loaded = True;
    }

    async def poll {
        p: ProgressView | None = None;
        try {
            p = await menu_read_progress(int(Date.now()));
            progress = p;
        } except Exception {
            console.error("progress poll failed");
        }
    }

    useEffect(lambda {
        timer = setInterval(lambda { poll(); }, 1000) if reading else None;
        return lambda { if timer { clearInterval(timer); } };
    }, [reading]);

    def pick_files(e: ChangeEvent) {
        picked: list[any] = Array.from(e.target.files);
        problem = check_picked(picked);
        final_status = [];
        read_message = "";
        if problem != "" {
            files = [];
            pick_error = problem;
            input_key = input_key + 1;
            return;
        }
        files = picked;
        pick_error = "";
    }

    async def read_menu {
        outcome: dict[str, any] = {};
        if reading or len(files) == 0 {
            return;
        }
        reading = True;
        read_message = "";
        progress = None;
        final_status = [];
        outcome = await post_photos(files);
        failed: list[int] = outcome["failed"];
        final_status = ["failed" if ((i + 1) in failed or not outcome["ok"]) else "done" for i in range(len(files))];
        read_message = outcome["message"];
        reading = False;
        if outcome["ok"] {
            reload = reload + 1;
        }
    }

    if not loaded {
        return <main style={{"minHeight": "100vh", "backgroundColor": GROUND}}><SetupHeader restaurant=""/><p style={{"color": MUTED, "padding": f"{SP_4}px"}}>Loading...</p></main>;
    }
    if restaurant == "" {
        return <main style={{"minHeight": "100vh", "backgroundColor": GROUND}}>
            <SetupHeader restaurant=""/>
            <div style={page_style() | {"maxWidth": "560px"}}>
                <div style={card_style() | {"textAlign": "center"}}>
                    <h1 style={{"color": INK, "fontSize": "28px", "margin": "0 0 8px"}}>Set up your restaurant first.</h1>
                    <p style={{"color": MUTED, "margin": "0 0 24px"}}>Menu setup will work as soon as your restaurant is ready.</p>
                    <Link to="/dashboard">Back to the dashboard</Link>
                </div>
            </div>
        </main>;
    }

    statuses: list[str] = [];
    for i in range(len(files)) {
        st = final_status[i] if i < len(final_status) else "";
        if reading {
            st = "reading";
            if progress is not None and progress.running {
                st = "done" if (i + 1) in progress.done else ("failed" if (i + 1) in progress.failed else "reading");
            }
        }
        statuses.append(st);
    }
    return <main style={{"minHeight": "100vh", "backgroundColor": GROUND}}>
        <SetupHeader restaurant={restaurant}/>
        <div style={{"display": "flex", "gap": f"{SP_4}px", "flexWrap": "wrap", "alignItems": "flex-start", "padding": f"{SP_4}px"}}>
            <div style={{"flex": "0 0 440px", "maxWidth": "100%"}}>
                <UploadCard names={[f.name for f in files]} statuses={statuses} reading={reading} input_key={input_key} error={pick_error} onPick={pick_files} onRead={read_menu}/>
                <StepsCard steps={steps}/>
            </div>
            <DraftPanel locked={reading} reload={reload} readError={read_message} onSteps={lambda (s: list[str]) { steps = s; }}/>
        </div>
    </main>;
}
