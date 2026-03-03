# lib/assets.ksh — copy static files, generate vars.css, build sidebar HTML
# Sourced by publish.ksh; relies on globals: BLOG_NAME, SITE_URL, TIMESTAMP,
# LIGHT_BG/FG/LINK, DARK_BG/FG/LINK, TERMINAL_THEME, THEME_FONT, pages.

build_assets() {
    # -------------------------------------------------------------------------
    # Asset directories + static files
    # -------------------------------------------------------------------------
    mkdir -p public/css public/js public/images public/fonts

    for _file in $(find static/ -type f -print); do
        _ext="${_file##*.}"
        case "$_ext" in
            css)                cp "$_file" public/css/ ;;
            js)                 cp "$_file" public/js/ ;;
            jpg|png|gif|svg)    cp "$_file" public/images/ ;;
            ttf|woff|woff2|eot) cp "$_file" public/fonts/ ;;
            *)                  cp "$_file" public/ ;;
        esac
    done

    # -------------------------------------------------------------------------
    # vars.css
    # -------------------------------------------------------------------------
    {
        printf ':root {\n'
        printf '    --light-bg: %s;\n'   "$LIGHT_BG"
        printf '    --light-fg: %s;\n'   "$LIGHT_FG"
        printf '    --light-link: %s;\n' "$LIGHT_LINK"
        printf '    --dark-bg: %s;\n'    "$DARK_BG"
        printf '    --dark-fg: %s;\n'    "$DARK_FG"
        printf '    --dark-link: %s;\n'  "$DARK_LINK"
        if [ "$TERMINAL_THEME" = "amber" ]; then
            printf '    --terminal-color: #ffb000;\n'
            printf '    --terminal-dim: #aa7700;\n'
            printf '    --terminal-accent: #ffd000;\n'
        else
            printf '    --terminal-color: #33ff33;\n'
            printf '    --terminal-dim: #33aa33;\n'
            printf '    --terminal-accent: #00aaaa;\n'
        fi
        printf "    --theme-font: '%s', 'Courier New', monospace;\n" "$THEME_FONT"
        printf "    --terminal-theme: '%s';\n" "$TERMINAL_THEME"
        printf '}\n'
    } > public/css/vars.css
}

# ---------------------------------------------------------------------------
# build_sidebar pages_var
# Builds temp_sidebar_html from static page titles + sidebar.links.
# pages_var is the name of the variable holding the space-separated page list.
# ---------------------------------------------------------------------------
build_sidebar() {
    _bs_pages_var="$1"
    eval "_bs_pages=\$$_bs_pages_var"

    sidebar_html='        <div class="sidebar-link"><span class="fa fa-terminal"></span> <a href="/index.html">Home</a></div>'

    for _page in $_bs_pages; do
        [ "$(basename "$_page" .ms)" = "index" ] && continue
        _pg_title=$(sed -n '/^\.TL/{n;p;}' "$_page")
        [ -z "$_pg_title" ] && _pg_title="Untitled Page"
        _pg_base=$(basename "$_page" .ms)
        sidebar_html="$sidebar_html
        <div class=\"sidebar-link\"><span class=\"fa fa-file-text\"></span> <a href=\"/$_pg_base.html\">$_pg_title</a></div>"
    done

    if [ -f sidebar.links ]; then
        : > temp_sidebar
        while IFS='|' read -r _type _url _label _icon; do
            printf '        <div class="sidebar-link"><span class="fa %s"></span> <a href="%s">%s</a></div>\n' \
                "$_icon" "$_url" "$_label" >> temp_sidebar
        done < sidebar.links
        _sidebar_links=$(cat temp_sidebar); rm -f temp_sidebar
    else
        _sidebar_links='        <div class="sidebar-link"><span class="fa fa-terminal"></span> <a href="https://x.com/example_user">X: @example_user</a></div>
        <div class="sidebar-link"><span class="fa fa-code"></span> <a href="https://example.com">My Website</a></div>'
    fi

    sidebar_html="$sidebar_html
$_sidebar_links"
    sidebar_html="<div class=\"sidebar-links-list\">
$sidebar_html
</div>"
    printf '%s\n' "$sidebar_html" > temp_sidebar_html
}
