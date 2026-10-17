"""The compact order status strip and its floating cards (moved out of the table page; behaviour unchanged).
Opens the cards after an order is sent or a status changes, closes them after 5 s or when the page scrolls away,
and a tap on the strip opens or closes them at any time."""

import from "react" { useEffect }
import from ..core.orders { OrderView }
import from .cart { StatusStrip, StatusPanel }

# Scroll events caused by the page itself (the strip appearing) must not close the panel.
glob SCROLL_GUARD: dict[str, float] = {"until": 0.0};

def:pub OrderStatusPart(orders: list[OrderView], loaded: bool) -> JsxElement {
    has seen_sig: str = "",
        seen_ready: bool = False,
        panel_mode: str = "closed",
        panel_stamp: int = 0;

    def toggle_panel {
        panel_mode = "closed" if panel_mode != "closed" else "pinned";
    }

    orders_sig = "|".join([o.id + ":" + o.status for o in orders]);

    # Open the cards after an order is sent or when a status changes (not for orders already there on arrival).
    can with [orders_sig] entry {
        if loaded {
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

    <>
        {if len(orders) > 0 {
            <StatusStrip orders={orders} open={panel_mode != "closed"} onToggle={toggle_panel}/>
        }}
        {if panel_mode != "closed" and len(orders) > 0 {
            <StatusPanel orders={orders}/>
        }}
    </>
}
