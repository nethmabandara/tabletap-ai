"""Draft editing and publishing tests (M-03). No AI: drafts are built by hand or from a mock."""

import from core.models { Restaurant, Section, Dish, Order, Placed, HasSection, HasDish }
import from core.menu { get_menu, all_dishes }
import from core.orders { place_order, table_orders, OrderLine }
import from core.menu_rules { MenuDraft }
import from core.menu_setup { read_menu_photos_for }
import from core.menu_draft { get_draft_for, draft_of }
import from core.menu_edit { add_draft_dish_for, update_draft_dish_for, delete_draft_dish_for, discard_draft_for }
import from core.menu_publish { publish_draft_for }
import from tests.menu_fixtures { fresh_tag, make_cafe, remove_cafe, upload, dish_draft, use_mock, done_mock }

def live_names(code: str) -> list[list[str]] {
    return [[d.name for d in s.dishes] for s in get_menu(code).sections];
}

def draft_dish(cafe: Restaurant, name: str) -> any {
    return [d for s in get_draft_for(cafe).sections for d in s.dishes if d.name == name][0];
}

test "the draft is separate: guests keep the old menu, and discard changes nothing live" {
    tag = fresh_tag();
    cafe = make_cafe(tag);
    try {
        assert add_draft_dish_for(cafe, "Starters", "Soup", 300).ok;
        assert live_names(f"tc-{tag}") == [["Old Dish"]];
        assert get_draft_for(cafe).dish_count == 1;
        assert discard_draft_for(cafe).ok;
        assert not get_draft_for(cafe).exists and draft_of(cafe) is None;
        assert live_names(f"tc-{tag}") == [["Old Dish"]];
        assert discard_draft_for(cafe).ok;
    } finally {
        remove_cafe(cafe);
    }
}

test "add dish by hand makes a draft, reuses a section by name, and validates name and price" {
    cafe = make_cafe(fresh_tag());
    try {
        assert add_draft_dish_for(cafe, "Starters", "Soup", 300).ok;
        assert add_draft_dish_for(cafe, "starters", "Salad", 350).ok;
        assert add_draft_dish_for(cafe, "", "Tea", 100).ok;
        view = get_draft_for(cafe);
        assert [s.name for s in view.sections] == ["Starters", "Menu"] and view.sections[0].dishes[1].name == "Salad";
        assert view.steps == ["Added by hand"] and view.need_check == 0;
        assert add_draft_dish_for(cafe, "x", "  ", 100).message == "Please enter a dish name.";
        assert add_draft_dish_for(cafe, "x", "Free", 0).message == "Please enter a price above 0.";
        assert "up to 80" in add_draft_dish_for(cafe, "x", "n" * 81, 100).message;
        assert get_draft_for(cafe).dish_count == 3;
    } finally {
        remove_cafe(cafe);
    }
}

test "needs_check clears only when the manager really changed the dish or ticked it" {
    cafe = make_cafe(fresh_tag());
    d = MenuDraft(dishes=[
        dish_draft("Rice", "Blurry One", 500, confident=False),
        dish_draft("Rice", "Blurry Two", 600, confident=False),
        dish_draft("Rice", "Blurry Three", 0, confident=True)
    ]);
    try {
        use_mock([d]);
        assert read_menu_photos_for(cafe, [upload()]).ok;
        one = draft_dish(cafe, "Blurry One");
        same = update_draft_dish_for(cafe, one.id, "Blurry One", 500, False, False, [], False);
        assert same.ok and same.dishes[0].needs_check;
        edited = update_draft_dish_for(cafe, one.id, "Blurry One", 520, False, False, [], False);
        assert edited.ok and not edited.dishes[0].needs_check and edited.dishes[0].price == 520;
        two = draft_dish(cafe, "Blurry Two");
        ticked = update_draft_dish_for(cafe, two.id, "Blurry Two", 600, False, False, [], True);
        assert ticked.ok and not ticked.dishes[0].needs_check;
        three = draft_dish(cafe, "Blurry Three");
        zero = update_draft_dish_for(cafe, three.id, "Blurry Three", 0, False, False, [], True);
        assert not zero.ok and zero.message == "Please enter a price above 0.";
        assert draft_dish(cafe, "Blurry Three").needs_check;
        assert get_draft_for(cafe).need_check == 1;
    } finally {
        done_mock();
        remove_cafe(cafe);
    }
}

test "tags are saved: allergens are cleaned, and fish or shellfish can't be vegetarian" {
    cafe = make_cafe(fresh_tag());
    try {
        assert add_draft_dish_for(cafe, "Mains", "Curry", 800).ok;
        dish = draft_dish(cafe, "Curry");
        saved = update_draft_dish_for(cafe, dish.id, "Curry", 800, True, False, ["Prawns", "pollen", "egg"], False);
        assert saved.ok and sorted(saved.dishes[0].allergens) == ["egg", "shellfish"] and saved.dishes[0].spicy;
        assert not saved.dishes[0].needs_check;
        veg = update_draft_dish_for(cafe, dish.id, "Curry", 800, True, True, ["fish"], False);
        assert not veg.ok and "can't be vegetarian" in veg.message;
        assert draft_dish(cafe, "Curry").allergens != ["fish"];
        assert not update_draft_dish_for(cafe, "no-such-id", "x", 5, False, False, [], False).ok;
    } finally {
        remove_cafe(cafe);
    }
}

