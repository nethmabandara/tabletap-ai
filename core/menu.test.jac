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

test "table link works only after the menu exists" {
    claim_demo_restaurant();
    assert table_status("t5") == "ready";
    assert table_status("zzz") == "coming_soon";
}
