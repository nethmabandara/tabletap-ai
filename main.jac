"""TableTap AI: app entry. Wraps every page and loads the theme fonts."""

import from core.theme { FONTS_URL, GROUND }
import from core.orders { place_order, table_orders }
import from core.kitchen { kitchen_orders, set_order_status, kitchen_dishes, set_sold_out }

def:pub app(children: any) -> JsxElement {
    <>
        <link rel="preconnect" href="https://fonts.googleapis.com"/>
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous"/>
        <link rel="stylesheet" href={FONTS_URL}/>
        <style>{"body { margin: 0; background: " + GROUND + "; }"}</style>
        {children}
    </>
}
