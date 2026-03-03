# lib/archives.ksh — generate year and year/month archive pages
# Sourced by publish.ksh; relies on globals: BLOG_NAME, SITE_URL, TIMESTAMP,
# temp_sidebar_html already written.
# Reads: archive.data (written by posts.ksh).
# Writes: public/YYYY/index.html, public/YYYY/MM/index.html.
# Appends: sitemap.urls (archive entries).

build_archives() {
    [ -f archive.data ] || return

    # Collect unique years and year-month pairs
    all_years=""
    all_year_months=""
    while IFS='|' read -r _sd _hf _ti _da _yr _mo; do
        case " $all_years " in
            *" $_yr "*) ;;
            *) all_years="$all_years $_yr" ;;
        esac
        _ym="${_yr}_${_mo}"
        case " $all_year_months " in
            *" $_ym "*) ;;
            *) all_year_months="$all_year_months $_ym" ;;
        esac
    done < archive.data

    # Per-year pages
    for _yr in $all_years; do
        mkdir -p "public/$_yr"
        : > "archive_posts_${_yr}.tmp"
        while IFS='|' read -r _sd _hf _ti _da _y _mo; do
            [ "$_y" = "$_yr" ] && echo "$_sd|$_hf|$_ti|$_da" >> "archive_posts_${_yr}.tmp"
        done < archive.data

        : > "archive_list_${_yr}.tmp"
        sort -r "archive_posts_${_yr}.tmp" | while IFS='|' read -r _sd _hf _ti _da; do
            printf '<li><a href="/%s">%s</a> - %s</li>\n' \
                "$(echo "$_hf" | sed 's|public/||')" "$_ti" "$_da" >> "archive_list_${_yr}.tmp"
        done

        sed \
            -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
            -e "s|{{ARCHIVE_LABEL}}|$_yr|g" \
            -e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
            -e "/{{SIDEBAR_HTML}}/r temp_sidebar_html" -e "/{{SIDEBAR_HTML}}/d" \
            -e "/{{POST_LIST}}/r archive_list_${_yr}.tmp" -e "/{{POST_LIST}}/d" \
            templates/archive.html.tmpl > "public/$_yr/index.html"

        rm -f "archive_posts_${_yr}.tmp" "archive_list_${_yr}.tmp"
        printf '  <url><loc>%s/%s/</loc></url>\n' "$SITE_URL" "$_yr" >> sitemap.urls
    done

    # Per-year/month pages
    for _ym in $all_year_months; do
        _yr=$(echo "$_ym" | cut -d_ -f1)
        _mo=$(echo "$_ym" | cut -d_ -f2)
        mkdir -p "public/$_yr/$_mo"
        num_to_month_name "$_mo" _mname
        _label="$_mname $_yr"

        : > "archive_posts_${_ym}.tmp"
        while IFS='|' read -r _sd _hf _ti _da _y _m; do
            [ "$_y" = "$_yr" ] && [ "$_m" = "$_mo" ] && \
                echo "$_sd|$_hf|$_ti|$_da" >> "archive_posts_${_ym}.tmp"
        done < archive.data

        : > "archive_list_${_ym}.tmp"
        sort -r "archive_posts_${_ym}.tmp" | while IFS='|' read -r _sd _hf _ti _da; do
            printf '<li><a href="/%s">%s</a> - %s</li>\n' \
                "$(echo "$_hf" | sed 's|public/||')" "$_ti" "$_da" >> "archive_list_${_ym}.tmp"
        done

        sed \
            -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
            -e "s|{{ARCHIVE_LABEL}}|$_label|g" \
            -e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
            -e "/{{SIDEBAR_HTML}}/r temp_sidebar_html" -e "/{{SIDEBAR_HTML}}/d" \
            -e "/{{POST_LIST}}/r archive_list_${_ym}.tmp" -e "/{{POST_LIST}}/d" \
            templates/archive.html.tmpl > "public/$_yr/$_mo/index.html"

        rm -f "archive_posts_${_ym}.tmp" "archive_list_${_ym}.tmp"
        printf '  <url><loc>%s/%s/%s/</loc></url>\n' "$SITE_URL" "$_yr" "$_mo" >> sitemap.urls
    done

    rm -f archive.data
}
