"""Menu Setup Agent tests with MockLLM (no real AI, no cost): reading photos into a draft."""

import os;
import from jaclang.byllm.lib { MockLLM }
import from core.models { Restaurant, Section, Dish, DraftMenu, HasDraft }
import from core.menu { get_menu }
import from core.kitchen { NOT_ALLOWED, SET_UP_FIRST }
import from core.menu_rules { MenuDraft, MAX_PHOTO_BYTES }
import from core.menu_agent { PROGRESS }
import from core.menu_setup { read_menu_photos_for, menu_read_progress_for, photo_dir, STORAGE_OVERRIDE, NO_PHOTOS_MESSAGE }
import from core.menu_draft { get_draft_for, draft_of }
import from core.menu_edit { add_draft_dish_for, update_draft_dish_for, delete_draft_dish_for, discard_draft_for }
import from core.menu_publish { publish_draft_for }
import from tests.menu_fixtures {
    fresh_tag, make_cafe, remove_cafe, photo_bytes, upload, dish_draft, use_mock, done_mock
}

def names_in(view: any) -> list[list[str]] {
    return [[d.name for d in s.dishes] for s in view.sections];
}

test "a 2-photo draft merges in photo order, keeps section order and drops duplicate names" {
    cafe = make_cafe(fresh_tag());
    p1 = MenuDraft(dishes=[
        dish_draft("Rice", "Vegetable Fried Rice", 750, veg=True),
        dish_draft("Rice", "Chicken Fried Rice", 850),
        dish_draft("Seafood", "Devilled Prawns", 990, spicy=True, allergens=["shellfish"])
    ]);
    p2 = MenuDraft(dishes=[
        dish_draft("Rice", "Beef Fried Rice", 900),
        dish_draft("Seafood", "Fish Pepper Stew", 790, allergens=["fish"]),
        dish_draft("Seafood", "devilled prawns", 990),
        dish_draft("Desserts", "Wattalapan", 230, veg=True, allergens=["egg", "dairy", "nuts"])
    ]);
    try {
        use_mock([p1, p2]);
        result = read_menu_photos_for(cafe, [upload("a.png"), upload("b.jpg")]);
        assert result.ok and result.failed_photos == [];
        view = get_draft_for(cafe);
        assert view.exists and view.dish_count == 6;
        assert [s.name for s in view.sections] == ["Rice", "Seafood", "Desserts"];
        assert names_in(view) == [
            ["Vegetable Fried Rice", "Chicken Fried Rice", "Beef Fried Rice"],
            ["Devilled Prawns", "Fish Pepper Stew"],
            ["Wattalapan"]
        ];
        assert view.steps[:3] == ["Read 2 photos", "Found 3 sections", "Extracted 6 dishes"];
        assert view.steps[3] == "Tagged 1 spicy, 2 vegetarian";
        assert view.steps[4] == "No dishes need a check";
    } finally {
        done_mock();
        remove_cafe(cafe);
    }
}

test "the live menu is untouched by reading photos: guests keep the old menu until publish" {
    tag = fresh_tag();
    cafe = make_cafe(tag);
    d = MenuDraft(dishes=[dish_draft("New", "New Dish", 500)]);
    try {
        use_mock([d]);
        assert read_menu_photos_for(cafe, [upload()]).ok;
        live = get_menu(f"tc-{tag}");
        assert live.status == "ready" and [x.name for s in live.sections for x in s.dishes] == ["Old Dish"];
    } finally {
        done_mock();
        remove_cafe(cafe);
    }
}

