"""Menu endpoints. The client may call the def:pub / def:protect ones; the rest is server-only."""

import from .models { Restaurant, Section, Dish, Table, Manages, HasSection, HasDish, HasTable }
import from .seed { build_wet_water }

"""The restaurant the caller manages, found through their Manages edge."""
def my_restaurant -> Restaurant | None {
    mine = [root ->:Manages:-> [?:Restaurant]];
    return mine[0] if mine else None;
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
    has name: str,
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
        sections: list[SectionView] = [];
}

def section_views(rest: Restaurant) -> list[SectionView] {
    views: list[SectionView] = [];
    for sec in sorted([rest ->:HasSection:-> [?:Section]], key=lambda (s: Section) { s.position; }) {
        dishes = [
            DishView(name=d.name, price=d.price, tags=d.tags, sold_out=d.sold_out)
            for d in sorted([sec ->:HasDish:-> [?:Dish]], key=lambda (d: Dish) { d.position; })
        ];
        views.append(SectionView(name=sec.name, dishes=dishes));
    }
    return views;
}

"""Guest menu for a table link. Finds the restaurant through the table code, never "the first one"."""
def:pub get_menu(table_code: str) -> MenuView {
    published = [r for r in [root.shared -->[?:Restaurant]] if r.menu_published];
    if not published {
        return MenuView(status="coming_soon");
    }
    for rest in published {
        for table in [rest ->:HasTable:-> [?:Table]] {
            if table.code == table_code {
                return MenuView(
                    status="ready", restaurant=rest.name, table=table.label,
                    sections=section_views(rest)
                );
            }
        }
    }
    return MenuView(status="invalid");
}

"""Name of the caller's own restaurant ('' if none yet). Shown on the dashboard."""
def:protect my_restaurant_name -> str {
    rest = my_restaurant();
    return rest.name if rest is not None else "";
}
