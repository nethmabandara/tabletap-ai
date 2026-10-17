"""Safety checks after the AI waiter answers (G-04). Pure code: no graph, no AI.

The AI only suggests. Code drops anything unsafe, merges duplicates and recomputes the total.
"""

glob MAX_QTY = 20,
     MAX_LINES = 30;

obj DishFacts {
    has id: str,
        name: str,
        price: int,
        allergens: list[str],
        is_veg: bool,
        sold_out: bool,
        section: str = "";
}

obj PlanItem {
    has dish_name: str,
        qty: int,
        reason: str;
}
sem PlanItem = "One dish in the suggested order.";
sem PlanItem.dish_name = "The dish name exactly as the menu tools return it.";
sem PlanItem.qty = "How many of this dish, at least 1.";
sem PlanItem.reason = "One short sentence on why this dish suits the table.";

obj Removed {
    has dish_name: str,
        reason: str;
}

obj SafetyResult {
    has items: list[PlanItem],
        removed: list[Removed],
        total: int,
        warnings: list[str];
}

def money_text(amount: int) -> str {
    digits = str(amount);
    return "Rs " + (digits[:len(digits) - 3] + "," + digits[len(digits) - 3:] if len(digits) > 3 else digits);
}

"""Exact total in rupees, worked out by code. Dishes not on the menu count as 0."""
def cart_total(items: list[PlanItem], facts: list[DishFacts]) -> int {
    prices = {f.name.lower(): f.price for f in facts};
    return sum([prices.get(i.dish_name.strip().lower(), 0) * i.qty for i in items]);
}

"""Why this dish cannot be served to these guests, or '' if it is fine."""
def problem_with(fact: DishFacts | None, restricted: list[str]) -> str {
    if fact is None {
        return "not on the menu";
    }
    if fact.sold_out {
        return "sold out today";
    }
    hits = [a for a in fact.allergens if a in restricted];
    return ("contains " + ", ".join(hits)) if hits else "";
}

"""Keep only safe dishes. Merge duplicates, cap quantities, recompute the total, and explain every removal."""
def check_plan(items: list[PlanItem], facts: list[DishFacts], restricted: list[str], budget: int) -> SafetyResult {
    by_name = {f.name.lower(): f for f in facts};
    kept: list[PlanItem] = [];
    removed: list[Removed] = [];
    for item in items {
        fact = by_name.get(item.dish_name.strip().lower());
        problem = problem_with(fact, restricted);
        if problem == "" and item.qty < 1 {
            problem = "quantity below 1";
        }
        if problem == "" and len(kept) >= MAX_LINES and item.dish_name not in [k.dish_name for k in kept] {
            problem = "too many dishes in one order";
        }
        if problem != "" {
            removed.append(Removed(dish_name=item.dish_name, reason=problem));
            continue;
        }
        name = fact.name if fact is not None else item.dish_name;
        merged = [k for k in kept if k.dish_name == name];
        if merged {
            merged[0].qty = min(MAX_QTY, merged[0].qty + item.qty);
        } else {
            kept.append(PlanItem(dish_name=name, qty=min(MAX_QTY, item.qty), reason=item.reason));
        }
    }
    total = cart_total(kept, facts);
    warnings = [f"Removed {r.dish_name}: {r.reason}." for r in removed];
    if budget > 0 and total > budget {
        warnings.append(f"The total ({money_text(total)}) is over your budget ({money_text(budget)}).");
    }
    return SafetyResult(items=kept, removed=removed, total=total, warnings=warnings);
}

"""Summary written by code when the safety check removed something from the final plan."""
def adjusted_summary(removed: list[Removed], total: int) -> str {
    names = ", ".join([r.dish_name for r in removed]);
    return f"Adjusted by safety check: removed {names}. Total {money_text(total)}.";
}
