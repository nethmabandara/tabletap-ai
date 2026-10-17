"""TableTap AI: app entry. Wraps every page and loads the theme fonts."""

import from core.theme { FONTS_URL, GROUND }

def:pub app(children: any) -> JsxElement {
    <>
        <link rel="preconnect" href="https://fonts.googleapis.com"/>
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous"/>
        <link rel="stylesheet" href={FONTS_URL}/>
        <style>{"body { margin: 0; background: " + GROUND + "; }"}</style>
        {children}
    </>
}
