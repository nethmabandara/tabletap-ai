"""The menu DRAFT (M-02, M-03): saved apart from the live menu, edited by the manager, published later.
Every endpoint passes the caller's own restaurant to a *_for function that first checks the Manages edge.
"""

import from datetime { datetime, timezone }
import from .models { Restaurant, Section, Dish, DraftMenu, HasDraft, DraftHasSection, HasDish }
import from .menu { my_restaurant }
import from .kitchen { refusal }
import from .seed { tags_for }
import from .waiter_rules { normalise_allergens }
import from .menu_rules { CleanSection }

glob MAX_NAME = 80,
     MAX_PRICE = 1000000;

obj SetupResult {
    has ok: bool,
        message: str = "",
        failed_photos: list[int] = [];
}

obj DraftDishView {
    has id: str,
        name: str,
        price: int,
        spicy: bool,
        is_veg: bool,
        allergens: list[str],
        needs_check: bool;
}

obj DraftSectionView {
    has name: str,
        dishes: list[DraftDishView];
}

obj DraftView {
    has ok: bool,
        message: str = "",
        exists: bool = False,
        steps: list[str] = [],
        sections: list[DraftSectionView] = [],
        dish_count: int = 0,
        need_check: int = 0;
}

"""Zero or one dish (a list keeps it simple on the wire)."""
obj DishResult {
    has ok: bool,
        message: str = "",
        dishes: list[DraftDishView] = [];
}

def now_iso -> str {
    return datetime.now(timezone.utc).isoformat();
}

def draft_of(rest: Restaurant) -> DraftMenu | None {
    found = [rest ->:HasDraft:-> [?:DraftMenu]];
    return found[0] if found else None;
}

def draft_sections(draft: DraftMenu) -> list[Section] {
    return sorted([draft ->:DraftHasSection:-> [?:Section]], key=lambda (s: Section) { s.position; });
}

def section_dishes(sec: Section) -> list[Dish] {
    return sorted([sec ->:HasDish:-> [?:Dish]], key=lambda (d: Dish) { d.position; });
}

def dish_view(d: Dish) -> DraftDishView {
    return DraftDishView(
        id=jid(d), name=d.name, price=d.price, spicy=d.spicy, is_veg=d.is_veg,
        allergens=d.allergens, needs_check=d.needs_check
    );
}

"""Remove a draft and everything under it. Only draft nodes are touched, never the live menu."""
def delete_draft_nodes(draft: DraftMenu) {
    for sec in draft_sections(draft) {
        for d in section_dishes(sec) {
            del d;
        }
        del sec;
    }
    del draft;
}

"""Build the new draft first, attach it, then remove the old one."""
def save_draft(rest: Restaurant, sections: list[CleanSection], steps: list[str], failed: list[int], photos: int) {
    old = [rest ->:HasDraft:-> [?:DraftMenu]];
    draft = DraftMenu(created_at=now_iso(), photo_count=photos, steps=steps, failed=failed);
    for (pos, cs) in enumerate(sections) {
        sec = draft +>:DraftHasSection:+> Section(name=cs.name, position=pos);
        for (dp, d) in enumerate(cs.dishes) {
            sec +>:HasDish:+> Dish(
                name=d.name, price=d.price, description=d.description, is_veg=d.is_veg, spicy=d.spicy,
                allergens=d.allergens, tags=tags_for(d.is_veg, d.spicy, d.allergens),
                needs_check=d.needs_check, position=dp
            );
        }
    }
    rest +>:HasDraft:+> draft;
    for o in old {
        delete_draft_nodes(o);
    }
}

def find_draft_dish(rest: Restaurant, dish_id: str) -> tuple[Section, Dish] | None {
    draft = draft_of(rest);
    if draft is None {
        return None;
    }
    for sec in draft_sections(draft) {
        for d in section_dishes(sec) {
            if jid(d) == dish_id {
                return (sec, d);
            }
        }
    }
    return None;
}

def get_draft_for(rest: Restaurant | None) -> DraftView {
    problem = refusal(rest);
    if problem != "" or rest is None {
        return DraftView(ok=False, message=problem);
    }
    draft = draft_of(rest);
    if draft is None {
        return DraftView(ok=True);
    }
    sections = [DraftSectionView(name=s.name, dishes=[dish_view(d) for d in section_dishes(s)]) for s in draft_sections(draft)];
    dishes = [d for s in sections for d in s.dishes];
    return DraftView(
        ok=True, exists=True, steps=draft.steps, sections=sections, dish_count=len(dishes),
        need_check=len([d for d in dishes if d.needs_check])
    );
}

def:protect get_draft -> DraftView {
    return get_draft_for(my_restaurant());
}
