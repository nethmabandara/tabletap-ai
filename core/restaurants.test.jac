"""Tests for creating a restaurant, its status and its table links (M-05, M-06).
Every test builds its own cafe and removes it, so the demo restaurant and the other tests are untouched."""

import time;
import from jaclang.byllm.lib { MockLLM }
import from .models { Section, Dish, Table, Order, Placed, HasSection, HasDish, HasDraft, DraftMenu }
import from .menu { claim_demo_restaurant, get_menu, restaurant_for_table, all_table_codes }
import from .kitchen { NOT_ALLOWED, SET_UP_FIRST }
import from .orders { place_order, OrderLine }
import from .agents { WaiterRun, MODEL_OVERRIDE }
import from .waiter { ask_waiter, reset_waiter_throttle }
import from .menu_draft { delete_draft_nodes }
import from .menu_edit { add_draft_dish_for }
import from .menu_publish { publish_draft_for }

obj Picker {
    has items: list[str],
        used: int = 0;

    def next -> str {
        value = self.items[self.used % len(self.items)];
        self.used += 1;
        return value;
    }
}

def fresh_name(label: str) -> str {
    return f"{label} {time.time_ns()}";
}

def count_restaurants -> int {
    return len([root.shared -->[?:Restaurant]]);
}

def drop(rest: Restaurant) {
    for d in [rest ->:HasDraft:-> [?:DraftMenu]] {
        delete_draft_nodes(d);
    }
    for sec in [rest ->:HasSection:-> [?:Section]] {
        for d in [sec ->:HasDish:-> [?:Dish]] {
            del d;
        }
        del sec;
    }
    for t in [rest ->:HasTable:-> [?:Table]] {
        for o in [t ->:Placed:-> [?:Order]] {
            del o;
        }
        del t;
    }
    del rest;
}

def make_cafe(label: str, tables: int = 3) -> Restaurant {
    claim_demo_restaurant();
    result = create_restaurant_for(None, fresh_name(label), tables, random_code);
    assert result.ok;
    found = [r for r in [root.shared -->[?:Restaurant]] if r.name == result.name];
    assert len(found) == 1;
    return found[0];
}

test "name and table count are checked with friendly messages and nothing is created" {
    before = count_restaurants();
    assert create_restaurant_for(None, "A", 3, random_code).message == "Please enter your restaurant's name (2 to 60 characters).";
    assert create_restaurant_for(None, "x" * 61, 3, random_code).message.startswith("Please enter your restaurant's name");
    assert create_restaurant_for(None, "   ", 3, random_code).ok == False;
    assert create_restaurant_for(None, "Cafe Valid", 0, random_code).message == "Please choose between 1 and 30 tables.";
    assert create_restaurant_for(None, "Cafe Valid", 31, random_code).message == "Please choose between 1 and 30 tables.";
    assert count_restaurants() == before;
}

test "a new restaurant: tables 1 to N with unique random codes, no menu yet, music off, owned by the caller" {
    cafe = make_cafe("Cafe Two", 3);
    try {
        tables = [cafe ->:HasTable:-> [?:Table]];
        assert [t.label for t in tables] == ["Table 1", "Table 2", "Table 3"];
        codes = [t.code for t in tables];
        assert len(set(codes)) == 3;
        for c in codes {
            assert len(c) == 6 and all([ch in CODE_CHARS for ch in c]);
            assert c not in RESERVED_CODES;
        }
        assert all_table_codes().count(codes[0]) == 1;
        assert not cafe.menu_published and cafe.music_mode == "off" and cafe.owner_root == jid(root);
        assert cafe.slug != "wet-water" and cafe.slug.startswith("cafe-two-");
        assert restaurant_for_table(codes[1]) is not None;
    } finally {
        drop(cafe);
    }
}

test "a guest at a new restaurant's code sees Menu coming soon, and cannot order or use the AI waiter" {
    cafe = make_cafe("Cafe Guest", 2);
    reset_waiter_throttle();
    MODEL_OVERRIDE.clear();
    MODEL_OVERRIDE.append(MockLLM(outputs=[]));
    try {
        code = [t.code for t in [cafe ->:HasTable:-> [?:Table]]][1];
        view = get_menu(code);
        assert view.status == "coming_soon" and view.restaurant == cafe.name and view.table == "Table 2";
        assert view.sections == [];
        wet = get_menu("t5");
        assert wet.status == "ready" and wet.restaurant == "Wet Water Resort" and wet.table == "Table 5";
        assert get_menu("zzzzzz").status == "invalid";
        refused = place_order(code, [OrderLine(dish_id="x", qty=1)], "");
        assert not refused.ok and "menu isn't ready" in refused.message;
        plan = ask_waiter(code, "dinner for 2", []);
        assert not plan.ok and "not ready" in plan.message and "Menu coming soon" in plan.message;
        assert len(MODEL_OVERRIDE[0].outputs) == 0 and len(MODEL_OVERRIDE[0].seen) == 0;
        assert WaiterRun(table_code=code).search_menu("", False, [], 0) == [];
    } finally {
        MODEL_OVERRIDE.clear();
        reset_waiter_throttle();
        drop(cafe);
    }
}

