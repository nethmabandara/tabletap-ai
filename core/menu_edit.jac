"""Editing the draft by hand (M-03): add, change, delete a dish, or discard the whole draft.
Every endpoint passes the caller's own restaurant to a *_for function that first checks the Manages edge.
"""

import from .models { Restaurant, Section, Dish, DraftMenu, HasDraft, DraftHasSection, HasDish }
import from .menu { my_restaurant }
import from .kitchen { refusal }
import from .seed { tags_for }
import from .waiter_rules { normalise_allergens }
import from .menu_draft {
    SetupResult, DishResult, now_iso, draft_of, draft_sections, section_dishes, dish_view, find_draft_dish,
    delete_draft_nodes, MAX_NAME, MAX_PRICE
}

"""Why this name or price cannot be used, or ''."""
def dish_problem(name: str, price: int) -> str {
    if name.strip() == "" {
        return "Please enter a dish name.";
    }
    if len(name.strip()) > MAX_NAME {
        return f"A dish name can be up to {MAX_NAME} characters.";
    }
    if price < 1 or price > MAX_PRICE {
        return "Please enter a price above 0.";
    }
    return "";
}

def add_draft_dish_for(rest: Restaurant | None, section: str, name: str, price: int) -> DishResult {
    problem = refusal(rest);
    if problem == "" {
        problem = dish_problem(name, price);
    }
    if problem != "" or rest is None {
        return DishResult(ok=False, message=problem);
    }
    draft = draft_of(rest);
    if draft is None {
        draft = DraftMenu(created_at=now_iso(), steps=["Added by hand"]);
        rest +>:HasDraft:+> draft;
    }
    title = section.strip() or "Menu";
    sections = draft_sections(draft);
    match_sec = [s for s in sections if s.name.lower() == title.lower()];
    sec = match_sec[0] if match_sec else (draft +>:DraftHasSection:+> Section(name=title, position=len(sections)));
    dish = sec +>:HasDish:+> Dish(name=name.strip(), price=price, position=len(section_dishes(sec)), tags=[]);
    return DishResult(ok=True, dishes=[dish_view(dish)]);
}

"""Save the manager's edit. needs_check clears only if something really changed or the manager ticked it."""
def update_draft_dish_for(
    rest: Restaurant | None, dish_id: str, name: str, price: int, spicy: bool, is_veg: bool, allergens: list[str], confirm: bool
) -> DishResult {
    problem = refusal(rest);
    if problem == "" {
        problem = dish_problem(name, price);
    }
    kinds = normalise_allergens(allergens);
    if problem == "" and is_veg and ("fish" in kinds or "shellfish" in kinds) {
        problem = "A dish with fish or shellfish can't be vegetarian.";
    }
    if problem != "" or rest is None {
        return DishResult(ok=False, message=problem);
    }
    found = find_draft_dish(rest, dish_id);
    if found is None {
        return DishResult(ok=False, message="We couldn't find that dish in your draft.");
    }
    (sec, d) = found;
    changed = (
        d.name != name.strip() or d.price != price or d.spicy != spicy or d.is_veg != is_veg
        or sorted(d.allergens) != sorted(kinds)
    );
    d.name = name.strip();
    d.price = price;
    d.spicy = spicy;
    d.is_veg = is_veg;
    d.allergens = kinds;
    d.tags = tags_for(is_veg, spicy, kinds);
    if changed or confirm {
        d.needs_check = False;
    }
    return DishResult(ok=True, dishes=[dish_view(d)]);
}

def delete_draft_dish_for(rest: Restaurant | None, dish_id: str) -> SetupResult {
    problem = refusal(rest);
    if problem != "" or rest is None {
        return SetupResult(ok=False, message=problem);
    }
    found = find_draft_dish(rest, dish_id);
    if found is None {
        return SetupResult(ok=False, message="We couldn't find that dish in your draft.");
    }
    (sec, d) = found;
    del d;
    if len(section_dishes(sec)) == 0 {
        del sec;
    }
    return SetupResult(ok=True);
}

def discard_draft_for(rest: Restaurant | None) -> SetupResult {
    problem = refusal(rest);
    if problem != "" or rest is None {
        return SetupResult(ok=False, message=problem);
    }
    draft = draft_of(rest);
    if draft is not None {
        delete_draft_nodes(draft);
    }
    return SetupResult(ok=True);
}

def:protect add_draft_dish(section: str, name: str, price: int) -> DishResult {
    return add_draft_dish_for(my_restaurant(), section, name, price);
}

def:protect update_draft_dish(
    dish_id: str, name: str, price: int, spicy: bool, is_veg: bool, allergens: list[str], confirm: bool
) -> DishResult {
    return update_draft_dish_for(my_restaurant(), dish_id, name, price, spicy, is_veg, allergens, confirm);
}

def:protect delete_draft_dish(dish_id: str) -> SetupResult {
    return delete_draft_dish_for(my_restaurant(), dish_id);
}

def:protect discard_draft -> SetupResult {
    return discard_draft_for(my_restaurant());
}
