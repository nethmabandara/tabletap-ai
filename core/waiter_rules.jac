"""What the guests said they cannot or will not eat (G-04). Pure code: no graph, no AI.

Each allergen word takes the nearest cue before it in the same sentence:
  allergy cue   -> an ALLERGY: kept for the whole conversation, never lifted
  avoid cue     -> a PREFERENCE: counts only while the latest mention is negative
  anything else -> a positive or neutral mention: lifts an earlier preference
A sentence ends at . ! ? ; or the words "but" / "however".
"""

import re;

glob ALLERGENS = ["shellfish", "fish", "nuts", "egg", "dairy", "gluten"],
     MAX_NOTE_CHARS = 200;

glob WORD_TO_ALLERGENS: dict[str, list[str]] = {
    "prawn": ["shellfish"], "prawns": ["shellfish"], "shrimp": ["shellfish"], "shrimps": ["shellfish"],
    "shellfish": ["shellfish"], "crab": ["shellfish"], "crabs": ["shellfish"], "lobster": ["shellfish"],
    "cuttlefish": ["shellfish"], "squid": ["shellfish"],
    "fish": ["fish"], "seafood": ["fish", "shellfish"],
    "nut": ["nuts"], "nuts": ["nuts"], "peanut": ["nuts"], "peanuts": ["nuts"], "cashew": ["nuts"], "cashews": ["nuts"],
    "egg": ["egg"], "eggs": ["egg"],
    "dairy": ["dairy"], "milk": ["dairy"], "cheese": ["dairy"],
    "gluten": ["gluten"], "wheat": ["gluten"]
};

# Cue phrases (apostrophes are removed before matching: can't -> cant)
glob ALLERGY_CUES: list[list[str]] = [
    ["allergic"], ["allergy"], ["allergies"], ["intolerant"], ["intolerance"],
    ["cant", "have"], ["cannot", "have"], ["cant", "eat"], ["cannot", "eat"], ["doesnt", "eat"]
],
     AVOID_CUES: list[list[str]] = [["no"], ["without"], ["avoid"], ["dont", "eat"], ["not", "eat"]],
     LIKE_CUES: list[list[str]] = [["love"], ["like"], ["with"], ["want"], ["add"], ["include"], ["prefer"], ["extra"]],
     TRAILING_ALLERGY = ["allergy", "allergies", "allergic", "intolerance", "intolerant"],
     SENTENCE_BREAKS = [".", "!", "?", ";", "but", "however"];

obj Rules {
    has allergies: dict[str, list[str]] = {},
        preferences: dict[str, list[str]] = {},
        mentioned: list[str] = [],
        lifted: list[str] = [];
}

def tokens_of(text: str) -> list[str] {
    clean = text.lower().replace("'", "").replace("’", "");
    return re.findall("[a-z]+|[.!?;]", clean);
}

"""The cue kind starting at position i, and how many tokens it uses. ('', 0) if none."""
def cue_at(tokens: list[str], i: int) -> tuple[str, int] {
    for (kind, cues) in [("allergy", ALLERGY_CUES), ("avoid", AVOID_CUES), ("like", LIKE_CUES)] {
        for cue in cues {
            if tokens[i:i + len(cue)] == cue {
                return (kind, len(cue));
            }
        }
    }
    return ("", 0);
}

def add_word(words: dict[str, list[str]], allergen: str, word: str) {
    if allergen not in words {
        words[allergen] = [];
    }
    if word not in words[allergen] and word != allergen {
        words[allergen].append(word);
    }
}

"""Read the guests' messages, oldest first, and work out the current rules."""
def read_rules(messages: list[str]) -> Rules {
    rules = Rules();
    negative: dict[str, bool] = {};
    words: dict[str, list[str]] = {};
    for text in messages {
        tokens = tokens_of(text);
        current = "";
        i = 0;
        while i < len(tokens) {
            tok = tokens[i];
            if tok in SENTENCE_BREAKS {
                current = "";
                i += 1;
                continue;
            }
            (kind, used) = cue_at(tokens, i);
            if used > 0 {
                current = kind;
                i += used;
                continue;
            }
            if tok in WORD_TO_ALLERGENS {
                here = current;
                if i + 1 < len(tokens) and tokens[i + 1] in TRAILING_ALLERGY {
                    here = "allergy";
                }
                for a in WORD_TO_ALLERGENS[tok] {
                    if a not in rules.mentioned {
                        rules.mentioned.append(a);
                    }
                    add_word(words, a, tok);
                    if here == "allergy" {
                        rules.allergies[a] = [];
                    } else {
                        negative[a] = (here == "avoid");
                    }
                }
            }
            i += 1;
        }
    }
    for a in rules.allergies.keys() {
        rules.allergies[a] = words.get(a, []);
    }
    for (a, neg) in negative.items() {
        if a in rules.allergies {
            continue;
        }
        if neg {
            rules.preferences[a] = words.get(a, []);
        } else {
            rules.lifted.append(a);
        }
    }
    return rules;
}

"""Allergen names from free words like 'prawns' or 'Fish'. Unknown words are dropped."""
def normalise_allergens(names: list[str]) -> list[str] {
    found: list[str] = [];
    for n in names {
        key = n.strip().lower();
        options = [key] if key in ALLERGENS else WORD_TO_ALLERGENS.get(key, []);
        for a in options {
            if a not in found {
                found.append(a);
            }
        }
    }
    return found;
}

"""The AI may add allergens the guests never mentioned (as preferences). It cannot re-add one they mentioned."""
def merge_ai_avoid(rules: Rules, avoid: list[str]) -> Rules {
    merged = Rules(
        allergies={k: v for (k, v) in rules.allergies.items()},
        preferences={k: v for (k, v) in rules.preferences.items()},
        mentioned=[m for m in rules.mentioned],
        lifted=[m for m in rules.lifted]
    );
    for a in normalise_allergens(avoid) {
        if a not in merged.mentioned {
            merged.preferences[a] = [];
            merged.mentioned.append(a);
        }
    }
    return merged;
}

def restricted_allergens(rules: Rules) -> list[str] {
    return list(rules.allergies.keys()) + [a for a in rules.preferences.keys() if a not in rules.allergies];
}

def label(allergen: str, words: list[str]) -> str {
    return allergen + (" (" + ", ".join(words) + ")" if words else "");
}

def clip(text: str) -> str {
    return text if len(text) <= MAX_NOTE_CHARS else text[:MAX_NOTE_CHARS - 3] + "...";
}

"""(allergy_note, preference_note). Built by code, no duplicates. Empty string when there is nothing."""
def build_notes(rules: Rules) -> tuple[str, str] {
    allergy = ", ".join([label(a, w) for (a, w) in rules.allergies.items()]);
    pref = ", ".join(["no " + label(a, w) for (a, w) in rules.preferences.items() if a not in rules.allergies]);
    return (clip("Allergy: " + allergy) if allergy else "", clip("Preference: " + pref) if pref else "");
}

"""The rules as plain text for the agent."""
def rules_text(rules: Rules) -> str {
    allergy = ", ".join([label(a, w) for (a, w) in rules.allergies.items()]) or "none";
    pref = ", ".join([label(a, w) for (a, w) in rules.preferences.items() if a not in rules.allergies]) or "none";
    lifted = ", ".join([a for a in rules.lifted if a not in rules.allergies]) or "none";
    return (
        f"ALLERGIES (never include these allergens, for the whole conversation): {allergy}. "
        + f"PREFERENCES (avoid these allergens): {pref}. "
        + f"Guests now accept: {lifted}."
    );
}
