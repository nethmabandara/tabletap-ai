"""Tables & links (M-06): each table's link with a Copy button and a QR code."""

import from "qrcode-generator" { qrcode }
import from ..core.theme {
    button_style, card_style, pill_style, mono_style,
    INK, MUTED, BODY, LINE, SURFACE, FONT_TEXT, VEG_FG, VEG_BG, ACCENT, RADIUS_BUTTON, SP_1, SP_2, SP_3, SP_4
}

"""A QR code for a link, drawn by the qrcode-generator package as a small picture."""
def:pub QrCode(text: str, label: str) -> JsxElement {
    code: any = qrcode(0, "M");
    code.addData(text);
    code.make();
    <img src={code.createDataURL(5, 2)} alt={"QR code for " + label} width={132} height={132} style={{"borderRadius": f"{RADIUS_BUTTON}px", "border": f"1px solid {LINE}", "backgroundColor": SURFACE}}/>
}

def:pub TableCard(label: str, code: str, link: str, copied: bool, onCopy: any) -> JsxElement {
    <div style={card_style() | {"padding": f"{SP_3}px {SP_4}px", "display": "flex", "gap": f"{SP_4}px", "alignItems": "center", "flexWrap": "wrap"}}>
        <div style={{"flex": "1", "minWidth": "240px"}}>
            <div style={{"color": INK, "fontSize": "22px", "fontWeight": "700", "marginBottom": f"{SP_2}px"}}>{label}</div>
            <input
                id={"link-" + code} readOnly={True} value={link} aria-label={"Link for " + label}
                onFocus={lambda (e: any) { e.target.select(); }}
                style={mono_style() | {"width": "100%", "boxSizing": "border-box", "minHeight": "44px", "padding": f"0 {SP_2}px", "border": f"1px solid {LINE}", "borderRadius": f"{RADIUS_BUTTON}px", "fontSize": "14px", "color": BODY, "backgroundColor": SURFACE}}
            />
            <div style={{"display": "flex", "alignItems": "center", "gap": f"{SP_2}px", "marginTop": f"{SP_2}px"}}>
                <button style={button_style()} onClick={lambda { onCopy(); }}>Copy link</button>
                {if copied {
                    <span style={pill_style(VEG_FG, VEG_BG) | {"fontWeight": "600"}}>Copied</span>
                }}
            </div>
        </div>
        <QrCode text={link} label={label}/>
    </div>
}
