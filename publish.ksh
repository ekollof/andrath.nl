#!/bin/ksh
set -e

# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------
DRAFTS="${DRAFTS:-0}"           # DRAFTS=1 to include draft posts
INCREMENTAL="${INCREMENTAL:-0}" # INCREMENTAL=1 to skip unchanged posts

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
if [ -f blog.conf ]; then
    . ./blog.conf
else
    BLOG_NAME="My Groff Blog"
    THEME_FONT="VT323"
    LIGHT_BG="#0c0c0c"
    LIGHT_FG="#33ff33"
    LIGHT_LINK="#3377ff"
    DARK_BG="#0c0c0c"
    DARK_FG="#33ff33"
    DARK_LINK="#3377ff"
    SITE_SUBTITLE="A minimalist blog built with groff on OpenBSD"
    TERMINAL_THEME="green"
    SITE_URL="https://example.com"
fi

if [ "$TERMINAL_THEME" = "amber" ]; then
    LIGHT_BG="#0c0c0c"; LIGHT_FG="#ffb000"; LIGHT_LINK="#ff9000"
    DARK_BG="#0c0c0c";  DARK_FG="#ffb000";  DARK_LINK="#ff9000"
fi

# ---------------------------------------------------------------------------
# Tool check
# ---------------------------------------------------------------------------
for _tool in groff perl sed awk sort; do
    command -v "$_tool" >/dev/null 2>&1 || { echo "Error: $_tool not found in PATH" >&2; exit 1; }
done

# ---------------------------------------------------------------------------
# Source library modules
# ---------------------------------------------------------------------------
. ./lib/helpers.ksh
. ./lib/assets.ksh
. ./lib/pages.ksh
. ./lib/posts.ksh
. ./lib/feeds.ksh
. ./lib/tags.ksh
. ./lib/archives.ksh

# ---------------------------------------------------------------------------
# Output directory setup
# ---------------------------------------------------------------------------
if [ "$INCREMENTAL" = "1" ] && [ -d public ]; then
    echo "Incremental build."
else
    rm -rf public
fi
mkdir -p public

TIMESTAMP=$(date +%s)

# ---------------------------------------------------------------------------
# Collect source files
# ---------------------------------------------------------------------------
set -- posts/*.ms
posts=""
i=1; while [ $i -le $# ]; do eval posts=\"\$posts \$$i\"; i=$((i+1)); done

set -- pages/*.ms
pages=""
i=1; while [ $i -le $# ]; do eval pages=\"\$pages \$$i\"; i=$((i+1)); done

# ---------------------------------------------------------------------------
# 1. Static assets + vars.css
# ---------------------------------------------------------------------------
build_assets

# ---------------------------------------------------------------------------
# 2. Sidebar HTML (needed by pages, posts, tags, archives)
# ---------------------------------------------------------------------------
build_sidebar pages

# ---------------------------------------------------------------------------
# 3. Static pages (bio, contact, …)
# ---------------------------------------------------------------------------
: > sitemap.urls
build_pages

# ---------------------------------------------------------------------------
# 4. Fallback index blurb if pages/index.ms didn't exist
# ---------------------------------------------------------------------------
if [ ! -f temp_site_description ]; then
    printf '<p>Welcome to my blog.</p>\n' > temp_site_description
fi

# ---------------------------------------------------------------------------
# 5. Date-sort all posts; build posts.sorted index
# ---------------------------------------------------------------------------
: > posts.order.unsorted
for post in $posts; do
    if grep -q "^\.DRAFT" "$post" && [ "$DRAFTS" != "1" ]; then
        continue
    fi
    _dl=$(sed -n '/^\.DA/{n;p;}' "$post")
    parse_date_line "$_dl" _sy _smo _sd _st
    echo "$_sy-$_smo-$_sd $_st|$post" >> posts.order.unsorted
done
sort posts.order.unsorted > posts.order
rm -f posts.order.unsorted

sorted_posts=""
: > posts.sorted
while IFS='|' read -r _sd _pf; do
    sorted_posts="$sorted_posts $_pf"
    echo "$_pf" >> posts.sorted
done < posts.order
rm -f posts.order

total_sorted=$(wc -l < posts.sorted | tr -d ' ')

# ---------------------------------------------------------------------------
# 6. Build post HTML + accumulate data files
# ---------------------------------------------------------------------------
build_posts

# ---------------------------------------------------------------------------
# 7. Feeds, index page, sitemap
# ---------------------------------------------------------------------------
build_feeds

# ---------------------------------------------------------------------------
# 8. Per-tag index pages
# ---------------------------------------------------------------------------
build_tags

# ---------------------------------------------------------------------------
# 9. Year/month archive pages
# ---------------------------------------------------------------------------
build_archives

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
rm -f temp_content temp_source temp_source_content \
      temp_sidebar_html temp_site_description \
      posts.sorted rss_content_*
