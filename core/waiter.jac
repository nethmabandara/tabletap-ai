"""AI Waiter flow (G-04). ask_waiter ONLY suggests; it never places an order.

1. Read the guests' restrictions in code (waiter_rules).
2. Ask the agent (call 1). If it fails: friendly "busy" message.
3. Check the answer in code (waiter_safety). If anything was removed: ask once more (call 2),
   check again. If call 2 fails, show the safe part of the first answer. Never more than 2 AI calls.
4. If the FINAL plan still had removals, the summary is written by code, not by the AI.
"""

import time;
import traceback;
import from .menu { find_table, dish_facts }
import from .agents { WaiterRun, WaiterPlan, PlanLine, ChatTurn, AgentAnswer }
import from .waiter_rules { Rules, read_rules, merge_ai_avoid, restricted_allergens, build_notes, rules_text }
import from .waiter_safety { check_plan, adjusted_summary, money_text, DishFacts, SafetyResult, Removed }

glob MAX_MESSAGE = 500,
     MAX_TURNS = 10,
     MAX_TURN_CHARS = 600,
     COOLDOWN_SECONDS = 5.0,
     BUSY_MESSAGE = "The AI waiter is busy right now. You can still add dishes from the menu.";

# One waiter request per table every few seconds; one in flight per table.
glob LAST_ASK: dict[str, float] = {},
     IN_FLIGHT: list[str] = [];

def reset_waiter_throttle {
    LAST_ASK.clear();
    IN_FLIGHT.clear();
}

def refuse(message: str) -> WaiterPlan {
    return WaiterPlan(ok=False, message=message);
}

def clean_history(history: list[ChatTurn]) -> list[ChatTurn] {
    kept = [t for t in history if t.role in ["guest", "waiter"]];
    return [ChatTurn(role=t.role, text=t.text[:MAX_TURN_CHARS]) for t in kept[-MAX_TURNS:]];
}

def conversation_text(turns: list[ChatTurn]) -> str {
    return "\n".join([("Guest: " if t.role == "guest" else "Waiter: ") + t.text for t in turns]);
}

def describe_removed(removed: list[Removed]) -> str {
    return "; ".join([f"{r.dish_name} ({r.reason})" for r in removed]);
}

def report_failure(where: str) {
    print(f"AI waiter error ({where}):");
    traceback.print_exc();
}

"""Run the safety check and log it as a step."""
def checked(run: WaiterRun, answer: AgentAnswer, facts: list[DishFacts], rules: Rules, budget: int) -> SafetyResult {
    result = check_plan(answer.items, facts, restricted_allergens(rules), budget);
    if result.removed {
        run.steps.append("safety check · removed " + describe_removed(result.removed));
    } else {
        run.steps.append(f"safety check · all {len(result.items)} dishes are safe and available");
    }
    return result;
}

def build_plan(run: WaiterRun, facts: list[DishFacts], final: SafetyResult, answer: AgentAnswer, rules: Rules) -> WaiterPlan {
    by_name = {f.name.lower(): f for f in facts};
    lines: list[PlanLine] = [];
    for i in final.items {
        f = by_name[i.dish_name.lower()];
        lines.append(PlanLine(dish_id=f.id, dish_name=f.name, qty=i.qty, reason=i.reason, price=f.price, is_veg=f.is_veg));
    }
    warnings = list(final.warnings);
    if not lines {
        warnings.append("We couldn't put a safe order together. You can still add dishes from the menu.");
    }
    (allergy, preference) = build_notes(rules);
    return WaiterPlan(
        ok=True,
        items=lines,
        total=final.total,
        summary=adjusted_summary(final.removed, final.total) if final.removed else answer.summary,
        warnings=warnings,
        steps=run.steps,
        allergy_note=allergy,
        preference_note=preference
    );
}

def run_waiter(table_code: str, facts: list[DishFacts], message: str, history: list[ChatTurn]) -> WaiterPlan {
    turns = clean_history(history);
    chat = conversation_text(turns);
    rules = read_rules([t.text for t in turns if t.role == "guest"] + [message]);
    run = WaiterRun(table_code=table_code, restricted=restricted_allergens(rules));
    (allergy_line, preference_line) = build_notes(rules);
    found_rules = " · ".join([x for x in [allergy_line, preference_line] if x]);
    run.steps.append("read your request · " + (found_rules if found_rules else "no restrictions found"));
    try {
        first = run.plan(message, chat, rules_text(rules));
    } except Exception {
        report_failure("first call");
        return refuse(BUSY_MESSAGE);
    }
    rules1 = merge_ai_avoid(rules, first.avoid_allergens);
    check1 = checked(run, first, facts, rules1, first.budget);
    (final, answer, final_rules) = (check1, first, rules1);
    if check1.removed {
        run.steps.append("asking the waiter again for safe replacements");
        run.restricted = restricted_allergens(rules1);
        try {
            second = run.retry(message, chat, rules_text(rules1), check1.items, describe_removed(check1.removed));
            rules2 = merge_ai_avoid(rules1, second.avoid_allergens);
            budget = second.budget if second.budget > 0 else first.budget;
            (final, answer, final_rules) = (checked(run, second, facts, rules2, budget), second, rules2);
        } except Exception {
            report_failure("second call");
            run.steps.append("second try failed · showing the safe part of the first answer");
        }
    }
    return build_plan(run, facts, final, answer, final_rules);
}

"""Ask the AI waiter. Returns a plan for the guests to review. Never creates an order."""
def:pub ask_waiter(table_code: str, message: str, history: list[ChatTurn]) -> WaiterPlan {
    text = message.strip();
    if text == "" {
        return refuse("Please tell the waiter what you would like.");
    }
    if len(text) > MAX_MESSAGE {
        return refuse(f"Your message is too long (up to {MAX_MESSAGE} characters). Please shorten it.");
    }
    found = find_table(table_code);
    if found is None {
        return refuse("This table link isn't valid.");
    }
    (rest, table) = found;
    if table_code in IN_FLIGHT {
        return refuse("The waiter is still working on your last request. Please wait a moment.");
    }
    now = time.monotonic();
    if now - LAST_ASK.get(table_code, -1000.0) < COOLDOWN_SECONDS {
        return refuse("Please wait a few seconds before asking again.");
    }
    LAST_ASK[table_code] = now;
    IN_FLIGHT.append(table_code);
    try {
        return run_waiter(table_code, dish_facts(rest), text, history);
    } finally {
        IN_FLIGHT.remove(table_code);
    }
}
