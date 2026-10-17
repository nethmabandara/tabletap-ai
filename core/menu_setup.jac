"""Menu Setup upload (M-02): read_menu_photos. The only endpoint that starts the AI, and it is manager-only.
Photos are saved with store() in a folder OUTSIDE the project, so nothing lands in git and the dev server never reloads.
"""

import os;
import io;
import time;
import from jaclang.server.serving.datatypes { UploadFile }
import from .models { Restaurant }
import from .menu { my_restaurant }
import from .kitchen { refusal }
import from .menu_rules { check_photos, sniff, merge_photos, build_steps, count_dishes }
import from .menu_agent { read_all, PROGRESS }
import from .menu_draft { SetupResult, save_draft }

# Tests point this at a temporary folder.
glob STORAGE_OVERRIDE: list[str] = [],
     NO_PHOTOS_MESSAGE = "We couldn't read your photos. You can add dishes by hand.";

obj ProgressView {
    has ok: bool,
        message: str = "",
        running: bool = False,
        total: int = 0,
        done: list[int] = [],
        failed: list[int] = [];
}

"""Where uploaded photos are kept: ~/.tabletap-ai/storage by default, never inside the project folder. Created if missing."""
def photo_dir -> str {
    if STORAGE_OVERRIDE {
        os.makedirs(STORAGE_OVERRIDE[0], exist_ok=True);
        return STORAGE_OVERRIDE[0];
    }
    home = os.path.join(os.path.expanduser("~"), ".tabletap-ai", "storage");
    path = os.path.abspath(os.environ.get("TABLETAP_STORAGE_DIR") or home);
    project = os.path.abspath(os.getcwd());
    if path == project or path.startswith(project + os.sep) {
        path = home;
    }
    os.makedirs(path, exist_ok=True);
    return path;
}

def save_photos(key: str, datas: list[bytes]) {
    try {
        storage: any = store(base_path=photo_dir());
        stamp = int(time.time() * 1000);
        for (i, data) in enumerate(datas) {
            storage.upload(io.BytesIO(data), f"menu/{key}/{stamp}-{i + 1}.{sniff(data[:16])}");
        }
    } except Exception {
        print("Menu Setup: could not save the photos (reading goes on without a saved copy).");
    }
}

def read_menu_photos_for(rest: Restaurant | None, files: list[UploadFile]) -> SetupResult {
    problem = refusal(rest);
    if problem != "" or rest is None {
        return SetupResult(ok=False, message=problem);
    }
    key = jid(rest);
    running = PROGRESS.get(key);
    if running is not None and running["running"] {
        return SetupResult(ok=False, message="We are still reading your photos. Please wait a moment.");
    }
    datas = [f.body for f in files];
    problem = check_photos([len(b) for b in datas], [b[:16] for b in datas]);
    if problem != "" {
        return SetupResult(ok=False, message=problem);
    }
    save_photos(key, datas);
    photos = [(b, "image/jpeg" if sniff(b[:16]) == "jpg" else "image/png") for b in datas];
    results = read_all(photos, key);
    failed = [r.number for r in results if not r.ok];
    sections = merge_photos([r.draft if r.ok else None for r in results]);
    if len(failed) == len(results) or count_dishes(sections) == 0 {
        return SetupResult(ok=False, message=NO_PHOTOS_MESSAGE, failed_photos=failed);
    }
    save_draft(rest, sections, build_steps(len(results) - len(failed), failed, sections), failed, len(results));
    note = "".join([f"Couldn't read photo {n}, try again. " for n in failed]).strip();
    return SetupResult(ok=True, message=note, failed_photos=failed);
}

def menu_read_progress_for(rest: Restaurant | None) -> ProgressView {
    problem = refusal(rest);
    if problem != "" or rest is None {
        return ProgressView(ok=False, message=problem);
    }
    state = PROGRESS.get(jid(rest));
    if state is None {
        return ProgressView(ok=True);
    }
    return ProgressView(
        ok=True, running=state["running"], total=state["total"], done=sorted(state["done"]), failed=sorted(state["failed"])
    );
}

"""Read the menu photos (jpg or png, up to 3, 10 MB each) into a draft. Does not touch the live menu."""
def:protect read_menu_photos(files: list[UploadFile]) -> SetupResult {
    return read_menu_photos_for(my_restaurant(), files);
}

"""Progress of the photo reading. tick is any changing number: it stops the browser from reusing an old answer."""
def:protect menu_read_progress(tick: int) -> ProgressView {
    return menu_read_progress_for(my_restaurant());
}
