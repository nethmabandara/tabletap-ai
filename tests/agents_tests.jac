"""AI waiter tests with MockLLM (no API cost). Each call to the model needs its tool calls PLUS one extra final output."""

import time;
import from jaclang.byllm.lib { MockLLM, MockToolCall }
import from core.models { Restaurant, Section, Dish, Table, HasSection, HasDish, HasTable, Order, Placed }
import from core.menu { claim_demo_restaurant, find_table }
import from core.agents { WaiterRun, AgentAnswer, ChatTurn, MODEL_OVERRIDE }
import from core.waiter { ask_waiter, reset_waiter_throttle, LAST_ASK, BUSY_MESSAGE }
import from core.waiter_safety { PlanItem }

def answer(items: list[PlanItem], summary: str = "Here is a shared meal.", avoid: list[str] = [], budget: int = 5000) -> AgentAnswer {
    return AgentAnswer(items=items, summary=summary, avoid_allergens=avoid, budget=budget);
}

def item(name: str, qty: int = 1) -> PlanItem {
    return PlanItem(dish_name=name, qty=qty, reason=f"Good choice: {name}");
}

"""Install a mock model with these outputs. Every call needs its answer twice (the extra final output)."""
def mock(outputs: list[any]) -> MockLLM {
    reset_waiter_throttle();
    claim_demo_restaurant();
    m = MockLLM(outputs=outputs);
    MODEL_OVERRIDE.clear();
    MODEL_OVERRIDE.append(m);
    return m;
}

def done {
    MODEL_OVERRIDE.clear();
    reset_waiter_throttle();
}

def count_orders(code: str) -> int {
    found = find_table(code);
    assert found is not None;
    (rest, table) = found;
    return len([table ->:Placed:-> [?:Order]]);
}

def names_of(plan: any) -> list[str] {
    return [i.dish_name for i in plan.items];
}

def ask(code: str, text: str, history: list[ChatTurn] = []) -> any {
    return ask_waiter(code, text, history);
}

test "tools log their own steps and two runs never mix" {
    claim_demo_restaurant();
    a = WaiterRun(table_code="t5");
    b = WaiterRun(table_code="t6");
    found = a.search_menu("fried rice", False, [], 0);
    assert len(found) >= 4;
    assert b.check_available(["EGB", "Not A Dish"]) == ["Not A Dish"];
    assert a.cart_total(["Sprite"], [2]) == 300;
    prawns = a.get_dish("Devilled Prawns");
    assert prawns is not None and "shellfish" in prawns.allergens;
    assert a.get_dish("No Such Dish") is None;
    assert len(a.steps) == 4 and len(b.steps) == 1;
    assert a.steps[0].startswith("search_menu(fried rice) · ");
    assert "cart_total · Rs 300" in a.steps;
    assert b.steps[0].startswith("check_available");
    assert WaiterRun(table_code="t7").steps == [];
}

test "search_menu hides dishes with off-limits allergens and sold-out dishes" {
    claim_demo_restaurant();
    safe = WaiterRun(table_code="t5", restricted=["shellfish"]);
    names = [d.name for d in safe.search_menu("", False, [], 0)];
    assert "Devilled Prawns" not in names and "Seafood Fried Rice" not in names and "Mixed Fried Rice" not in names;
    assert "Chicken Fried Rice" in names;
    assert "hid" in safe.steps[0];
    veg = WaiterRun(table_code="t5").search_menu("", True, ["gluten"], 800);
    assert all([d.is_veg and "gluten" not in d.allergens and d.price <= 800 for d in veg]);
}

test "one AI call: plan, steps from the tools, no order is created" {
    m = mock([
        MockToolCall(tool="search_menu", args={"query": "rice", "veg_only": False, "exclude_allergens": [], "max_price": 0}),
        MockToolCall(tool="cart_total", args={"dish_names": ["Sprite"], "quantities": [2]}),
        answer([item("Vegetable Fried Rice"), item("Chicken Fried Rice"), item("Sprite", 2)]),
        answer([item("Vegetable Fried Rice"), item("Chicken Fried Rice"), item("Sprite", 2)])
    ]);
    before = count_orders("t1");
    plan = ask("t1", "We're 4, one vegetarian, about Rs 5000");
    assert plan.ok;
    assert names_of(plan) == ["Vegetable Fried Rice", "Chicken Fried Rice", "Sprite"];
    assert plan.total == 750 + 850 + 300;
    assert plan.items[0].dish_id != "" and plan.items[0].reason.startswith("Good choice");
    assert plan.summary == "Here is a shared meal." and plan.warnings == [];
    assert any([s.startswith("search_menu(rice)") for s in plan.steps]);
    assert "cart_total · Rs 300" in plan.steps;
    assert plan.steps[-1].startswith("safety check · all 3 dishes");
    assert m.exhausted();
    assert count_orders("t1") == before;
    done();
}

test "the guest's words and the rules reach the agent; notes are built by code" {
    m = mock([
        answer([item("Chicken Fried Rice")], avoid=["fish", "nuts"]),
        answer([item("Chicken Fried Rice")], avoid=["fish", "nuts"])
    ]);
    plan = ask("t2", "one allergic to prawns, no fish please");
    prompt = str(m.sent("messages")[0]);
    assert "ALLERGIES" in prompt and "shellfish (prawns)" in prompt and "PREFERENCES" in prompt;
    assert plan.allergy_note == "Allergy: shellfish (prawns)";
    assert plan.preference_note == "Preference: no fish, no nuts";
    done();
}

