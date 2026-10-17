"""The draft menu table (M-03): section chips, editable rows, add-dish form. Presentational: the page owns all state,
so the 1-second photo progress poll never touches what is typed here."""

import from ..core.menu_draft { DraftDishView, DraftSectionView }
import from ..core.theme {
    button_style, pill_style, mono_style, chip_style,
    INK, MUTED, BODY, GROUND, SURFACE, LINE, ACCENT, ACCENT_SOFT, FONT_TEXT, RADIUS_BUTTON, SP_1, SP_2, SP_3, SP_4,
    WARN_FG, WARN_BG, VEG_FG, VEG_BG, ALLERGY_FG, ALLERGY_BG, INFO_FG, INFO_BG
}

glob TAGS: list[list[str]] = [
    ["spicy", "Spicy", WARN_FG, WARN_BG], ["vegetarian", "Vegetarian", VEG_FG, VEG_BG],
    ["shellfish", "Shellfish", ALLERGY_FG, ALLERGY_BG], ["fish", "Fish", INFO_FG, INFO_BG],
    ["nuts", "Nuts", ALLERGY_FG, ALLERGY_BG], ["egg", "Egg", ALLERGY_FG, ALLERGY_BG],
    ["dairy", "Dairy", ALLERGY_FG, ALLERGY_BG], ["gluten", "Gluten", ALLERGY_FG, ALLERGY_BG]
],
     GRID = "minmax(180px, 3fr) 110px minmax(250px, 4fr) 150px";

def has_tag(d: DraftDishView, tag: str) -> bool {
    if tag == "spicy" {
        return d.spicy;
    }
    if tag == "vegetarian" {
        return d.is_veg;
    }
    return tag in d.allergens;
}

def:pub TagToggle(label: str, active: bool, fg: str, bg: str, locked: bool, onToggle: any) -> JsxElement {
    <button
        role="switch"
        aria-checked={active}
        aria-label={label}
        disabled={locked}
        onClick={lambda { onToggle(); }}
        style={{
            "border": f"1px solid {LINE}" if not active else "none", "borderRadius": "999px", "padding": "4px 10px",
            "fontFamily": FONT_TEXT, "fontSize": "13px", "fontWeight": "600" if active else "400", "cursor": "pointer",
            "backgroundColor": bg if active else SURFACE, "color": fg if active else MUTED
        }}
    >{label}</button>
}

def:pub DraftChips(sections: list[DraftSectionView], active: str, onPick: any) -> JsxElement {
    <div style={{"display": "flex", "gap": f"{SP_1}px", "flexWrap": "wrap", "margin": f"{SP_3}px 0"}}>
        {for s in sections {
            <button key={s.name} style={chip_style(s.name == active)} onClick={lambda { onPick(s.name); }}>
                {s.name + " · " + str(len(s.dishes))}
            </button>
        }}
    </div>
}

