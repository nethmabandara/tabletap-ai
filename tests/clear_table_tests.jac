"""Clear table (K-04): in-process tests, no AI. Each test builds its own cafe and removes it."""

import from core.models { Restaurant, Table, Order, SongRequest, HasTable, Placed, Requested }
import from core.menu { get_menu }
import from core.kitchen {
    NOT_ALLOWED, SET_UP_FIRST, kitchen_orders_for, set_order_status_for, clear_table_for
}
import from core.orders { place_order, table_orders, OrderLine }
import from core.music { send_song_request, table_requests, music_queue_for, answer_request_for }
import from tests.menu_fixtures { fresh_tag, make_cafe, remove_cafe }

def cafe_with_two_tables(tag: str, owned: bool = True) -> Restaurant {
    cafe = make_cafe(tag, owned);
    cafe.music_mode = "both";
    second = cafe +>:HasTable:+> Table(label="Table 2", code=f"tc-{tag}-two");
    grant(second, level=AccessLevel.CONNECT);
    return cafe;
}

def drop_cafe(cafe: Restaurant) {
    for t in [cafe ->:HasTable:-> [?:Table]] {
        for r in [t ->:Requested:-> [?:SongRequest]] {
            del r;
        }
    }
    remove_cafe(cafe);
}

def dish_id(code: str) -> str {
    return get_menu(code).sections[0].dishes[0].id;
}

"""Place an order with a note nobody used before (so the double-tap check never trips)."""
def order_at(code: str, note: str) -> str {
    result = place_order(code, [OrderLine(dish_id=dish_id(code), qty=1)], f"{note} {fresh_tag()}");
    assert result.ok;
    return result.order_id;
}

def board_ids(cafe: Restaurant, code: str) -> list[str] {
    return [o.id for o in kitchen_orders_for(cafe).orders if o.table_code == code];
}

def make_ready(cafe: Restaurant, order_id: str) {
    assert set_order_status_for(cafe, order_id, "preparing").ok;
    assert set_order_status_for(cafe, order_id, "ready").ok;
}

def stored_orders(cafe: Restaurant, code: str) -> list[Order] {
    mine = [t for t in [cafe ->:HasTable:-> [?:Table]] if t.code == code][0];
    return [mine ->:Placed:-> [?:Order]];
}

test "clearing a table works once: orders are closed, not deleted, and vanish for guests and the kitchen" {
    tag = fresh_tag();
    cafe = cafe_with_two_tables(tag);
    one = f"tc-{tag}";
    two = f"tc-{tag}-two";
    try {
        first = order_at(one, "first");
        second = order_at(one, "second");
        other = order_at(two, "other table");
        make_ready(cafe, first);
        make_ready(cafe, second);
        assert sorted(board_ids(cafe, one)) == sorted([first, second]) and len(table_orders(one)) == 2;
        done = clear_table_for(cafe, one);
        assert done.ok and done.message == "Table 1 is cleared.";
        assert board_ids(cafe, one) == [] and table_orders(one) == [];
        assert board_ids(cafe, two) == [other] and len(table_orders(two)) == 1;
        kept = stored_orders(cafe, one);
        assert len(kept) == 2 and all([o.closed_at != "" for o in kept]);
        again = clear_table_for(cafe, one);
        assert not again.ok and again.message == "Table 1 has no open orders to clear.";
        fresh = order_at(one, "next guests");
        assert board_ids(cafe, one) == [fresh] and [o.id for o in table_orders(one)] == [fresh];
        assert not set_order_status_for(cafe, first, "preparing").ok;
        assert set_order_status_for(cafe, first, "preparing").message == "We couldn't find that order.";
    } finally {
        drop_cafe(cafe);
    }
}

