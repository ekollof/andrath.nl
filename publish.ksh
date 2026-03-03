#!/bin/ksh
set -e

# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------
DRAFTS="${DRAFTS:-0}"       # set DRAFTS=1 to include draft posts
INCREMENTAL="${INCREMENTAL:-0}"  # set INCREMENTAL=1 to skip unchanged posts

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
# Rebuild or incremental setup
# ---------------------------------------------------------------------------
if [ "$INCREMENTAL" = "1" ] && [ -d public ]; then
    echo "Incremental build."
else
    rm -rf public
fi
mkdir -p public

TIMESTAMP=$(date +%s)

# ---------------------------------------------------------------------------
# Helper: English month name → zero-padded number
# month_to_num "March" varname
# ---------------------------------------------------------------------------
month_to_num() {
    _mtn_name="$1"; _mtn_var="${2:-_month_num}"
    case "$_mtn_name" in
        January)   eval "$_mtn_var=01" ;; February)  eval "$_mtn_var=02" ;;
        March)     eval "$_mtn_var=03" ;; April)     eval "$_mtn_var=04" ;;
        May)       eval "$_mtn_var=05" ;; June)      eval "$_mtn_var=06" ;;
        July)      eval "$_mtn_var=07" ;; August)    eval "$_mtn_var=08" ;;
        September) eval "$_mtn_var=09" ;; October)   eval "$_mtn_var=10" ;;
        November)  eval "$_mtn_var=11" ;; December)  eval "$_mtn_var=12" ;;
        *)         eval "$_mtn_var=00" ;;
    esac
}

# ---------------------------------------------------------------------------
# Helper: run groff pipeline, write body HTML to output file
# process_ms src.ms output_file
# ---------------------------------------------------------------------------
process_ms() {
    _pm_src="$1"; _pm_out="$2"
    perl preprocess-code.pl "$_pm_src" > temp_preprocessed.ms
    groff -ms -mwww -Thtml temp_preprocessed.ms > temp_groff.html
    perl normalize-html.pl temp_groff.html > temp_normalized.html
    sed -n '/<body>/,/<\/body>/p' temp_normalized.html \
    | sed -e '1d' -e '$d' \
          -e '/<h1 align="center">/d' \
          -e 's|<p\(.*\)>\(.*\)</p>|<p\1 data-text="\2">\2</p>|g' \
    > "$_pm_out"
    rm -f temp_preprocessed.ms temp_groff.html temp_normalized.html
}

# ---------------------------------------------------------------------------
# Helper: parse a .DA date line into year/month/day/time variables
# parse_date_line "March 03, 2026 11:01:32" yr_var mo_var dy_var tm_var
# ---------------------------------------------------------------------------
parse_date_line() {
    _pdl_line="$1"
    _pdl_yr_var="${2:-_yr}"; _pdl_mo_var="${3:-_mo}"
    _pdl_dy_var="${4:-_dy}"; _pdl_tm_var="${5:-_tm}"

    _pdl_last=$(echo "$_pdl_line" | awk '{print $NF}')
    if echo "$_pdl_last" | grep -qE '^[0-2][0-9]:[0-5][0-9]:[0-5][0-9]$'; then
        _pdl_date=$(echo "$_pdl_line" | awk '{$NF=""; sub(/ *$/, ""); print}')
        _pdl_time="$_pdl_last"
    else
        _pdl_date="$_pdl_line"; _pdl_time="00:00:00"
    fi

    if [ -z "$_pdl_date" ]; then
        eval "$_pdl_yr_var=0000"; eval "$_pdl_mo_var=00"
        eval "$_pdl_dy_var=00";   eval "$_pdl_tm_var=00:00:00"
        return
    fi

    _pdl_mn=$(echo "$_pdl_date" | awk '{print $1}')
    _pdl_d=$(echo "$_pdl_date"  | awk '{print $2}' | tr -d ',')
    _pdl_y=$(echo "$_pdl_date"  | awk '{print $3}')
    [ "${#_pdl_d}" -eq 1 ] && _pdl_d="0$_pdl_d"
    month_to_num "$_pdl_mn" _pdl_mnum
    eval "$_pdl_yr_var=$_pdl_y"; eval "$_pdl_mo_var=$_pdl_mnum"
    eval "$_pdl_dy_var=$_pdl_d"; eval "$_pdl_tm_var=$_pdl_time"
}

