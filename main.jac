"""TableTap AI: app entry. Wraps every page and loads the theme fonts."""

import from core.theme { FONTS_URL, GROUND }
import from core.orders { place_order, table_orders }
import from core.waiter { ask_waiter }
import from core.menu_setup { read_menu_photos, menu_read_progress }
import from core.menu_draft { get_draft }
import from core.menu_edit { add_draft_dish, update_draft_dish, delete_draft_dish, discard_draft }
import from core.menu_publish { publish_draft }
import from core.restaurants { create_restaurant, restaurant_status, table_links }
import from core.dj { ask_dj }
import from core.music { send_song_request, table_requests, music_queue, answer_request }
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
