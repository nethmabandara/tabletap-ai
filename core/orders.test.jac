"""Tests for place_order and table_orders (G-03). Each test uses its own table so they never collide."""

import from .models { Restaurant, Order, Placed, HasTable }
import from .menu { claim_demo_restaurant, my_restaurant, all_dishes, find_table }

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

def count_orders(code: str) -> int {
    found = find_table(code);
    assert found is not None;
    (rest, table) = found;
    return len([table ->:Placed:-> [?:Order]]);
}

test "place_order copies name and price and computes the total in code" {
    sprite = dish_id("Sprite");
    cola = dish_id("Coca-Cola");
    result = place_order("t1", [OrderLine(dish_id=sprite, qty=2), OrderLine(dish_id=cola, qty=1)], "no nuts please t1");
    assert result.ok;
    assert result.total == 450;
    mine = [o for o in table_orders("t1") if o.allergy_note == "no nuts please t1"];
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
    result = place_order("t3", [OrderLine(dish_id=sprite, qty=20)], "y" * 200);
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
    first = place_order("t8", [OrderLine(dish_id=sprite, qty=3)], "double tap test");
    second = place_order("t8", [OrderLine(dish_id=sprite, qty=3)], "double tap test");
    assert not second.ok;
    assert "just sent" in second.message;
    other = place_order("t8", [OrderLine(dish_id=sprite, qty=4)], "double tap test");
    assert other.ok;
}
