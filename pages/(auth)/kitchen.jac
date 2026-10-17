"""Kitchen board page (K-01, K-02). Manager login required. Refreshes every 3 s; keeps content on screen."""

import from "react" { useEffect }
import from "@jac/runtime" { Link }
import from ...core.kitchen { kitchen_orders, set_order_status, kitchen_dishes, set_sold_out, KitchenBoard, SoldOutBoard, KitchenResult }
import from ...core.menu { SectionView }
import from ...core.orders { OrderView }
import from ...core.theme {
    page_style, card_style, pill_style, GROUND, INK, MUTED, ACCENT, ACCENT_SOFT, SP_3, SP_4,
    WARN_FG, WARN_BG, INFO_FG, INFO_BG, VEG_FG, VEG_BG, ALLERGY_FG, ALLERGY_BG
}
import from ...ui.kitchen { KitchenHeader, OrderColumn, SoldOutPanel }

def:pub KitchenPage -> JsxPage {
    has orders: list[OrderView] = [],
        sections: list[SectionView] = [],
        restaurant: str = "",
        loaded: bool = False,
        blocked: str = "",
        failed: bool = False,
        show_dishes: bool = False,
        busy: str = "",
        message: str = "";

    async def refresh {
        board: KitchenBoard | None = None;
        menu: SoldOutBoard | None = None;
        try {
            board = await kitchen_orders();
            if board.ok {
                orders = board.orders;
                restaurant = board.restaurant;
                blocked = "";
                if show_dishes {
                    menu = await kitchen_dishes();
                    if menu.ok {
                        sections = menu.sections;
                    }
                }
            } else {
                blocked = board.message;
            }
            failed = False;
            loaded = True;
        } except Exception {
            failed = True;
        }
    }

    async def move(order_id: str, new_status: str) {
        result: KitchenResult | None = None;
        if busy != "" {
            return;
        }
        busy = order_id;
        message = "";
        for o in orders {
            if o.id == order_id {
                o.status = new_status;
            }
        }
        orders = [o for o in orders];
        try {
            result = await set_order_status(order_id, new_status);
            if not result.ok {
                message = result.message;
            }
        } except Exception {
            message = "We couldn't update that order. Please try again.";
        }
        await refresh();
        busy = "";
    }

    async def toggle_dish(dish_id: str, value: bool) {
        result: KitchenResult | None = None;
        if busy != "" {
            return;
        }
        busy = dish_id;
        message = "";
        for s in sections {
            for d in s.dishes {
                if d.id == dish_id {
                    d.sold_out = value;
                }
            }
        }
        sections = [s for s in sections];
        try {
            result = await set_sold_out(dish_id, value);
            if not result.ok {
                message = result.message;
            }
        } except Exception {
            message = "We couldn't update that dish. Please try again.";
        }
        await refresh();
        busy = "";
    }

    def toggle_view {
        show_dishes = not show_dishes;
    }

    useEffect(lambda {
        refresh();
        timer = setInterval(lambda { refresh(); }, 3000);
        return lambda { clearInterval(timer); };
    }, [show_dishes]);

    if blocked != "" {
        return <main style={page_style() | {"maxWidth": "560px"}}>
            <div style={card_style() | {"textAlign": "center"}}>
                <span style={pill_style(ACCENT, ACCENT_SOFT)}>Kitchen board</span>
                <h1 style={{"color": INK, "fontSize": "28px", "margin": "16px 0 8px"}}>{blocked}</h1>
                <p style={{"color": MUTED, "margin": "0 0 24px"}}>The kitchen board will work as soon as your restaurant is ready.</p>
                <Link to="/dashboard">Back to the dashboard</Link>
            </div>
        </main>;
    }

    new_orders = [o for o in orders if o.status == "sent"];
    preparing = [o for o in orders if o.status == "preparing"];
    ready = [o for o in orders if o.status == "ready"];

    return <main style={{"minHeight": "100vh", "backgroundColor": GROUND}}>
        <KitchenHeader restaurant={restaurant} showDishes={show_dishes} onToggle={toggle_view}/>
        <div style={{"padding": f"{SP_4}px"}}>
            {if failed {
                <p style={pill_style(WARN_FG, WARN_BG) | {"display": "block", "marginBottom": f"{SP_3}px"}}>We couldn't reach the server. Trying again...</p>
            }}
            {if message != "" {
                <p style={pill_style(ALLERGY_FG, ALLERGY_BG) | {"display": "block", "marginBottom": f"{SP_3}px"}}>{message}</p>
            }}
            {if not loaded {
                <p style={{"color": MUTED}}>Loading the board...</p>
            } elif show_dishes {
                <SoldOutPanel sections={sections} busy={busy} onToggle={toggle_dish}/>
            } else {
                <div style={{"display": "grid", "gridTemplateColumns": "repeat(3, minmax(0, 1fr))", "gap": f"{SP_4}px", "alignItems": "start"}}>
                    <OrderColumn title="New" orders={new_orders} accent={WARN_FG} soft={WARN_BG} busy={busy} onMove={move}/>
                    <OrderColumn title="Preparing" orders={preparing} accent={INFO_FG} soft={INFO_BG} busy={busy} onMove={move}/>
                    <OrderColumn title="Ready" orders={ready} accent={VEG_FG} soft={VEG_BG} busy={busy} onMove={move}/>
                </div>
            }}
        </div>
    </main>;
}
