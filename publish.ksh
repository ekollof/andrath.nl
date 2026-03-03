#!/bin/ksh
set -e

# Full rebuild: remove and recreate public/
rm -rf public
mkdir -p public

rm -f posts.list posts.list.unsorted

# Load blog config
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

# Set terminal theme colors
if [ "$TERMINAL_THEME" = "amber" ]; then
    LIGHT_BG="#0c0c0c"
    LIGHT_FG="#ffb000"
    LIGHT_LINK="#ff9000"
    DARK_BG="#0c0c0c"
    DARK_FG="#ffb000"
    DARK_LINK="#ff9000"
fi

# Validate required tools
for _tool in groff perl sed awk sort; do
    command -v "$_tool" >/dev/null 2>&1 || { echo "Error: $_tool not found in PATH" >&2; exit 1; }
done

# Generate a timestamp for cache busting
TIMESTAMP=$(date +%s)

# ---------------------------------------------------------------------------
# Helper: convert English month name to zero-padded number.
# Sets the variable named in $2 (default: _month_num).
# Usage: month_to_num "March" month
# ---------------------------------------------------------------------------
month_to_num() {
    _mtn_name="$1"
    _mtn_var="${2:-_month_num}"
    case "$_mtn_name" in
        January)   eval "$_mtn_var=01" ;;
        February)  eval "$_mtn_var=02" ;;
        March)     eval "$_mtn_var=03" ;;
        April)     eval "$_mtn_var=04" ;;
        May)       eval "$_mtn_var=05" ;;
        June)      eval "$_mtn_var=06" ;;
        July)      eval "$_mtn_var=07" ;;
        August)    eval "$_mtn_var=08" ;;
        September) eval "$_mtn_var=09" ;;
        October)   eval "$_mtn_var=10" ;;
        November)  eval "$_mtn_var=11" ;;
        December)  eval "$_mtn_var=12" ;;
        *)         eval "$_mtn_var=00" ;;
    esac
}

# ---------------------------------------------------------------------------
# Helper: run the full groff pipeline on a .ms file, write body content to
# the given output file.
# Usage: process_ms file.ms output_content_file
# ---------------------------------------------------------------------------
process_ms() {
    _pm_src="$1"
    _pm_out="$2"
    perl preprocess-code.pl "$_pm_src" > temp_preprocessed.ms
    groff -ms -mwww -Thtml temp_preprocessed.ms > temp_groff.html
    perl normalize-html.pl temp_groff.html > temp_normalized.html
    sed -n \
        -e '/<body>/,/<\/body>/p' \
        temp_normalized.html \
    | sed \
        -e '1d' -e '$d' \
        -e '/<h1 align="center">/d' \
        -e 's|<p\(.*\)>\(.*\)</p>|<p\1 data-text="\2">\2</p>|g' \
    > "$_pm_out"
    rm -f temp_preprocessed.ms temp_groff.html temp_normalized.html
}

# ---------------------------------------------------------------------------
# Helper: parse a .DA date line into year/month/day/time variables.
# The four target variable names are passed as arguments.
# Usage: parse_date_line "March 03, 2026 11:01:32" year month day time
# ---------------------------------------------------------------------------
parse_date_line() {
    _pdl_line="$1"
    _pdl_yr_var="${2:-_yr}"
    _pdl_mo_var="${3:-_mo}"
    _pdl_dy_var="${4:-_dy}"
    _pdl_tm_var="${5:-_tm}"

    # Split time from date: last field is time if it matches HH:MM:SS
    _pdl_last=$(echo "$_pdl_line" | awk '{print $NF}')
    if echo "$_pdl_last" | grep -qE '^[0-2][0-9]:[0-5][0-9]:[0-5][0-9]$'; then
        _pdl_date=$(echo "$_pdl_line" | awk '{$NF=""; sub(/ *$/, ""); print}')
        _pdl_time="$_pdl_last"
    else
        _pdl_date="$_pdl_line"
        _pdl_time="00:00:00"
    fi

    if [ -z "$_pdl_date" ]; then
        eval "$_pdl_yr_var=0000"
        eval "$_pdl_mo_var=00"
        eval "$_pdl_dy_var=00"
        eval "$_pdl_tm_var=00:00:00"
        return
    fi

    _pdl_mn=$(echo "$_pdl_date" | awk '{print $1}')
    _pdl_d=$(echo "$_pdl_date"  | awk '{print $2}' | tr -d ',')
    _pdl_y=$(echo "$_pdl_date"  | awk '{print $3}')
    [ "${#_pdl_d}" -eq 1 ] && _pdl_d="0$_pdl_d"

    month_to_num "$_pdl_mn" _pdl_mnum

    eval "$_pdl_yr_var=$_pdl_y"
    eval "$_pdl_mo_var=$_pdl_mnum"
    eval "$_pdl_dy_var=$_pdl_d"
    eval "$_pdl_tm_var=$_pdl_time"
}

