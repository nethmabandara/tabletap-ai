"""Manager dashboard (M-01, M-05). Opening it claims the Wet Water demo for the FIRST manager (S-01).
A manager with no restaurant sees "Create your restaurant"; otherwise the real status and the buttons."""

import from "@jac/runtime" { jacLogout, useNavigate }
import from ...core.menu { claim_demo_restaurant }
import from ...core.restaurants { create_restaurant, restaurant_status, CreateResult, RestaurantStatus }
import from ...core.theme {
    page_style, card_style, button_style, pill_style, mono_style,
    INK, MUTED, ACCENT, ACCENT_SOFT, WARN_FG, WARN_BG, VEG_FG, VEG_BG
}
import from ...ui.onboarding { CreateRestaurantForm }

def:pub Dashboard -> JsxPage {
    has loaded: bool = False,
        failed: bool = False,
        status: RestaurantStatus | None = None,
        creating: bool = False,
        create_message: str = "";
    nav = useNavigate();

    async def load_status {
        s: RestaurantStatus | None = None;
        s = await restaurant_status();
        status = s;
    }

    async can with entry {
        try {
            await claim_demo_restaurant();
            await load_status();
        } except Exception {
            failed = True;
        }
        loaded = True;
    }

    async def create(name: str, tables: str) {
        r: CreateResult | None = None;
        if creating {
            return;
        }
        creating = True;
        create_message = "";
        num: any = Number;
        count: any = num(tables);
        try {
            r = await create_restaurant(name, int(count) if num.isInteger(count) else 0);
            if r.ok {
                nav("/menu-setup");
            } else {
                create_message = r.message;
                await load_status();
            }
        } except Exception {
            create_message = "We couldn't create your restaurant. Please try again.";
        }
        creating = False;
    }

    def log_out {
        jacLogout();
        nav("/login");
    }

    has_restaurant = status is not None and status.has_restaurant;
    st_name = status.name if status is not None else "";
    st_line = status.status_line if status is not None else "";
    st_draft = status.draft_line if status is not None else "";
    st_pub = status.published if status is not None else False;
    st_tables = status.table_count if status is not None else 0;
    return <main style={page_style() | {"maxWidth": "640px"}}>
        <div style={card_style()}>
            <span style={pill_style(ACCENT, ACCENT_SOFT)}>Manager dashboard</span>
            {if failed {
                <h1 style={{"color": INK, "fontSize": "28px", "margin": "16px 0 8px"}}>We couldn't load your restaurant.</h1>
                <p style={{"color": MUTED}}>Please refresh the page.</p>
            } elif not loaded {
                <h1 style={{"color": INK, "fontSize": "28px", "margin": "16px 0 8px"}}>Opening your dashboard...</h1>
            } elif not has_restaurant {
                <div style={{"marginTop": "16px"}}>
                    <CreateRestaurantForm working={creating} message={create_message} onCreate={create}/>
                </div>
            } else {
                <h1 style={{"color": INK, "fontSize": "28px", "margin": "16px 0 8px"}}>{st_name}</h1>
                <p style={pill_style(VEG_FG if st_pub else WARN_FG, VEG_BG if st_pub else WARN_BG) | {"display": "block", "margin": "0 0 8px", "fontWeight": "600"}}>{st_line}</p>
                if st_draft != "" {
                    <p style={{"color": MUTED, "margin": "0 0 8px"}}>{st_draft}</p>
                }
                <p style={mono_style() | {"color": MUTED, "margin": "0 0 24px", "fontSize": "14px"}}>{str(st_tables) + (" table" if st_tables == 1 else " tables")}</p>
                if create_message != "" {
                    <p style={pill_style(WARN_FG, WARN_BG) | {"display": "block", "margin": "0 0 16px"}}>{create_message}</p>
                }
                <div style={{"display": "flex", "gap": "12px", "flexWrap": "wrap"}}>
                    <button style={button_style()} onClick={lambda { nav("/menu-setup"); }}>Menu setup</button>
                    <button style={button_style()} onClick={lambda { nav("/tables"); }}>Tables & links</button>
                    <button style={button_style()} onClick={lambda { nav("/kitchen"); }}>Kitchen board</button>
                    <button style={button_style()} onClick={lambda { nav("/music"); }}>Music screen</button>
                    <button style={button_style(False)} onClick={lambda { log_out(); }}>Log out</button>
                </div>
            }}
        </div>
        {if loaded and not has_restaurant and not failed {
            <div style={{"textAlign": "center", "marginTop": "16px"}}>
                <button style={button_style(False)} onClick={lambda { log_out(); }}>Log out</button>
            </div>
        }}
    </main>;
}
