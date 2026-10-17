"""AI DJ tests with MockLLM (no real AI, no cost). A call without tools uses exactly one queued output."""

import from jaclang.byllm.lib { MockLLM }
import from core.models { Restaurant, Song, SongRequest, Table, HasSong, HasTable, Requested }
import from core.dj_agent { SongPick, DJ_MODEL_OVERRIDE }
import from core.dj { ask_dj, reset_dj_throttle, BUSY_MESSAGE, NOT_OPEN, LAST_ASK }
import from tests.menu_fixtures { fresh_tag, make_cafe, remove_cafe }

def dj_cafe(tag: str, mode: str, songs: list[tuple[str, str]], published: bool = True) -> Restaurant {
    cafe = make_cafe(tag);
    cafe.music_mode = mode;
    cafe.menu_published = published;
    for (title, artist) in songs {
        cafe +>:HasSong:+> Song(title=title, artist=artist);
    }
    return cafe;
}

def drop_cafe(cafe: Restaurant) {
    for s in [cafe ->:HasSong:-> [?:Song]] {
        del s;
    }
    for t in [cafe ->:HasTable:-> [?:Table]] {
        for r in [t ->:Requested:-> [?:SongRequest]] {
            del r;
        }
    }
    remove_cafe(cafe);
}

def pick(song: str, artist: str, message: str = "For the table", claims_approved: bool = False) -> SongPick {
    return SongPick(song=song, artist=artist, message=message, from_approved_list=claims_approved);
}

"""Install a mock DJ model. Each ask uses exactly one queued output."""
def use_dj(outputs: list[any]) -> MockLLM {
    reset_dj_throttle();
    m = MockLLM(outputs=outputs);
    DJ_MODEL_OVERRIDE.clear();
    DJ_MODEL_OVERRIDE.append(m);
    return m;
}

def done_dj {
    DJ_MODEL_OVERRIDE.clear();
    reset_dj_throttle();
}

def requests_at(cafe: Restaurant) -> int {
    total = 0;
    for t in [cafe ->:HasTable:-> [?:Table]] {
        total += len([t ->:Requested:-> [?:SongRequest]]);
    }
    return total;
}

test "a wish gives a pick and steps, and nothing is saved" {
    tag = fresh_tag();
    cafe = dj_cafe(tag, "both", [("Perfect", "Ed Sheeran")]);
    try {
        m = use_dj([pick("Hanguran", "Nanda Malini", "For our anniversary")]);
        reply = ask_dj(f"tc-{tag}", "something romantic, old Sinhala");
        assert reply.ok and len(reply.pick) == 1;
        assert reply.pick[0].song == "Hanguran" and reply.pick[0].artist == "Nanda Malini";
        assert reply.pick[0].message == "For our anniversary" and not reply.pick[0].from_approved_list;
        assert reply.steps[0] == "Read your wish" and reply.steps[1] == "Checked the approved list (1 songs)";
        assert "Picked Hanguran by Nanda Malini" in reply.steps and reply.steps[-1].startswith("Not on the approved list");
        assert requests_at(cafe) == 0;
        prompt = str(m.sent("messages")[0]);
        assert "something romantic, old Sinhala" in prompt and "Perfect - Ed Sheeran" in prompt;
        assert "real, well-known song" in prompt and "Never invent" in prompt;
    } finally {
        done_dj();
        drop_cafe(cafe);
    }
}

test "from_approved_list is set by code: true only when the title is on the list, whatever the AI says" {
    tag = fresh_tag();
    cafe = dj_cafe(tag, "singer", [("Perfect", "Ed Sheeran"), ("Can't Help Falling in Love", "Elvis Presley")]);
    try {
        use_dj([pick("  perfect ", "Ed Sheeran")]);
        yes = ask_dj(f"tc-{tag}", "a love song");
        assert yes.pick[0].song == "perfect" and yes.pick[0].from_approved_list;
        assert yes.steps[-1] == "On the approved list";
        reset_dj_throttle();
        DJ_MODEL_OVERRIDE[0].outputs = [pick("Imagine", "John Lennon", claims_approved=True)];
        no = ask_dj(f"tc-{tag}", "peaceful");
        assert no.pick[0].song == "Imagine" and not no.pick[0].from_approved_list;
    } finally {
        done_dj();
        drop_cafe(cafe);
    }
}

test "an AI failure gives the friendly message and no pick" {
    tag = fresh_tag();
    cafe = dj_cafe(tag, "both", []);
    try {
        use_dj([]);
        reply = ask_dj(f"tc-{tag}", "anything");
        assert not reply.ok and reply.message == "The AI DJ is busy right now. You can type a song yourself.";
        assert reply.message == BUSY_MESSAGE and reply.pick == [] and requests_at(cafe) == 0;
        use_dj([pick("", "Nobody")]);
        empty = ask_dj(f"tc-{tag}", "anything");
        assert not empty.ok and empty.message == BUSY_MESSAGE;
    } finally {
        done_dj();
        drop_cafe(cafe);
    }
}