test "clearing is refused while any order is still new or preparing, and nothing changes" {
    tag = fresh_tag();
    cafe = cafe_with_two_tables(tag);
    code = f"tc-{tag}";
    try {
        sent = order_at(code, "new one");
        refused = clear_table_for(cafe, code);
        assert not refused.ok and refused.message == "Table 1 still has orders in progress. Clear it when they are all ready.";
        assert set_order_status_for(cafe, sent, "preparing").ok;
        assert not clear_table_for(cafe, code).ok;
        done = order_at(code, "ready one");
        make_ready(cafe, done);
        mixed = clear_table_for(cafe, code);
        assert not mixed.ok and "in progress" in mixed.message;
        assert len(board_ids(cafe, code)) == 2 and len(table_orders(code)) == 2;
        assert all([o.closed_at == "" for o in stored_orders(cafe, code)]);
        assert set_order_status_for(cafe, sent, "ready").ok;
        assert clear_table_for(cafe, code).ok;
    } finally {
        drop_cafe(cafe);
    }
}

test "a second manager, another restaurant's table, or no restaurant: refused and nothing changes" {
    tag = fresh_tag();
    mine = cafe_with_two_tables(tag);
    stranger = cafe_with_two_tables(fresh_tag(), owned=False);
    code = f"tc-{tag}";
    try {
        order = order_at(code, "mine");
        make_ready(mine, order);
        assert clear_table_for(stranger, code).message == NOT_ALLOWED;
        assert clear_table_for(None, code).message == SET_UP_FIRST;
        wrong_table = clear_table_for(mine, "tc-not-my-table");
        assert not wrong_table.ok and wrong_table.message == "We couldn't find that table.";
        stranger_code = [t.code for t in [stranger ->:HasTable:-> [?:Table]]][0];
        cross = clear_table_for(mine, stranger_code);
        assert not cross.ok and cross.message == "We couldn't find that table.";
        assert board_ids(mine, code) == [order] and len(table_orders(code)) == 1;
        assert all([o.closed_at == "" for o in stored_orders(mine, code)]);
    } finally {
        drop_cafe(mine);
        drop_cafe(stranger);
    }
}

test "clearing a table also closes its song requests: hidden from the guest and the singer, kept as history" {
    tag = fresh_tag();
    cafe = cafe_with_two_tables(tag);
    one = f"tc-{tag}";
    two = f"tc-{tag}-two";
    try {
        order = order_at(one, "dinner");
        make_ready(cafe, order);
        assert send_song_request(one, "Song One", "A", "", "wish").ok and send_song_request(one, "Song Two", "B", "", "wish").ok;
        assert not send_song_request(one, "Song Three", "C", "", "wish").ok;
        assert send_song_request(two, "Other Table Song", "D", "", "wish").ok;
        waiting = [q.id for q in music_queue_for(cafe).requests if q.table == "Table 1"];
        assert len(waiting) == 2 and answer_request_for(cafe, waiting[0], True).ok;
        assert len(table_requests(one)) == 2;
        assert clear_table_for(cafe, one).ok;
        assert table_requests(one) == [];
        assert [q.table for q in music_queue_for(cafe).requests] == ["Table 2"];
        assert not answer_request_for(cafe, waiting[1], True).ok;
        assert len([r.song for r in table_requests(two)]) == 1;
        table = [t for t in [cafe ->:HasTable:-> [?:Table]] if t.code == one][0];
        kept = [table ->:Requested:-> [?:SongRequest]];
        assert len(kept) == 2 and all([r.closed_at != "" for r in kept]);
        assert send_song_request(one, "Song Three", "C", "", "wish").ok;
        assert [r.song for r in table_requests(one)] == ["Song Three"];
    } finally {
        drop_cafe(cafe);
    }
}

test "a table with only song requests and no orders cannot be cleared, and its songs stay" {
    tag = fresh_tag();
    cafe = cafe_with_two_tables(tag);
    code = f"tc-{tag}";
    try {
        assert send_song_request(code, "Lonely Song", "A", "", "wish").ok;
        refused = clear_table_for(cafe, code);
        assert not refused.ok and refused.message == "Table 1 has no open orders to clear.";
        assert len(table_requests(code)) == 1;
    } finally {
        drop_cafe(cafe);
    }
}