# ---------------------------------------------------------------------------
# Collect posts and pages
# ---------------------------------------------------------------------------
set -- posts/*.ms
posts=""
i=1; while [ $i -le $# ]; do eval posts=\"\$posts \$$i\"; i=$((i+1)); done

set -- pages/*.ms
pages=""
i=1; while [ $i -le $# ]; do eval pages=\"\$pages \$$i\"; i=$((i+1)); done

# ---------------------------------------------------------------------------
# Asset directories + static files
# ---------------------------------------------------------------------------
mkdir -p public/css public/js public/images public/fonts

for file in $(find static/ -type f -print); do
    ext="${file##*.}"
    case "$ext" in
        css)                cp "$file" public/css/ ;;
        js)                 cp "$file" public/js/ ;;
        jpg|png|gif|svg)    cp "$file" public/images/ ;;
        ttf|woff|woff2|eot) cp "$file" public/fonts/ ;;
        *)                  cp "$file" public/ ;;
    esac
done

# ---------------------------------------------------------------------------
# vars.css
# ---------------------------------------------------------------------------
{
    echo ":root {"
    echo "    --light-bg: $LIGHT_BG;"; echo "    --light-fg: $LIGHT_FG;"
    echo "    --light-link: $LIGHT_LINK;"
    echo "    --dark-bg: $DARK_BG;";   echo "    --dark-fg: $DARK_FG;"
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
# Build sidebar HTML (static page titles first, then sidebar.links)
# ---------------------------------------------------------------------------
sidebar_html='        <div class="sidebar-link"><span class="fa fa-terminal"></span> <a href="/index.html">Home</a></div>'

for page in $pages; do
    [ "$(basename "$page" .ms)" = "index" ] && continue
    _pg_title=$(sed -n '/^\.TL/{n;p;}' "$page")
    [ -z "$_pg_title" ] && _pg_title="Untitled Page"
    _pg_base=$(basename "$page" .ms)
    sidebar_html="$sidebar_html
        <div class=\"sidebar-link\"><span class=\"fa fa-file-text\"></span> <a href=\"/$_pg_base.html\">$_pg_title</a></div>"
done

if [ -f sidebar.links ]; then
    : > temp_sidebar
    while IFS='|' read -r _type _url _label _icon; do
        printf '        <div class="sidebar-link"><span class="fa %s"></span> <a href="%s">%s</a></div>\n' \
            "$_icon" "$_url" "$_label" >> temp_sidebar
    done < sidebar.links
    sidebar_links=$(cat temp_sidebar); rm -f temp_sidebar
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
# Validate templates
# ---------------------------------------------------------------------------
if ! grep -q "CONTENT_PLACEHOLDER" templates/static.html.tmpl; then
    echo "Error: CONTENT_PLACEHOLDER not found in templates/static.html.tmpl" >&2; exit 1
fi

# ---------------------------------------------------------------------------
# Static pages
# ---------------------------------------------------------------------------
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

    sed 's/</\&lt;/g; s/>/\&gt;/g' "$page" > temp_source
    { printf '<pre class="source-code"><code class="language-troff">\n'; cat temp_source; printf '</code></pre>\n'; } > temp_source_content

    sed \
        -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
        -e "s|{{TITLE}}|$title (Source)|g" \
        -e "s|{{AUTHOR}}||g" -e "s|{{DATE}}||g" \
        -e "s|{{PAGE_TYPE}}||g" -e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
        -e "/{{SIDEBAR_HTML}}/r temp_sidebar_html" -e "/{{SIDEBAR_HTML}}/d" \
        -e "/CONTENT_PLACEHOLDER/r temp_source_content" -e "/CONTENT_PLACEHOLDER/d" \
        -e "s|{{PREV_LINK}}||g" -e "s|{{NEXT_LINK}}||g" -e "s|{{SOURCE_LINK}}||g" \
        templates/static.html.tmpl > "$sourcehtml"

    sed \
        -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
        -e "s|{{TITLE}}|$title|g" \
        -e "s|{{AUTHOR}}||g" -e "s|{{DATE}}||g" \
        -e "s|{{PAGE_TYPE}}|static-page|g" -e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
        -e "/{{SIDEBAR_HTML}}/r temp_sidebar_html" -e "/{{SIDEBAR_HTML}}/d" \
        -e "/CONTENT_PLACEHOLDER/r temp_content" -e "/CONTENT_PLACEHOLDER/d" \
        -e "s|{{PREV_LINK}}||g" -e "s|{{NEXT_LINK}}||g" \
        -e "s|{{SOURCE_LINK}}|<a href=\"/${_pg_base}_source.html\">View Source</a>|g" \
        templates/static.html.tmpl > "$htmlfile"
done

# ---------------------------------------------------------------------------
# index.ms description
# ---------------------------------------------------------------------------
if [ -f index.ms ]; then
    process_ms index.ms temp_site_description
else
    printf '<p>Welcome to my blog.</p>\n' > temp_site_description
fi

# ---------------------------------------------------------------------------
# Date-sort all posts; build posts.sorted index
# ---------------------------------------------------------------------------
: > posts.order.unsorted
for post in $posts; do
    # Skip drafts unless DRAFTS=1
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
# Generate posts
# ---------------------------------------------------------------------------
: > posts.list.unsorted
: > rss.items
: > atom.entries
: > sitemap.urls
: > tag.data          # sortable_date|htmlfile|title|display_date|taglist
: > archive.data      # sortable_date|htmlfile|title|display_date|YYYY|MM

i=0
for post in $sorted_posts; do
    title=$(sed -n '/^\.TL/{n;p;}' "$post")
    author=$(sed -n '/^\.AU/{n;p;}' "$post")
    summary=$(sed -n '/^\.SUMMARY/{n;p;}' "$post")
    tags_raw=$(sed -n '/^\.TAG/{n;p;}' "$post")
    _dl=$(sed -n '/^\.DA/{n;p;}' "$post")
    parse_date_line "$_dl" year month day time

    [ -z "$title" ]   && title="Untitled"
    [ -z "$author" ]  && author="Anonymous"
    [ -z "$summary" ] && summary="$title — $BLOG_NAME"

    # Warn about posts with no date
    [ "$year" = "0000" ] && echo "Warning: no valid date in $post" >&2

    # Display date from parsed components
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

    sortable_date="$year-$month-$day $time"
    post_dir="public/$year/$month/$day"
    mkdir -p "$post_dir"
    htmlfile="$post_dir/$(basename "$post" .ms).html"
    sourcehtml="$post_dir/$(basename "$post" .ms)_source.html"
    sourcefile="$post_dir/$(basename "$post" .ms).ms"
    post_url="$SITE_URL/$(echo "$htmlfile" | sed 's|public/||')"

    # Reading time: count non-macro lines in source
    read_words=$(grep -v '^\.' "$post" | wc -w | tr -d ' ')
    read_mins=$(( (read_words + 199) / 200 ))
    [ "$read_mins" -lt 1 ] && read_mins=1
    read_time_str=" · ${read_mins} min read"

    # Build tag links HTML
    tag_links_html=""
    if [ -n "$tags_raw" ]; then
        tag_links_html='<div class="post-tags">'
        for _tag in $tags_raw; do
            _tag=$(printf '%s' "$_tag" | tr -d ',')
            [ -z "$_tag" ] && continue
            tag_links_html="${tag_links_html}<a href=\"/tags/${_tag}.html\">#${_tag}</a> "
        done
        tag_links_html="${tag_links_html}</div>"
    fi

    cp "$post" "$sourcefile"

    # Source page
    sed 's/</\&lt;/g; s/>/\&gt;/g' "$post" > temp_source
    { printf '<pre class="source-code"><code class="language-troff">\n'; cat temp_source; printf '</code></pre>\n'; } > temp_source_content
    sed \
        -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
        -e "s|{{TITLE}}|$title (Source)|g" \
        -e "s|{{SUMMARY}}|$summary|g" \
        -e "s|{{AUTHOR}}|$author|g" -e "s|{{DATE}}|$display_date|g" \
        -e "s|{{PAGE_TYPE}}||g" -e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
        -e "s|{{POST_URL}}|$post_url|g" \
        -e "s|{{SITE_URL}}|$SITE_URL|g" \
        -e "s|{{READ_TIME}}||g" \
        -e "/{{TAG_LINKS}}/d" \
        -e "/{{SIDEBAR_HTML}}/r temp_sidebar_html" -e "/{{SIDEBAR_HTML}}/d" \
        -e "/CONTENT_PLACEHOLDER/r temp_source_content" -e "/CONTENT_PLACEHOLDER/d" \
        -e "s|{{PREV_LINK}}||g" -e "s|{{NEXT_LINK}}||g" -e "s|{{SOURCE_LINK}}||g" \
        templates/post.html.tmpl > "$sourcehtml"

    # Prev/Next (O(1) via posts.sorted)
    prev_link=""; next_link=""
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

    # Post content — skip groff if incremental and output is up to date
    if [ "$INCREMENTAL" = "1" ] && [ -f "$htmlfile" ] && [ "$htmlfile" -nt "$post" ]; then
        echo "  skip (unchanged): $post"
    else
        process_ms "$post" temp_content

        # Save for RSS/Atom
        rss_content_file="rss_content_$(echo "$htmlfile" | sed 's|/|_|g')"
        cp temp_content "$rss_content_file"

        printf '%s\n' "$tag_links_html" > temp_tag_links

        sed \
            -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
            -e "s|{{TITLE}}|$title|g" \
            -e "s|{{SUMMARY}}|$summary|g" \
            -e "s|{{AUTHOR}}|$author|g" \
            -e "s|{{DATE}}|$display_date|g" \
            -e "s|{{PAGE_TYPE}}||g" \
            -e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
            -e "s|{{POST_URL}}|$post_url|g" \
            -e "s|{{SITE_URL}}|$SITE_URL|g" \
            -e "s|{{READ_TIME}}|$read_time_str|g" \
            -e "/{{TAG_LINKS}}/r temp_tag_links" -e "/{{TAG_LINKS}}/d" \
            -e "/{{SIDEBAR_HTML}}/r temp_sidebar_html" -e "/{{SIDEBAR_HTML}}/d" \
            -e "/CONTENT_PLACEHOLDER/r temp_content" -e "/CONTENT_PLACEHOLDER/d" \
            -e "s|{{PREV_LINK}}|$prev_link|g" \
            -e "s|{{NEXT_LINK}}|$next_link|g" \
            -e "s|{{SOURCE_LINK}}|<a href=\"$(basename "$sourcehtml")\">View Source</a>|g" \
            templates/post.html.tmpl > "$htmlfile"

        rm -f temp_tag_links
    fi

    echo "$sortable_date|$htmlfile|$title|$display_date|$author|$summary" >> posts.list.unsorted

    # Tag data for per-tag index pages
    if [ -n "$tags_raw" ]; then
        echo "$sortable_date|$htmlfile|$title|$display_date|$tags_raw" >> tag.data
    fi

    # Archive data
    echo "$sortable_date|$htmlfile|$title|$display_date|$year|$month" >> archive.data

    # Sitemap entry
    printf '  <url><loc>%s</loc><lastmod>%s</lastmod></url>\n' \
        "$post_url" "$year-$month-$day" >> sitemap.urls

    i=$((i + 1))
done

# ---------------------------------------------------------------------------
# Add static pages to sitemap
# ---------------------------------------------------------------------------
for page in $pages; do
    [ "$(basename "$page" .ms)" = "index" ] && continue
    _pg_base=$(basename "$page" .ms)
    printf '  <url><loc>%s/%s.html</loc></url>\n' "$SITE_URL" "$_pg_base" >> sitemap.urls
done
printf '  <url><loc>%s/</loc></url>\n' "$SITE_URL" >> sitemap.urls

# ---------------------------------------------------------------------------
# Sort posts and build posts.list + rss.items + atom.entries
# ---------------------------------------------------------------------------
: > posts.list
sort -r posts.list.unsorted | while IFS='|' read -r _sortable _htmlfile _title _date _author _summary; do
    printf '<li><a href="%s">%s</a> - %s</li>\n' \
        "$(echo "$_htmlfile" | sed 's|public/||')" "$_title" "$_date" >> posts.list

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

# ---------------------------------------------------------------------------
# Per-tag index pages
# ---------------------------------------------------------------------------
mkdir -p public/tags

# Collect unique tag names
all_tags=""
if [ -f tag.data ]; then
    while IFS='|' read -r _sd _hf _ti _da _tgs; do
        for _t in $_tgs; do
            _t=$(printf '%s' "$_t" | tr -d ',')
            [ -z "$_t" ] && continue
            case " $all_tags " in
                *" $_t "*) ;;
                *) all_tags="$all_tags $_t" ;;
            esac
        done
    done < tag.data
fi

for _tag in $all_tags; do
    : > "tag_posts_${_tag}.tmp"
    while IFS='|' read -r _sd _hf _ti _da _tgs; do
        for _t in $_tgs; do
            _t=$(printf '%s' "$_t" | tr -d ',')
            if [ "$_t" = "$_tag" ]; then
                echo "$_sd|$_hf|$_ti|$_da" >> "tag_posts_${_tag}.tmp"
                break
            fi
        done
    done < tag.data

    : > "tag_list_${_tag}.tmp"
    sort -r "tag_posts_${_tag}.tmp" | while IFS='|' read -r _sd _hf _ti _da; do
        printf '<li><a href="/%s">%s</a> - %s</li>\n' \
            "$(echo "$_hf" | sed 's|public/||')" "$_ti" "$_da" >> "tag_list_${_tag}.tmp"
    done

    sed \
        -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
        -e "s|{{TAG}}|$_tag|g" \
        -e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
        -e "/{{SIDEBAR_HTML}}/r temp_sidebar_html" -e "/{{SIDEBAR_HTML}}/d" \
        -e "/{{POST_LIST}}/r tag_list_${_tag}.tmp" -e "/{{POST_LIST}}/d" \
        templates/tag.html.tmpl > "public/tags/${_tag}.html"

    rm -f "tag_posts_${_tag}.tmp" "tag_list_${_tag}.tmp"
done

# ---------------------------------------------------------------------------
# Archive pages (by year and by year/month)
# ---------------------------------------------------------------------------
all_years=""
all_year_months=""
if [ -f archive.data ]; then
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
fi

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

for _ym in $all_year_months; do
    _yr=$(echo "$_ym" | cut -d_ -f1)
    _mo=$(echo "$_ym" | cut -d_ -f2)
    mkdir -p "public/$_yr/$_mo"
    case "$_mo" in
        01) _mname="January"   ;; 02) _mname="February"  ;; 03) _mname="March"     ;;
        04) _mname="April"     ;; 05) _mname="May"        ;; 06) _mname="June"      ;;
        07) _mname="July"      ;; 08) _mname="August"     ;; 09) _mname="September" ;;
        10) _mname="October"   ;; 11) _mname="November"   ;; 12) _mname="December"  ;;
        *)  _mname="Unknown"   ;;
    esac
    _label="$_mname $_yr"
    : > "archive_posts_${_ym}.tmp"
    while IFS='|' read -r _sd _hf _ti _da _y _m; do
        [ "$_y" = "$_yr" ] && [ "$_m" = "$_mo" ] && echo "$_sd|$_hf|$_ti|$_da" >> "archive_posts_${_ym}.tmp"
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

# ---------------------------------------------------------------------------
# Index page
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# RSS feed
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
# Atom feed
# ---------------------------------------------------------------------------
ATOM_DATE=$(LC_ALL=en_US.UTF-8 date "+%Y-%m-%dT%H:%M:%SZ")
sed \
    -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
    -e "s|{{SITE_URL}}|$SITE_URL|g" \
    -e "s|{{SITE_SUBTITLE}}|$SITE_SUBTITLE|g" \
    -e "s|{{BUILD_DATE}}|$ATOM_DATE|g" \
    -e "/{{ATOM_ENTRIES}}/r atom.entries" -e "/{{ATOM_ENTRIES}}/d" \
    templates/atom.xml.tmpl > public/atom.xml

# ---------------------------------------------------------------------------
# Sitemap
# ---------------------------------------------------------------------------
sed \
    -e "/{{SITEMAP_URLS}}/r sitemap.urls" -e "/{{SITEMAP_URLS}}/d" \
    templates/sitemap.xml.tmpl > public/sitemap.xml

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
rm -f temp_content temp_source temp_source_content temp_sidebar_html \
      temp_site_description posts.list posts.order posts.order.unsorted \
      posts.sorted rss.items atom.entries sitemap.urls \
      tag.data archive.data rss_content_*
