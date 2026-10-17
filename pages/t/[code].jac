"""Guest table page (G-01, G-02, G-03). Calls only def:pub endpoints; refreshes every 3 s.
The cart lives here in state until the guest confirms "Send order"."""

import from "react" { useEffect }
import from "@jac/runtime" { useParams }
import from ...core.menu { get_menu, MenuView, DishView }
import from ...core.orders { place_order, table_orders, OrderLine, OrderView, PlaceResult }
import from ...core.theme { page_style, card_style, pill_style, INK, MUTED, ACCENT, ACCENT_SOFT, SURFACE, LINE, VEG_FG, VEG_BG, SP_3 }
import from ...ui.guest { MenuHeader, SectionChips, MenuList, WaiterBanner, section_id }
import from ...ui.cart { CartBar, OrderSheet, StatusStrip, StatusPanel }
import from ...ui.waiter { WaiterScreen }

# Scroll events caused by the page itself (the strip appearing) must not close the panel.
glob SCROLL_GUARD: dict[str, float] = {"until": 0.0};

def:pub TablePage -> JsxPage {
    has menu: MenuView | None = None,
        orders: list[OrderView] = [],
        failed: bool = False,
        active: str = "",
        cart: dict[str, int] = {},
        sheet_open: bool = False,
        sending: bool = False,
        note: str = "",
        message: str = "",
        notice: str = "",
        view: str = "menu",
        orders_loaded: bool = False,
        seen_sig: str = "",
        seen_ready: bool = False,
        panel_mode: str = "closed",
        panel_stamp: int = 0;
    params = useParams();
    code: str = params["code"];

    async def refresh {
        try {
            menu = await get_menu(code);
            orders = await table_orders(code);
            orders_loaded = True;
            failed = False;
        } except Exception {
            failed = True;
        }
    }

    def open_waiter {
        view = "waiter";
        window.scrollTo(0, 0);
    }

    def close_waiter {
        view = "menu";
    }

    async def waiter_sent(text: str) {
        notice = text;
        view = "menu";
        await refresh();
    }

    def pick(name: str) {
        active = name;
        el: any = document.getElementById(section_id(name));
        if el {
            el.scrollIntoView({"behavior": "smooth"});
        }
    }

    def add(dish_id: str) {
        current = cart.get(dish_id, 0);
        if current < 20 {
            updated = {k: v for (k, v) in cart.items()};
            updated[dish_id] = current + 1;
            cart = updated;
        }
        notice = "";
    }

    def remove(dish_id: str) {
        current = cart.get(dish_id, 0);
        if current <= 1 {
            cart = {k: v for (k, v) in cart.items() if k != dish_id};
        } else {
            updated = {k: v for (k, v) in cart.items()};
            updated[dish_id] = current - 1;
            cart = updated;
        }
    }

    def dishes_in_cart -> list[DishView] {
        if menu is None {
            return [];
        }
        return [d for s in menu.sections for d in s.dishes if cart.get(d.id, 0) > 0];
    }

    async def send {
        result: PlaceResult | None = None;
        if sending {
            return;
        }
        sending = True;
        message = "";
        try {
            items = [OrderLine(dish_id=d.id, qty=cart[d.id]) for d in dishes_in_cart()];
            result = await place_order(code, items, note);
            if result.ok {
                cart = {};
                note = "";
                sheet_open = False;
                notice = result.message;
                await refresh();
            } else {
                message = result.message;
            }
        } except Exception {
            message = "We couldn't send your order. Please try again.";
        }
        sending = False;
    }

    def toggle_panel {
        panel_mode = "closed" if panel_mode != "closed" else "pinned";
    }

    orders_sig = "|".join([o.id + ":" + o.status for o in orders]);

    # Open the cards after an order is sent or when a status changes (not for orders already there on arrival).
    can with [orders_sig] entry {
        if orders_loaded {
            if seen_ready and orders_sig != seen_sig and orders_sig != "" {
                SCROLL_GUARD["until"] = Date.now() + 700;
                panel_mode = "pinned" if panel_mode == "pinned" else "auto";
                panel_stamp = panel_stamp + 1;
            }
            seen_sig = orders_sig;
            seen_ready = True;
        }
    }

    # An automatically opened panel closes itself after 5 seconds.
    useEffect(lambda {
        timer = setTimeout(lambda { panel_mode = "closed"; }, 5000) if panel_mode == "auto" else None;
        return lambda { if timer { clearTimeout(timer); } };
    }, [panel_mode, panel_stamp]);

    # Scrolling away closes the panel.
    useEffect(lambda {
        on_scroll = lambda {
            if Date.now() > SCROLL_GUARD["until"] and window.scrollY > 24 {
                panel_mode = "closed";
            }
        };
        window.addEventListener("scroll", on_scroll);
        return lambda { window.removeEventListener("scroll", on_scroll); };
    }, []);

    useEffect(lambda {
        refresh();
        timer = setInterval(lambda { refresh(); }, 3000);
        return lambda { clearInterval(timer); };
    }, [code]);

    if menu is None {
        return <main style={page_style() | {"maxWidth": "480px"}}>
            <p style={{"color": MUTED, "textAlign": "center"}}>
                {"We couldn't load the menu. Trying again..." if failed else ""}
            </p>
        </main>;
    } elif menu.status != "ready" {
        return <main style={page_style() | {"maxWidth": "480px"}}>
            <div style={card_style() | {"textAlign": "center"}}>
                <span style={pill_style(ACCENT, ACCENT_SOFT)}>TableTap AI</span>
                <h1 style={{"color": INK, "fontSize": "28px", "margin": "16px 0 8px"}}>
                    {"Menu coming soon" if menu.status == "coming_soon" else "This table link isn't valid"}
                </h1>
                <p style={{"color": MUTED, "margin": "0"}}>
                    {"The restaurant is getting ready." if menu.status == "coming_soon" else "Please ask your waiter for the right link."}
                </p>
            </div>
        </main>;
    } else {
        lines = dishes_in_cart();
        count = sum([cart[d.id] for d in lines]);
        total = sum([cart[d.id] * d.price for d in lines]);
        return <div>
            <div style={{"display": "none" if view == "waiter" else "block"}}>
            <main style={{"maxWidth": "480px", "margin": "0 auto", "minHeight": "100vh"}}>
                <div style={{
                    "position": "sticky", "top": "0", "zIndex": "10", "backgroundColor": SURFACE,
                    "padding": f"{SP_3}px", "borderBottom": f"1px solid {LINE}"
                }}>
                    <MenuHeader restaurant={menu.restaurant} table={menu.table}/>
                    {if len(orders) > 0 {
                        <StatusStrip orders={orders} open={panel_mode != "closed"} onToggle={toggle_panel}/>
                    }}
                    <WaiterBanner onOpen={open_waiter}/>
                    <SectionChips sections={menu.sections} active={active if active else menu.sections[0].name} onPick={pick}/>
                    {if panel_mode != "closed" and len(orders) > 0 {
                        <StatusPanel orders={orders}/>
                    }}
                </div>
                <div style={{"padding": f"0 {SP_3}px 120px"}}>
                    {if notice != "" {
                        <p style={pill_style(VEG_FG, VEG_BG) | {"display": "block", "margin": f"{SP_3}px 0 0"}}>{notice}</p>
                    }}
                    <MenuList sections={menu.sections} cart={cart} onAdd={add} onRemove={remove}/>
                </div>
                {if count > 0 and not sheet_open {
                    <CartBar count={count} total={total} onOpen={lambda { sheet_open = True; message = ""; }}/>
                }}
                {if sheet_open {
                    <OrderSheet
                        lines={lines} cart={cart} total={total} note={note} sending={sending} message={message}
                        onNote={lambda (v: str) { note = v; }} onAdd={add} onRemove={remove}
                        onClose={lambda { sheet_open = False; }} onSend={send}
                    />
                }}
            </main>
            </div>
            <div style={{"display": "block" if view == "waiter" else "none"}}>
                <WaiterScreen code={code} table={menu.table} onBack={close_waiter} onSent={waiter_sent}/>
            </div>
        </div>;
    }
}