test "code overrides the AI: Mixed Fried Rice gets shellfish and needs_check, bad prices and unknown allergens are fixed" {
    cafe = make_cafe(fresh_tag());
    d = MenuDraft(dishes=[
        dish_draft("Rice", "Mixed Fried Rice", 950, confident=True, allergens=["gluten"]),
        dish_draft("Rice", "Special Noodles", 800, confident=True),
        dish_draft("Rice", "Plain Rice", 0, confident=True),
        dish_draft("Rice", "Garden Salad", 400, veg=True, allergens=["pollen", "Egg", "prawns"], confident=True),
        dish_draft("Rice", "Blurry Dish", 500, confident=False),
        dish_draft("Rice", "Fine Rice", 600, confident=True)
    ]);
    try {
        use_mock([d]);
        assert read_menu_photos_for(cafe, [upload()]).ok;
        by_name = {x.name: x for s in get_draft_for(cafe).sections for x in s.dishes};
        assert "shellfish" in by_name["Mixed Fried Rice"].allergens and "gluten" in by_name["Mixed Fried Rice"].allergens;
        assert by_name["Mixed Fried Rice"].needs_check;
        assert "shellfish" in by_name["Special Noodles"].allergens and by_name["Special Noodles"].needs_check;
        assert by_name["Plain Rice"].needs_check and by_name["Plain Rice"].price == 0;
        assert sorted(by_name["Garden Salad"].allergens) == ["egg", "shellfish"];
        assert not by_name["Garden Salad"].is_veg;
        assert by_name["Blurry Dish"].needs_check;
        assert not by_name["Fine Rice"].needs_check;
        assert get_draft_for(cafe).need_check == 5;
        assert get_draft_for(cafe).steps[-1] == "5 need your check";
    } finally {
        done_mock();
        remove_cafe(cafe);
    }
}

test "one failed photo does not lose the others, and it is named on screen" {
    cafe = make_cafe(fresh_tag());
    d = MenuDraft(dishes=[dish_draft("Rice", "Fried Rice", 700)]);
    try {
        use_mock([d]);
        result = read_menu_photos_for(cafe, [upload("1.png"), upload("2.png")]);
        assert result.ok and result.failed_photos == [2];
        assert "Couldn't read photo 2, try again" in result.message;
        view = get_draft_for(cafe);
        assert view.dish_count == 1 and "Couldn't read photo 2, try again" in view.steps;
        assert view.steps[0] == "Read 1 photo";
    } finally {
        done_mock();
        remove_cafe(cafe);
    }
}

test "when every photo fails: the friendly message, and an existing draft is kept" {
    cafe = make_cafe(fresh_tag());
    try {
        assert add_draft_dish_for(cafe, "Starters", "Soup", 300).ok;
        use_mock([]);
        result = read_menu_photos_for(cafe, [upload("1.png"), upload("2.png")]);
        assert not result.ok and result.message == "We couldn't read your photos. You can add dishes by hand.";
        assert result.message == NO_PHOTOS_MESSAGE and result.failed_photos == [1, 2];
        assert get_draft_for(cafe).dish_count == 1;
    } finally {
        done_mock();
        remove_cafe(cafe);
    }
}

test "upload limits are refused with a friendly message and no AI call" {
    cafe = make_cafe(fresh_tag());
    d = MenuDraft(dishes=[dish_draft("Rice", "Fried Rice", 700)]);
    try {
        m = use_mock([d]);
        too_many = read_menu_photos_for(cafe, [upload(), upload(), upload(), upload()]);
        assert not too_many.ok and "up to 3 photos" in too_many.message;
        big = read_menu_photos_for(cafe, [upload("big.png", b"\x89PNG\r\n\x1a\n" + b"0" * (MAX_PHOTO_BYTES + 1))]);
        assert not big.ok and "Photo 1 is too big" in big.message and "10 MB" in big.message;
        exe = read_menu_photos_for(cafe, [upload("virus.png", b"MZ" + b"0" * 100)]);
        assert not exe.ok and "JPG or PNG" in exe.message;
        pdf = read_menu_photos_for(cafe, [upload(), upload("doc.png", b"%PDF-1.4 " + b"0" * 100)]);
        assert not pdf.ok and "Photo 2 must be a JPG or PNG" in pdf.message;
        none = read_menu_photos_for(cafe, []);
        assert not none.ok and "at least one photo" in none.message;
        assert len(m.outputs) == 1 and draft_of(cafe) is None;
    } finally {
        done_mock();
        remove_cafe(cafe);
    }
}

