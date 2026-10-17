"""Tests for the safety check on the AI's plan (G-04). No AI, no graph."""

def menu_facts -> list[DishFacts] {
    return [
        DishFacts(id="1", name="Vegetable Fried Rice", price=750, allergens=[], is_veg=True, sold_out=False),
        DishFacts(id="2", name="Devilled Prawns", price=990, allergens=["shellfish"], is_veg=False, sold_out=False),
        DishFacts(id="3", name="Fish Pepper Stew", price=790, allergens=["fish"], is_veg=False, sold_out=False),
        DishFacts(id="4", name="Mixed Fried Noodles", price=1050, allergens=["shellfish", "gluten"], is_veg=False, sold_out=True),
        DishFacts(id="5", name="Wattalapan", price=230, allergens=["egg", "dairy", "nuts"], is_veg=True, sold_out=False)
    ];
}

test "unknown, sold-out and allergen dishes are dropped with reasons" {
    items = [
        PlanItem(dish_name="Vegetable Fried Rice", qty=1, reason="veg"),
        PlanItem(dish_name="Devilled Prawns", qty=2, reason="x"),
        PlanItem(dish_name="Mixed Fried Noodles", qty=1, reason="x"),
        PlanItem(dish_name="Pizza", qty=1, reason="x"),
        PlanItem(dish_name="Fish Pepper Stew", qty=1, reason="x")
    ];
    result = check_plan(items, menu_facts(), ["shellfish", "fish"], 0);
    assert [i.dish_name for i in result.items] == ["Vegetable Fried Rice"];
    reasons = {r.dish_name: r.reason for r in result.removed};
    assert reasons["Devilled Prawns"] == "contains shellfish";
    assert reasons["Mixed Fried Noodles"] == "sold out today";
    assert reasons["Pizza"] == "not on the menu";
    assert reasons["Fish Pepper Stew"] == "contains fish";
    assert len(result.warnings) == 4;
    assert result.total == 750;
}

test "duplicates merge, names are matched ignoring case, quantity is capped" {
    items = [
        PlanItem(dish_name="vegetable fried rice", qty=15, reason="a"),
        PlanItem(dish_name="Vegetable Fried Rice", qty=10, reason="b"),
        PlanItem(dish_name="Wattalapan", qty=0, reason="c")
    ];
    result = check_plan(items, menu_facts(), [], 0);
    assert len(result.items) == 1;
    assert result.items[0].dish_name == "Vegetable Fried Rice" and result.items[0].qty == 20;
    assert result.removed[0].reason == "quantity below 1";
}

test "the total is recomputed by code, not taken from the AI" {
    items = [PlanItem(dish_name="Vegetable Fried Rice", qty=2, reason="a"), PlanItem(dish_name="Wattalapan", qty=2, reason="b")];
    assert cart_total(items, menu_facts()) == 1960;
    result = check_plan(items, menu_facts(), [], 0);
    assert result.total == 1960 and result.warnings == [];
}

test "over budget gives a warning and nothing is removed for it" {
    items = [PlanItem(dish_name="Vegetable Fried Rice", qty=4, reason="a")];
    result = check_plan(items, menu_facts(), [], 2000);
    assert len(result.items) == 1 and result.removed == [];
    assert len(result.warnings) == 1 and "over your budget" in result.warnings[0];
    assert check_plan(items, menu_facts(), [], 3000).warnings == [];
}

test "the code-written summary names what was removed and the total" {
    text = adjusted_summary([Removed(dish_name="Devilled Prawns", reason="x"), Removed(dish_name="Pizza", reason="y")], 4860);
    assert text == "Adjusted by safety check: removed Devilled Prawns, Pizza. Total Rs 4,860.";
}