def:pub DishRow(
    dish: DraftDishView, price_text: str, locked: bool, saving: bool,
    onName: any, onPrice: any, onSave: any, onToggle: any, onTick: any, onRemove: any
) -> JsxElement {
    field = {
        "width": "100%", "boxSizing": "border-box", "minHeight": "40px", "padding": f"0 {SP_2}px", "border": f"1px solid {LINE}",
        "borderRadius": f"{RADIUS_BUTTON}px", "fontSize": "16px", "color": INK, "backgroundColor": SURFACE, "fontFamily": FONT_TEXT
    };
    <div style={{
        "display": "grid", "gridTemplateColumns": GRID, "gap": f"{SP_2}px", "alignItems": "center",
        "padding": f"{SP_2}px {SP_3}px", "borderBottom": f"1px solid {LINE}", "backgroundColor": WARN_BG if dish.needs_check else SURFACE
    }}>
        <input
            aria-label="Dish name" value={dish.name} disabled={locked} style={field}
            onChange={lambda (e: ChangeEvent) { onName(dish.id, e.target.value); }}
            onBlur={lambda { onSave(dish.id); }}
        />
        <input
            aria-label="Price" value={price_text} disabled={locked} inputMode="numeric"
            style={field | {"fontFamily": "inherit", "textAlign": "right"} | mono_style()}
            onChange={lambda (e: ChangeEvent) { onPrice(dish.id, e.target.value); }}
            onBlur={lambda { onSave(dish.id); }}
        />
        <div style={{"display": "flex", "gap": "6px", "flexWrap": "wrap"}}>
            {for t in TAGS {
                <TagToggle key={t[0]} label={t[1]} active={has_tag(dish, t[0])} fg={t[2]} bg={t[3]} locked={locked} onToggle={lambda { onToggle(dish.id, t[0]); }}/>
            }}
        </div>
        <div style={{"minHeight": "56px"}}>
            {if dish.needs_check {
                <div style={{"color": WARN_FG, "fontWeight": "700"}}>Please check</div>
                <button style={button_style(False) | {"minHeight": "32px", "padding": "0 10px", "fontSize": "13px", "marginTop": "4px"}} disabled={locked} onClick={lambda { onTick(dish.id); }}>Mark checked</button>
            } else {
                <div style={{"color": VEG_FG, "fontWeight": "600"}}>Looks good</div>
            }}
            <button style={{"border": "none", "background": "none", "color": MUTED, "fontSize": "13px", "cursor": "pointer", "padding": "4px 0"}} disabled={locked} onClick={lambda { onRemove(dish.id); }}>Remove</button>
            <span style={mono_style() | {"color": MUTED, "fontSize": "12px", "marginLeft": f"{SP_1}px"}}>{"saving..." if saving else ""}</span>
        </div>
    </div>
}

def:pub TableHead() -> JsxElement {
    <div style={{"display": "grid", "gridTemplateColumns": GRID, "gap": f"{SP_2}px", "padding": f"{SP_2}px {SP_3}px", "borderBottom": f"1px solid {LINE}", "color": MUTED, "fontSize": "13px", "fontWeight": "700", "letterSpacing": "0.08em"}}>
        <span>DISH</span><span style={{"textAlign": "right"}}>PRICE (RS)</span><span>TAGS</span><span>STATUS</span>
    </div>
}

"""Add one dish by hand. Keeps its own typed text until the dish is really added (onAdd returns True)."""
def:pub AddDishForm(section: str, locked: bool, onAdd: any, onCancel: any) -> JsxElement {
    has sec: str = "",
        name: str = "",
        price: str = "";
    async def submit {
        added: bool = False;
        added = await onAdd(sec if sec != "" else section, name, price);
        if added {
            name = "";
            price = "";
        }
    }
    field = {"minHeight": "40px", "padding": f"0 {SP_2}px", "border": f"1px solid {LINE}", "borderRadius": f"{RADIUS_BUTTON}px", "fontSize": "16px", "fontFamily": FONT_TEXT, "color": INK, "backgroundColor": SURFACE};
    <form
        onSubmit={lambda (e: FormEvent) { e.preventDefault(); submit(); }}
        style={{"display": "flex", "gap": f"{SP_2}px", "flexWrap": "wrap", "padding": f"{SP_3}px", "backgroundColor": GROUND, "borderBottom": f"1px solid {LINE}"}}
    >
        <input aria-label="Section" placeholder={"Section (" + section + ")"} value={sec} disabled={locked} style={field | {"flex": "1", "minWidth": "140px"}} onChange={lambda (e: ChangeEvent) { sec = e.target.value; }}/>
        <input aria-label="New dish name" placeholder="Dish name" value={name} disabled={locked} style={field | {"flex": "2", "minWidth": "180px"}} onChange={lambda (e: ChangeEvent) { name = e.target.value; }}/>
        <input aria-label="New dish price" placeholder="Price (Rs)" inputMode="numeric" value={price} disabled={locked} style={field | {"width": "120px"}} onChange={lambda (e: ChangeEvent) { price = e.target.value; }}/>
        <button type="submit" style={button_style() | {"minHeight": "40px"}} disabled={locked or name.strip() == ""}>Add</button>
        <button type="button" style={button_style(False) | {"minHeight": "40px"}} onClick={lambda { onCancel(); }}>Close</button>
    </form>
}

