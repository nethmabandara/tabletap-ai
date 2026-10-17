"""Nodes and edges (docs/06-data-model.md). Server-only: the client never imports this."""

node Restaurant {
    has name: str,
        slug: str,
        music_mode: str = "off",
        menu_published: bool = False,
        owner_root: str = "";
}

node Section {
    has name: str,
        position: int = 0;
}

node Dish {
    has name: str,
        price: int,
        description: str = "",
        tags: list[str] = [],
        is_veg: bool = False,
        allergens: list[str] = [],
        spicy: bool = False,
        sold_out: bool = False,
        needs_check: bool = False,
        photo_url: str = "",
        position: int = 0;
}

node Table {
    has label: str,
        code: str;
}

node Order {
    has status: str = "sent",
        allergy_note: str = "",
        preference_note: str = "",
        created_at: str = "",
        via_ai: bool = False;
}

node OrderItem {
    has dish_name: str,
        price: int,
        qty: int = 1,
        note: str = "";
}

node Song {
    has title: str,
        artist: str,
        now_playing: bool = False;
}

node Vote {
    has table_code: str;
}

node SongRequest {
    has song: str,
        artist: str = "",
        message: str = "",
        wish: str = "",
        status: str = "pending",
        created_at: str = "";
}

edge Manages: Root --> Restaurant {}
edge HasSection: Restaurant --> Section {}
edge HasDish: Section --> Dish {}
edge HasTable: Restaurant --> Table {}
edge Placed: Table --> Order {}
edge Contains: Order --> OrderItem {}
edge HasSong: Restaurant --> Song {}
edge Got: Song --> Vote {}
edge Requested: Table --> SongRequest {}