test "delete a draft dish; an empty section goes with its last dish" {
    cafe = make_cafe(fresh_tag());
    try {
        add_draft_dish_for(cafe, "A", "One", 100);
        add_draft_dish_for(cafe, "A", "Two", 200);
        add_draft_dish_for(cafe, "B", "Three", 300);
        assert delete_draft_dish_for(cafe, draft_dish(cafe, "Three").id).ok;
        assert [s.name for s in get_draft_for(cafe).sections] == ["A"];
        assert delete_draft_dish_for(cafe, draft_dish(cafe, "One").id).ok;
        assert get_draft_for(cafe).dish_count == 1;
        assert not delete_draft_dish_for(cafe, "no-such-id").ok;
    } finally {
        remove_cafe(cafe);
    }
}

test "publish is refused while Please check rows are left and says how many" {
    tag = fresh_tag();
    cafe = make_cafe(tag);
    d = MenuDraft(dishes=[
        dish_draft("Rice", "Unsure One", 500, confident=False),
        dish_draft("Rice", "Unsure Two", 600, confident=False),
        dish_draft("Rice", "Fine Dish", 700)
    ]);
    try {
        use_mock([d]);
        assert read_menu_photos_for(cafe, [upload()]).ok;
        refused = publish_draft_for(cafe);
        assert not refused.ok and refused.message.startswith("2 dishes still need your check");
        assert live_names(f"tc-{tag}") == [["Old Dish"]];
        update_draft_dish_for(cafe, draft_dish(cafe, "Unsure One").id, "Unsure One", 500, False, False, [], True);
        again = publish_draft_for(cafe);
        assert not again.ok and again.message.startswith("1 dish still needs your check");
        update_draft_dish_for(cafe, draft_dish(cafe, "Unsure Two").id, "Unsure Two", 650, False, False, [], False);
        assert publish_draft_for(cafe).ok;
        assert live_names(f"tc-{tag}") == [["Unsure One", "Unsure Two", "Fine Dish"]];
    } finally {
        done_mock();
        remove_cafe(cafe);
    }
}

test "after publish guests see the new menu in order, sold-out switches carry over by name, the draft is gone" {
    tag = fresh_tag();
    cafe = make_cafe(tag);
    try {
        for d in all_dishes(cafe) {
            d.sold_out = True;
        }
        add_draft_dish_for(cafe, "New Starters", "New Soup", 300);
        add_draft_dish_for(cafe, "Old Section", "old dish", 120);
        add_draft_dish_for(cafe, "New Starters", "New Salad", 350);
        result = publish_draft_for(cafe);
        assert result.ok and "3 dishes" in result.message;
        menu = get_menu(f"tc-{tag}");
        assert menu.status == "ready" and [s.name for s in menu.sections] == ["New Starters", "Old Section"];
        assert live_names(f"tc-{tag}") == [["New Soup", "New Salad"], ["old dish"]];
        sold = {d.name: d.sold_out for s in menu.sections for d in s.dishes};
        assert sold == {"New Soup": False, "New Salad": False, "old dish": True};
        assert len([cafe ->:HasSection:-> [?:Section]]) == 2;
        assert draft_of(cafe) is None and not get_draft_for(cafe).exists;
        assert len(all_dishes(cafe)) == 3;
    } finally {
        remove_cafe(cafe);
    }
}

test "old orders keep their copied dish names and prices after a publish" {
    tag = fresh_tag();
    cafe = make_cafe(tag);
    try {
        old_id = get_menu(f"tc-{tag}").sections[0].dishes[0].id;
        placed = place_order(f"tc-{tag}", [OrderLine(dish_id=old_id, qty=2)], "orders survive publish " + tag);
        assert placed.ok and placed.total == 200;
        add_draft_dish_for(cafe, "Brand New", "Totally Different", 999);
        assert publish_draft_for(cafe).ok;
        assert live_names(f"tc-{tag}") == [["Totally Different"]];
        orders = table_orders(f"tc-{tag}");
        assert len(orders) == 1 and orders[0].total == 200;
        assert orders[0].items[0].name == "Old Dish" and orders[0].items[0].price == 100 and orders[0].items[0].qty == 2;
        assert not place_order(f"tc-{tag}", [OrderLine(dish_id=old_id, qty=1)], "").ok;
    } finally {
        remove_cafe(cafe);
    }
}

test "publish is refused with no draft or an empty draft" {
    tag = fresh_tag();
    cafe = make_cafe(tag);
    try {
        none = publish_draft_for(cafe);
        assert not none.ok and "no draft" in none.message;
        add_draft_dish_for(cafe, "A", "Only", 100);
        assert delete_draft_dish_for(cafe, draft_dish(cafe, "Only").id).ok;
        assert live_names(f"tc-{tag}") == [["Old Dish"]];
        assert not publish_draft_for(cafe).ok;
    } finally {
        remove_cafe(cafe);
    }
}
