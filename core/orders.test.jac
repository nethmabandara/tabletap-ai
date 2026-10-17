"""Tests for place_order and table_orders (G-03). Each test uses its own table so they never collide."""

import time;
import from .models { Restaurant, Order, Placed, HasTable }
import from .menu { claim_demo_restaurant, my_restaurant, all_dishes, restaurant_for_table }

def owned -> Restaurant {
    claim_demo_restaurant();
    r = my_restaurant();
    assert r is not None;
    return r;
}

def dish_id(name: str) -> str {
    claim_demo_restaurant();
    for d in all_dishes(owned()) {
        if d.name == name {
            return jid(d);
        }
    }
    return "";
}

"""A note nobody used before, so a quick re-run never trips the 10-second double-tap check."""
def fresh(label: str) -> str {
    return f"{label} {time.time_ns()}";
}

def count_orders(code: str) -> int {
    found = restaurant_for_table(code);
    assert found is not None;
    (rest, table) = found;
    return len([table ->:Placed:-> [?:Order]]);
}

test "place_order copies name and price and computes the total in code" {
    sprite = dish_id("Sprite");
    cola = dish_id("Coca-Cola");
    note = fresh("no nuts please t1");
    result = place_order("t1", [OrderLine(dish_id=sprite, qty=2), OrderLine(dish_id=cola, qty=1)], note);
    assert result.ok;
    assert result.total == 450;
    mine = [o for o in table_orders("t1") if o.allergy_note == note];
    assert len(mine) >= 1;
    assert mine[0].status == "sent" and mine[0].table == "Table 1";
    assert mine[0].total == 450;
    names = [i.name for i in mine[0].items];
    assert "Sprite" in names and "Coca-Cola" in names;
}

test "bad carts are refused with a friendly message and create no order" {
    sprite = dish_id("Sprite");
    before = count_orders("t2");
    assert not place_order("t2", [], "").ok;
    assert not place_order("t2", [OrderLine(dish_id=sprite, qty=0)], "").ok;
    assert not place_order("t2", [OrderLine(dish_id=sprite, qty=-3)], "").ok;
    assert not place_order("t2", [OrderLine(dish_id=sprite, qty=21)], "").ok;
    assert not place_order("t2", [OrderLine(dish_id=sprite, qty=12), OrderLine(dish_id=sprite, qty=12)], "").ok;
    many = [OrderLine(dish_id=sprite, qty=1) for i in range(31)];
    assert not place_order("t2", many, "").ok;
    assert not place_order("t2", [OrderLine(dish_id=sprite, qty=1)], "x" * 201).ok;
    assert not place_order("t2", [OrderLine(dish_id="not-a-real-id", qty=1)], "").ok;
    assert not place_order("zzz", [OrderLine(dish_id=sprite, qty=1)], "").ok;
    assert count_orders("t2") == before;
    msg = place_order("t2", [OrderLine(dish_id=sprite, qty=21)], "").message;
    assert "20" in msg;
    note_msg = place_order("t2", [OrderLine(dish_id=sprite, qty=1)], "x" * 201).message;
    assert "200" in note_msg;
}

test "limits allow exactly the maximum" {
    sprite = dish_id("Sprite");
    result = place_order("t3", [OrderLine(dish_id=sprite, qty=20)], ("y" * 170 + str(time.time_ns())).ljust(200, "z")[:200]);
    assert result.ok;
    assert result.total == 3000;
}

test "sold-out dish is refused by name and creates no order" {
    claim_demo_restaurant();
    egb = dish_id("EGB");
    for d in all_dishes(owned()) {
        if d.name == "EGB" {
            d.sold_out = True;
        }
    }
    before = count_orders("t4");
    result = place_order("t4", [OrderLine(dish_id=egb, qty=1)], "");
    for d in all_dishes(owned()) {
        if d.name == "EGB" {
            d.sold_out = False;
        }
    }
    assert not result.ok;
    assert "EGB" in result.message and "sold out" in result.message;
    assert count_orders("t4") == before;
}

test "the same order twice within 10 seconds is refused, a different one is fine" {
    sprite = dish_id("Sprite");
    note = fresh("double tap test");
    first = place_order("t8", [OrderLine(dish_id=sprite, qty=3)], note);
    second = place_order("t8", [OrderLine(dish_id=sprite, qty=3)], note);
    assert not second.ok;
    assert "just sent" in second.message;
    other = place_order("t8", [OrderLine(dish_id=sprite, qty=4)], note);
    assert other.ok;
}

test "AI orders store via_ai and keep allergies and preferences separate" {
    sprite = dish_id("Sprite");
    result = place_order(
        "t7", [OrderLine(dish_id=sprite, qty=2)], "Allergy: shellfish (prawns)", True, fresh("Preference: no fish via-ai-test")
    );
    assert result.ok and result.total == 300;
    mine = [o for o in table_orders("t7") if o.preference_note.startswith("Preference: no fish via-ai-test") and o.via_ai];
    assert len(mine) >= 1;
    assert mine[0].via_ai and mine[0].allergy_note == "Allergy: shellfish (prawns)";
    manual_note = fresh("no nuts manual-test");
    manual = place_order("t7", [OrderLine(dish_id=sprite, qty=1)], manual_note);
    assert manual.ok;
    found = [o for o in table_orders("t7") if o.allergy_note == manual_note];
    assert not found[0].via_ai and found[0].preference_note == "";
}

test "preference note is capped at 200 characters and refused with a friendly message" {
    sprite = dish_id("Sprite");
    before = count_orders("t6");
    refused = place_order("t6", [OrderLine(dish_id=sprite, qty=1)], "", False, "p" * 201);
    assert not refused.ok and "200" in refused.message and "preferences" in refused.message;
    assert count_orders("t6") == before;
    assert place_order("t6", [OrderLine(dish_id=sprite, qty=1)], fresh("cap ok"), True, "q" * 200).ok;
}

test "the double-tap check compares the preference note too" {
    sprite = dish_id("Sprite");
    note = fresh("dup pref test");
    first = place_order("t1", [OrderLine(dish_id=sprite, qty=7)], note, True, "Preference: no egg");
    twin = place_order("t1", [OrderLine(dish_id=sprite, qty=7)], note, True, "Preference: no egg");
    different = place_order("t1", [OrderLine(dish_id=sprite, qty=7)], note, True, "Preference: no fish");
    assert not twin.ok and "just sent" in twin.message;
    assert different.ok;
}
