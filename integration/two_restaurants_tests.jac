"""Integration test with REAL logins over HTTP (M-05, M-06). Run on demand: jac test -d integration

It copies the project to a temporary folder, starts a real server there (its own database, no API key, photos in a
temporary folder), registers real managers, then stops the server, drops ITS OWN database and deletes the copy.
Nothing of yours is read or changed. About a minute.
"""

import os;
import re;
import json;
import time;
import shutil;
import socket;
import subprocess;
import tempfile;
import urllib.request;
import urllib.error;

def project_root -> str {
    here = os.path.abspath(os.getcwd());
    assert os.path.exists(os.path.join(here, "jac.toml")), "run jac test from the project folder";
    return here;
}

def free_port -> int {
    s = socket.socket();
    s.bind(("127.0.0.1", 0));
    port = s.getsockname()[1];
    s.close();
    return port;
}

def post(base: str, path: str, body: dict[str, any] = {}, token: str = "") -> tuple[int, any] {
    headers = {"Content-Type": "application/json"};
    if token != "" {
        headers["Authorization"] = "Bearer " + token;
    }
    req = urllib.request.Request(base + path, data=json.dumps(body).encode(), headers=headers, method="POST");
    try {
        with urllib.request.urlopen(req, timeout=60) as resp {
            return (resp.status, json.load(resp));
        }
    } except urllib.error.HTTPError as e {
        return (e.code, None);
    } except Exception {
        return (0, None);
    }
}

"""Call a function endpoint and return its result (None if the call failed)."""
def call(base: str, name: str, body: dict[str, any] = {}, token: str = "") -> any {
    (status, data) = post(base, "/function/" + name, body, token);
    if status != 200 or data is None or not data.get("ok") {
        return None;
    }
    return data["data"]["result"];
}

def login(base: str, name: str) -> str {
    post(base, "/user/register", {"identities": [{"type": "username", "value": name}], "credential": {"type": "password", "password": "secret123"}});
    (status, data) = post(base, "/user/login", {"identity": {"type": "username", "value": name}, "credential": {"type": "password", "password": "secret123"}});
    assert status == 200;
    return data["data"]["token"];
}

def db_names -> dict[str, str] {
    out = subprocess.run(["jac", "db", "list"], capture_output=True, text=True).stdout;
    clean = re.sub("\x1b\\[[0-9;]*m", "", out);
    found: dict[str, str] = {};
    for line in clean.splitlines() {
        parts = line.split();
        if len(parts) > 3 and parts[0].startswith("jac_") {
            found[parts[0]] = parts[-1];
        }
    }
    return found;
}

def stop_server(proc: any) {
    if proc is None or proc.poll() is not None {
        return;
    }
    try {
        os.killpg(os.getpgid(proc.pid), 15);
        proc.wait(timeout=30);
    } except Exception {
        try {
            os.killpg(os.getpgid(proc.pid), 9);
        } except Exception {
            print("could not stop the test server");
        }
    }
}

def dish_names(menu: any) -> list[str] {
    return [d["name"] for s in menu["sections"] for d in s["dishes"]];
}