test "removal triggers exactly one retry and the AI summary of the clean retry is shown" {
    bad = answer([item("Devilled Prawns"), item("Vegetable Fried Rice")], summary="FIRST SUMMARY");
    good = answer([item("Chicken Fried Rice"), item("Vegetable Fried Rice")], summary="SECOND SUMMARY");
    m = mock([bad, bad, good, good]);
    plan = ask("t3", "We're 2, allergic to prawns, about Rs 3000");
    assert plan.ok and m.exhausted();
    assert "Devilled Prawns" not in names_of(plan) and "Chicken Fried Rice" in names_of(plan);
    assert plan.summary == "SECOND SUMMARY";
    assert any([s.startswith("safety check · removed Devilled Prawns (contains shellfish)") for s in plan.steps]);
    assert "asking the waiter again for safe replacements" in plan.steps;
    sent = [str(x) for x in m.sent("messages")];
    retry_prompts = [x for x in sent if "Devilled Prawns (contains shellfish)" in x];
    assert len(retry_prompts) >= 1 and "Devilled Prawns (contains shellfish)" not in sent[0];
    done();
}

test "at most one retry: still-unsafe second answer gives a code-written summary and no third call" {
    bad = answer([item("Devilled Prawns"), item("Vegetable Fried Rice")], summary="AI SUMMARY");
    m = mock([bad, bad, bad, bad, bad, bad]);
    plan = ask("t4", "allergic to prawns");
    assert len(m.outputs) == 2;
    assert plan.ok and names_of(plan) == ["Vegetable Fried Rice"];
    assert plan.summary == "Adjusted by safety check: removed Devilled Prawns. Total Rs 750.";
    assert "AI SUMMARY" not in plan.summary;
    done();
}

test "if the retry fails, the safe part of the first answer is shown, not a busy message" {
    bad = answer([item("Devilled Prawns"), item("Vegetable Fried Rice")]);
    m = mock([bad, bad]);
    plan = ask("t5", "allergic to prawns");
    assert plan.ok and plan.message == "";
    assert names_of(plan) == ["Vegetable Fried Rice"];
    assert plan.summary.startswith("Adjusted by safety check: removed Devilled Prawns.");
    assert "second try failed · showing the safe part of the first answer" in plan.steps;
    assert m.exhausted();
    done();
}

test "if the first AI call fails the guest gets the friendly message and nothing is ordered" {
    mock([]);
    before = count_orders("t6");
    plan = ask("t6", "something nice for 4");
    assert not plan.ok and plan.message == BUSY_MESSAGE;
    assert plan.items == [];
    assert count_orders("t6") == before;
    done();
}

test "a later positive mention lifts a preference but never an allergy" {
    fish = answer([item("Fish Pepper Stew"), item("Vegetable Fried Rice")]);
    mock([fish, fish]);
    lifted = ask("t7", "we love fish", [ChatTurn(role="guest", text="no fish please"), ChatTurn(role="waiter", text="Suggested: rice")]);
    assert "Fish Pepper Stew" in names_of(lifted) and lifted.preference_note == "";
    done();
    mock([fish, fish, fish, fish]);
    kept = ask("t8", "we love fish", [ChatTurn(role="guest", text="my son is allergic to fish")]);
    assert "Fish Pepper Stew" not in names_of(kept);
    assert kept.allergy_note == "Allergy: fish";
    done();
}

test "a waiter never sees another restaurant's dishes" {
    claim_demo_restaurant();
    other = root.shared ++> Restaurant(name="Other Cafe", slug="other-cafe-test", menu_published=True);
    sec = other +>:HasSection:+> Section(name="Specials", position=0);
    secret = sec +>:HasDish:+> Dish(name="Zebra Special Only B", price=500, position=0);
    table = other +>:HasTable:+> Table(label="Table 1", code="tb9");
    try {
        wa = WaiterRun(table_code="t5");
        wb = WaiterRun(table_code="tb9");
        assert [d.name for d in wa.search_menu("zebra", False, [], 0)] == [];
        assert wa.get_dish("Zebra Special Only B") is None;
        assert wa.check_available(["Zebra Special Only B"]) == ["Zebra Special Only B"];
        assert [d.name for d in wb.search_menu("", False, [], 0)] == ["Zebra Special Only B"];
        assert wb.get_dish("Sprite") is None;
        assert wb.search_menu("rice", False, [], 0) == [];
        sneaky = answer([item("Zebra Special Only B"), item("Chicken Fried Rice")]);
        m = mock([sneaky, sneaky, sneaky, sneaky]);
        plan = ask("t5", "dinner for 2");
        assert "Zebra Special Only B" not in names_of(plan);
        assert any([s.startswith("safety check · removed Zebra Special Only B (not on the menu)") for s in plan.steps]);
    } finally {
        done();
        del secret;
        del sec;
        del table;
        del other;
    }
}

test "one waiter request per table every 5 seconds, with a friendly message and no extra AI call" {
    ok = answer([item("Chicken Fried Rice")]);
    m = mock([ok, ok, ok, ok, ok, ok]);
    first = ask("t1", "dinner for 2");
    assert first.ok and len(m.outputs) == 4;
    again = ask("t1", "and a dessert");
    assert not again.ok and "wait a few seconds" in again.message;
    assert len(m.outputs) == 4;
    elsewhere = ask("t2", "dinner for 2");
    assert elsewhere.ok;
    LAST_ASK["t1"] = time.monotonic() - 10.0;
    assert ask("t1", "and a dessert").ok;
    done();
}

test "empty, too long and invalid-table requests are refused before any AI call" {
    m = mock([]);
    assert not ask("t1", "   ").ok;
    assert "too long" in ask("t1", "x" * 501).message;
    assert ask("nope", "dinner").message == "This table link isn't valid.";
    assert len(m.outputs) == 0;
    done();
}