test "a second create by a manager who already has a restaurant is refused" {
    cafe = make_cafe("Cafe Once", 1);
    try {
        before = count_restaurants();
        again = create_restaurant_for(cafe, fresh_name("Cafe Twice"), 2, random_code);
        assert not again.ok and again.message == "You already have a restaurant.";
        assert count_restaurants() == before;
    } finally {
        drop(cafe);
    }
}

test "table codes are unique across all restaurants even when the random picker repeats itself" {
    taken = ["aaaaaa", "bbbbbb"];
    picker = Picker(items=["aaaaaa", "cccccc", "cccccc", "bbbbbb", "t3", "dddddd", "eeeeee"]);
    assert make_codes(3, taken, picker.next) == ["cccccc", "dddddd", "eeeeee"];
    stuck = Picker(items=["aaaaaa"]);
    with testraises(RuntimeError) {
        make_codes(1, ["aaaaaa"], stuck.next);
    }
    cafe = make_cafe("Cafe Codes", 2);
    try {
        existing = [t.code for t in [cafe ->:HasTable:-> [?:Table]]];
        clash = Picker(items=[existing[0], "ffffff", "gggggg"]);
        other = create_restaurant_for(None, fresh_name("Cafe Clash"), 2, clash.next);
        assert other.ok;
        made = [r for r in [root.shared -->[?:Restaurant]] if r.name == other.name][0];
        codes = [t.code for t in [made ->:HasTable:-> [?:Table]]];
        assert codes == ["ffffff", "gggggg"] and existing[0] not in codes;
        drop(made);
    } finally {
        drop(cafe);
    }
}

test "creation is all-or-nothing: a failure while making tables leaves nothing behind" {
    claim_demo_restaurant();
    before_restaurants = count_restaurants();
    before_codes = sorted(all_table_codes());
    name = fresh_name("Cafe Broken");
    CREATE_FAULT.clear();
    CREATE_FAULT.append(2);
    try {
        result = create_restaurant_for(None, name, 3, random_code);
        assert not result.ok and "Nothing was saved" in result.message;
    } finally {
        CREATE_FAULT.clear();
    }
    assert count_restaurants() == before_restaurants;
    assert sorted(all_table_codes()) == before_codes;
    assert len([r for r in [root.shared -->[?:Restaurant]] if r.name == name]) == 0;
    retry = create_restaurant_for(None, name, 3, random_code);
    assert retry.ok;
    made = [r for r in [root.shared -->[?:Restaurant]] if r.name == name];
    assert len(made) == 1 and len([made[0] ->:HasTable:-> [?:Table]]) == 3;
    drop(made[0]);
}

test "dashboard status lines are real: no menu, draft, published" {
    assert status_lines(False, 0, 0) == ("No menu yet: start with Menu setup", "");
    assert status_lines(False, 0, 4) == ("Draft menu: 4 dishes, not published yet", "");
    assert status_lines(False, 0, 1) == ("Draft menu: 1 dish, not published yet", "");
    assert status_lines(True, 35, 0) == ("Menu: 35 dishes, published", "");
    assert status_lines(True, 1, 2) == ("Menu: 1 dish, published", "Draft in progress: 2 dishes");
    assert restaurant_status_for(None).has_restaurant == False;
    cafe = make_cafe("Cafe Status", 3);
    try {
        first = restaurant_status_for(cafe);
        assert first.ok and first.has_restaurant and first.name == cafe.name and first.table_count == 3;
        assert first.status_line == "No menu yet: start with Menu setup" and not first.published;
        assert add_draft_dish_for(cafe, "Starters", "Soup", 300).ok;
        assert restaurant_status_for(cafe).status_line == "Draft menu: 1 dish, not published yet";
        assert publish_draft_for(cafe).ok;
        done = restaurant_status_for(cafe);
        assert done.status_line == "Menu: 1 dish, published" and done.published and done.dish_count == 1;
        code = [t.code for t in [cafe ->:HasTable:-> [?:Table]]][0];
        assert get_menu(code).status == "ready" and get_menu(code).sections[0].dishes[0].name == "Soup";
    } finally {
        drop(cafe);
    }
}

test "table links: only my tables, and a stranger or a manager with no restaurant is refused" {
    cafe = make_cafe("Cafe Links", 3);
    stranger = root.shared ++> Restaurant(name=fresh_name("Someone Else"), slug="someone-else-test");
    try {
        links = table_links_for(cafe);
        assert links.ok and links.restaurant == cafe.name and [t.label for t in links.tables] == ["Table 1", "Table 2", "Table 3"];
        assert len(set([t.code for t in links.tables])) == 3;
        assert "t5" not in [t.code for t in links.tables];
        assert table_links_for(stranger).message == NOT_ALLOWED;
        assert table_links_for(None).message == SET_UP_FIRST;
        assert restaurant_status_for(stranger).message == NOT_ALLOWED;
    } finally {
        del stranger;
        drop(cafe);
    }
}
