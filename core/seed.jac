"""Starting data: the Wet Water Resort menu, tables t1..t8 and approved songs.

Server-only. Called by claim_demo_restaurant() in menu.jac; guests never seed.
Dish row: (name, price LKR, veg, spicy, allergens).
"""

import from .models { Restaurant, Section, Dish, Table, Song, Manages, HasSection, HasDish, HasTable, HasSong }

glob MENU: list[tuple[str, list[tuple[str, int, bool, bool, list[str]]]]] = [
    ("Rice, Pasta & Noodles", [
        ("Vegetable Fried Rice", 750, True, False, []),
        ("Chicken Fried Rice", 850, False, False, []),
        ("Seafood Fried Rice", 950, False, False, ["shellfish"]),
        ("Mixed Fried Rice", 950, False, False, ["shellfish"]),
        ("Vegetable Fried Noodles", 850, True, False, ["gluten"]),
        ("Chicken Fried Noodles", 950, False, False, ["gluten"]),
        ("Seafood Fried Noodles", 1050, False, False, ["shellfish", "gluten"]),
        ("Mixed Fried Noodles", 1050, False, False, ["shellfish", "gluten"]),
        ("Spaghetti Bolognaise (Beef Sauce)", 750, False, False, ["gluten"]),
        ("Macaroni Topped With Cheese", 750, True, False, ["dairy", "gluten"])
    ]),
    ("Vegetable", [
        ("Vegetable Chop Suey", 700, True, False, []),
        ("Hot Batter Mushroom", 530, True, True, ["egg", "gluten"]),
        ("Assorted Butter Vegetable", 690, True, False, ["dairy"])
    ]),
    ("Meat & Poultry", [
        ("Chicken Pepper Stew", 680, False, True, []),
        ("Singapore Fried Chili Chicken", 780, False, True, []),
        ("Devilled Chicken", 680, False, True, []),
        ("Sweet & Sour Chicken", 740, False, False, []),
        ("Half Roast Chicken With Boiled Vegetable", 990, False, False, []),
        ("Beef Stew", 850, False, False, []),
        ("Devilled Beef", 830, False, True, []),
        ("Pork Black Curry", 700, False, True, []),
        ("Pork Pepper Stew", 750, False, True, []),
        ("Devilled Pork", 750, False, True, [])
    ]),
    ("Seafood", [
        ("Fried Fish In Hot Garlic Sauce", 790, False, True, ["fish"]),
        ("Devilled Fish", 790, False, True, ["fish"]),
        ("Fish Pepper Stew", 790, False, True, ["fish"]),
        ("Devilled Prawns", 990, False, True, ["shellfish"]),
        ("Prawns Curry With Murunga Leaves", 990, False, True, ["shellfish"]),
        ("Hot Batter Cuttlefish", 850, False, True, ["shellfish", "egg", "gluten"]),
        ("Devilled Cuttlefish", 830, False, True, ["shellfish"])
    ]),
    ("Desserts", [
        ("Wattalapan", 230, True, False, ["egg", "dairy", "nuts"]),
        ("Chocolate Mousse", 280, True, False, ["egg", "dairy"])
    ]),
    ("Beverages", [
        ("Sprite", 150, True, False, []),
        ("Coca-Cola", 150, True, False, []),
        ("EGB", 150, True, False, [])
    ])
];

glob SONGS: list[tuple[str, str]] = [
    ("Perfect", "Ed Sheeran"),
    ("Can't Help Falling in Love", "Elvis Presley"),
    ("A Thousand Years", "Christina Perri"),
    ("Happy", "Pharrell Williams"),
    ("Uptown Funk", "Mark Ronson ft. Bruno Mars"),
    ("Celebration", "Kool & the Gang"),
    ("Despacito", "Luis Fonsi"),
    ("Manike Mage Hithe", "Yohani")
];

def tags_for(is_veg: bool, spicy: bool, allergens: list[str]) -> list[str] {
    tags: list[str] = [];
    if is_veg {
        tags.append("vegetarian");
    }
    if spicy {
        tags.append("spicy");
    }
    return tags + allergens;
}

"""Create the whole starting graph on root.shared, owned by the caller (the manager)."""
def build_wet_water -> Restaurant {
    rest = root.shared ++> Restaurant(
        name="Wet Water Resort", slug="wet-water", music_mode="both", menu_published=True,
        owner_root=jid(root)
    );
    root +>:Manages:+> rest;
    grant(rest, level=AccessLevel.READ);
    for (s_pos, (sec_name, dishes)) in enumerate(MENU) {
        sec = rest +>:HasSection:+> Section(name=sec_name, position=s_pos);
        grant(sec, level=AccessLevel.READ);
        for (d_pos, (name, price, is_veg, spicy, allergens)) in enumerate(dishes) {
            dish = sec +>:HasDish:+> Dish(
                name=name, price=price, is_veg=is_veg, spicy=spicy,
                allergens=allergens, tags=tags_for(is_veg, spicy, allergens), position=d_pos
            );
            grant(dish, level=AccessLevel.READ);
        }
    }
    for n in range(1, 9) {
        table = rest +>:HasTable:+> Table(label=f"Table {n}", code=f"t{n}");
        grant(table, level=AccessLevel.CONNECT);
    }
    for (title, artist) in SONGS {
        song = rest +>:HasSong:+> Song(title=title, artist=artist);
        grant(song, level=AccessLevel.CONNECT);
    }
    return rest;
}
