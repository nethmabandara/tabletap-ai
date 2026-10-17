"""Tests for the Menu Setup rules (M-02). No AI, no graph."""

def d(section: str, name: str, price: int = 500, conf: bool = True, veg: bool = False, spicy: bool = False, allergens: list[str] = []) -> DishDraft {
    return DishDraft(section=section, name=name, price=price, confident=conf, is_veg=veg, spicy=spicy, allergens=allergens);
}

test "file type is decided by the first bytes, not the name" {
    assert sniff(b"\xff\xd8\xff\xe0abc") == "jpg";
    assert sniff(b"\x89PNG\r\n\x1a\nabc") == "png";
    assert sniff(b"%PDF-1.4") == "" and sniff(b"MZ\x90") == "" and sniff(b"") == "";
}

test "photo checks: count, size limit of 10 MB and type, with friendly messages" {
    png = b"\x89PNG\r\n\x1a\n";
    assert check_photos([100, 200, 300], [png, png, png]) == "";
    assert check_photos([], []) == "Please choose at least one photo.";
    assert check_photos([1, 1, 1, 1], [png, png, png, png]) == "You can read up to 3 photos at a time. Please choose fewer photos.";
    assert check_photos([10 * 1024 * 1024], [png]) == "";
    assert check_photos([10 * 1024 * 1024 + 1], [png]) == "Photo 1 is too big. Each photo can be up to 10 MB.";
    assert check_photos([5, 5], [png, b"GIF89a"]) == "Photo 2 must be a JPG or PNG picture.";
}

test "clean_dish: risky names, missing price, unknown allergen words and vegetarian contradictions" {
    mixed = clean_dish(d("Rice", "Mixed Fried Rice", allergens=["gluten"]));
    assert mixed.allergens == ["gluten", "shellfish"] and mixed.needs_check;
    assert clean_dish(d("Rice", "SEAFOOD Noodles")).allergens == ["shellfish"];
    assert clean_dish(d("Rice", "Chef's Special Curry")).needs_check;
    assert not clean_dish(d("Rice", "Specialty Rice")).needs_check;
    assert clean_dish(d("Rice", "Plain", price=0)).needs_check and clean_dish(d("Rice", "Plain", price=-5)).price == 0;
    assert clean_dish(d("Rice", "Plain", conf=False)).needs_check;
    salad = clean_dish(d("Rice", "Salad", veg=True, allergens=["pollen", "Egg", "prawns", "egg"]));
    assert sorted(salad.allergens) == ["egg", "shellfish"] and not salad.is_veg and salad.needs_check;
    ok = clean_dish(d("Rice", "Veg Rice", veg=True, allergens=["egg", "dairy"]));
    assert ok.is_veg and not ok.needs_check and ok.allergens == ["egg", "dairy"];
}

test "merge keeps photo order and section order, merges same sections and drops exact duplicate names" {
    a = MenuDraft(dishes=[d("Rice", "One"), d("Seafood", "Two"), d("Rice", "Three")]);
    b = MenuDraft(dishes=[d("seafood", "Four"), d("Desserts", "One"), d("", "Five"), d("Rice", "   ")]);
    merged = merge_photos([a, None, b]);
    assert [s.name for s in merged] == ["Rice", "Seafood", "Menu"];
    assert [[x.name for x in s.dishes] for s in merged] == [["One", "Three"], ["Two", "Four"], ["Five"]];
    assert count_dishes(merged) == 5;
    assert merge_photos([None, None]) == [] and merge_photos([]) == [];
}

test "steps read like the screen: photos, sections, dishes, tags and what needs a check" {
    sections = merge_photos([MenuDraft(dishes=[
        d("A", "x1", veg=True), d("A", "x2", spicy=True), d("B", "x3", conf=False), d("B", "x4", price=0), d("C", "x5")
    ])]);
    assert build_steps(3, [], sections) == [
        "Read 3 photos", "Found 3 sections", "Extracted 5 dishes", "Tagged 1 spicy, 1 vegetarian", "2 need your check"
    ];
    one = merge_photos([MenuDraft(dishes=[d("A", "solo", conf=False)])]);
    assert build_steps(1, [2], one) == [
        "Read 1 photo", "Couldn't read photo 2, try again", "Found 1 section", "Extracted 1 dish", "Tagged 0 spicy, 0 vegetarian", "1 needs your check"
    ];
    assert build_steps(1, [], merge_photos([MenuDraft(dishes=[d("A", "fine")])]))[-1] == "No dishes need a check";
}
