"""Tests for reading the guests' restrictions (G-04). No AI, no graph."""

def pref_keys(r: Rules) -> list[str] {
    return sorted(list(r.preferences.keys()));
}

test "allergic to prawns becomes a shellfish allergy with the guest's own word" {
    r = read_rules(["We're 4, one vegetarian, one allergic to prawns, about Rs 5000"]);
    assert list(r.allergies.keys()) == ["shellfish"];
    assert r.allergies["shellfish"] == ["prawns"];
    assert pref_keys(r) == [];
    assert build_notes(r) == ("Allergy: shellfish (prawns)", "");
}

test "no fish is a preference; a later positive mention lifts it" {
    r = read_rules(["no fish please"]);
    assert pref_keys(r) == ["fish"];
    assert build_notes(r) == ("", "Preference: no fish");
    r2 = read_rules(["no fish please", "actually we love fish"]);
    assert pref_keys(r2) == [] and "fish" in r2.lifted;
    assert build_notes(r2) == ("", "");
    r3 = read_rules(["no fish please", "we love fish", "no fish after all"]);
    assert pref_keys(r3) == ["fish"];
}

test "an allergy is never lifted by a later positive mention" {
    r = read_rules(["my son is allergic to fish", "we love fish"]);
    assert list(r.allergies.keys()) == ["fish"];
    assert restricted_allergens(r) == ["fish"];
    assert build_notes(r)[1] == "";
}

test "we love fish alone adds no restriction" {
    r = read_rules(["we love fish and prawns"]);
    assert restricted_allergens(r) == [];
    assert build_notes(r) == ("", "");
}

test "the nearest cue wins in a list and a new sentence starts fresh" {
    both = read_rules(["allergic to prawns and fish"]);
    assert sorted(list(both.allergies.keys())) == ["fish", "shellfish"];
    mixed = read_rules(["no fish, we love prawns"]);
    assert pref_keys(mixed) == ["fish"] and "shellfish" in mixed.lifted;
    sentences = read_rules(["Allergic to prawns. Fish is fine."]);
    assert list(sentences.allergies.keys()) == ["shellfish"] and restricted_allergens(sentences) == ["shellfish"];
    but = read_rules(["no nuts but we love fish"]);
    assert pref_keys(but) == ["nuts"];
}

test "can't have, cannot eat and doesn't eat count as allergies; peanuts and cashew map to nuts" {
    a = read_rules(["she can't have peanuts"]);
    assert a.allergies == {"nuts": ["peanuts"]};
    b = read_rules(["he cannot eat cashew"]);
    assert list(b.allergies.keys()) == ["nuts"];
    c = read_rules(["my friend doesn't eat egg"]);
    assert list(c.allergies.keys()) == ["egg"];
    d = read_rules(["we can’t eat prawns"]);
    assert list(d.allergies.keys()) == ["shellfish"];
}

test "a nut allergy or seafood allergy is found when the cue comes after the word" {
    assert list(read_rules(["we have a nut allergy"]).allergies.keys()) == ["nuts"];
    assert sorted(list(read_rules(["seafood allergy"]).allergies.keys())) == ["fish", "shellfish"];
}

test "an allergy and a preference for the same thing show once, as an allergy" {
    r = read_rules(["no prawns please", "she is allergic to prawns"]);
    assert build_notes(r) == ("Allergy: shellfish (prawns)", "");
    assert restricted_allergens(r) == ["shellfish"];
}

test "the AI can only add allergens the guests never mentioned" {
    r = read_rules(["no fish please", "actually we love fish"]);
    merged = merge_ai_avoid(r, ["fish", "nuts", "pizza"]);
    assert "fish" not in restricted_allergens(merged);
    assert "nuts" in restricted_allergens(merged);
    assert "nuts" in merged.preferences;
    assert "nuts" not in r.preferences;
    assert build_notes(merged)[1] == "Preference: no nuts";
}

test "notes are capped at 200 characters and the rules text names every group" {
    long = read_rules(["allergic to " + ", ".join(["prawns", "fish", "peanuts", "egg", "milk", "wheat"]) + " " + "x" * 300]);
    note = build_notes(long)[0];
    assert len(note) <= 200;
    text = rules_text(read_rules(["allergic to prawns, no fish"]));
    assert "ALLERGIES" in text and "shellfish (prawns)" in text and "PREFERENCES" in text and "fish" in text;
}
