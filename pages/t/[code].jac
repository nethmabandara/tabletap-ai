"""Guest table page (G-01, G-02). Calls only the def:pub get_menu; refreshes every 3 s."""

import from "react" { useEffect }
import from "@jac/runtime" { useParams }
import from ...core.menu { get_menu, MenuView }
import from ...core.theme { page_style, card_style, pill_style, INK, MUTED, ACCENT, ACCENT_SOFT, SURFACE, LINE, SP_3 }
import from ...ui.guest { MenuHeader, SectionChips, MenuList, section_id }

def:pub TablePage -> JsxPage {
    has menu: MenuView | None = None,
        failed: bool = False,
        active: str = "";
    params = useParams();
    code: str = params["code"];

    async def refresh {
        try {
            menu = await get_menu(code);
            failed = False;
        } except Exception {
            failed = True;
        }
    }

    def pick(name: str) {
        active = name;
        el: any = document.getElementById(section_id(name));
        if el {
            el.scrollIntoView({"behavior": "smooth"});
        }
    }

    useEffect(lambda {
        refresh();
        timer = setInterval(lambda { refresh(); }, 3000);
        return lambda { clearInterval(timer); };
    }, [code]);

    if menu is None {
        return <main style={page_style() | {"maxWidth": "480px"}}>
            <p style={{"color": MUTED, "textAlign": "center"}}>
                {"We couldn't load the menu. Trying again..." if failed else ""}
            </p>
        </main>;
    } elif menu.status != "ready" {
        return <main style={page_style() | {"maxWidth": "480px"}}>
            <div style={card_style() | {"textAlign": "center"}}>
                <span style={pill_style(ACCENT, ACCENT_SOFT)}>TableTap AI</span>
                <h1 style={{"color": INK, "fontSize": "28px", "margin": "16px 0 8px"}}>
                    {"Menu coming soon" if menu.status == "coming_soon" else "This table link isn't valid"}
                </h1>
                <p style={{"color": MUTED, "margin": "0"}}>
                    {"The restaurant is getting ready." if menu.status == "coming_soon" else "Please ask your waiter for the right link."}
                </p>
            </div>
        </main>;
    } else {
        return <main style={{"maxWidth": "480px", "margin": "0 auto", "minHeight": "100vh"}}>
            <div style={{
                "position": "sticky", "top": "0", "zIndex": "10", "backgroundColor": SURFACE,
                "padding": f"{SP_3}px", "borderBottom": f"1px solid {LINE}"
            }}>
                <MenuHeader restaurant={menu.restaurant} table={menu.table}/>
                <SectionChips sections={menu.sections} active={active if active else menu.sections[0].name} onPick={pick}/>
            </div>
            <div style={{"padding": f"0 {SP_3}px 32px"}}>
                <MenuList sections={menu.sections}/>
            </div>
        </main>;
    }
}
