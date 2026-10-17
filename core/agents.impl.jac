"""Tool bodies for the AI waiter. Each reads ONLY the menu of this table's restaurant and logs one step."""

import from .waiter_rules { normalise_allergens }
import from .waiter_safety { money_text }

def brief_of(f: DishFacts) -> DishBrief {
    return DishBrief(
        name=f.name, price=f.price, section=f.section, is_veg=f.is_veg,
        allergens=f.allergens, available=not f.sold_out
    );
}

impl WaiterRun.search_menu(query: str, veg_only: bool, exclude_allergens: list[str], max_price: int) -> list[DishBrief] {
    facts = [f for f in facts_for_table(self.table_code) if not f.sold_out];
    blocked = normalise_allergens(exclude_allergens) + [a for a in self.restricted if a not in normalise_allergens(exclude_allergens)];
    words = [w for w in query.lower().replace(",", " ").split() if w not in ["dish", "dishes", "food", "vegetarian", "veg"]];
    found: list[DishBrief] = [];
    hidden = 0;
    for f in facts {
        text = (f.name + " " + f.section).lower();
        if veg_only and not f.is_veg {
            continue;
        }
        if max_price > 0 and f.price > max_price {
            continue;
        }
        if words and not any([w in text for w in words]) {
            continue;
        }
        if any([a in blocked for a in f.allergens]) {
            hidden += 1;
            continue;
        }
        found.append(brief_of(f));
    }
    shown = (("vegetarian " if veg_only else "") + query.strip()).strip() or "all dishes";
    note = f" · hid {hidden} with {', '.join(blocked)}" if hidden > 0 and blocked else "";
    self.steps.append(f"search_menu({shown}) · {len(found)} dishes{note}");
    return found[:40];
}

impl WaiterRun.get_dish(name: str) -> DishBrief | None {
    hits = [f for f in facts_for_table(self.table_code) if f.name.lower() == name.strip().lower()];
    self.steps.append(f"get_dish({name.strip()})" + ("" if hits else " · not on the menu"));
    return brief_of(hits[0]) if hits else None;
}

impl WaiterRun.check_available(names: list[str]) -> list[str] {
    by_name = {f.name.lower(): f for f in facts_for_table(self.table_code)};
    unavailable: list[str] = [];
    for n in names {
        f = by_name.get(n.strip().lower());
        if f is None or f.sold_out {
            unavailable.append(n);
        }
    }
    self.steps.append("check_available · " + (", ".join(unavailable) + " sold out or missing" if unavailable else "all available"));
    return unavailable;
}