# ---------------------------------------------------------------------------
# Collect all posts and pages
# ---------------------------------------------------------------------------
set -- posts/*.ms
posts=""
i=1
while [ $i -le $# ]; do
    eval posts=\"\$posts \$$i\"
    i=$((i + 1))
done

set -- pages/*.ms
pages=""
i=1
while [ $i -le $# ]; do
    eval pages=\"\$pages \$$i\"
    i=$((i + 1))
done

# Create asset directories
mkdir -p public/css public/js public/images public/fonts

# ---------------------------------------------------------------------------
# Build sidebar HTML
# ---------------------------------------------------------------------------
sidebar_html="        <div class=\"sidebar-link\"><span class=\"fa fa-terminal\"></span> <a href=\"/index.html\">Home</a></div>"

# Add static pages to sidebar (first pass — titles only, no groff needed yet)
for page in $pages; do
    [ "$(basename "$page" .ms)" = "index" ] && continue
    _pg_title=$(sed -n '/^\.TL/{n;p;}' "$page")
    [ -z "$_pg_title" ] && _pg_title="Untitled Page"
    _pg_base=$(basename "$page" .ms)
    sidebar_html="$sidebar_html
        <div class=\"sidebar-link\"><span class=\"fa fa-file-text\"></span> <a href=\"/$_pg_base.html\">$_pg_title</a></div>"
done

# Append external links from sidebar.links
if [ -f sidebar.links ]; then
    : > temp_sidebar
    while IFS='|' read -r _type _url _label _icon; do
        printf '        <div class="sidebar-link"><span class="fa %s"></span> <a href="%s">%s</a></div>\n' \
            "$_icon" "$_url" "$_label" >> temp_sidebar
    done < sidebar.links
    sidebar_links=$(cat temp_sidebar)
    rm -f temp_sidebar
else
    sidebar_links='        <div class="sidebar-link"><span class="fa fa-terminal"></span> <a href="https://x.com/example_user">X: @example_user</a></div>
        <div class="sidebar-link"><span class="fa fa-code"></span> <a href="https://example.com">My Website</a></div>'
fi
sidebar_html="$sidebar_html
$sidebar_links"
sidebar_html="<div class=\"sidebar-links-list\">
$sidebar_html
</div>"
printf '%s\n' "$sidebar_html" > temp_sidebar_html

# ---------------------------------------------------------------------------
# Generate vars.css
# ---------------------------------------------------------------------------
{
    echo ":root {"
    echo "    --light-bg: $LIGHT_BG;"
    echo "    --light-fg: $LIGHT_FG;"
    echo "    --light-link: $LIGHT_LINK;"
    echo "    --dark-bg: $DARK_BG;"
    echo "    --dark-fg: $DARK_FG;"
    echo "    --dark-link: $DARK_LINK;"
    if [ "$TERMINAL_THEME" = "amber" ]; then
        echo "    --terminal-color: #ffb000;"
        echo "    --terminal-dim: #aa7700;"
        echo "    --terminal-accent: #ffd000;"
    else
        echo "    --terminal-color: #33ff33;"
        echo "    --terminal-dim: #33aa33;"
        echo "    --terminal-accent: #00aaaa;"
    fi
    echo "    --theme-font: '$THEME_FONT', 'Courier New', monospace;"
    echo "    --terminal-theme: '$TERMINAL_THEME';"
    echo "}"
} > public/css/vars.css

# ---------------------------------------------------------------------------
# Copy static files
# ---------------------------------------------------------------------------
for file in $(find static/ -type f -print); do
    ext="${file##*.}"
    case "$ext" in
        css)              cp "$file" public/css/ ;;
        js)               cp "$file" public/js/ ;;
        jpg|png|gif|svg)  cp "$file" public/images/ ;;
        ttf|woff|woff2|eot) cp "$file" public/fonts/ ;;
        *)                cp "$file" public/ ;;
    esac
done

# ---------------------------------------------------------------------------
# Process static pages (single pass now that sidebar is complete)
# ---------------------------------------------------------------------------

# Validate template before looping
if ! grep -q "CONTENT_PLACEHOLDER" templates/static.html.tmpl; then
    echo "Error: CONTENT_PLACEHOLDER not found in templates/static.html.tmpl" >&2
    exit 1
fi

for page in $pages; do
    [ "$(basename "$page" .ms)" = "index" ] && continue

    _pg_base=$(basename "$page" .ms)
    title=$(sed -n '/^\.TL/{n;p;}' "$page")
    [ -z "$title" ] && title="Untitled Page"
    htmlfile="public/${_pg_base}.html"
    sourcehtml="public/${_pg_base}_source.html"
    sourcefile="public/${_pg_base}.ms"

    process_ms "$page" temp_content

    cp "$page" "$sourcefile"

    # Source HTML
    sed 's/</\&lt;/g; s/>/\&gt;/g' "$page" > temp_source
    {
        printf '<pre class="source-code"><code class="language-troff">\n'
        cat temp_source
        printf '</code></pre>\n'
    } > temp_source_content
    sed \
        -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
        -e "s|{{TITLE}}|$title (Source)|g" \
        -e "s|{{AUTHOR}}||g" \
        -e "s|{{DATE}}||g" \
        -e "s|{{PAGE_TYPE}}||g" \
        -e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
        -e "/{{SIDEBAR_HTML}}/r temp_sidebar_html" -e "/{{SIDEBAR_HTML}}/d" \
        -e "/CONTENT_PLACEHOLDER/r temp_source_content" -e "/CONTENT_PLACEHOLDER/d" \
        -e "s|{{PREV_LINK}}||g" \
        -e "s|{{NEXT_LINK}}||g" \
        -e "s|{{SOURCE_LINK}}||g" \
        templates/static.html.tmpl > "$sourcehtml"

    # Main HTML
    sed \
        -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
        -e "s|{{TITLE}}|$title|g" \
        -e "s|{{AUTHOR}}||g" \
        -e "s|{{DATE}}||g" \
        -e "s|{{PAGE_TYPE}}|static-page|g" \
        -e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
        -e "/{{SIDEBAR_HTML}}/r temp_sidebar_html" -e "/{{SIDEBAR_HTML}}/d" \
        -e "/CONTENT_PLACEHOLDER/r temp_content" -e "/CONTENT_PLACEHOLDER/d" \
        -e "s|{{PREV_LINK}}||g" \
        -e "s|{{NEXT_LINK}}||g" \
        -e "s|{{SOURCE_LINK}}|<a href=\"/${_pg_base}_source.html\">View Source</a>|g" \
        templates/static.html.tmpl > "$htmlfile"
done

# ---------------------------------------------------------------------------
# Process index.ms description blurb
# ---------------------------------------------------------------------------
if [ -f index.ms ]; then
    process_ms index.ms temp_site_description
else
    printf '<p>Welcome to my blog.</p>\n' > temp_site_description
fi

# ---------------------------------------------------------------------------
# Date-sort posts (oldest first) into sorted_posts and posts.sorted index
# ---------------------------------------------------------------------------
: > posts.order.unsorted
for post in $posts; do
    _dl=$(sed -n '/^\.DA/{n;p;}' "$post")
    parse_date_line "$_dl" _sy _smo _sd _st
    echo "$_sy-$_smo-$_sd $_st|$post" >> posts.order.unsorted
done
sort posts.order.unsorted > posts.order
rm -f posts.order.unsorted

# Build sorted_posts string and a line-indexed file for O(1) prev/next lookup
sorted_posts=""
: > posts.sorted
while IFS='|' read -r _sd _pf; do
    sorted_posts="$sorted_posts $_pf"
    echo "$_pf" >> posts.sorted
done < posts.order
rm -f posts.order

total_sorted=$(wc -l < posts.sorted | tr -d ' ')

# ---------------------------------------------------------------------------
# Generate posts
# ---------------------------------------------------------------------------
: > posts.list.unsorted
: > rss.items

i=0
for post in $sorted_posts; do
    title=$(sed -n '/^\.TL/{n;p;}' "$post")
    author=$(sed -n '/^\.AU/{n;p;}' "$post")
    _dl=$(sed -n '/^\.DA/{n;p;}' "$post")
    parse_date_line "$_dl" year month day time
    [ -z "$title" ] && title="Untitled"
    [ -z "$author" ] && author="Anonymous"
    sortable_date="$year-$month-$day $time"

    # Reconstruct display date from parsed components for consistency
    case "$month" in
        01) _mname="January"   ;; 02) _mname="February"  ;; 03) _mname="March"     ;;
        04) _mname="April"     ;; 05) _mname="May"        ;; 06) _mname="June"      ;;
        07) _mname="July"      ;; 08) _mname="August"     ;; 09) _mname="September" ;;
        10) _mname="October"   ;; 11) _mname="November"   ;; 12) _mname="December"  ;;
        *)  _mname="Unknown"   ;;
    esac
    if [ "$year" = "0000" ]; then
        display_date="No Date"
    else
        display_date="$_mname $day, $year"
    fi

    post_dir="public/$year/$month/$day"
    mkdir -p "$post_dir"
    htmlfile="$post_dir/$(basename "$post" .ms).html"
    sourcehtml="$post_dir/$(basename "$post" .ms)_source.html"
    sourcefile="$post_dir/$(basename "$post" .ms).ms"

    cp "$post" "$sourcefile"

    # Source page
    sed 's/</\&lt;/g; s/>/\&gt;/g' "$post" > temp_source
    {
        printf '<pre class="source-code"><code class="language-troff">\n'
        cat temp_source
        printf '</code></pre>\n'
    } > temp_source_content
    sed \
        -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
        -e "s|{{TITLE}}|$title (Source)|g" \
        -e "s|{{AUTHOR}}|$author|g" \
        -e "s|{{DATE}}|$display_date|g" \
        -e "s|{{PAGE_TYPE}}||g" \
        -e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
        -e "/{{SIDEBAR_HTML}}/r temp_sidebar_html" -e "/{{SIDEBAR_HTML}}/d" \
        -e "/CONTENT_PLACEHOLDER/r temp_source_content" -e "/CONTENT_PLACEHOLDER/d" \
        -e "s|{{PREV_LINK}}||g" \
        -e "s|{{NEXT_LINK}}||g" \
        -e "s|{{SOURCE_LINK}}||g" \
        templates/post.html.tmpl > "$sourcehtml"

    # Prev/Next using indexed file (O(1) per lookup)
    prev_link=""
    next_link=""
    one_based=$((i + 1))

    if [ "$one_based" -gt 1 ]; then
        prev_i=$((one_based - 1))
        prev_post=$(sed -n "${prev_i}p" posts.sorted)
        _pdl=$(sed -n '/^\.DA/{n;p;}' "$prev_post")
        parse_date_line "$_pdl" prev_year prev_month prev_day _pt
        prev_file="$(basename "$prev_post" .ms).html"
        prev_title=$(sed -n '/^\.TL/{n;p;}' "$prev_post")
        [ -z "$prev_title" ] && prev_title="Previous Post"
        if [ "$year/$month/$day" = "$prev_year/$prev_month/$prev_day" ]; then
            prev_link="<a href=\"$prev_file\">← $prev_title</a>"
        else
            prev_link="<a href=\"../../../$prev_year/$prev_month/$prev_day/$prev_file\">← $prev_title</a>"
        fi
    fi

    next_i=$((one_based + 1))
    if [ "$next_i" -le "$total_sorted" ]; then
        next_post=$(sed -n "${next_i}p" posts.sorted)
        _ndl=$(sed -n '/^\.DA/{n;p;}' "$next_post")
        parse_date_line "$_ndl" next_year next_month next_day _nt
        next_file="$(basename "$next_post" .ms).html"
        next_title=$(sed -n '/^\.TL/{n;p;}' "$next_post")
        [ -z "$next_title" ] && next_title="Next Post"
        if [ "$year/$month/$day" = "$next_year/$next_month/$next_day" ]; then
            next_link="<a href=\"$next_file\">$next_title →</a>"
        else
            next_link="<a href=\"../../../$next_year/$next_month/$next_day/$next_file\">$next_title →</a>"
        fi
    fi

    # Post content
    process_ms "$post" temp_content

    # Save for RSS
    rss_content_file="rss_content_$(echo "$htmlfile" | sed 's|/|_|g')"
    cp temp_content "$rss_content_file"

    sed \
        -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
        -e "s|{{TITLE}}|$title|g" \
        -e "s|{{AUTHOR}}|$author|g" \
        -e "s|{{DATE}}|$display_date|g" \
        -e "s|{{PAGE_TYPE}}||g" \
        -e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
        -e "/{{SIDEBAR_HTML}}/r temp_sidebar_html" -e "/{{SIDEBAR_HTML}}/d" \
        -e "/CONTENT_PLACEHOLDER/r temp_content" -e "/CONTENT_PLACEHOLDER/d" \
        -e "s|{{PREV_LINK}}|$prev_link|g" \
        -e "s|{{NEXT_LINK}}|$next_link|g" \
        -e "s|{{SOURCE_LINK}}|<a href=\"$(basename "$sourcehtml")\">View Source</a>|g" \
        templates/post.html.tmpl > "$htmlfile"

    echo "$sortable_date|$htmlfile|$title|$display_date|$author" >> posts.list.unsorted
    i=$((i + 1))
done

# ---------------------------------------------------------------------------
# Sort posts and build posts.list + rss.items (newest first)
# ---------------------------------------------------------------------------
: > posts.list
sort -r posts.list.unsorted | while IFS='|' read -r _sortable _htmlfile _title _date _author; do
    printf '<li><a href="%s">%s</a> - %s</li>\n' \
        "$(echo "$_htmlfile" | sed 's|public/||')" "$_title" "$_date" >> posts.list

    # RFC 2822 pubDate — needs day-of-week
    _yr=$(echo "$_sortable" | cut -c1-4)
    _mo=$(echo "$_sortable" | cut -c6-7)
    _dy=$(echo "$_sortable" | cut -c9-10)
    _tm=$(echo "$_sortable" | cut -c12-19)
    case "$_mo" in
        01) _mon="Jan" ;; 02) _mon="Feb" ;; 03) _mon="Mar" ;;
        04) _mon="Apr" ;; 05) _mon="May" ;; 06) _mon="Jun" ;;
        07) _mon="Jul" ;; 08) _mon="Aug" ;; 09) _mon="Sep" ;;
        10) _mon="Oct" ;; 11) _mon="Nov" ;; 12) _mon="Dec" ;;
        *) _mon="Jan" ;;
    esac
    # Compute day-of-week via date(1) — LC_ALL ensures English output
    _dow=$(LC_ALL=en_US.UTF-8 date -j -f "%Y-%m-%d" "${_yr}-${_mo}-${_dy}" "+%a" 2>/dev/null || echo "Mon")
    rss_date="$_dow, $_dy $_mon $_yr $_tm +0000"

    _post_url="$SITE_URL/$(echo "$_htmlfile" | sed 's|public/||')"
    _rss_title=$(printf '%s' "$_title" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
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
    cat "$_rss_content_file" >> rss.items
    cat >> rss.items <<RSSITEM
      ]]></description>
    </item>
RSSITEM
    rm -f "$_rss_content_file"
done
rm -f posts.list.unsorted

# ---------------------------------------------------------------------------
# Generate index page
# ---------------------------------------------------------------------------
sed \
    -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
    -e "s|{{SITE_SUBTITLE}}|$SITE_SUBTITLE|g" \
    -e "s|{{PAGE_TYPE}}|index-page|g" \
    -e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
    -e "/{{SIDEBAR_HTML}}/r temp_sidebar_html" -e "/{{SIDEBAR_HTML}}/d" \
    -e "/{{SITE_DESCRIPTION_GROFF}}/r temp_site_description" -e "/{{SITE_DESCRIPTION_GROFF}}/d" \
    -e "/{{POST_LIST}}/r posts.list" -e "/{{POST_LIST}}/d" \
    templates/index.html.tmpl > public/index.html

# ---------------------------------------------------------------------------
# Generate RSS feed
# ---------------------------------------------------------------------------
BUILD_DATE=$(LC_ALL=en_US.UTF-8 date "+%a, %d %b %Y %H:%M:%S +0000")
sed \
    -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
    -e "s|{{SITE_URL}}|$SITE_URL|g" \
    -e "s|{{SITE_SUBTITLE}}|$SITE_SUBTITLE|g" \
    -e "s|{{BUILD_DATE}}|$BUILD_DATE|g" \
    -e "/{{RSS_ITEMS}}/r rss.items" -e "/{{RSS_ITEMS}}/d" \
    templates/rss.xml.tmpl > public/rss.xml

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
rm -f temp_content temp_source temp_source_content temp_sidebar_html \
      temp_site_description posts.list posts.order posts.order.unsorted \
      posts.sorted rss.items rss_content_*
