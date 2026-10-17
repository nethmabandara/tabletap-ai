"""Tests for S-01 starting data (docs/05-user-stories.md)."""

import from .models { Section, Dish, Song, HasSection, HasDish, HasSong }

test "claim creates Wet Water once with 6 sections, 35 dishes, 8 tables, 8 songs" {
    claim_demo_restaurant();
    claim_demo_restaurant();
    rest = my_restaurant();
    assert rest is not None;
    assert rest.name == "Wet Water Resort";
    sections = [rest ->:HasSection:-> [?:Section]];
    assert len(sections) == 6;
    dishes: list[Dish] = [];
    for s in sections {
        dishes += [s ->:HasDish:-> [?:Dish]];
    }
    assert len(dishes) == 35;
    labels = [t.label for t in [rest ->:HasTable:-> [?:Table]]];
    assert len(labels) == 8;
    assert "Table 1" in labels and "Table 8" in labels;
    assert len([rest ->:HasSong:-> [?:Song]]) == 8;
    assert len([root ->:Manages:-> [?:Restaurant]]) == 1;
}

test "allergen notes and prices follow the data model" {
    claim_demo_restaurant();
    rest = my_restaurant();
    assert rest is not None;
    by_name: dict[str, Dish] = {};
    for s in [rest ->:HasSection:-> [?:Section]] {
        for d in [s ->:HasDish:-> [?:Dish]] {
            by_name[d.name] = d;
        }
    }
    assert by_name["Devilled Prawns"].price == 990;
    assert "shellfish" in by_name["Devilled Prawns"].allergens;
    assert by_name["Devilled Prawns"].spicy;
    assert by_name["Wattalapan"].allergens == ["egg", "dairy", "nuts"];
    assert by_name["Mixed Fried Rice"].allergens == ["shellfish"];
    assert by_name["Vegetable Chop Suey"].is_veg;
}

test "get_menu: ready for t5, invalid for unknown code, sections in order" {
    claim_demo_restaurant();
    m = get_menu("t5");
    assert m.status == "ready";
    assert m.restaurant == "Wet Water Resort" and m.table == "Table 5";
    assert len(m.sections) == 6;
    assert m.sections[0].name == "Rice, Pasta & Noodles";
    assert m.sections[0].dishes[0].name == "Vegetable Fried Rice";
    assert m.sections[0].dishes[0].price == 750;
    assert "vegetarian" in m.sections[0].dishes[0].tags;
    assert get_menu("zzz").status == "invalid";
}

test "second claim does nothing" {
    claim_demo_restaurant();
    assert demo_claimed();
    assert claim_demo_restaurant() == False;
    assert claim_demo_restaurant() == False;
    demos = [root.shared -->[?:Restaurant, slug == "wet-water"]];
    assert len(demos) == 1;
    tables = [demos[0] ->:HasTable:-> [?:Table]];
    assert len(tables) == 8;
    assert len([t for t in tables if t.code == "t5"]) == 1;
}
