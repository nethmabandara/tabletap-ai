"""Tests for the kitchen board (K-01, K-02): order flow, sold-out switch, and refusing non-owners."""

import from .models { Restaurant, Order, Dish, Placed }
import from .menu { claim_demo_restaurant, my_restaurant, all_dishes, find_table, get_menu }
import from .orders { place_order, table_orders, OrderLine }

def owned -> Restaurant {
    claim_demo_restaurant();
    r = my_restaurant();
    assert r is not None;
    return r;
}

def dish_named(name: str) -> Dish {
    found = [d for d in all_dishes(owned()) if d.name == name];
    assert len(found) == 1;
    return found[0];
}

def order_with_note(note: str) -> OrderView | None {
    for o in kitchen_orders_for(owned()).orders {
        if o.allergy_note == note {
            return o;
        }
    }
    return None;
}

test "kitchen board lists a new order with table, items and allergy note" {
    claim_demo_restaurant();
    sprite = jid(dish_named("Sprite"));
    place_order("t5", [OrderLine(dish_id=sprite, qty=2)], "board test prawns");
    board = kitchen_orders_for(owned());
    assert board.ok and board.restaurant == "Wet Water Resort";
    mine = order_with_note("board test prawns");
    assert mine is not None;
    assert mine.table == "Table 5" and mine.status == "sent";
    assert mine.items[0].name == "Sprite" and mine.items[0].qty == 2;
    stamps = [o.minutes_ago for o in board.orders];
    assert stamps == sorted(stamps, reverse=True);
}

test "status only moves sent to preparing to ready, one step at a time" {
    claim_demo_restaurant();
    sprite = jid(dish_named("Sprite"));
    place_order("t6", [OrderLine(dish_id=sprite, qty=1)], "status flow test");
    rest = owned();
    order = order_with_note("status flow test");
    assert order is not None;
    assert not set_order_status_for(rest, order.id, "ready").ok;
    assert set_order_status_for(rest, order.id, "preparing").ok;
    assert not set_order_status_for(rest, order.id, "sent").ok;
    assert set_order_status_for(rest, order.id, "ready").ok;
    assert not set_order_status_for(rest, order.id, "preparing").ok;
    assert table_orders("t6")[0].status == "ready" or len(table_orders("t6")) > 1;
    assert not set_order_status_for(rest, "no-such-order", "preparing").ok;
}

test "sold out greys the dish for guests and blocks orders until it is available again" {
    claim_demo_restaurant();
    rest = owned();
    mousse = dish_named("Chocolate Mousse");
    assert set_sold_out_for(rest, jid(mousse), True).ok;
    flagged = [d for s in get_menu("t7").sections for d in s.dishes if d.name == "Chocolate Mousse"];
    assert flagged[0].sold_out;
    assert not place_order("t7", [OrderLine(dish_id=jid(mousse), qty=1)], "").ok;
    assert set_sold_out_for(rest, jid(mousse), False).ok;
    flagged = [d for s in get_menu("t7").sections for d in s.dishes if d.name == "Chocolate Mousse"];
    assert not flagged[0].sold_out;
    assert place_order("t7", [OrderLine(dish_id=jid(mousse), qty=1)], "mousse back test").ok;
}

test "a user who does not manage the restaurant is refused and nothing changes" {
    claim_demo_restaurant();
    sprite = dish_named("Sprite");
    place_order("t2", [OrderLine(dish_id=jid(sprite), qty=5)], "not allowed test");
    order = order_with_note("not allowed test");
    assert order is not None;
    stranger = root.shared ++> Restaurant(name="Someone Else", slug="someone-else");
    assert not kitchen_orders_for(stranger).ok;
    assert kitchen_orders_for(stranger).message == NOT_ALLOWED;
    assert set_order_status_for(stranger, order.id, "preparing").message == NOT_ALLOWED;
    assert set_sold_out_for(stranger, jid(sprite), True).message == NOT_ALLOWED;
    assert kitchen_dishes_for(stranger).message == NOT_ALLOWED;
    assert not sprite.sold_out;
    again = order_with_note("not allowed test");
    assert again is not None and again.status == "sent";
    del stranger;
}

test "a manager with no restaurant yet gets a friendly set-up message, not an error" {
    assert kitchen_orders_for(None).message == SET_UP_FIRST;
    assert set_order_status_for(None, "x", "preparing").message == SET_UP_FIRST;
    assert kitchen_dishes_for(None).message == SET_UP_FIRST;
    assert set_sold_out_for(None, "x", True).message == SET_UP_FIRST;
    assert not kitchen_orders_for(None).ok;
}
