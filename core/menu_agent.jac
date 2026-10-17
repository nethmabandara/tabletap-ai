"""The Menu Setup Agent (M-02): reads menu photos, one AI call per photo, in parallel.
Server-only. Never imported by pages/ or ui/. The AI only suggests: menu_rules.jac checks everything after.
"""

import traceback;
import from jaclang.byllm.lib { Image }
import from .menu_rules { MenuDraft }

# Tests put a MockLLM here. Empty in production: the model from jac.toml [byllm.model] is used.
glob MENU_MODEL_OVERRIDE: list[any] = [],
     READ_IN_PARALLEL: list[bool] = [True];

# Progress per restaurant: {"total": n, "done": [photo numbers], "failed": [photo numbers], "running": bool}
glob PROGRESS: dict[str, dict[str, any]] = {};

obj PhotoResult {
    has number: int,
        ok: bool,
        draft: MenuDraft | None = None;
}

obj PhotoReader {
    has model: any {
        getter -> any { return MENU_MODEL_OVERRIDE[0] if MENU_MODEL_OVERRIDE else llm; }
    };

    def read(photo: Image) -> MenuDraft by self.model();
}

sem PhotoReader = "Reads one photo of a restaurant menu.";
sem PhotoReader.read =
    "Read every dish on this photo of a restaurant menu, in the order printed. "
    "Prices are whole Sri Lankan rupees exactly as printed. "
    "A dish is vegetarian only if it has no meat and no fish; egg and dairy dishes can be vegetarian but list egg or dairy. "
    "Allergens may only be: shellfish, fish, nuts, egg, dairy, gluten. "
    "Allergen notes: Wattalapan has egg, dairy and nuts (cashew); batter dishes (hot batter) have egg and gluten; "
    "noodles, spaghetti and macaroni have gluten; Chocolate Mousse has egg and dairy; "
    "dishes named Mixed, Seafood or Special may contain shellfish; prawns, cuttlefish and crab are shellfish; fish dishes have fish. "
    "Devilled dishes are spicy. "
    "Set confident to false if the name or the price is hard to read.";
sem PhotoReader.read.photo = "A photo of one page of the menu.";

def set_progress(key: str, number: int, ok: bool) {
    state = PROGRESS.get(key);
    if state is not None {
        state["done" if ok else "failed"].append(number);
    }
}

"""Read one photo. A failure is caught here, printed in the server terminal, and reported without losing the other photos."""
def read_one(data: bytes, mime: str, number: int, key: str) -> PhotoResult {
    try {
        reader = PhotoReader();
        draft = reader.read(Image(url=data, mime_type=mime));
        set_progress(key, number, True);
        return PhotoResult(number=number, ok=True, draft=draft);
    } except Exception {
        print(f"Menu Setup Agent: could not read photo {number}:");
        traceback.print_exc();
        set_progress(key, number, False);
        return PhotoResult(number=number, ok=False);
    }
}

"""Read all photos at the same time (or one after another when READ_IN_PARALLEL is off, for ordered tests)."""
def read_all(photos: list[tuple[bytes, str]], key: str) -> list[PhotoResult] {
    PROGRESS[key] = {"total": len(photos), "done": [], "failed": [], "running": True};
    try {
        if READ_IN_PARALLEL[0] and len(photos) > 1 {
            futures = [flow read_one(data, mime, i + 1, key) for (i, (data, mime)) in enumerate(photos)];
            results = [wait f for f in futures];
        } else {
            results = [read_one(data, mime, i + 1, key) for (i, (data, mime)) in enumerate(photos)];
        }
    } finally {
        PROGRESS[key]["running"] = False;
    }
    return results;
}
