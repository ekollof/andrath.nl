# lib/feeds.ksh — sort post list, build posts.list, RSS, Atom, sitemap, index page
# Sourced by publish.ksh; relies on globals: BLOG_NAME, SITE_URL, SITE_SUBTITLE,
# TIMESTAMP, pages, temp_sidebar_html already written.
# Reads: posts.list.unsorted, rss_content_* temp files, sitemap.urls.
# Writes: public/index.html, public/rss.xml, public/atom.xml, public/sitemap.xml.

build_feeds() {
    # -------------------------------------------------------------------------
    # Sort and process post list → posts.list, rss.items, atom.entries
    # -------------------------------------------------------------------------
    : > posts.list
    : > rss.items
    : > atom.entries

    BUILD_DATE=$(LC_ALL=en_US.UTF-8 date "+%a, %d %b %Y %H:%M:%S +0000")
    ATOM_DATE=$(LC_ALL=en_US.UTF-8 date "+%Y-%m-%dT%H:%M:%SZ")

    sort -r posts.list.unsorted | while IFS='|' read -r _sortable _htmlfile _title _date _author _summary; do
        printf '<li><a href="%s">%s</a> - %s</li>\n' \
            "$(echo "$_htmlfile" | sed 's|public/||')" "$_title" "$_date" >> posts.list

        _yr=$(echo "$_sortable" | cut -c1-4)
        _mo=$(echo "$_sortable" | cut -c6-7)
        _dy=$(echo "$_sortable" | cut -c9-10)
        _tm=$(echo "$_sortable" | cut -c12-19)
        num_to_month_abbr "$_mo" _mon
        _dow=$(LC_ALL=en_US.UTF-8 date -j -f "%Y-%m-%d" "${_yr}-${_mo}-${_dy}" "+%a" 2>/dev/null || echo "Mon")
        rss_date="$_dow, $_dy $_mon $_yr $_tm +0000"
        atom_date="${_yr}-${_mo}-${_dy}T${_tm}Z"

        _post_url="$SITE_URL/$(echo "$_htmlfile" | sed 's|public/||')"
        _rss_title=$(printf '%s' "$_title" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
        _rss_summary=$(printf '%s' "$_summary" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
        _rss_content_file="rss_content_$(echo "$_htmlfile" | sed 's|/|_|g')"

        cat >> rss.items <<RSSITEM
    <item>
      <title>$_rss_title</title>
      <link>$_post_url</link>
      <guid isPermaLink="true">$_post_url</guid>
      <pubDate>$rss_date</pubDate>
      <author>$_author</author>
      <description><![CDATA[
RSSITEM
        [ -f "$_rss_content_file" ] && cat "$_rss_content_file" >> rss.items
        cat >> rss.items <<RSSITEM
      ]]></description>
    </item>
RSSITEM

        cat >> atom.entries <<ATOMENTRY
  <entry>
    <title>$_rss_title</title>
    <link href="$_post_url" rel="alternate" type="text/html"/>
    <id>$_post_url</id>
    <updated>$atom_date</updated>
    <author><name>$_author</name></author>
    <summary>$_rss_summary</summary>
    <content type="html"><![CDATA[
ATOMENTRY
        [ -f "$_rss_content_file" ] && cat "$_rss_content_file" >> atom.entries
        cat >> atom.entries <<ATOMENTRY
    ]]></content>
  </entry>
ATOMENTRY

        rm -f "$_rss_content_file"
    done
    rm -f posts.list.unsorted

    # -------------------------------------------------------------------------
    # Index page
    # -------------------------------------------------------------------------
    sed \
        -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
        -e "s|{{SITE_SUBTITLE}}|$SITE_SUBTITLE|g" \
        -e "s|{{SITE_URL}}|$SITE_URL|g" \
        -e "s|{{PAGE_TYPE}}|index-page|g" \
        -e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
        -e "/{{SIDEBAR_HTML}}/r temp_sidebar_html" -e "/{{SIDEBAR_HTML}}/d" \
        -e "/{{SITE_DESCRIPTION_GROFF}}/r temp_site_description" -e "/{{SITE_DESCRIPTION_GROFF}}/d" \
        -e "/{{POST_LIST}}/r posts.list" -e "/{{POST_LIST}}/d" \
        templates/index.html.tmpl > public/index.html

    # -------------------------------------------------------------------------
    # RSS feed
    # -------------------------------------------------------------------------
    sed \
        -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
        -e "s|{{SITE_URL}}|$SITE_URL|g" \
        -e "s|{{SITE_SUBTITLE}}|$SITE_SUBTITLE|g" \
        -e "s|{{BUILD_DATE}}|$BUILD_DATE|g" \
        -e "/{{RSS_ITEMS}}/r rss.items" -e "/{{RSS_ITEMS}}/d" \
        templates/rss.xml.tmpl > public/rss.xml

    # -------------------------------------------------------------------------
    # Atom feed
    # -------------------------------------------------------------------------
    sed \
        -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
        -e "s|{{SITE_URL}}|$SITE_URL|g" \
        -e "s|{{SITE_SUBTITLE}}|$SITE_SUBTITLE|g" \
        -e "s|{{BUILD_DATE}}|$ATOM_DATE|g" \
        -e "/{{ATOM_ENTRIES}}/r atom.entries" -e "/{{ATOM_ENTRIES}}/d" \
        templates/atom.xml.tmpl > public/atom.xml

    # -------------------------------------------------------------------------
    # Sitemap
    # -------------------------------------------------------------------------
    printf '  <url><loc>%s/</loc></url>\n' "$SITE_URL" >> sitemap.urls
    sed \
        -e "/{{SITEMAP_URLS}}/r sitemap.urls" -e "/{{SITEMAP_URLS}}/d" \
        templates/sitemap.xml.tmpl > public/sitemap.xml

    rm -f posts.list rss.items atom.entries sitemap.urls
}
