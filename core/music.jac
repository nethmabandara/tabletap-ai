"""Song requests (G-05, MU-01): send_song_request, table_requests, and the manager's music_queue and answer_request.
Guests reach a restaurant by table code only. Every manager function first checks the Manages edge.
"""

import from uuid { UUID }
import from jaclang { JacRuntime as Jac }
import from .models { Restaurant, Table, SongRequest, HasTable, Requested }
import from .menu { restaurant_for_table, my_restaurant }
import from .kitchen { refusal }
import from .orders { now_iso, seconds_since }
import from .dj_agent { clip, MAX_SONG, MAX_MESSAGE, MAX_WISH }
import from .dj { singer_allowed, NOT_OPEN }

glob MAX_PENDING = 2,
     SHOWN_REQUESTS = 10,
     MODE_LABELS: dict[str, str] = {"off": "Off", "singer": "Live singer", "speakers": "Speakers", "both": "Live singer + speakers"};

obj RequestResult {
    has ok: bool,
        message: str = "";
}

"""One of this table's requests, for the guest. status: pending, accepted or skipped."""
obj RequestView {
    has id: str,
        song: str,
        artist: str,
        message: str,
        status: str,
        minutes_ago: int;
}

"""One waiting request for the singer, with the table and the guest's own words."""
obj QueueItem {
    has id: str,
        song: str,
        artist: str,
        table: str,
        message: str,
        wish: str,
        minutes_ago: int;
}

obj QueueView {
    has ok: bool,
        message: str = "",
        restaurant: str = "",
        mode: str = "off",
        mode_label: str = "Off",
        requests: list[QueueItem] = [];
}

def refuse(message: str) -> RequestResult {
    return RequestResult(ok=False, message=message);
}

"""Only the manager who owns the restaurant may answer a request. Nobody else gets access."""
def share_with_owner(rest: Restaurant, target: SongRequest) {
    if rest.owner_root != "" {
        Jac.allow_root(target, UUID(rest.owner_root), AccessLevel.WRITE);  # jac:ignore[E1053]
    }
}

def table_pending(table: Table) -> list[SongRequest] {
    return [table ->:Requested:-> [?:SongRequest, status == "pending"]];
}

"""A guest sends a request for the singer. Every rule is checked here, in code."""
def:pub send_song_request(table_code: str, song: str, artist: str, message: str, wish: str) -> RequestResult {
    found = restaurant_for_table(table_code);
    if found is None {
        return refuse("This table link isn't valid.");
    }
    (rest, table) = found;
    if not rest.menu_published or not singer_allowed(rest) {
        return refuse(NOT_OPEN);
    }
    title = song.strip();
    if title == "" {
        return refuse("Please type a song title.");
    }
    if len(title) > MAX_SONG or len(artist.strip()) > MAX_SONG {
        return refuse(f"The song and artist can each be up to {MAX_SONG} characters.");
    }
    waiting = table_pending(table);
    if len(waiting) >= MAX_PENDING {
        return refuse(f"Your table already has {MAX_PENDING} requests waiting. Please wait for the singer to answer.");
    }
    if len([r for r in waiting if r.song.lower() == title.lower()]) > 0 {
        return refuse("That song is already waiting.");
    }
    request = table +>:Requested:+> SongRequest(
        song=title, artist=artist.strip(), message=clip(message, MAX_MESSAGE), wish=clip(wish, MAX_WISH),
        status="pending", created_at=now_iso()
    );
    share_with_owner(rest, request);
    return RequestResult(ok=True, message="Your request was sent to the singer.");
}

"""This table's requests and their answers, newest first."""
def:pub table_requests(table_code: str) -> list[RequestView] {
    found = restaurant_for_table(table_code);
    if found is None {
        return [];
    }
    (rest, table) = found;
    ordered = sorted([table ->:Requested:-> [?:SongRequest]], key=lambda (r: SongRequest) { r.created_at; }, reverse=True);
    return [
        RequestView(
            id=jid(r), song=r.song, artist=r.artist, message=r.message, status=r.status,
            minutes_ago=int(seconds_since(r.created_at) // 60)
        )
        for r in ordered[:SHOWN_REQUESTS]
    ];
}

def music_queue_for(rest: Restaurant | None) -> QueueView {
    problem = refusal(rest);
    if problem != "" or rest is None {
        return QueueView(ok=False, message=problem);
    }
    waiting: list[tuple[SongRequest, Table]] = [];
    for table in [rest ->:HasTable:-> [?:Table]] {
        for r in table_pending(table) {
            waiting.append((r, table));
        }
    }
    waiting = sorted(waiting, key=lambda (p: tuple[SongRequest, Table]) { p[0].created_at; });
    return QueueView(
        ok=True, restaurant=rest.name, mode=rest.music_mode, mode_label=MODE_LABELS.get(rest.music_mode, "Off"),
        requests=[
            QueueItem(
                id=jid(r), song=r.song, artist=r.artist, table=t.label, message=r.message, wish=r.wish,
                minutes_ago=int(seconds_since(r.created_at) // 60)
            )
            for (r, t) in waiting
        ]
    );
}

"""Accept or skip one waiting request. Only requests under this restaurant's own tables can be found."""
def answer_request_for(rest: Restaurant | None, request_id: str, accept: bool) -> RequestResult {
    problem = refusal(rest);
    if problem != "" or rest is None {
        return refuse(problem);
    }
    for table in [rest ->:HasTable:-> [?:Table]] {
        for r in [table ->:Requested:-> [?:SongRequest]] {
            if jid(r) == request_id {
                if r.status != "pending" {
                    return refuse("That request was already answered.");
                }
                r.status = "accepted" if accept else "skipped";
                return RequestResult(ok=True);
            }
        }
    }
    return refuse("We couldn't find that request.");
}

"""Waiting requests for the singer, oldest first. Manager only."""
def:protect music_queue -> QueueView {
    return music_queue_for(my_restaurant());
}

"""Accept (True) or skip (False) a waiting request. Manager only."""
def:protect answer_request(request_id: str, accept: bool) -> RequestResult {
    return answer_request_for(my_restaurant(), request_id, accept);
}
