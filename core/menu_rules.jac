"""Menu Setup rules (M-02): upload checks, safety checks on what the AI read, merging photos.
Pure code: no graph, no AI. The AI only suggests; everything here is checked by code.
"""

import re;
import from .waiter_rules { normalise_allergens }

glob MAX_PHOTOS = 3,
     MAX_PHOTO_MB = 10,
     MAX_PHOTO_BYTES = 10 * 1024 * 1024,
     RISKY_WORDS = ["mixed", "seafood", "special"];

obj DishDraft {
    has section: str,
        name: str,
        price: int = 0,
        description: str = "",
        is_veg: bool = False,
        spicy: bool = False,
        allergens: list[str] = [],
        confident: bool = True;
}
sem DishDraft = "One dish read from a menu photo.";
sem DishDraft.section = "The section heading printed above the dish, like 'Seafood'.";
sem DishDraft.name = "The dish name exactly as printed.";
sem DishDraft.price = "Price in whole Sri Lankan rupees exactly as printed, no cents and no currency sign. 0 if you cannot read it.";
sem DishDraft.description = "Printed description of the dish, or an empty string.";
sem DishDraft.is_veg = "True only if the dish has no meat and no fish. Egg and dairy dishes can be vegetarian.";
sem DishDraft.spicy = "True if the dish is spicy, for example devilled, hot or chili dishes.";
sem DishDraft.allergens = "Allergens in the dish. Only these words: shellfish, fish, nuts, egg, dairy, gluten.";
sem DishDraft.confident = "False if the name or the price is hard to read or you are unsure about the tags.";

obj MenuDraft {
    has restaurant_name: str = "",
        dishes: list[DishDraft] = [];
}
sem MenuDraft = "Everything read from one photo of a menu, in the order printed.";
sem MenuDraft.restaurant_name = "The restaurant name if printed on the photo, otherwise an empty string.";
sem MenuDraft.dishes = "Every dish on the photo, in the order printed.";

obj CleanDish {
    has name: str,
        price: int,
        description: str,
        is_veg: bool,
        spicy: bool,
        allergens: list[str],
        needs_check: bool;
}

obj CleanSection {
    has name: str,
        dishes: list[CleanDish];
}

"""'jpg', 'png' or '' from the first bytes of a file. The file name and type are not trusted."""
def sniff(head: bytes) -> str {
    if head[:3] == b"\xff\xd8\xff" {
        return "jpg";
    }
    if head[:8] == b"\x89PNG\r\n\x1a\n" {
        return "png";
    }
    return "";
}

"""Friendly refusal for the chosen photos, or '' if they are fine. Sizes are in bytes."""
def check_photos(sizes: list[int], heads: list[bytes]) -> str {
    if len(sizes) == 0 {
        return "Please choose at least one photo.";
    }
    if len(sizes) > MAX_PHOTOS {
        return f"You can read up to {MAX_PHOTOS} photos at a time. Please choose fewer photos.";
    }
    for (i, size) in enumerate(sizes) {
        if size > MAX_PHOTO_BYTES {
            return f"Photo {i + 1} is too big. Each photo can be up to {MAX_PHOTO_MB} MB.";
        }
        if sniff(heads[i]) == "" {
            return f"Photo {i + 1} must be a JPG or PNG picture.";
        }
    }
    return "";
}

"""Check one dish the AI read. Returns the cleaned dish; needs_check is true when a human must look at it
(unsure AI, Mixed/Seafood/Special names, no price, or a vegetarian dish that also lists fish or shellfish)."""
def clean_dish(d: DishDraft) -> CleanDish {
    allergens = normalise_allergens(d.allergens);
    words = re.findall("[a-z]+", d.name.lower());
    risky = len([w for w in words if w in RISKY_WORDS]) > 0;
    if risky and "shellfish" not in allergens {
        allergens.append("shellfish");
    }
    price = d.price if d.price > 0 else 0;
    is_veg = d.is_veg and "fish" not in allergens and "shellfish" not in allergens;
    contradiction = d.is_veg and not is_veg;
    return CleanDish(
        name=d.name.strip(), price=price, description=d.description.strip(), is_veg=is_veg,
        spicy=d.spicy, allergens=allergens, needs_check=(not d.confident) or risky or price <= 0 or contradiction
    );
}

"""Merge what was read from each photo (None = that photo failed), in photo order.
Sections keep the order they first appear. Same-named sections merge. Exact duplicate dish names are dropped."""
def merge_photos(drafts: list[MenuDraft | None]) -> list[CleanSection] {
    sections: list[CleanSection] = [];
    seen: list[str] = [];
    for draft in drafts {
        if draft is None {
            continue;
        }
        for d in draft.dishes {
            name = d.name.strip();
            if name == "" or name.lower() in seen {
                continue;
            }
            seen.append(name.lower());
            title = d.section.strip() or "Menu";
            target = [s for s in sections if s.name.lower() == title.lower()];
            if not target {
                sections.append(CleanSection(name=title, dishes=[]));
                target = [sections[-1]];
            }
            target[0].dishes.append(clean_dish(d));
        }
    }
    return sections;
}

def count_dishes(sections: list[CleanSection]) -> int {
    return sum([len(s.dishes) for s in sections]);
}

def plural(n: int, word: str) -> str {
    return f"{n} {word}" + ("" if n == 1 else "s");
}

"""The steps the screen shows. photos_read = photos that worked; failed = 1-based numbers of photos that did not."""
def build_steps(photos_read: int, failed: list[int], sections: list[CleanSection]) -> list[str] {
    dishes = [d for s in sections for d in s.dishes];
    steps = ["Read " + plural(photos_read, "photo")];
    for n in failed {
        steps.append(f"Couldn't read photo {n}, try again");
    }
    steps.append("Found " + plural(len(sections), "section"));
    steps.append("Extracted " + f"{len(dishes)} " + ("dish" if len(dishes) == 1 else "dishes"));
    steps.append(f"Tagged {len([d for d in dishes if d.spicy])} spicy, {len([d for d in dishes if d.is_veg])} vegetarian");
    check = len([d for d in dishes if d.needs_check]);
    steps.append(f"{check} need your check" if check != 1 else "1 needs your check");
    if check == 0 {
        steps[-1] = "No dishes need a check";
    }
    return steps;
}
