"""The AI Waiter agent (G-04): result types and the per-request WaiterRun.

Server-only. Every request builds its own WaiterRun, so its steps list is never shared.
The tools are methods of WaiterRun and each adds one line to that run's steps.
The AI only SUGGESTS: the flow in waiter.jac checks everything in code afterwards.
"""

import from .waiter_safety { PlanItem, DishFacts, money_text, cart_total as total_of }
import from .menu { restaurant_for_table, dish_facts }

# Tests put a MockLLM here. Empty in production: the model from jac.toml [byllm.model] is used.
glob MODEL_OVERRIDE: list[any] = [];

obj DishBrief {
    has name: str,
        price: int,
        section: str,
        is_veg: bool,
        allergens: list[str],
        available: bool;
}
sem DishBrief = "A dish as the menu tools describe it.";
sem DishBrief.price = "Price in whole Sri Lankan rupees.";
sem DishBrief.allergens = "Allergens in the dish: shellfish, fish, nuts, egg, dairy or gluten.";
sem DishBrief.available = "False if the dish is sold out today.";

obj AgentAnswer {
    has items: list[PlanItem],
        summary: str,
        avoid_allergens: list[str] = [],
        budget: int = 0;
}
sem AgentAnswer = "The waiter's suggested order for the table. Code checks it afterwards.";
sem AgentAnswer.items = "The dishes to order, with quantities and one-line reasons.";
sem AgentAnswer.summary = "One or two friendly sentences explaining the order to the guests.";
sem AgentAnswer.avoid_allergens = "Allergens the guests want to avoid: shellfish, fish, nuts, egg, dairy, gluten.";
sem AgentAnswer.budget = "The guests' budget in rupees, or 0 if they gave none.";

obj ChatTurn {
    has role: str,
        text: str;
}
sem ChatTurn = "One earlier message in the conversation.";
sem ChatTurn.role = "'guest' or 'waiter'.";
sem ChatTurn.text = "What was said.";

obj PlanLine {
    has dish_id: str,
        dish_name: str,
        qty: int,
        reason: str,
        price: int,
        is_veg: bool;
}

"""What the screen gets back. Never an order: the guests confirm first."""
obj WaiterPlan {
    has ok: bool,
        message: str = "",
        items: list[PlanLine] = [],
        total: int = 0,
        summary: str = "",
        warnings: list[str] = [],
        steps: list[str] = [],
        allergy_note: str = "",
        preference_note: str = "";
}

def facts_for_table(code: str) -> list[DishFacts] {
    found = restaurant_for_table(code);
    if found is None {
        return [];
    }
    (rest, table) = found;
    return dish_facts(rest) if rest.menu_published else [];
}

obj WaiterRun {
    has table_code: str,
        restricted: list[str] = [],
        steps: list[str] = [],
        model: any {
            getter -> any { return MODEL_OVERRIDE[0] if MODEL_OVERRIDE else llm; }
        };

    def search_menu(query: str, veg_only: bool, exclude_allergens: list[str], max_price: int) -> list[DishBrief];
    def get_dish(name: str) -> DishBrief | None;
    def check_available(names: list[str]) -> list[str];
    def cart_total(dish_names: list[str], quantities: list[int]) -> int {
        lines = [PlanItem(dish_name=n, qty=q, reason="") for (n, q) in zip(dish_names, quantities)];
        total = total_of(lines, facts_for_table(self.table_code));
        self.steps.append(f"cart_total · {money_text(total)}");
        return total;
    }
    def plan(message: str, conversation: str, rules: str) -> AgentAnswer
        by self.model(tools=[self.search_menu, self.get_dish, self.check_available, self.cart_total], max_react_iterations=10);
    def retry(message: str, conversation: str, rules: str, kept: list[PlanItem], removed: str) -> AgentAnswer
        by self.model(tools=[self.search_menu, self.get_dish, self.check_available, self.cart_total], max_react_iterations=10);
}

sem WaiterRun = "The waiter for one table, for one request.";
sem WaiterRun.table_code = "The table this waiter is serving. Only this table's restaurant menu exists for you.";
sem WaiterRun.restricted = "Allergens already known to be off limits. search_menu hides dishes that contain them.";
sem WaiterRun.steps = "What the waiter checked so far, one short line each.";

sem WaiterRun.search_menu = "Find dishes on the menu that are NOT sold out. Dishes with off-limits allergens are hidden.";
sem WaiterRun.search_menu.query = "Words to look for in dish names and sections, like 'rice' or 'dessert'. Empty means everything.";
sem WaiterRun.search_menu.veg_only = "True to return only vegetarian dishes.";
sem WaiterRun.search_menu.exclude_allergens = "Allergens to leave out: shellfish, fish, nuts, egg, dairy, gluten.";
sem WaiterRun.search_menu.max_price = "Highest price of one dish in rupees. 0 means no limit.";
sem WaiterRun.get_dish = "Look up one dish by its exact name: price, allergens and whether it is available. None if it is not on the menu.";
sem WaiterRun.get_dish.name = "The dish name.";
sem WaiterRun.check_available = "Return the names from the list that are sold out today or not on the menu. An empty list means all are available.";
sem WaiterRun.check_available.names = "Dish names to check.";
sem WaiterRun.cart_total = "The exact total in rupees for these dishes. Always use this instead of adding up prices yourself.";
sem WaiterRun.cart_total.dish_names = "Dish names exactly as the menu returns them.";
sem WaiterRun.cart_total.quantities = "How many of each dish. Same length and order as dish_names.";

sem WaiterRun.plan =
    "You are the waiter at a restaurant table. Plan ONE shared order for the guests' latest request. "
    "Use search_menu to find dishes, get_dish for details, check_available to be sure nothing is sold out, "
    "and cart_total for the exact total. "
    "Choose enough food for the group: about 1.5 dishes per person, plus dessert or drinks if the budget allows. "
    "Use most of the budget without going over it. "
    "If a guest is vegetarian, include at least 2 vegetarian dishes. "
    "Never include a dish whose allergens appear in the RULES. Map words like prawns, shrimp or crab to the shellfish allergen. "
    "Use dish names exactly as the tools return them. Give every dish a one-sentence reason. "
    "Set budget to the guests' rupee budget, or 0 if they gave none. "
    "In avoid_allergens list allergens the guests want to avoid. Write a short friendly summary.";
sem WaiterRun.plan.message = "The guests' latest message.";
sem WaiterRun.plan.conversation = "The conversation so far, oldest first, including your earlier suggestions.";
sem WaiterRun.plan.rules = "The current allergy and preference rules worked out from everything the guests said. Follow them strictly.";

sem WaiterRun.retry =
    "Your first suggestion broke the rules, so some dishes were removed. Suggest the order again: keep the dishes already "
    "kept, and add safe replacements for the removed ones so the group still has enough food within the budget. "
    "Use the tools. Never include a dish whose allergens appear in the RULES. "
    "Give every dish a one-sentence reason and a short friendly summary.";
sem WaiterRun.retry.message = "The guests' latest message.";
sem WaiterRun.retry.conversation = "The conversation so far, oldest first.";
sem WaiterRun.retry.rules = "The current allergy and preference rules. Follow them strictly.";
sem WaiterRun.retry.kept = "The dishes that passed the safety check. Keep them.";
sem WaiterRun.retry.removed = "The dishes that were removed and why.";