test "a manager who does not own the restaurant is refused everywhere and nothing changes" {
    mine = make_cafe(fresh_tag());
    other = make_cafe(fresh_tag(), owned=False);
    d = MenuDraft(dishes=[dish_draft("Rice", "Fried Rice", 700)]);
    try {
        m = use_mock([d]);
        assert add_draft_dish_for(mine, "Starters", "Soup", 300).ok;
        dish_id = get_draft_for(mine).sections[0].dishes[0].id;
        assert read_menu_photos_for(other, [upload()]).message == NOT_ALLOWED;
        assert get_draft_for(other).message == NOT_ALLOWED;
        assert add_draft_dish_for(other, "x", "y", 5).message == NOT_ALLOWED;
        assert update_draft_dish_for(other, dish_id, "Hacked", 1, False, False, [], True).message == NOT_ALLOWED;
        assert delete_draft_dish_for(other, dish_id).message == NOT_ALLOWED;
        assert discard_draft_for(other).message == NOT_ALLOWED;
        assert publish_draft_for(other).message == NOT_ALLOWED;
        assert menu_read_progress_for(other).message == NOT_ALLOWED;
        assert len(m.outputs) == 1;
        assert draft_of(other) is None;
        assert get_draft_for(mine).sections[0].dishes[0].name == "Soup";
    } finally {
        done_mock();
        remove_cafe(mine);
        remove_cafe(other);
    }
}

test "a manager with no restaurant gets 'Set up your restaurant first' from every menu-setup function" {
    assert read_menu_photos_for(None, [upload()]).message == SET_UP_FIRST;
    assert get_draft_for(None).message == SET_UP_FIRST;
    assert add_draft_dish_for(None, "x", "y", 5).message == SET_UP_FIRST;
    assert update_draft_dish_for(None, "x", "y", 5, False, False, [], False).message == SET_UP_FIRST;
    assert delete_draft_dish_for(None, "x").message == SET_UP_FIRST;
    assert discard_draft_for(None).message == SET_UP_FIRST;
    assert publish_draft_for(None).message == SET_UP_FIRST;
    assert menu_read_progress_for(None).message == SET_UP_FIRST;
}

test "photos are read in parallel with progress, and results still come back for every photo" {
    cafe = make_cafe(fresh_tag());
    d = MenuDraft(dishes=[dish_draft("Rice", "Fried Rice", 700)]);
    try {
        use_mock([d, d, d], parallel=True);
        result = read_menu_photos_for(cafe, [upload("1.png"), upload("2.png"), upload("3.png")]);
        assert result.ok and result.failed_photos == [];
        progress = menu_read_progress_for(cafe);
        assert progress.ok and not progress.running and progress.total == 3;
        assert progress.done == [1, 2, 3] and progress.failed == [];
        assert get_draft_for(cafe).dish_count == 1;
        assert get_draft_for(cafe).steps[0] == "Read 3 photos";
    } finally {
        done_mock();
        remove_cafe(cafe);
    }
}

test "photos are saved outside the project, in a folder that is created if missing" {
    cafe = make_cafe(fresh_tag());
    d = MenuDraft(dishes=[dish_draft("Rice", "Fried Rice", 700)]);
    try {
        use_mock([d]);
        gone = os.path.join(STORAGE_OVERRIDE[0], "created-later");
        STORAGE_OVERRIDE.clear();
        STORAGE_OVERRIDE.append(gone);
        assert not os.path.exists(gone);
        assert read_menu_photos_for(cafe, [upload()]).ok;
        saved = [f for (dirpath, dirs, files) in os.walk(gone) for f in files];
        assert len(saved) == 1 and saved[0].endswith(".png");
        project = os.path.abspath(os.getcwd());
        assert not os.path.abspath(gone).startswith(project + os.sep);
        STORAGE_OVERRIDE.clear();
        os.environ["TABLETAP_STORAGE_DIR"] = os.path.join(project, "uploads-inside-project");
        inside = photo_dir();
        os.environ.pop("TABLETAP_STORAGE_DIR");
        assert not os.path.abspath(inside).startswith(project + os.sep) and os.path.isdir(inside);
        assert not os.path.exists(os.path.join(project, "uploads-inside-project"));
    } finally {
        done_mock();
        remove_cafe(cafe);
    }
}

test "the rules the AI is given include the price, vegetarian, allergen and note rules" {
    cafe = make_cafe(fresh_tag());
    d = MenuDraft(dishes=[dish_draft("Rice", "Fried Rice", 700)]);
    try {
        m = use_mock([d]);
        assert read_menu_photos_for(cafe, [upload()]).ok;
        prompt = str(m.sent("messages")[0]);
        assert "whole Sri Lankan rupees" in prompt and "no meat and no fish" in prompt;
        assert "shellfish, fish, nuts, egg, dairy, gluten" in prompt;
        assert "Wattalapan" in prompt and "Chocolate Mousse" in prompt and "confident" in prompt;
    } finally {
        done_mock();
        remove_cafe(cafe);
    }
}
