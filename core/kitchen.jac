"""Kitchen board (K-01, K-02). Every function first checks the caller manages the restaurant.

Each def:protect endpoint passes the caller's own restaurant to a *_for function.
The *_for function refuses with a friendly message (and changes nothing) when there is
no restaurant yet, or when the caller does not have a Manages edge to it.
"""

import from .models { Restaurant, Table, Section, Dish, Order, Manages, HasTable, HasSection, HasDish, Placed }
import from .menu { my_restaurant, all_dishes, section_views, SectionView }
import from .orders { OrderView, order_view, seconds_since }

glob NEXT_STATUS: dict[str, str] = {"sent": "preparing", "preparing": "ready"},
     READY_MINUTES = 60,
     SET_UP_FIRST = "Set up your restaurant first.",
     NOT_ALLOWED = "You're not allowed to do that.";

obj KitchenResult {
    has ok: bool,
        message: str = "";
}

obj KitchenBoard {
    has ok: bool,
        message: str = "",
        restaurant: str = "",
        orders: list[OrderView] = [];
}

obj SoldOutBoard {
    has ok: bool,
        message: str = "",
        sections: list[SectionView] = [];
}

"""Empty string if the caller may manage this restaurant, otherwise the friendly refusal."""
def refusal(rest: Restaurant | None) -> str {
    if rest is None {
        return SET_UP_FIRST;
    }
    if rest not in [root ->:Manages:-> [?:Restaurant]] {
        return NOT_ALLOWED;
    }
    return "";
}

"""Pairs of (order, table) for this restaurant's own tables only."""
def restaurant_orders(rest: Restaurant) -> list[tuple[Order, Table]] {
    pairs: list[tuple[Order, Table]] = [];
    for table in [rest ->:HasTable:-> [?:Table]] {
        for o in [table ->:Placed:-> [?:Order]] {
            pairs.append((o, table));
        }
    }
    return pairs;
}

def kitchen_orders_for(rest: Restaurant | None) -> KitchenBoard {
    problem = refusal(rest);
    if problem != "" or rest is None {
        return KitchenBoard(ok=False, message=problem);
    }
    shown = [
        (o, t) for (o, t) in restaurant_orders(rest)
        if o.status != "ready" or seconds_since(o.created_at) < READY_MINUTES * 60
    ];
    shown = sorted(shown, key=lambda (p: tuple[Order, Table]) { p[0].created_at; });
    return KitchenBoard(ok=True, restaurant=rest.name, orders=[order_view(o, t) for (o, t) in shown]);
}

def set_order_status_for(rest: Restaurant | None, order_id: str, new_status: str) -> KitchenResult {
    problem = refusal(rest);
    if problem != "" or rest is None {
        return KitchenResult(ok=False, message=problem);
    }
    for (o, t) in restaurant_orders(rest) {
        if jid(o) == order_id {
            if NEXT_STATUS.get(o.status, "") != new_status {
                return KitchenResult(ok=False, message="That order can only move forward one step at a time.");
            }
            o.status = new_status;
            return KitchenResult(ok=True);
        }
    }
    return KitchenResult(ok=False, message="We couldn't find that order.");
}

def kitchen_dishes_for(rest: Restaurant | None) -> SoldOutBoard {
    problem = refusal(rest);
    if problem != "" or rest is None {
        return SoldOutBoard(ok=False, message=problem);
    }
    return SoldOutBoard(ok=True, sections=section_views(rest));
}

def set_sold_out_for(rest: Restaurant | None, dish_id: str, value: bool) -> KitchenResult {
    problem = refusal(rest);
    if problem != "" or rest is None {
        return KitchenResult(ok=False, message=problem);
    }
    for d in all_dishes(rest) {
        if jid(d) == dish_id {
            d.sold_out = value;
            return KitchenResult(ok=True);
        }
    }
    return KitchenResult(ok=False, message="We couldn't find that dish.");
}

def:protect kitchen_orders -> KitchenBoard {
    return kitchen_orders_for(my_restaurant());
}

def:protect set_order_status(order_id: str, new_status: str) -> KitchenResult {
    return set_order_status_for(my_restaurant(), order_id, new_status);
}

def:protect kitchen_dishes -> SoldOutBoard {
    return kitchen_dishes_for(my_restaurant());
}

def:protect set_sold_out(dish_id: str, value: bool) -> KitchenResult {
    return set_sold_out_for(my_restaurant(), dish_id, value);
}
