"""The AI DJ agent (G-05, live singer mode). Server-only. Never imported by pages/ or ui/.
The AI only SUGGESTS one song. It never saves anything, and code sets from_approved_list.
"""

glob MAX_SONG = 80,
     MAX_MESSAGE = 80,
     MAX_WISH = 120,
     MAX_NOT_THESE = 5;

# Tests put a MockLLM here. Empty in production: the model from jac.toml [byllm.model] is used.
glob DJ_MODEL_OVERRIDE: list[any] = [];

obj SongPick {
    has song: str,
        artist: str,
        message: str,
        from_approved_list: bool = False;
}
sem SongPick = "One song suggested for the live singer to perform.";
sem SongPick.song = "The song title. A real, well-known song. Never invent one.";
sem SongPick.artist = "The artist or band who made the song.";
sem SongPick.message = "One friendly line for the singer about the request, at most 80 characters, for example the occasion.";
sem SongPick.from_approved_list = "Leave this false. The code works it out.";

obj DjAssistant {
    has model: any {
        getter -> any { return DJ_MODEL_OVERRIDE[0] if DJ_MODEL_OVERRIDE else llm; }
    };

    def pick(wish: str, approved: str, not_these: str) -> SongPick by self.model();
}

sem DjAssistant = "The DJ for a restaurant with a live singer.";
sem DjAssistant.pick =
    "Suggest ONE real, well-known song that a live singer can perform, in Sinhala, Tamil or English, that fits the guest's wish. "
    "If the wish names a song, use that song. Never invent a song or an artist. "
    "The message is one friendly line for the singer, at most 80 characters. "
    "The approved list shows songs this restaurant likes. It is only a hint: you may pick a song that is not on it. "
    "Do not suggest any song listed as already shown. Leave from_approved_list false.";
sem DjAssistant.pick.wish = "What the guest would like to hear, in their own words.";
sem DjAssistant.pick.approved = "The restaurant's approved songs, one per line as 'title - artist'. Empty if there are none.";
sem DjAssistant.pick.not_these = "Songs the guest has already seen and does not want, one per line. Empty if none.";

def clip(text: str, limit: int) -> str {
    clean = text.strip();
    return clean if len(clean) <= limit else clean[:limit - 1].rstrip() + "…";
}

"""The approved songs as plain lines for the agent: 'title - artist'."""
def approved_text(songs: list[tuple[str, str]]) -> str {
    return "\n".join([f"{title} - {artist}" for (title, artist) in songs]);
}

"""Titles already shown, capped at MAX_NOT_THESE (the most recent ones) and trimmed."""
def clean_not_these(titles: list[str]) -> list[str] {
    kept = [clip(t, MAX_SONG) for t in titles if t.strip() != ""];
    return kept[-MAX_NOT_THESE:];
}

"""True if this title is on the restaurant's approved list (ignores case and extra spaces)."""
def on_approved_list(title: str, songs: list[tuple[str, str]]) -> bool {
    wanted = " ".join(title.lower().split());
    return len([1 for (t, a) in songs if " ".join(t.lower().split()) == wanted]) > 0;
}

"""Trim and cap what the AI returned, and set from_approved_list by code (the AI's value is ignored)."""
def clean_pick(p: SongPick, songs: list[tuple[str, str]]) -> SongPick {
    song = clip(p.song, MAX_SONG);
    return SongPick(
        song=song, artist=clip(p.artist, MAX_SONG), message=clip(p.message, MAX_MESSAGE),
        from_approved_list=on_approved_list(song, songs)
    );
}
