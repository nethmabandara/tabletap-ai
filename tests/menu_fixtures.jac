"""Shared helpers for the Menu Setup tests. Each test builds its own cafe and removes it at the end,
so the demo restaurant (and the other tests) are never touched."""

import io;
import tempfile;
import time;
import from PIL { Image as PILImage }
import from jaclang.server.serving.datatypes { UploadFile }
import from jaclang.byllm.lib { MockLLM }
import from core.models { Restaurant, Section, Dish, Table, Order, OrderItem, Manages, HasSection, HasDish, HasTable, Placed, Contains }
import from core.menu_rules { MenuDraft, DishDraft }
import from core.menu_agent { MENU_MODEL_OVERRIDE, READ_IN_PARALLEL, PROGRESS }
import from core.menu_setup { STORAGE_OVERRIDE }
import from core.menu_draft { draft_of, delete_draft_nodes }

def fresh_tag -> str {
    return str(time.time_ns());
}

"""A cafe with one old section and dish, one table, and (if owned) a Manages edge from this root."""
def make_cafe(tag: str, owned: bool = True) -> Restaurant {
    rest = root.shared ++> Restaurant(
        name=f"Test Cafe {tag}", slug=f"test-cafe-{tag}", menu_published=True, owner_root=jid(root)
    );
    if owned {
        root +>:Manages:+> rest;
    }
    grant(rest, level=AccessLevel.READ);
    sec = rest +>:HasSection:+> Section(name="Old Section", position=0);
    dish = sec +>:HasDish:+> Dish(name="Old Dish", price=100, position=0, tags=[]);
    table = rest +>:HasTable:+> Table(label="Table 1", code=f"tc-{tag}");
    grant(sec, level=AccessLevel.READ);
    grant(dish, level=AccessLevel.READ);
    grant(table, level=AccessLevel.CONNECT);
    return rest;
}

def remove_cafe(rest: Restaurant) {
    draft = draft_of(rest);
    if draft is not None {
        delete_draft_nodes(draft);
    }
    for table in [rest ->:HasTable:-> [?:Table]] {
        for o in [table ->:Placed:-> [?:Order]] {
            for i in [o ->:Contains:-> [?:OrderItem]] {
                del i;
            }
            del o;
        }
        del table;
    }
    for sec in [rest ->:HasSection:-> [?:Section]] {
        for d in [sec ->:HasDish:-> [?:Dish]] {
            del d;
        }
        del sec;
    }
    del rest;
}

def photo_bytes(kind: str = "png") -> bytes {
    buf = io.BytesIO();
    PILImage.new("RGB", (6, 6), (200, 30, 30)).save(buf, format="PNG" if kind == "png" else "JPEG");
    return buf.getvalue();
}

def upload(name: str = "menu.png", data: bytes | None = None) -> UploadFile {
    body = data if data is not None else photo_bytes("jpg" if name.endswith(".jpg") else "png");
    return UploadFile.from_bytes(name, "image/png", body);
}

def dish_draft(section: str, name: str, price: int, veg: bool = False, spicy: bool = False, allergens: list[str] = [], confident: bool = True) -> DishDraft {
    return DishDraft(section=section, name=name, price=price, is_veg=veg, spicy=spicy, allergens=allergens, confident=confident);
}

"""Install a mock model. Each photo (an AI call without tools) uses exactly one queued output."""
def use_mock(outputs: list[any], parallel: bool = False) -> MockLLM {
    m = MockLLM(outputs=outputs);
    MENU_MODEL_OVERRIDE.clear();
    MENU_MODEL_OVERRIDE.append(m);
    READ_IN_PARALLEL[0] = parallel;
    STORAGE_OVERRIDE.clear();
    STORAGE_OVERRIDE.append(tempfile.mkdtemp(prefix="tabletap-test-photos-"));
    return m;
}

def done_mock {
    MENU_MODEL_OVERRIDE.clear();
    READ_IN_PARALLEL[0] = True;
    STORAGE_OVERRIDE.clear();
    PROGRESS.clear();
}