"""A price typed in a box as a whole number above 0, or 0 if it is not valid."""
def:pub parse_price(text: str) -> int {
    num: any = Number;
    n: any = num(text.strip());
    if text.strip() == "" or not num.isInteger(n) or n < 1 {
        return 0;
    }
    return int(n);
}

"""Flip one tag on a dish in the browser. Returns a friendly refusal, or '' when it worked."""
def:pub flip_tag(d: DraftDishView, tag: str) -> str {
    if tag == "spicy" {
        d.spicy = not d.spicy;
    } elif tag == "vegetarian" {
        if not d.is_veg and ("fish" in d.allergens or "shellfish" in d.allergens) {
            return "A dish with fish or shellfish can't be vegetarian.";
        }
        d.is_veg = not d.is_veg;
    } elif tag in d.allergens {
        d.allergens = [a for a in d.allergens if a != tag];
    } else {
        d.allergens = d.allergens + [tag];
        if tag == "fish" or tag == "shellfish" {
            d.is_veg = False;
        }
    }
    return "";
}

def:pub DraftHeader(
    dish_count: int, exists: bool, busy: bool, publishing: bool, confirm: bool,
    onAdd: any, onKeep: any, onAskDiscard: any, onDiscard: any, onPublish: any
) -> JsxElement {
    <div style={{"padding": f"{SP_4}px {SP_4}px 0", "display": "flex", "justifyContent": "space-between", "alignItems": "flex-start", "gap": f"{SP_3}px", "flexWrap": "wrap"}}>
        <div>
            <h2 style={{"color": INK, "fontSize": "28px", "margin": "0"}}>{("Draft menu · " + str(dish_count) + (" dish" if dish_count == 1 else " dishes")) if exists else "Draft menu"}</h2>
            <div style={{"color": MUTED}}>{"Review, fix anything wrong, then publish" if exists else "No draft yet. Read your menu photos, or add dishes by hand."}</div>
        </div>
        <div style={{"display": "flex", "gap": f"{SP_2}px", "flexWrap": "wrap"}}>
            <button style={button_style(False)} disabled={busy} onClick={lambda { onAdd(); }}>Add dish</button>
            {if exists {
                if confirm {
                    <button style={button_style(False)} disabled={busy} onClick={lambda { onKeep(); }}>Keep draft</button>
                    <button style={button_style() | {"backgroundColor": WARN_FG}} disabled={busy} onClick={lambda { onDiscard(); }}>Yes, discard</button>
                } else {
                    <button style={button_style(False)} disabled={busy} onClick={lambda { onAskDiscard(); }}>Discard</button>
                }
                <button style={button_style() | {"backgroundColor": INK, "opacity": "0.5" if busy else "1"}} disabled={busy} onClick={lambda { onPublish(); }}>{"Publishing..." if publishing else "Publish menu"}</button>
            }}
        </div>
    </div>
}

"""Everything the manager needs to be told: rows to check, publish refusal, errors, success."""
def:pub DraftMessages(need_check: int, publish_message: str, errors: list[str], notice: str) -> JsxElement {
    <div style={{"padding": f"0 {SP_4}px"}}>
        {if need_check > 0 {
            <p style={pill_style(WARN_FG, WARN_BG) | {"display": "block", "margin": f"{SP_3}px 0 0"}}>{str(need_check) + (" dish needs" if need_check == 1 else " dishes need") + " your check before you can publish."}</p>
        }}
        {if publish_message != "" {
            <p style={pill_style(WARN_FG, WARN_BG) | {"display": "block", "margin": f"{SP_2}px 0 0", "fontWeight": "700"}}>{publish_message}</p>
        }}
        {for msg in errors {
            if msg != "" {
                <p key={msg} style={pill_style(WARN_FG, WARN_BG) | {"display": "block", "margin": f"{SP_2}px 0 0"}}>{msg}</p>
            }
        }}
        {if notice != "" {
            <p style={pill_style(VEG_FG, VEG_BG) | {"display": "block", "margin": f"{SP_2}px 0 0"}}>{notice}</p>
        }}
    </div>
}
