"""The draft menu card (M-03). Owns ALL draft state, so the page's 1-second photo progress poll can never wipe the table or typed text.
Editing a row saves when the field is left; nothing is reloaded, so nothing jumps."""

import from "react" { useEffect }
import from ..core.menu_draft { get_draft, DraftView, DraftSectionView, DraftDishView, DishResult, SetupResult }
import from ..core.menu_edit { add_draft_dish, update_draft_dish, delete_draft_dish, discard_draft }
import from ..core.menu_publish { publish_draft }
import from ..core.theme { card_style }
import from .menu_draft { DraftHeader, DraftMessages, DraftChips, DishRow, TableHead, AddDishForm, parse_price, flip_tag }

def:pub DraftPanel(locked: bool, reload: int, readError: str, onSteps: any) -> JsxElement {
    has sections: list[DraftSectionView] = [],
        exists: bool = False,
        active: str = "",
        price_text: dict[str, str] = {},
        baseline: dict[str, list[str]] = {},
        saving_id: str = "",
        adding: bool = False,
        confirm_discard: bool = False,
        publishing: bool = False,
        publish_message: str = "",
        error: str = "",
        notice: str = "";

    async def load_draft {
        view: DraftView | None = None;
        try {
            view = await get_draft();
            texts: dict[str, str] = {};
            base: dict[str, list[str]] = {};
            for s in view.sections {
                for d in s.dishes {
                    texts[d.id] = str(d.price);
                    base[d.id] = [d.name, str(d.price)];
                }
            }
            price_text = texts;
            baseline = base;
            sections = view.sections;
            exists = view.exists;
            if active == "" or active not in [s.name for s in view.sections] {
                active = view.sections[0].name if view.sections else "";
            }
            onSteps(view.steps);
        } except Exception {
            error = "We couldn't load your draft. Please refresh the page.";
        }
    }

    # Load on arrival and again each time the page says a photo reading finished.
    async can with [reload] entry {
        await load_draft();
    }

    def find_dish(dish_id: str) -> DraftDishView | None {
        for s in sections {
            for d in s.dishes {
                if d.id == dish_id {
                    return d;
                }
            }
        }
        return None;
    }

    def edit_name(dish_id: str, value: str) {
        d = find_dish(dish_id);
        if d is not None {
            d.name = value;
            sections = [s for s in sections];
        }
    }

    def set_price_text(dish_id: str, value: str) {
        copy = {k: v for (k, v) in price_text.items()};
        copy[dish_id] = value;
        price_text = copy;
    }

    """Put a row back to what is saved, after a refused edit."""
    def revert(dish_id: str) {
        d = find_dish(dish_id);
        base = baseline.get(dish_id);
        if d is not None and base {
            d.name = base[0];
            set_price_text(dish_id, base[1]);
            sections = [s for s in sections];
        }
    }

    """Save one dish when a field is left, a tag is flipped or 'Mark checked' is pressed. The row's own text is never replaced."""
    async def save_dish(dish_id: str, confirm: bool, force: bool) {
        r: DishResult | None = None;
        d = find_dish(dish_id);
        if d is None {
            return;
        }
        base = baseline.get(dish_id, [d.name, str(d.price)]);
        text = price_text.get(dish_id, str(d.price)).strip();
        if not confirm and not force and d.name == base[0] and text == base[1] {
            return;
        }
        price = parse_price(text);
        if price == 0 {
            error = "Please enter a price above 0.";
            revert(dish_id);
            return;
        }
        saving_id = dish_id;
        error = "";
        try {
            r = await update_draft_dish(dish_id, d.name, price, d.spicy, d.is_veg, d.allergens, confirm);
            if r.ok {
                d.needs_check = r.dishes[0].needs_check;
                d.allergens = r.dishes[0].allergens;
                d.price = price;
                copy = {k: v for (k, v) in baseline.items()};
                copy[dish_id] = [d.name, str(price)];
                baseline = copy;
                sections = [s for s in sections];
            } else {
                error = r.message;
                revert(dish_id);
            }
        } except Exception {
            error = "We couldn't save that change. Please try again.";
        }
        saving_id = "";
    }

    def toggle_tag(dish_id: str, tag: str) {
        d = find_dish(dish_id);
        if d is not None {
            refusal = flip_tag(d, tag);
            if refusal != "" {
                error = refusal;
                return;
            }
            sections = [s for s in sections];
            save_dish(dish_id, False, True);
        }
    }

    async def remove_dish(dish_id: str) {
        r: SetupResult | None = None;
        r = await delete_draft_dish(dish_id);
        if r.ok {
            await load_draft();
        } else {
            error = r.message;
        }
    }

    async def add_dish(section: str, name: str, price_input: str) -> bool {
        r: DishResult | None = None;
        error = "";
        price = parse_price(price_input);
        if price == 0 {
            error = "Please enter a price above 0.";
            return False;
        }
        r = await add_draft_dish(section, name, price);
        if not r.ok {
            error = r.message;
            return False;
        }
        await load_draft();
        same = [s.name for s in sections if s.name.lower() == section.strip().lower()];
        active = same[0] if same else (section.strip() or "Menu");
        notice = "Dish added to your draft.";
        return True;
    }

    async def discard {
        r: SetupResult | None = None;
        confirm_discard = False;
        r = await discard_draft();
        if r.ok {
            await load_draft();
            notice = "Draft discarded. Your live menu is unchanged.";
            publish_message = "";
        } else {
            error = r.message;
        }
    }

    async def publish {
        r: SetupResult | None = None;
        if publishing {
            return;
        }
        publishing = True;
        publish_message = "";
        error = "";
        try {
            r = await publish_draft();
            if r.ok {
                await load_draft();
                notice = r.message + " Guests see it now.";
            } else {
                publish_message = r.message;
            }
        } except Exception {
            publish_message = "We couldn't publish your menu. Please try again.";
        }
        publishing = False;
    }

    dishes = [d for s in sections for d in s.dishes];
    need_check = len([d for d in dishes if d.needs_check]);
    shown = [s for s in sections if s.name == active];
    busy = locked or publishing;
    <div style={card_style() | {"flex": "1", "minWidth": "340px", "padding": "0"}}>
        <DraftHeader
            dish_count={len(dishes)} exists={exists} busy={busy} publishing={publishing} confirm={confirm_discard}
            onAdd={lambda { adding = not adding; }} onKeep={lambda { confirm_discard = False; }}
            onAskDiscard={lambda { confirm_discard = True; }} onDiscard={discard} onPublish={publish}
        />
        <DraftMessages need_check={need_check} publish_message={publish_message} errors={[readError, error]} notice={notice}/>
        {if exists {
            <DraftChips sections={sections} active={active} onPick={lambda (n: str) { active = n; }}/>
        }}
        {if adding {
            <AddDishForm section={active if active else "Menu"} locked={busy} onAdd={add_dish} onCancel={lambda { adding = False; }}/>
        }}
        {if exists {
            <TableHead/>
            for s in shown {
                for d in s.dishes {
                    <DishRow
                        key={d.id} dish={d} price_text={price_text.get(d.id, str(d.price))} locked={busy} saving={saving_id == d.id}
                        onName={edit_name} onPrice={set_price_text} onSave={lambda (id: str) { save_dish(id, False, False); }}
                        onToggle={toggle_tag} onTick={lambda (id: str) { save_dish(id, True, True); }} onRemove={remove_dish}
                    />
                }
            }
        }}
    </div>
}
