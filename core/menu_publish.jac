"""Publish the draft (M-03): build-then-swap, so a crash halfway leaves the old menu, never a half menu."""

import from .models { Restaurant, Section, Dish, HasSection, HasDish, HasDraft, DraftHasSection }
import from .menu { my_restaurant, all_dishes }
import from .kitchen { refusal }
import from .seed { tags_for }
import from .menu_draft { SetupResult, draft_of, draft_sections, section_dishes, delete_draft_nodes }

def publish_draft_for(rest: Restaurant | None) -> SetupResult {
    problem = refusal(rest);
    if problem != "" or rest is None {
        return SetupResult(ok=False, message=problem);
    }
    draft = draft_of(rest);
    if draft is None {
        return SetupResult(ok=False, message="There is no draft to publish. Read your menu photos or add a dish first.");
    }
    drafted = [(s, section_dishes(s)) for s in draft_sections(draft)];
    total = sum([len(ds) for (s, ds) in drafted]);
    pending = len([d for (s, ds) in drafted for d in ds if d.needs_check]);
    if total == 0 {
        return SetupResult(ok=False, message="The draft is empty. Add a dish first.");
    }
    if pending > 0 {
        what = "dish still needs" if pending == 1 else "dishes still need";
        return SetupResult(ok=False, message=f"{pending} {what} your check. Fix or tick them, then publish.");
    }
    sold_out = {d.name.lower(): d.sold_out for d in all_dishes(rest)};
    # 1. Build the whole new menu. Nothing is linked to the restaurant yet.
    fresh: list[Section] = [];
    for (pos, (ds, dishes)) in enumerate(drafted) {
        sec = Section(name=ds.name, position=pos);
        for (dp, d) in enumerate(dishes) {
            dish = sec +>:HasDish:+> Dish(
                name=d.name, price=d.price, description=d.description, is_veg=d.is_veg, spicy=d.spicy,
                allergens=d.allergens, tags=tags_for(d.is_veg, d.spicy, d.allergens),
                sold_out=sold_out.get(d.name.lower(), False), needs_check=False, photo_url=d.photo_url, position=dp
            );
            grant(dish, level=AccessLevel.READ);
        }
        grant(sec, level=AccessLevel.READ);
        fresh.append(sec);
    }
    # 2. Swap: link the new sections, then detach the old ones.
    old = [rest ->:HasSection:-> [?:Section]];
    for sec in fresh {
        rest +>:HasSection:+> sec;
    }
    for o in old {
        del [edge rest ->:HasSection:-> o];
    }
    rest.menu_published = True;
    # 3. Clean up: the old live nodes and the draft are no longer needed (old orders keep their copied names and prices).
    for o in old {
        for d in [o ->:HasDish:-> [?:Dish]] {
            del d;
        }
        del o;
    }
    delete_draft_nodes(draft);
    return SetupResult(ok=True, message=f"Your menu is published with {total} dishes.");
}

"""Replace the live menu with the draft. Refused while any 'Please check' dish is left."""
def:protect publish_draft -> SetupResult {
    return publish_draft_for(my_restaurant());
}
