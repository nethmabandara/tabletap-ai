"""Song requests and the music queue (G-05, MU-01). In-process, no AI."""

import from core.models { Restaurant, Song, SongRequest, Table, HasSong, HasTable, Requested }
import from core.kitchen { NOT_ALLOWED, SET_UP_FIRST }
import from core.music {
    send_song_request, table_requests, music_queue_for, answer_request_for, MAX_PENDING
}
import from tests.menu_fixtures { fresh_tag, make_cafe, remove_cafe }

def cafe_with_mode(tag: str, mode: str, owned: bool = True) -> Restaurant {
    cafe = make_cafe(tag, owned);
    cafe.music_mode = mode;
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

test "a table can have 2 requests waiting; the third is refused and says so" {
    tag = fresh_tag();
    cafe = cafe_with_mode(tag, "both");
    code = f"tc-{tag}";
    try {
        assert send_song_request(code, "Perfect", "Ed Sheeran", "For Anna", "romantic").ok;
        assert send_song_request(code, "Happy", "Pharrell Williams", "", "upbeat").ok;
        third = send_song_request(code, "Despacito", "Luis Fonsi", "", "party");
        assert not third.ok and "already has 2 requests waiting" in third.message and MAX_PENDING == 2;
        assert len(table_requests(code)) == 2;
        queue = music_queue_for(cafe);
        assert answer_request_for(cafe, queue.requests[0].id, True).ok;
        assert send_song_request(code, "Despacito", "Luis Fonsi", "", "party").ok;
    } finally {
        drop_cafe(cafe);
    }
}

test "requests are checked in code: unknown table, mode, empty song, duplicate, lengths" {
    tag = fresh_tag();
    cafe = cafe_with_mode(tag, "singer");
    off_tag = fresh_tag();
    off = cafe_with_mode(off_tag, "off");
    speakers_tag = fresh_tag();
    speakers = cafe_with_mode(speakers_tag, "speakers");
    code = f"tc-{tag}";
    try {
        assert send_song_request("no-such-code", "Perfect", "", "", "").message == "This table link isn't valid.";
        assert send_song_request(f"tc-{off_tag}", "Perfect", "", "", "").message == "Song requests are not open right now.";
        assert send_song_request(f"tc-{speakers_tag}", "Perfect", "", "", "").message == "Song requests are not open right now.";
        assert send_song_request(code, "   ", "Artist", "", "").message == "Please type a song title.";
        assert "up to 80" in send_song_request(code, "s" * 81, "", "", "").message;
        assert "up to 80" in send_song_request(code, "Song", "a" * 81, "", "").message;
        assert send_song_request(code, "Perfect", "Ed Sheeran", "m" * 300, "w" * 300).ok;
        saved = table_requests(code)[0];
        assert len(saved.message) <= 80 and saved.status == "pending";
        dup = send_song_request(code, "PERFECT", "Ed Sheeran", "", "");
        assert not dup.ok and dup.message == "That song is already waiting.";
        assert len(table_requests(f"tc-{off_tag}")) == 0;
        assert table_requests("no-such-code") == [];
    } finally {
        drop_cafe(cafe);
        drop_cafe(off);
        drop_cafe(speakers);
    }
}

test "the singer's queue: oldest first, with song, artist, table, message and the guest's own words" {
    tag = fresh_tag();
    cafe = cafe_with_mode(tag, "both");
    second = cafe +>:HasTable:+> Table(label="Table 2", code=f"tc-{tag}-two");
    grant(second, level=AccessLevel.CONNECT);
    tables = [cafe ->:HasTable:-> [?:Table]];
    try {
        assert send_song_request(tables[1].code, "Second Song", "B", "for table two", "wish two").ok;
        assert send_song_request(tables[0].code, "First Song", "A", "for table one", "wish one").ok;
        queue = music_queue_for(cafe);
        assert queue.ok and queue.restaurant == cafe.name and queue.mode == "both" and queue.mode_label == "Live singer + speakers";
        assert [q.song for q in queue.requests] == ["Second Song", "First Song"];
        first = queue.requests[0];
        assert first.artist == "B" and first.table == "Table 2" and first.message == "for table two" and first.wish == "wish two";
    } finally {
        drop_cafe(cafe);
    }
}

test "accept and skip: the guest sees the answer, and a request is answered only once" {
    tag = fresh_tag();
    cafe = cafe_with_mode(tag, "both");
    code = f"tc-{tag}";
    try {
        assert send_song_request(code, "Song One", "A", "", "").ok;
        assert send_song_request(code, "Song Two", "B", "", "").ok;
        queue = music_queue_for(cafe);
        one = [q for q in queue.requests if q.song == "Song One"][0];
        two = [q for q in queue.requests if q.song == "Song Two"][0];
        assert answer_request_for(cafe, one.id, True).ok;
        assert answer_request_for(cafe, two.id, False).ok;
        status = {r.song: r.status for r in table_requests(code)};
        assert status == {"Song One": "accepted", "Song Two": "skipped"};
        again = answer_request_for(cafe, one.id, False);
        assert not again.ok and again.message == "That request was already answered.";
        assert music_queue_for(cafe).requests == [];
        assert not answer_request_for(cafe, "no-such-id", True).ok;
    } finally {
        drop_cafe(cafe);
    }
}

test "a second manager cannot see or answer the queue; no restaurant says Set up first" {
    mine = cafe_with_mode(fresh_tag(), "both");
    stranger = cafe_with_mode(fresh_tag(), "both", owned=False);
    try {
        code = [t.code for t in [mine ->:HasTable:-> [?:Table]]][0];
        assert send_song_request(code, "Private Song", "A", "", "").ok;
        request_id = music_queue_for(mine).requests[0].id;
        assert music_queue_for(stranger).message == NOT_ALLOWED and not music_queue_for(stranger).ok;
        assert answer_request_for(stranger, request_id, True).message == NOT_ALLOWED;
        assert music_queue_for(None).message == SET_UP_FIRST and answer_request_for(None, "x", True).message == SET_UP_FIRST;
        assert table_requests(code)[0].status == "pending";
        assert answer_request_for(mine, request_id, True).ok;
    } finally {
        drop_cafe(mine);
        drop_cafe(stranger);
    }
}

test "requests belong to their restaurant: one restaurant's queue never shows another's" {
    a = cafe_with_mode(fresh_tag(), "both");
    b = cafe_with_mode(fresh_tag(), "both");
    try {
        code_a = [t.code for t in [a ->:HasTable:-> [?:Table]]][0];
        code_b = [t.code for t in [b ->:HasTable:-> [?:Table]]][0];
        assert send_song_request(code_a, "Song For A", "X", "", "").ok;
        assert send_song_request(code_b, "Song For B", "Y", "", "").ok;
        assert [q.song for q in music_queue_for(a).requests] == ["Song For A"];
        assert [q.song for q in music_queue_for(b).requests] == ["Song For B"];
        assert [r.song for r in table_requests(code_a)] == ["Song For A"];
    } finally {
        drop_cafe(a);
        drop_cafe(b);
    }
}
