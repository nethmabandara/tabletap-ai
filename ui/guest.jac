"""Guest screens: table menu pieces (G-01, G-02). Calls nothing itself; the page passes data in."""

import from ..core.menu { DishView, SectionView }
import from ..core.theme {
    pill_style, chip_style, step_style, dish_photo_style, price_style,
    INK, MUTED, GROUND, SURFACE, LINE, ACCENT, ACCENT_SOFT, ON_DARK, ON_DARK_MUTED, ON_DARK_SOFT, ON_DARK_LINE, FONT_TEXT,
    WARN_FG, WARN_BG, VEG_FG, VEG_BG, ALLERGY_FG, ALLERGY_BG, INFO_FG, INFO_BG,
    RADIUS_CARD, RADIUS_BUTTON, SHADOW_SOFT, TAP_HEIGHT, FS_XS, FS_SM, FS_MD, FS_LG, FS_XL, FS_3XL, SP_0, SP_1, SP_2, SP_3, SP_4
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
    <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "flex-end", "gap": f"{SP_2}px"}}>
        <div>
            <div style={{"color": ON_DARK_MUTED, "fontSize": f"{FS_MD}px", "fontWeight": "500"}}>{restaurant}</div>
            <h1 style={{"color": ON_DARK, "fontSize": f"{FS_3XL}px", "fontWeight": "700", "margin": "0", "lineHeight": "1.1"}}>{table}</h1>
        </div>
        <span style={pill_style(ACCENT, ACCENT_SOFT) | {"fontSize": f"{FS_SM}px", "padding": f"{SP_1}px {SP_3}px", "fontWeight": "600"}}>Open</span>
    </div>
}

def:pub SectionChips(sections: list[SectionView], active: str, onPick: any) -> JsxElement {
    <div style={{"display": "flex", "gap": f"{SP_1}px", "overflowX": "auto", "padding": f"{SP_2}px 0"}}>
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
    <span style={pill_style(look[1], look[2]) | {"marginRight": f"{SP_1}px", "marginTop": f"{SP_0}px", "fontWeight": "600"}}>{look[0]}</span>
}

def:pub DishCard(dish: DishView, qty: int, onAdd: any, onRemove: any) -> JsxElement {
    card = {
        "display": "flex",
        "gap": f"{SP_3}px",
        "alignItems": "center",
        "backgroundColor": SURFACE,
        "border": f"1px solid {LINE}",
        "boxShadow": SHADOW_SOFT,
        "borderRadius": f"{RADIUS_CARD}px",
        "padding": f"{SP_3}px",
        "marginBottom": f"{SP_2}px",
        "opacity": "0.55" if dish.sold_out else "1"
    };
    <div style={card}>
        <div style={dish_photo_style(64)} aria-hidden="true">{dish.name[:1].upper()}</div>
        <div style={{"flex": "1", "minWidth": "0"}}>
            <div style={{"color": INK, "fontSize": f"{FS_LG}px", "fontWeight": "600", "lineHeight": "1.25"}}>{dish.name}</div>
            {if len(dish.tags) > 0 {
                <div style={{"marginTop": f"{SP_0}px"}}>
                    {for t in dish.tags {
                        <TagPill key={t} tag={t}/>
                    }}
                </div>
            }}
            {if dish.sold_out {
                <div style={{"color": MUTED, "fontSize": f"{FS_MD}px", "marginTop": f"{SP_1}px"}}>Sold out today</div>
            } else {
                <div style={price_style() | {"marginTop": f"{SP_1}px"}}>{money(dish.price)}</div>
            }}
        </div>
        {if not dish.sold_out {
            <div style={{"display": "flex", "alignItems": "center", "gap": f"{SP_1}px"}}>
                {if qty > 0 {
                    <button style={step_style(False)} aria-label={"Remove one " + dish.name} onClick={lambda { onRemove(dish.id); }}>−</button>
                    <span style={{"minWidth": "20px", "textAlign": "center", "color": INK, "fontWeight": "700", "fontSize": f"{FS_LG}px"}}>{qty}</span>
                }}
                <button style={step_style(qty > 0)} aria-label={"Add one " + dish.name} disabled={qty >= 20} onClick={lambda { onAdd(dish.id); }}>+</button>
            </div>
        }}
    </div>
}

def:pub MenuList(sections: list[SectionView], cart: dict[str, int], onAdd: any, onRemove: any) -> JsxElement {
    <div>
        {for sec in sections {
            <section key={sec.name} id={section_id(sec.name)} style={{"scrollMarginTop": "150px"}}>
                <h2 style={{
                    "color": MUTED, "fontSize": f"{FS_SM}px", "fontWeight": "700",
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

"""The 'Ask the AI waiter' button on the photo banner (accent colour)."""
def:pub WaiterBanner(onOpen: any) -> JsxElement {
    <button
        onClick={lambda { onOpen(); }}
        style={{
            "width": "100%", "marginTop": f"{SP_3}px", "minHeight": f"{TAP_HEIGHT}px", "padding": f"{SP_2}px {SP_3}px", "border": "none",
            "borderRadius": f"{RADIUS_CARD}px", "backgroundColor": ACCENT, "color": ON_DARK, "cursor": "pointer",
            "display": "flex", "alignItems": "center", "gap": f"{SP_3}px", "textAlign": "left", "fontFamily": FONT_TEXT
        }}
    >
        <span style={{
            "flex": "0 0 48px", "height": "48px", "borderRadius": f"{RADIUS_BUTTON}px", "backgroundColor": ON_DARK_SOFT,
            "display": "flex", "alignItems": "center", "justifyContent": "center", "fontSize": f"{FS_XL}px"
        }}>✦</span>
        <span>
            <span style={{"display": "block", "fontSize": f"{FS_LG}px", "fontWeight": "700"}}>Ask the AI waiter</span>
            <span style={{"display": "block", "color": ON_DARK, "fontSize": f"{FS_SM}px"}}>Tell us your diets, allergies and budget</span>
        </span>
    </button>
}

"""Allergies in a red pill, preferences in an amber pill. Shows nothing when both are empty."""
def:pub NotePills(allergy: str, preference: str) -> JsxElement {
    <div>
        {if allergy != "" {
            <span style={pill_style(ALLERGY_FG, ALLERGY_BG) | {"marginRight": f"{SP_1}px", "marginTop": f"{SP_1}px", "fontWeight": "600"}}>{allergy}</span>
        }}
        {if preference != "" {
            <span style={pill_style(WARN_FG, WARN_BG) | {"marginTop": f"{SP_1}px", "fontWeight": "600"}}>{preference}</span>
        }}
    </div>
}

"""A slim button that opens the Music screen (glass style on the photo banner). Only shown when the restaurant takes live singer requests."""
def:pub MusicButton(onOpen: any) -> JsxElement {
    <button
        onClick={lambda { onOpen(); }}
        style={{
            "width": "100%", "marginTop": f"{SP_2}px", "minHeight": f"{TAP_HEIGHT}px", "padding": f"0 {SP_3}px", "border": f"1px solid {ON_DARK_LINE}",
            "borderRadius": f"{RADIUS_CARD}px", "backgroundColor": ON_DARK_SOFT, "color": ON_DARK, "cursor": "pointer", "fontFamily": FONT_TEXT,
            "fontSize": f"{FS_MD}px", "fontWeight": "600", "display": "flex", "alignItems": "center", "gap": f"{SP_2}px"
        }}
    >
        <span style={{"color": ON_DARK, "fontSize": f"{FS_XL}px"}}>♪</span>
        <span>Music · Ask the AI DJ</span>
    </button>
}