test "Try another: the shown titles reach the AI (at most 5, the latest ones)" {
    tag = fresh_tag();
    cafe = dj_cafe(tag, "both", []);
    try {
        m = use_dj([pick("Song Z", "Artist Z")]);
        reply = ask_dj(f"tc-{tag}", "upbeat", ["One", "Two", "Three", "Four", "Five", "Six", "Seven"]);
        assert reply.ok and "Skipped 5 songs you already saw" in reply.steps;
        prompt = str(m.sent("messages")[0]);
        assert "Three" in prompt and "Seven" in prompt and "One\n" not in prompt and "Two\n" not in prompt;
        assert "already shown" in prompt or "not_these" in prompt;
    } finally {
        done_dj();
        drop_cafe(cafe);
    }
}

test "the pick is trimmed and capped: message 80 characters, song and artist 80" {
    tag = fresh_tag();
    cafe = dj_cafe(tag, "both", []);
    try {
        use_dj([pick("  " + "S" * 200 + "  ", "A" * 200, "M" * 200)]);
        reply = ask_dj(f"tc-{tag}", "anything");
        p = reply.pick[0];
        assert len(p.song) <= 80 and len(p.artist) <= 80 and len(p.message) <= 80;
        assert p.message.endswith("…") and not p.song.startswith(" ");
    } finally {
        done_dj();
        drop_cafe(cafe);
    }
}

test "bad wishes, an unknown table, mode off, speakers only and an unpublished menu are refused with no AI call" {
    tag = fresh_tag();
    singer = dj_cafe(tag, "singer", []);
    tag2 = fresh_tag();
    off = dj_cafe(tag2, "off", []);
    tag3 = fresh_tag();
    speakers = dj_cafe(tag3, "speakers", []);
    tag4 = fresh_tag();
    soon = dj_cafe(tag4, "both", [], published=False);
    try {
        m = use_dj([pick("Never Used", "Nobody")]);
        assert ask_dj(f"tc-{tag}", "   ").message == "Please tell the DJ what you would like to hear.";
        assert "too long" in ask_dj(f"tc-{tag}", "w" * 121).message;
        assert ask_dj("nope-code", "a song").message == "This table link isn't valid.";
        assert ask_dj(f"tc-{tag2}", "a song").message == NOT_OPEN;
        assert ask_dj(f"tc-{tag3}", "a song").message == NOT_OPEN;
        assert "not ready" in ask_dj(f"tc-{tag4}", "a song").message;
        assert len(m.outputs) == 1 and len(m.seen) == 0;
        assert ask_dj(f"tc-{tag}", "w" * 120).ok;
    } finally {
        done_dj();
        drop_cafe(singer);
        drop_cafe(off);
        drop_cafe(speakers);
        drop_cafe(soon);
    }
}

test "songs belong to their restaurant: another restaurant's list never reaches the AI" {
    tag_a = fresh_tag();
    tag_b = fresh_tag();
    a = dj_cafe(tag_a, "both", [("Song Only A", "Artist A")]);
    b = dj_cafe(tag_b, "singer", [("Song Only B", "Artist B")]);
    try {
        m = use_dj([pick("Song Only B", "Artist B"), pick("Song Only B", "Artist B")]);
        for_a = ask_dj(f"tc-{tag_a}", "something");
        prompt_a = str(m.sent("messages")[0]);
        assert "Song Only A - Artist A" in prompt_a and "Song Only B" not in prompt_a;
        assert for_a.pick[0].song == "Song Only B" and not for_a.pick[0].from_approved_list;
        reset_dj_throttle();
        for_b = ask_dj(f"tc-{tag_b}", "something");
        assert for_b.pick[0].from_approved_list;
        prompt_b = str(m.sent("messages")[1]);
        assert "Song Only B - Artist B" in prompt_b and "Song Only A - Artist A" not in prompt_b;
    } finally {
        done_dj();
        drop_cafe(a);
        drop_cafe(b);
    }
}

test "one DJ question per table every 3 seconds, with a friendly message and no extra AI call" {
    tag = fresh_tag();
    cafe = dj_cafe(tag, "both", []);
    try {
        m = use_dj([pick("One", "A"), pick("Two", "B")]);
        assert ask_dj(f"tc-{tag}", "first").ok;
        again = ask_dj(f"tc-{tag}", "second");
        assert not again.ok and "wait a few seconds" in again.message and len(m.outputs) == 1;
        LAST_ASK[f"tc-{tag}"] = LAST_ASK[f"tc-{tag}"] - 10.0;
        assert ask_dj(f"tc-{tag}", "second").ok;
    } finally {
        done_dj();
        drop_cafe(cafe);
    }
}
