"""Menu endpoints. The client may call the def:pub / def:protect ones; the rest is server-only."""

import from .models { Restaurant, Section, Dish, Table, Manages, HasSection, HasDish, HasTable }
import from .seed { build_wet_water }
import from .waiter_safety { DishFacts }

"""The restaurant the caller manages, found through their Manages edge.
Also records the manager's root on it (older restaurants lack this), so guest orders can be shared with the owner only."""
def my_restaurant -> Restaurant | None {
    mine = [root ->:Manages:-> [?:Restaurant]];
    if not mine {
        return None;
    }
    if mine[0].owner_root != jid(root) {
        mine[0].owner_root = jid(root);
    }
    return mine[0];
}

"""True if any manager has already claimed the Wet Water demo (it can be claimed only once)."""
def demo_claimed -> bool {
    return len([root.shared -->[?:Restaurant, slug == "wet-water"]]) > 0;
}

"""Create the Wet Water starting data for this manager. True only if created now."""
def:protect claim_demo_restaurant -> bool {
    if my_restaurant() is not None or demo_claimed() {
        return False;
    }
    build_wet_water();
    return True;
}

"""One dish as the guest sees it. Plain obj, so no graph nodes cross to the browser."""
obj DishView {
    has id: str,
        name: str,
        price: int,
        tags: list[str],
        sold_out: bool;
}

obj SectionView {
    has name: str,
        dishes: list[DishView];
}

"""What a table page shows. status: ready, coming_soon or invalid."""
obj MenuView {
    has status: str,
        restaurant: str = "",
        table: str = "",
        music_mode: str = "off",
        sections: list[SectionView] = [];
}

def section_views(rest: Restaurant) -> list[SectionView] {
    views: list[SectionView] = [];
    for sec in sorted([rest ->:HasSection:-> [?:Section]], key=lambda (s: Section) { s.position; }) {
        dishes = [
            DishView(id=jid(d), name=d.name, price=d.price, tags=d.tags, sold_out=d.sold_out)
            for d in sorted([sec ->:HasDish:-> [?:Dish]], key=lambda (d: Dish) { d.position; })
        ];
        views.append(SectionView(name=sec.name, dishes=dishes));
    }
    return views;
}

"""The restaurant and table that own a table code. Looks through ALL restaurants, published or not.
This is the ONE way guest-side code finds a restaurant: by table code, never "the first one". None if no table has this code."""
def restaurant_for_table(table_code: str) -> tuple[Restaurant, Table] | None {
    for rest in [root.shared -->[?:Restaurant]] {
        for table in [rest ->:HasTable:-> [?:Table]] {
            if table.code == table_code {
                return (rest, table);
            }
        }
    }
    return None;
}

"""Every table code in use by any restaurant (codes must be unique across all of them)."""
def all_table_codes -> list[str] {
    codes: list[str] = [];
    for rest in [root.shared -->[?:Restaurant]] {
        codes += [t.code for t in [rest ->:HasTable:-> [?:Table]]];
    }
    return codes;
}

"""Guest menu for a table link. ready, coming_soon (restaurant has no published menu yet) or invalid."""
def:pub get_menu(table_code: str) -> MenuView {
    found = restaurant_for_table(table_code);
    if found is None {
        # Before any restaurant exists every link says "coming soon" (S-01); afterwards an unknown code is invalid.
        return MenuView(status="invalid" if len([root.shared -->[?:Restaurant]]) > 0 else "coming_soon");
    }
    (rest, table) = found;
    if not rest.menu_published {
        return MenuView(status="coming_soon", restaurant=rest.name, table=table.label);
    }
    return MenuView(
        status="ready", restaurant=rest.name, table=table.label, music_mode=rest.music_mode, sections=section_views(rest)
    );
}

"""Name of the caller's own restaurant ('' if none yet). Shown on the dashboard."""
def:protect my_restaurant_name -> str {
    rest = my_restaurant();
    return rest.name if rest is not None else "";
}

"""Every dish of a restaurant, across its sections."""
def all_dishes(rest: Restaurant) -> list[Dish] {
    dishes: list[Dish] = [];
    for sec in [rest ->:HasSection:-> [?:Section]] {
        dishes += [sec ->:HasDish:-> [?:Dish]];
    }
    return dishes;
}

"""Plain facts about every dish of ONE restaurant, for the AI waiter and its safety checks."""
def dish_facts(rest: Restaurant) -> list[DishFacts] {
    facts: list[DishFacts] = [];
    for sec in sorted([rest ->:HasSection:-> [?:Section]], key=lambda (s: Section) { s.position; }) {
        for d in sorted([sec ->:HasDish:-> [?:Dish]], key=lambda (d: Dish) { d.position; }) {
            facts.append(DishFacts(
                id=jid(d), name=d.name, price=d.price, allergens=d.allergens,
                is_veg=d.is_veg, sold_out=d.sold_out, section=sec.name
            ));
        }
    }
    return facts;
}
