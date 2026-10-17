"""Create your restaurant (M-05): name and number of tables. The button is disabled while the server works."""

import from ..core.theme {
    button_style, pill_style, INK, MUTED, BODY, LINE, SURFACE, FONT_TEXT, WARN_FG, WARN_BG, RADIUS_BUTTON, SP_1, SP_2, SP_3
}

glob MIN_NAME = 2,
     MAX_NAME = 60,
     MAX_TABLES = 30;

def:pub CreateRestaurantForm(working: bool, message: str, onCreate: any) -> JsxElement {
    has name: str = "",
        tables: str = "4";
    field = {
        "width": "100%", "boxSizing": "border-box", "minHeight": "48px", "padding": f"0 {SP_3}px", "border": f"1px solid {LINE}",
        "borderRadius": f"{RADIUS_BUTTON}px", "fontFamily": FONT_TEXT, "fontSize": "17px", "color": INK, "backgroundColor": SURFACE
    };
    <form onSubmit={lambda (e: FormEvent) { e.preventDefault(); onCreate(name, tables); }}>
        <h2 style={{"color": INK, "fontSize": "24px", "margin": f"0 0 {SP_1}px"}}>Create your restaurant</h2>
        <p style={{"color": MUTED, "margin": f"0 0 {SP_3}px"}}>Give it a name and say how many tables it has. Each table gets its own link for guests.</p>
        <label style={{"color": BODY, "fontSize": "14px"}}>Restaurant name</label>
        <input
            style={field | {"margin": f"{SP_1}px 0 {SP_3}px"}} value={name} disabled={working} maxLength={MAX_NAME}
            placeholder="For example: Cafe Two"
            onChange={lambda (e: ChangeEvent) { name = e.target.value; }}
        />
        <label style={{"color": BODY, "fontSize": "14px"}}>{"Number of tables (1 to " + str(MAX_TABLES) + ")"}</label>
        <input
            style={field | {"margin": f"{SP_1}px 0 {SP_3}px", "maxWidth": "140px"}} type="number" min="1" max={str(MAX_TABLES)}
            value={tables} disabled={working}
            onChange={lambda (e: ChangeEvent) { tables = e.target.value; }}
        />
        {if message != "" {
            <p style={pill_style(WARN_FG, WARN_BG) | {"display": "block", "margin": f"0 0 {SP_3}px"}}>{message}</p>
        }}
        <button type="submit" disabled={working} style={button_style() | {"minHeight": "52px", "width": "100%", "fontSize": "18px", "opacity": "0.5" if working else "1"}}>
            {"Creating your restaurant..." if working else "Create restaurant"}
        </button>
    </form>
}
