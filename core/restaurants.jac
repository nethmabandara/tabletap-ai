"""Restaurants for any manager (M-05, M-06): create your own, see its real status, get the table links.
create_restaurant is all-or-nothing: everything is built first and attached last, and a failure removes whatever was built.
"""

import re;
import secrets;
import from .models { Restaurant, Table, Manages, HasTable }
import from .menu { my_restaurant, all_dishes, all_table_codes }
import from .kitchen { refusal }
import from .menu_draft { draft_of, draft_sections, section_dishes }

glob MIN_NAME = 2,
     MAX_NAME = 60,
     MAX_TABLES = 30,
     CODE_LENGTH = 6,
     CODE_CHARS = "abcdefghjkmnpqrstuvwxyz23456789",
     RESERVED_CODES = ["t1", "t2", "t3", "t4", "t5", "t6", "t7", "t8"],
     ALREADY_HAVE = "You already have a restaurant.";

# Tests only: when set to [n], creating table number n fails (to prove nothing half-built is left behind).
glob CREATE_FAULT: list[int] = [];

obj CreateResult {
    has ok: bool,
        message: str = "",
        name: str = "";
}

obj RestaurantStatus {
    has ok: bool,
        message: str = "",
        has_restaurant: bool = False,
        name: str = "",
        status_line: str = "",
        draft_line: str = "",
        published: bool = False,
        dish_count: int = 0,
        table_count: int = 0;
}

obj TableLink {
    has label: str,
        code: str;
}

"""Each table's label and code. The page builds the full link from its own address."""
obj TableLinks {
    has ok: bool,
        message: str = "",
        restaurant: str = "",
        tables: list[TableLink] = [];
}

def random_code -> str {
    return "".join([secrets.choice(CODE_CHARS) for i in range(CODE_LENGTH)]);
}

"""Make `count` table codes that are not taken by any restaurant, not reserved and not repeated. pick() makes one candidate."""
def make_codes(count: int, taken: list[str], pick: any) -> list[str] {
    codes: list[str] = [];
    tries = 0;
    while len(codes) < count and tries < 2000 {
        candidate = pick();
        tries += 1;
        if candidate in taken or candidate in codes or candidate in RESERVED_CODES {
            continue;
        }
        codes.append(candidate);
    }
    if len(codes) < count {
        raise RuntimeError("could not make unique table codes");
    }
    return codes;
}

"""A slug that is never the demo's 'wet-water': the name plus a random ending."""
def make_slug(name: str) -> str {
    base = re.sub("[^a-z0-9]+", "-", name.lower()).strip("-")[:30] or "restaurant";
    return base + "-" + "".join([secrets.choice(CODE_CHARS) for i in range(4)]);
}

"""The friendly reason a name or table count cannot be used, or ''."""
def create_problem(name: str, table_count: int) -> str {
    if len(name.strip()) < MIN_NAME or len(name.strip()) > MAX_NAME {
        return f"Please enter your restaurant's name ({MIN_NAME} to {MAX_NAME} characters).";
    }
    if table_count < 1 or table_count > MAX_TABLES {
        return f"Please choose between 1 and {MAX_TABLES} tables.";
    }
    return "";
}

"""Remove whatever a failed creation built. Deleting the restaurant also removes its edges."""
def remove_partial(rest: Restaurant | None, tables: list[Table]) {
    try {
        for t in tables {
            del t;
        }
        if rest is not None {
            del rest;
        }
    } except Exception {
        print("create_restaurant: cleanup after a failure also failed");
    }
}

"""Create the caller's restaurant. existing = the restaurant the caller already manages (None if none).
All-or-nothing: tables are built first, the restaurant is attached last, and any failure removes everything built."""
def create_restaurant_for(existing: Restaurant | None, name: str, table_count: int, pick: any) -> CreateResult {
    if existing is not None {
        return CreateResult(ok=False, message=ALREADY_HAVE);
    }
    problem = create_problem(name, table_count);
    if problem != "" {
        return CreateResult(ok=False, message=problem);
    }
    rest: Restaurant | None = None;
    tables: list[Table] = [];
    try {
        codes = make_codes(table_count, all_table_codes(), pick);
        rest = Restaurant(
            name=name.strip(), slug=make_slug(name), music_mode="off", menu_published=False, owner_root=jid(root)
        );
        for (i, code) in enumerate(codes) {
            if CREATE_FAULT and CREATE_FAULT[0] == i + 1 {
                raise RuntimeError("test fault while creating a table");
            }
            table = rest +>:HasTable:+> Table(label=f"Table {i + 1}", code=code);
            grant(table, level=AccessLevel.CONNECT);
            tables.append(table);
        }
        grant(rest, level=AccessLevel.READ);
        root +>:Manages:+> rest;
        root.shared ++> rest;
    } except Exception {
        print("create_restaurant failed; removing what was built:");
        remove_partial(rest, tables);
        return CreateResult(ok=False, message="We couldn't create your restaurant. Nothing was saved. Please try again.");
    }
    return CreateResult(ok=True, name=name.strip());
}

"""(status line, draft line) for the dashboard."""
def status_lines(published: bool, dish_count: int, draft_count: int) -> tuple[str, str] {
    dishes = f"{dish_count} dish" + ("" if dish_count == 1 else "es");
    drafts = f"{draft_count} dish" + ("" if draft_count == 1 else "es");
    if published and dish_count > 0 {
        return (f"Menu: {dishes}, published", f"Draft in progress: {drafts}" if draft_count > 0 else "");
    }
    if draft_count > 0 {
        return (f"Draft menu: {drafts}, not published yet", "");
    }
    return ("No menu yet: start with Menu setup", "");
}

def restaurant_status_for(rest: Restaurant | None) -> RestaurantStatus {
    if rest is None {
        return RestaurantStatus(ok=True, has_restaurant=False);
    }
    problem = refusal(rest);
    if problem != "" {
        return RestaurantStatus(ok=False, message=problem);
    }
    live = len(all_dishes(rest)) if rest.menu_published else 0;
    draft = draft_of(rest);
    drafted = sum([len(section_dishes(s)) for s in draft_sections(draft)]) if draft is not None else 0;
    (status, draft_line) = status_lines(rest.menu_published, live, drafted);
    return RestaurantStatus(
        ok=True, has_restaurant=True, name=rest.name, status_line=status, draft_line=draft_line,
        published=rest.menu_published, dish_count=live, table_count=len([rest ->:HasTable:-> [?:Table]])
    );
}

def table_links_for(rest: Restaurant | None) -> TableLinks {
    problem = refusal(rest);
    if problem != "" or rest is None {
        return TableLinks(ok=False, message=problem);
    }
    return TableLinks(
        ok=True, restaurant=rest.name,
        tables=[TableLink(label=t.label, code=t.code) for t in [rest ->:HasTable:-> [?:Table]]]
    );
}

"""Create my restaurant: a name (2 to 60 characters) and 1 to 30 tables, each with its own random code."""
def:protect create_restaurant(name: str, table_count: int) -> CreateResult {
    return create_restaurant_for(my_restaurant(), name, table_count, random_code);
}

"""Name, menu status and counts for the dashboard. has_restaurant is False for a manager with none yet."""
def:protect restaurant_status -> RestaurantStatus {
    return restaurant_status_for(my_restaurant());
}

"""My tables with their codes, for the Tables & links page."""
def:protect table_links -> TableLinks {
    return table_links_for(my_restaurant());
}
