"""Ask the AI DJ (G-05). ask_dj ONLY suggests a song; it never saves a request.
The restaurant is found by table code (restaurant_for_table), and only THAT restaurant's songs are used.
"""

import time;
import traceback;
import from .models { Restaurant, Table, Song, HasSong }
import from .menu { restaurant_for_table }
import from .dj_agent { DjAssistant, SongPick, clip, approved_text, clean_not_these, clean_pick, MAX_WISH, MAX_SONG }

glob COOLDOWN_SECONDS = 3.0,
     BUSY_MESSAGE = "The AI DJ is busy right now. You can type a song yourself.",
     NOT_OPEN = "Song requests are not open right now.";

# One DJ question per table every few seconds; one in flight per table.
glob LAST_ASK: dict[str, float] = {},
     IN_FLIGHT: list[str] = [];

def reset_dj_throttle {
    LAST_ASK.clear();
    IN_FLIGHT.clear();
}

"""Zero or one pick (a list keeps it simple on the wire), and the steps the screen shows."""
obj DjReply {
    has ok: bool,
        message: str = "",
        pick: list[SongPick] = [],
        steps: list[str] = [];
}

def refuse(message: str) -> DjReply {
    return DjReply(ok=False, message=message);
}

"""This restaurant's approved songs as (title, artist). Only this restaurant's, never another one's."""
def approved_songs(rest: Restaurant) -> list[tuple[str, str]] {
    return [(s.title, s.artist) for s in [rest ->:HasSong:-> [?:Song]]];
}

def singer_allowed(rest: Restaurant) -> bool {
    return rest.music_mode in ["singer", "both"];
}

"""Suggest one song for a wish. not_these = titles already shown (up to 5) so the DJ picks a different one."""
def:pub ask_dj(table_code: str, wish: str, not_these: list[str] = []) -> DjReply {
    text = wish.strip();
    if text == "" {
        return refuse("Please tell the DJ what you would like to hear.");
    }
    if len(text) > MAX_WISH {
        return refuse(f"Your wish is too long (up to {MAX_WISH} characters). Please shorten it.");
    }
    found = restaurant_for_table(table_code);
    if found is None {
        return refuse("This table link isn't valid.");
    }
    (rest, table) = found;
    if not rest.menu_published {
        return refuse("The menu is not ready yet, so the AI DJ is not available. Menu coming soon.");
    }
    if not singer_allowed(rest) {
        return refuse(NOT_OPEN);
    }
    if table_code in IN_FLIGHT {
        return refuse("The DJ is still working on your last request. Please wait a moment.");
    }
    now = time.monotonic();
    if now - LAST_ASK.get(table_code, -1000.0) < COOLDOWN_SECONDS {
        return refuse("Please wait a few seconds before asking again.");
    }
    LAST_ASK[table_code] = now;
    IN_FLIGHT.append(table_code);
    try {
        songs = approved_songs(rest);
        shown = clean_not_these(not_these);
        steps = ["Read your wish", f"Checked the approved list ({len(songs)} songs)"];
        if shown {
            steps.append(f"Skipped {len(shown)} song{'' if len(shown) == 1 else 's'} you already saw");
        }
        try {
            raw = DjAssistant().pick(text, approved_text(songs), "\n".join(shown));
            pick = clean_pick(raw, songs);
            if pick.song == "" {
                raise ValueError("the DJ returned no song");
            }
        } except Exception {
            print("AI DJ error:");
            traceback.print_exc();
            return refuse(BUSY_MESSAGE);
        }
        steps.append(f"Picked {pick.song} by {pick.artist}");
        steps.append("On the approved list" if pick.from_approved_list else "Not on the approved list (the singer can still try it)");
        return DjReply(ok=True, pick=[pick], steps=steps);
    } finally {
        IN_FLIGHT.remove(table_code);
    }
}
