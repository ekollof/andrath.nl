# lib/pages.ksh — build static pages (non-post .ms files)
# Sourced by publish.ksh; relies on globals: BLOG_NAME, SITE_URL, TIMESTAMP,
# pages (space-separated list), temp_sidebar_html already written.
# Also appends to sitemap.urls.

build_pages() {
    if ! grep -q "CONTENT_PLACEHOLDER" templates/static.html.tmpl; then
        echo "Error: CONTENT_PLACEHOLDER not found in templates/static.html.tmpl" >&2
        exit 1
    fi

    for _page in $pages; do
        _pg_base=$(basename "$_page" .ms)
        _pg_title=$(sed -n '/^\.TL/{n;p;}' "$_page")
        [ -z "$_pg_title" ] && _pg_title="Untitled Page"
        _pg_html="public/${_pg_base}.html"
        _pg_sourcehtml="public/${_pg_base}_source.html"
        _pg_sourcefile="public/${_pg_base}.ms"

        # index.ms is the homepage blurb — render it into temp_site_description
        # and skip generating a standalone page for it
        if [ "$_pg_base" = "index" ]; then
            process_ms "$_page" temp_site_description
            continue
        fi

        process_ms "$_page" temp_content
        cp "$_page" "$_pg_sourcefile"

        sed 's/</\&lt;/g; s/>/\&gt;/g' "$_page" > temp_source
        { printf '<pre class="source-code"><code class="language-troff">\n'
          cat temp_source
          printf '</code></pre>\n'
        } > temp_source_content

        # Source view
        sed \
            -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
            -e "s|{{TITLE}}|$_pg_title (Source)|g" \
            -e "s|{{AUTHOR}}||g" -e "s|{{DATE}}||g" \
            -e "s|{{PAGE_TYPE}}|source-page|g" -e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
            -e "/{{SIDEBAR_HTML}}/r temp_sidebar_html" -e "/{{SIDEBAR_HTML}}/d" \
            -e "/CONTENT_PLACEHOLDER/r temp_source_content" -e "/CONTENT_PLACEHOLDER/d" \
            -e "s|{{PREV_LINK}}||g" -e "s|{{NEXT_LINK}}||g" -e "s|{{SOURCE_LINK}}||g" \
            templates/static.html.tmpl > "$_pg_sourcehtml"

        # Page itself
        sed \
            -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
            -e "s|{{TITLE}}|$_pg_title|g" \
            -e "s|{{AUTHOR}}||g" -e "s|{{DATE}}||g" \
            -e "s|{{PAGE_TYPE}}|static-page|g" -e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
            -e "/{{SIDEBAR_HTML}}/r temp_sidebar_html" -e "/{{SIDEBAR_HTML}}/d" \
            -e "/CONTENT_PLACEHOLDER/r temp_content" -e "/CONTENT_PLACEHOLDER/d" \
            -e "s|{{PREV_LINK}}||g" -e "s|{{NEXT_LINK}}||g" \
            -e "s|{{SOURCE_LINK}}|<a href=\"/${_pg_base}_source.html\">View Source</a>|g" \
            templates/static.html.tmpl > "$_pg_html"

        printf '  <url><loc>%s/%s.html</loc></url>\n' "$SITE_URL" "$_pg_base" >> sitemap.urls
    done

    rm -f temp_content temp_source temp_source_content
}
