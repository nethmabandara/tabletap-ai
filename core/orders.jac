"""Guest ordering (G-03): place_order and table_orders. Server-only graph code.

The phone sends dish ids and quantities only. Names, prices, sold-out checks and
the total are all worked out here, by code.
"""

import from datetime { datetime, timezone }
import from uuid { UUID }
import from jaclang { JacRuntime as Jac }
import from .models { Restaurant, Table, Dish, Order, OrderItem, Placed, Contains }
import from .menu { find_table, all_dishes }

glob MAX_QTY = 20,
     MAX_LINES = 30,
     MAX_NOTE = 200,
     DUPLICATE_SECONDS = 10;

obj OrderLine {
    has dish_id: str,
        qty: int;
}

obj PlaceResult {
    has ok: bool,
        message: str,
        order_id: str = "",
        total: int = 0;
}

obj OrderItemView {
    has name: str,
        qty: int,
        price: int;
}

"""An order as guests and the kitchen see it. minutes_ago is worked out on the server."""
obj OrderView {
    has id: str,
        table: str,
        status: str,
        allergy_note: str,
        minutes_ago: int,
        total: int,
        items: list[OrderItemView];
}

def refuse(message: str) -> PlaceResult {
    return PlaceResult(ok=False, message=message);
}

def now_iso -> str {
    return datetime.now(timezone.utc).isoformat();
}

def seconds_since(created_at: str) -> float {
    if created_at == "" {
        return 1000000.0;
    }
    return (datetime.now(timezone.utc) - datetime.fromisoformat(created_at)).total_seconds();
}

def order_items(order: Order) -> list[OrderItem] {
    return [order ->:Contains:-> [?:OrderItem]];
}

def order_view(order: Order, table: Table) -> OrderView {
    items = [OrderItemView(name=i.dish_name, qty=i.qty, price=i.price) for i in order_items(order)];
    total = sum([i.price * i.qty for i in items]);
    return OrderView(
        id=jid(order), table=table.label, status=order.status, allergy_note=order.allergy_note,
        minutes_ago=int(seconds_since(order.created_at) // 60), total=total, items=items
    );
}

"""Same dishes, quantities and note? Used to refuse a double tap within a few seconds."""
def same_order(order: Order, wanted: dict[str, int], note: str) -> bool {
    have: dict[str, int] = {};
    for i in order_items(order) {
        have[i.dish_name] = have.get(i.dish_name, 0) + i.qty;
    }
    return have == wanted and order.allergy_note == note;
}

"""Only the manager who owns the restaurant may change this record. Nobody else gets access."""
def share_with_owner(rest: Restaurant, target: Order | OrderItem) {
    if rest.owner_root != "" {
        Jac.allow_root(target, UUID(rest.owner_root), AccessLevel.WRITE);  # jac:ignore[E1053]
    }
}

"""Check the cart. Returns (message, merged quantities by dish id); message is '' when fine."""
def check_lines(items: list[OrderLine], note: str) -> tuple[str, dict[str, int]] {
    wanted: dict[str, int] = {};
    if len(items) == 0 {
        return ("Your order is empty. Please add a dish first.", wanted);
    }
    if len(items) > MAX_LINES {
        return (f"That is too many different dishes for one order (up to {MAX_LINES}). Please send it in two orders.", wanted);
    }
    if len(note) > MAX_NOTE {
        return (f"Your allergy note is too long (up to {MAX_NOTE} characters). Please shorten it.", wanted);
    }
    for line in items {
        if line.qty < 1 {
            return ("Each dish needs a quantity of at least 1.", wanted);
        }
        wanted[line.dish_id] = wanted.get(line.dish_id, 0) + line.qty;
        if wanted[line.dish_id] > MAX_QTY {
            return (f"You can order up to {MAX_QTY} of one dish. Please lower the quantity.", wanted);
        }
    }
    return ("", wanted);
}

"""Guest sends the cart. Creates one Order only if every check passes."""
def:pub place_order(table_code: str, items: list[OrderLine], allergy_note: str) -> PlaceResult {
    found = find_table(table_code);
    if found is None {
        return refuse("This table link isn't valid.");
    }
    (rest, table) = found;
    note = allergy_note.strip();
    (problem, wanted) = check_lines(items, note);
    if problem != "" {
        return refuse(problem);
    }
    by_id: dict[str, Dish] = {};
    for d in all_dishes(rest) {
        by_id[jid(d)] = d;
    }
    named: dict[str, int] = {};
    for (dish_id, qty) in wanted.items() {
        dish: Dish | None = by_id.get(dish_id);
        if dish is None {
            return refuse("One of the dishes is no longer on the menu. Please refresh and try again.");
        }
        if dish.sold_out {
            return refuse(f"{dish.name} is sold out today. Please remove it and try again.");
        }
        named[dish.name] = named.get(dish.name, 0) + qty;
    }
    for earlier in [table ->:Placed:-> [?:Order]] {
        if seconds_since(earlier.created_at) < DUPLICATE_SECONDS and same_order(earlier, named, note) {
            return refuse("This order was just sent. Please wait a few seconds before sending it again.");
        }
    }
    order = table +>:Placed:+> Order(status="sent", allergy_note=note, created_at=now_iso());
    share_with_owner(rest, order);
    total = 0;
    for (dish_id, qty) in wanted.items() {
        dish = by_id[dish_id];
        item = order +>:Contains:+> OrderItem(dish_name=dish.name, price=dish.price, qty=qty);
        share_with_owner(rest, item);
        total += dish.price * qty;
    }
    return PlaceResult(ok=True, message="Your order was sent to the kitchen.", order_id=jid(order), total=total);
}

"""This table's orders, newest first, for the guest's status card."""
def:pub table_orders(table_code: str) -> list[OrderView] {
    found = find_table(table_code);
    if found is None {
        return [];
    }
    (rest, table) = found;
    orders = sorted([table ->:Placed:-> [?:Order]], key=lambda (o: Order) { o.created_at; }, reverse=True);
    return [order_view(o, table) for o in orders];
}