test "two managers, two restaurants: nothing leaks between them (real logins, real server, own database)" {
    work = tempfile.mkdtemp(prefix="tabletap-integration-");
    app = os.path.join(work, "app");
    proc = None;
    try {
        shutil.copytree(project_root(), app, ignore=shutil.ignore_patterns(
            ".jac", "node_modules", ".git", "tests", "integration", "docs", ".claude", "storage", "__pycache__"
        ));
        subprocess.run(["jac", "install"], cwd=app, capture_output=True, timeout=600);
        env = dict(os.environ);
        env.pop("ANTHROPIC_API_KEY", None);
        env["TABLETAP_STORAGE_DIR"] = os.path.join(work, "photos");
        port = free_port();
        log = open(os.path.join(work, "server.log"), "w");
        proc = subprocess.Popen(
            ["jac", "run", "--dev", "--no-client", "-p", str(port), "main.jac"],
            cwd=app, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True
        );
        base = f"http://127.0.0.1:{port}";
        ready = False;
        for i in range(240) {
            if proc.poll() is not None {
                break;
            }
            if call(base, "get_menu", {"table_code": "t5"}) is not None {
                ready = True;
                break;
            }
            time.sleep(1);
        }
        assert ready, "the test server did not start (see server.log in " + work + ")";

        n = str(int(time.time()));
        t1 = login(base, "itest_one_" + n);
        t2 = login(base, "itest_two_" + n);

        # Manager 1 claims the Wet Water demo; manager 2 cannot, and has no restaurant yet.
        assert call(base, "claim_demo_restaurant", {}, t1) == True;
        assert call(base, "claim_demo_restaurant", {}, t2) == False;
        assert call(base, "restaurant_status", {}, t2)["has_restaurant"] == False;
        assert call(base, "kitchen_orders", {}, t2)["message"] == "Set up your restaurant first.";
        assert call(base, "get_draft", {}, t2)["message"] == "Set up your restaurant first.";
        assert call(base, "table_links", {}, t2)["message"] == "Set up your restaurant first.";

        # Manager 2 creates Cafe Two with 3 tables; a second create is refused.
        bad = call(base, "create_restaurant", {"name": "C", "table_count": 3}, t2);
        assert not bad["ok"] and "2 to 60" in bad["message"];
        assert not call(base, "create_restaurant", {"name": "Cafe Two", "table_count": 31}, t2)["ok"];
        made = call(base, "create_restaurant", {"name": "Cafe Two", "table_count": 3}, t2);
        assert made["ok"] and made["name"] == "Cafe Two";
        again = call(base, "create_restaurant", {"name": "Cafe Three", "table_count": 2}, t2);
        assert not again["ok"] and again["message"] == "You already have a restaurant.";
        assert not call(base, "create_restaurant", {"name": "Cafe Four", "table_count": 2}, t1)["ok"];

        status2 = call(base, "restaurant_status", {}, t2);
        assert status2["name"] == "Cafe Two" and status2["table_count"] == 3;
        assert status2["status_line"] == "No menu yet: start with Menu setup";
        status1 = call(base, "restaurant_status", {}, t1);
        assert status1["name"] == "Wet Water Resort" and status1["status_line"] == "Menu: 35 dishes, published";

        # Table codes: 3 for Cafe Two, 6 characters, unique, not t1-t8; manager 1 sees only t1-t8.
        links2 = call(base, "table_links", {}, t2);
        codes2 = [t["code"] for t in links2["tables"]];
        assert links2["restaurant"] == "Cafe Two" and [t["label"] for t in links2["tables"]] == ["Table 1", "Table 2", "Table 3"];
        assert len(set(codes2)) == 3 and all([len(c) == 6 for c in codes2]);
        links1 = call(base, "table_links", {}, t1);
        codes1 = [t["code"] for t in links1["tables"]];
        assert codes1 == ["t1", "t2", "t3", "t4", "t5", "t6", "t7", "t8"] and links1["restaurant"] == "Wet Water Resort";
        assert not (set(codes2) & set(codes1));

        # Guests: Wet Water is untouched; a Cafe Two code says "Menu coming soon"; nothing can be ordered or asked of the AI yet.
        wet = call(base, "get_menu", {"table_code": "t5"});
        assert wet["status"] == "ready" and wet["restaurant"] == "Wet Water Resort" and wet["table"] == "Table 5";
        assert len(wet["sections"]) == 6 and len(dish_names(wet)) == 35;
        soon = call(base, "get_menu", {"table_code": codes2[1]});
        assert soon["status"] == "coming_soon" and soon["restaurant"] == "Cafe Two" and soon["table"] == "Table 2";
        assert call(base, "get_menu", {"table_code": "zzzzzz"})["status"] == "invalid";
        sprite = [d["id"] for s in wet["sections"] for d in s["dishes"] if d["name"] == "Sprite"][0];
        no_order = call(base, "place_order", {"table_code": codes2[0], "items": [{"dish_id": sprite, "qty": 1}], "allergy_note": ""});
        assert not no_order["ok"] and "isn't ready" in no_order["message"];
        no_ai = call(base, "ask_waiter", {"table_code": codes2[0], "message": "dinner for 2", "history": []});
        assert not no_ai["ok"] and "not ready" in no_ai["message"];

        # A Wet Water order shows on manager 1's kitchen only.
        placed = call(base, "place_order", {"table_code": "t5", "items": [{"dish_id": sprite, "qty": 2}], "allergy_note": "integration test"});
        assert placed["ok"];
        board1 = call(base, "kitchen_orders", {}, t1);
        assert board1["restaurant"] == "Wet Water Resort" and len(board1["orders"]) == 1;
        board2 = call(base, "kitchen_orders", {}, t2);
        assert board2["restaurant"] == "Cafe Two" and board2["orders"] == [];
        wet_order = board1["orders"][0]["id"];
        stolen = call(base, "set_order_status", {"order_id": wet_order, "new_status": "preparing"}, t2);
        assert not stolen["ok"] and "couldn't find that order" in stolen["message"];

        # Menu setup shows only each manager's own draft; manager 2 builds a menu by hand and publishes it.
        assert call(base, "get_draft", {}, t1)["exists"] == False;
        added = call(base, "add_draft_dish", {"section": "Starters", "name": "Soup", "price": 300}, t2);
        assert added["ok"];
        draft2 = call(base, "get_draft", {}, t2);
        assert draft2["exists"] and draft2["dish_count"] == 1 and draft2["sections"][0]["dishes"][0]["name"] == "Soup";
        assert call(base, "get_draft", {}, t1)["exists"] == False;
        assert call(base, "restaurant_status", {}, t2)["status_line"] == "Draft menu: 1 dish, not published yet";
        assert call(base, "publish_draft", {}, t1)["message"] == "There is no draft to publish. Read your menu photos or add a dish first.";
        published = call(base, "publish_draft", {}, t2);
        assert published["ok"];
        assert call(base, "restaurant_status", {}, t2)["status_line"] == "Menu: 1 dish, published";

        # Now guests at a Cafe Two code see Cafe Two's menu; Wet Water is unchanged.
        ready = call(base, "get_menu", {"table_code": codes2[1]});
        assert ready["status"] == "ready" and ready["restaurant"] == "Cafe Two" and dish_names(ready) == ["Soup"];
        assert len(dish_names(call(base, "get_menu", {"table_code": "t5"}))) == 35;
        soup = ready["sections"][0]["dishes"][0]["id"];
        cafe_order = call(base, "place_order", {"table_code": codes2[1], "items": [{"dish_id": soup, "qty": 1}], "allergy_note": ""});
        assert cafe_order["ok"] and cafe_order["total"] == 300;
        wrong_dish = call(base, "place_order", {"table_code": codes2[1], "items": [{"dish_id": sprite, "qty": 1}], "allergy_note": ""});
        assert not wrong_dish["ok"];
        board2 = call(base, "kitchen_orders", {}, t2);
        assert len(board2["orders"]) == 1 and board2["orders"][0]["table"] == "Table 2";
        board1 = call(base, "kitchen_orders", {}, t1);
        assert len(board1["orders"]) == 1 and board1["orders"][0]["table"] == "Table 5";
        assert not call(base, "set_order_status", {"order_id": board2["orders"][0]["id"], "new_status": "preparing"}, t1)["ok"];
        assert call(base, "set_order_status", {"order_id": board2["orders"][0]["id"], "new_status": "preparing"}, t2)["ok"];
    } finally {
        stop_server(proc);
        mine = [name for (name, owner) in db_names().items() if owner.startswith(app)];
        for name in mine {
            subprocess.run(["jac", "db", "drop", name, "-y"], capture_output=True, text=True);
        }
        shutil.rmtree(work, ignore_errors=True);
    }
}
