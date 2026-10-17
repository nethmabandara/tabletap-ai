"""Menu endpoints. The client may call these two; everything else is server-only."""

import from .models { Restaurant, Table, Manages, HasTable }
import from .seed { build_wet_water }

"""The restaurant the caller manages, found through their Manages edge."""
def my_restaurant -> Restaurant | None {
    mine = [root ->:Manages:-> [?:Restaurant]];
    return mine[0] if mine else None;
}

"""Create the Wet Water starting data for this manager. True if created now."""
def:protect claim_demo_restaurant -> bool {
    if my_restaurant() is not None {
        return False;
    }
    build_wet_water();
    return True;
}

"""Guest check for a table link: 'ready', or 'coming_soon' before any menu exists."""
def:pub table_status(code: str) -> str {
    for rest in [root.shared -->[?:Restaurant]] {
        for table in [rest ->:HasTable:-> [?:Table]] {
            if table.code == code and rest.menu_published {
                return "ready";
            }
        }
    }
    return "coming_soon";
}
