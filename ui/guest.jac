"""Guest screens: table menu pieces (G-01, G-02). Calls nothing itself; the page passes data in."""

import from ..core.menu { DishView, SectionView }
import from ..core.theme {
    pill_style, chip_style, mono_style, step_style,
    INK, MUTED, BODY, GROUND, SURFACE, LINE, ACCENT, ACCENT_SOFT, FONT_TEXT,
    WARN_FG, WARN_BG, VEG_FG, VEG_BG, ALLERGY_FG, ALLERGY_BG, INFO_FG, INFO_BG,
    RADIUS_CARD, SP_1, SP_2, SP_3, SP_4
}

# tag -> (label, text colour, background). Allergy tags always show.
glob TAG_LOOK: dict[str, list[str]] = {
    "vegetarian": ["Vegetarian", VEG_FG, VEG_BG],
    "spicy": ["Spicy", WARN_FG, WARN_BG],
    "fish": ["Fish", INFO_FG, INFO_BG],
    "shellfish": ["Contains shellfish", ALLERGY_FG, ALLERGY_BG],
    "nuts": ["Contains nuts", ALLERGY_FG, ALLERGY_BG],
    "egg": ["Contains egg", ALLERGY_FG, ALLERGY_BG],
    "dairy": ["Contains dairy", ALLERGY_FG, ALLERGY_BG],
    "gluten": ["Contains gluten", ALLERGY_FG, ALLERGY_BG]
};

def:pub money(price: int) -> str {
    digits = str(price);
    if len(digits) > 3 {
        return "Rs " + digits[:len(digits) - 3] + "," + digits[len(digits) - 3:];
    }
    return "Rs " + digits;
}

def:pub section_id(name: str) -> str {
    return "sec-" + name.replace(" ", "-").replace(",", "").replace("&", "and");
}

def:pub MenuHeader(restaurant: str, table: str) -> JsxElement {
    <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center"}}>
        <div>
            <div style={{"color": MUTED, "fontSize": "16px"}}>{restaurant}</div>
            <h1 style={{"color": INK, "fontSize": "32px", "fontWeight": "700", "margin": "0"}}>{table}</h1>
        </div>
        <span style={pill_style(ACCENT, ACCENT_SOFT) | {"fontSize": "15px", "padding": "8px 16px"}}>Open</span>
    </div>
}

def:pub SectionChips(sections: list[SectionView], active: str, onPick: any) -> JsxElement {
    <div style={{"display": "flex", "gap": f"{SP_1}px", "overflowX": "auto", "paddingTop": f"{SP_3}px"}}>
        {for sec in sections {
            <button
                key={sec.name}
                style={chip_style(sec.name == active)}
                onClick={lambda { onPick(sec.name); }}
            >
                {sec.name}
            </button>
        }}
    </div>
}

def:pub TagPill(tag: str) -> JsxElement {
    look = TAG_LOOK.get(tag, [tag, MUTED, GROUND]);
    <span style={pill_style(look[1], look[2]) | {"marginRight": "6px"}}>{look[0]}</span>
}

def:pub DishCard(dish: DishView, qty: int, onAdd: any, onRemove: any) -> JsxElement {
    card = {
        "display": "flex",
        "gap": f"{SP_3}px",
        "alignItems": "center",
        "backgroundColor": SURFACE,
        "borderRadius": f"{RADIUS_CARD}px",
        "padding": f"{SP_3}px",
        "marginBottom": f"{SP_2}px",
        "opacity": "0.55" if dish.sold_out else "1"
    };
    <div style={card}>
        <div style={{
            "flex": "0 0 64px", "height": "64px", "borderRadius": "10px",
            "backgroundColor": LINE, "color": MUTED, "fontSize": "13px",
            "display": "flex", "alignItems": "center", "justifyContent": "center"
        }}>Photo</div>
        <div style={{"flex": "1", "minWidth": "0"}}>
            <div style={{"color": INK, "fontSize": "18px", "fontWeight": "600"}}>{dish.name}</div>
            {if len(dish.tags) > 0 {
                <div style={{"marginTop": "6px"}}>
                    {for t in dish.tags {
                        <TagPill key={t} tag={t}/>
                    }}
                </div>
            }}
            {if dish.sold_out {
                <div style={{"color": MUTED, "fontSize": "15px", "marginTop": "6px"}}>Sold out today</div>
            } else {
                <div style={mono_style() | {"color": INK, "fontSize": "16px", "marginTop": "6px"}}>{money(dish.price)}</div>
            }}
        </div>
        {if not dish.sold_out {
            <div style={{"display": "flex", "alignItems": "center", "gap": f"{SP_1}px"}}>
                {if qty > 0 {
                    <button style={step_style(False)} aria-label={"Remove one " + dish.name} onClick={lambda { onRemove(dish.id); }}>−</button>
                    <span style={{"minWidth": "20px", "textAlign": "center", "color": INK, "fontWeight": "600"}}>{qty}</span>
                }}
                <button style={step_style(qty > 0)} aria-label={"Add one " + dish.name} disabled={qty >= 20} onClick={lambda { onAdd(dish.id); }}>+</button>
            </div>
        }}
    </div>
}

def:pub MenuList(sections: list[SectionView], cart: dict[str, int], onAdd: any, onRemove: any) -> JsxElement {
    <div>
        {for sec in sections {
            <section key={sec.name} id={section_id(sec.name)} style={{"scrollMarginTop": "180px"}}>
                <h2 style={{
                    "color": MUTED, "fontSize": "14px", "fontWeight": "600",
                    "letterSpacing": "0.08em", "textTransform": "uppercase",
                    "margin": f"{SP_4}px 0 {SP_2}px"
                }}>{sec.name}</h2>
                {for d in sec.dishes {
                    <DishCard key={d.id} dish={d} qty={cart.get(d.id, 0)} onAdd={onAdd} onRemove={onRemove}/>
                }}
            </section>
        }}
    </div>
}
