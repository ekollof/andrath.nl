#!/bin/ksh

# Clean out public/ without deleting the directory
mkdir -p public
rm -f public/* 2>/dev/null

rm -f posts.list

# Load blog config
if [ -f blog.conf ]; then
    . ./blog.conf
else
    BLOG_NAME="My Groff Blog"
    THEME_FONT="JetBrains Mono"
    LIGHT_BG="#ffffff"
    LIGHT_FG="#000000"
    LIGHT_LINK="#1a73e8"
    DARK_BG="#1e1e1e"
    DARK_FG="#d4d4d4"
    DARK_LINK="#8ab4f8"
    SITE_SUBTITLE="A minimalist blog built with groff on OpenBSD"
fi

# Generate a timestamp for cache busting
TIMESTAMP=$(date +%s)

# Collect all posts into a simple array
set -A posts posts/*.ms
total_posts=${#posts[*]}

# Collect all static pages
set -A pages pages/*.ms

# Create asset directories
mkdir -p public/css public/js public/images public/fonts

# Generate sidebar HTML: static pages first, then sidebar.links, then theme toggle
sidebar_html=""
sidebar_html="        <div class=\"sidebar-link\"><span class=\"fa fa-file-text\"></span> <a href=\"/index.html\">Home</a></div>"

# Static pages section (excluding index.ms)
for page in "${pages[@]}"; do
    if [ "$(basename "$page" .ms)" = "index" ]; then
        continue
    fi
    perl preprocess-code.pl "$page" > temp_preprocessed.ms
    title=$(sed -n '/^\.TL/{n;p;}' temp_preprocessed.ms)
    [ -z "$title" ] && title="Untitled Page"
    htmlfile="public/$(basename "$page" .ms).html"
    sourcehtml="public/$(basename "$page" .ms)_source.html"
    sourcefile="public/$(basename "$page" .ms).ms"
    groff -ms -mwww -Thtml temp_preprocessed.ms > temp.html
    perl normalize-html.pl temp.html > temp_normalized.html
    mv temp_normalized.html temp.html
    content=$(sed -n '/<body>/,/<\/body>/p' temp.html | sed '1d;$d' | sed '/<h1 align="center">/d' | sed 's|<p\(.*\)>\(.*\)</p>|<p\1 data-text="\2">\2</p>|g')
    printf '%s\n' "$content" > temp_content
    cp "$page" "$sourcefile"

    # Generate source HTML for static page
    cat "$page" | sed 's/</\</g; s/>/\>/g' > temp_source
    echo "<pre class=\"source-code\">" > temp_source_content
    cat temp_source >> temp_source_content
    echo "</pre>" >> temp_source_content
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

    if ! grep -q "CONTENT_PLACEHOLDER" templates/static.html.tmpl; then
        echo "Error: CONTENT_PLACEHOLDER placeholder not found in templates/static.html.tmpl" >&2
        exit 1
    fi
    author=""
    date=""
    sed \
        -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
        -e "s|{{TITLE}}|$title|g" \
        -e "s|{{AUTHOR}}|$author|g" \
        -e "s|{{DATE}}|$date|g" \
        -e "s|{{PAGE_TYPE}}|static-page|g" \
        -e "s|{{SIDEBAR_HTML}}|$sidebar_html|g" \
        -e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
        -e "/CONTENT_PLACEHOLDER/r temp_content" -e "/CONTENT_PLACEHOLDER/d" \
        -e "s|{{PREV_LINK}}||g" \
        -e "s|{{NEXT_LINK}}||g" \
        -e "s|{{SOURCE_LINK}}|<a href=\"/$(basename "$sourcehtml")\">View Source</a>|g" \
        templates/static.html.tmpl > "$htmlfile"
    sidebar_html="$sidebar_html        <div class=\"sidebar-link\"><span class=\"fa fa-file-text\"></span> <a href=\"/$(basename "$htmlfile")\">$title</a></div>"
done

# Sidebar.links section
if [ -f sidebar.links ]; then
    cat sidebar.links | while IFS='|' read -r type url label icon; do
        echo "        <div class=\"sidebar-link\"><span class=\"fa $icon\"></span> <a href=\"$url\">$label</a></div>" >> temp_sidebar
    done
    if [ -f temp_sidebar ]; then
        sidebar_links=$(cat temp_sidebar)
        rm -f temp_sidebar
    fi
else
    sidebar_links="        <div class=\"sidebar-link\"><span class=\"fa fa-twitter\"></span> <a href=\"https://x.com/example_user\">X: @example_user</a></div>"
    sidebar_links="$sidebar_links        <div class=\"sidebar-link\"><span class=\"fa fa-globe\"></span> <a href=\"https://example.com\">My Website</a></div>"
fi
sidebar_html="$sidebar_html$sidebar_links"

sidebar_html="<div class=\"sidebar-links-list\">$sidebar_html</div>"
printf '%s\n' "$sidebar_html" > temp_sidebar_html

# Re-generate static pages with updated sidebar_html
for page in "${pages[@]}"; do
    if [ "$(basename "$page" .ms)" = "index" ]; then
        continue
    fi
    title=$(sed -n '/^\.TL/{n;p;}' "$page")
    [ -z "$title" ] && title="Untitled Page"
    htmlfile="public/$(basename "$page" .ms).html"
    sourcehtml="public/$(basename "$page" .ms)_source.html"
    sourcefile="public/$(basename "$page" .ms).ms"
    perl preprocess-code.pl "$page" > temp_preprocessed.ms
    groff -ms -mwww -Thtml temp_preprocessed.ms > temp.html
    perl normalize-html.pl temp.html > temp_normalized.html
    mv temp_normalized.html temp.html
    content=$(sed -n '/<body>/,/<\/body>/p' temp.html | sed '1d;$d' | sed '/<h1 align="center">/d' | sed 's|<p\(.*\)>\(.*\)</p>|<p\1 data-text="\2">\2</p>|g')
    printf '%s\n' "$content" > temp_content

    # Generate source HTML for static page (re-run for consistency)
    cat "$page" | sed 's/</\</g; s/>/\>/g' > temp_source
    echo "<pre class=\"source-code\">" > temp_source_content
    cat temp_source >> temp_source_content
    echo "</pre>" >> temp_source_content
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

    author=""
    date=""
    sed \
        -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
        -e "s|{{TITLE}}|$title|g" \
        -e "s|{{AUTHOR}}|$author|g" \
        -e "s|{{DATE}}|$date|g" \
        -e "s|{{PAGE_TYPE}}|static-page|g" \
        -e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
        -e "/{{SIDEBAR_HTML}}/r temp_sidebar_html" -e "/{{SIDEBAR_HTML}}/d" \
        -e "/CONTENT_PLACEHOLDER/r temp_content" -e "/CONTENT_PLACEHOLDER/d" \
        -e "s|{{PREV_LINK}}||g" \
        -e "s|{{NEXT_LINK}}||g" \
        -e "s|{{SOURCE_LINK}}|<a href=\"/$(basename "$sourcehtml")\">View Source</a>|g" \
        templates/static.html.tmpl > "$htmlfile"
done

# Generate vars.css from config
{
    print ":root {"
    print "    --light-bg: $LIGHT_BG;"
    print "    --light-fg: $LIGHT_FG;"
    print "    --light-link: $LIGHT_LINK;"
    print "    --dark-bg: $DARK_BG;"
    print "    --dark-fg: $DARK_FG;"
    print "    --dark-link: $DARK_LINK;"
    print "}"
} > public/css/vars.css

# Copy static files to categorized directories
for file in $(find static/ -type f -print); do
    ext=$(echo "$file" | sed 's/.*\.//')
    case "$ext" in
        css) cp "$file" public/css/ ;;
        js) cp "$file" public/js/ ;;
        jpg|png|gif|svg) cp "$file" public/images/ ;;
        ttf|woff|woff2) cp "$file" public/fonts/ ;;
        *) cp "$file" public/ ;;  # Fallback for uncategorized files
    esac
done

# Process index.ms
if [ -f index.ms ]; then
    perl preprocess-code.pl index.ms > temp_preprocessed.ms
    groff -ms -mwww -Thtml temp_preprocessed.ms > temp.html
    perl normalize-html.pl temp.html > temp_normalized.html
    mv temp_normalized.html temp.html
    site_description_groff=$(sed -n '/<body>/,/<\/body>/p' temp.html | sed '1d;$d' | sed '/<h1 align="center">/d' | sed 's|<p\(.*\)>\(.*\)</p>|<p\1 data-text="\2">\2</p>|g')
    printf '%s\n' "$site_description_groff" > temp_site_description
else
    site_description_groff="<p>Welcome to my blog, where I share my thoughts on minimalist coding, UNIX philosophy, and the power of groff. Explore my posts, bio, and contact information below.</p>"
    printf '%s\n' "$site_description_groff" > temp_site_description
fi

# Clear posts.list before generating
: > posts.list

# Generate posts with date-based structure
i=0
while [ "$i" -lt "$total_posts" ]; do
    post=${posts[$i]}
    title=$(sed -n '/^\.TL/{n;p;}' "$post")
    author=$(sed -n '/^\.AU/{n;p;}' "$post")
    date_line=$(sed -n '/^\.DA/{n;p;}' "$post")
    date=$(echo "$date_line" | awk '{$NF=""; print $0}' | sed 's/ $//')
    time=$(echo "$date_line" | awk '{print $NF}')
    if ! echo "$time" | grep -qE '^[0-2][0-9]:[0-5][0-9]:[0-5][0-9]$'; then
        date="$date_line"
        time="00:00:00"
    fi
    [ -z "$title" ] && title="Untitled"
    [ -z "$author" ] && author="Anonymous"
    [ -z "$date" ] && date="No Date"

    # Parse date for directory structure and sortable date
    if [ "$date" = "No Date" ]; then
        year="0000"
        month="00"
        day="00"
        sortable_date="0000-00-00 00:00:00"
    else
        month_name=$(echo "$date" | awk '{print $1}')
        day=$(echo "$date" | awk '{print $2}' | tr -d ',')
        year=$(echo "$date" | awk '{print $3}')
        case "$month_name" in
            January) month="01" ;; February) month="02" ;; March) month="03" ;;
            April) month="04" ;; May) month="05" ;; June) month="06" ;;
            July) month="07" ;; August) month="08" ;; September) month="09" ;;
            October) month="10" ;; November) month="11" ;; December) month="12" ;;
            *) month="00" ;;
        esac
        [ "${#day}" -eq 1 ] && day="0$day"
        sortable_date="$year-$month-$day $time"
    fi

    # Create dated directory structure
    post_dir="public/$year/$month/$day"
    mkdir -p "$post_dir"
    htmlfile="$post_dir/$(basename "$post" .ms).html"
    sourcehtml="$post_dir/$(basename "$post" .ms)_source.html"
    sourcefile="$post_dir/$(basename "$post" .ms).ms"

    # Copy and generate source page
    cp "$post" "$sourcefile"
    cat "$post" | sed 's/</\</g; s/>/\>/g' > temp_source
    echo "<pre class=\"source-code\">" > temp_source_content
    cat temp_source >> temp_source_content
    echo "</pre>" >> temp_source_content
    sed \
        -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
        -e "s|{{TITLE}}|$title (Source)|g" \
        -e "s|{{AUTHOR}}|$author|g" \
        -e "s|{{DATE}}|$date|g" \
        -e "s|{{PAGE_TYPE}}||g" \
        -e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
        -e "/{{SIDEBAR_HTML}}/r temp_sidebar_html" -e "/{{SIDEBAR_HTML}}/d" \
        -e "/CONTENT_PLACEHOLDER/r temp_source_content" -e "/CONTENT_PLACEHOLDER/d" \
        -e "s|{{PREV_LINK}}||g" \
        -e "s|{{NEXT_LINK}}||g" \
        -e "s|{{SOURCE_LINK}}||g" \
        templates/post.html.tmpl > "$sourcehtml"

    # Prev/Next links with correct relative paths
    prev_link=""
    next_link=""
    if [ "$i" -gt 0 ]; then
        prev_i=$((i - 1))
        prev_post=${posts[$prev_i]}
        prev_date=$(sed -n '/^\.DA/{n;p;}' "$prev_post" | awk '{$NF=""; print $0}' | sed 's/ $//')
        [ -z "$prev_date" ] && prev_date="No Date"
        if [ "$prev_date" = "No Date" ]; then
            prev_year="0000"; prev_month="00"; prev_day="00"
        else
            prev_month_name=$(echo "$prev_date" | awk '{print $1}')
            prev_day=$(echo "$prev_date" | awk '{print $2}' | tr -d ',')
            prev_year=$(echo "$prev_date" | awk '{print $3}')
            case "$prev_month_name" in
                January) prev_month="01" ;; February) prev_month="02" ;; March) prev_month="03" ;;
                April) prev_month="04" ;; May) prev_month="05" ;; June) prev_month="06" ;;
                July) prev_month="07" ;; August) prev_month="08" ;; September) prev_month="09" ;;
                October) prev_month="10" ;; November) prev_month="11" ;; December) prev_month="12" ;;
                *) prev_month="00" ;;
            esac
            [ "${#prev_day}" -eq 1 ] && prev_day="0$prev_day"
        fi
        prev_file="$(basename "$prev_post" .ms).html"
        prev_title=$(sed -n '/^\.TL/{n;p;}' "$prev_post")
        [ -z "$prev_title" ] && prev_title="Previous Post"
        # Relative path from current post to previous post
        prev_path="$prev_year/$prev_month/$prev_day/$prev_file"
        # Adjust relative path based on current directory
        if [ "$year/$month/$day" = "$prev_year/$prev_month/$prev_day" ]; then
            prev_link="<a href=\"$prev_file\">← $prev_title</a>"
        else
            prev_link="<a href=\"../../../$prev_path\">← $prev_title</a>"
        fi
    fi
    if [ "$i" -lt "$((total_posts - 1))" ]; then
        next_i=$((i + 1))
        next_post=${posts[$next_i]}
        next_date=$(sed -n '/^\.DA/{n;p;}' "$next_post" | awk '{$NF=""; print $0}' | sed 's/ $//')
        [ -z "$next_date" ] && next_date="No Date"
        if [ "$next_date" = "No Date" ]; then
            next_year="0000"; next_month="00"; next_day="00"
        else
            next_month_name=$(echo "$next_date" | awk '{print $1}')
            next_day=$(echo "$next_date" | awk '{print $2}' | tr -d ',')
            next_year=$(echo "$next_date" | awk '{print $3}')
            case "$next_month_name" in
                January) next_month="01" ;; February) next_month="02" ;; March) next_month="03" ;;
                April) next_month="04" ;; May) next_month="05" ;; June) next_month="06" ;;
                July) next_month="07" ;; August) next_month="08" ;; September) next_month="09" ;;
                October) next_month="10" ;; November) next_month="11" ;; December) next_month="12" ;;
                *) next_month="00" ;;
            esac
            [ "${#next_day}" -eq 1 ] && next_day="0$next_day"
        fi
        next_file="$(basename "$next_post" .ms).html"
        next_title=$(sed -n '/^\.TL/{n;p;}' "$next_post")
        [ -z "$next_title" ] && next_title="Next Post"
        # Relative path from current post to next post
        next_path="$next_year/$next_month/$next_day/$next_file"
        if [ "$year/$month/$day" = "$next_year/$next_month/$next_day" ]; then
            next_link="<a href=\"$next_file\">$next_title →</a>"
        else
            next_link="<a href=\"../../../$next_path\">$next_title →</a>"
        fi
    fi

    # Generate post content
    perl preprocess-code.pl "$post" > temp_preprocessed.ms
    groff -ms -mwww -Thtml temp_preprocessed.ms > temp.html
    perl normalize-html.pl temp.html > temp_normalized.html
    mv temp_normalized.html temp.html
    content=$(sed -n '/<body>/,/<\/body>/p' temp.html | sed '1d;$d' | sed '/<h1 align="center">/d' | sed 's|<p\(.*\)>\(.*\)</p>|<p\1 data-text="\2">\2</p>|g')
    printf '%s\n' "$content" > temp_content

    # Substitute into template with relative source link
    sed \
        -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
        -e "s|{{TITLE}}|$title|g" \
        -e "s|{{AUTHOR}}|$author|g" \
        -e "s|{{DATE}}|$date|g" \
        -e "s|{{PAGE_TYPE}}||g" \
        -e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
        -e "/{{SIDEBAR_HTML}}/r temp_sidebar_html" -e "/{{SIDEBAR_HTML}}/d" \
        -e "/CONTENT_PLACEHOLDER/r temp_content" -e "/CONTENT_PLACEHOLDER/d" \
        -e "s|{{PREV_LINK}}|$prev_link|g" \
        -e "s|{{NEXT_LINK}}|$next_link|g" \
        -e "s|{{SOURCE_LINK}}|<a href=\"$(basename "$sourcehtml")\">View Source</a>|g" \
        templates/post.html.tmpl > "$htmlfile"

    echo "$sortable_date|$htmlfile|$title|$date" >> posts.list.unsorted
    i=$((i + 1))
done

# Sort posts and generate posts.list
sort -r posts.list.unsorted | while IFS='|' read -r sortable_date htmlfile title date; do
    print "<li><a href=\"$(echo "$htmlfile" | sed 's|public/||')\">$title</a> - $date</li>" >> posts.list
done
rm -f posts.list.unsorted

# Generate index page
cat posts.list > temp_post_list
sed \
    -e "s|{{BLOG_NAME}}|$BLOG_NAME|g" \
    -e "s|{{SITE_SUBTITLE}}|$SITE_SUBTITLE|g" \
    -e "s|{{PAGE_TYPE}}||g" \
    -e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
    -e "/{{SIDEBAR_HTML}}/r temp_sidebar_html" -e "/{{SIDEBAR_HTML}}/d" \
    -e "/{{SITE_DESCRIPTION_GROFF}}/r temp_site_description" -e "/{{SITE_DESCRIPTION_GROFF}}/d" \
    -e "/{{POST_LIST}}/r temp_post_list" -e "/{{POST_LIST}}/d" \
    templates/index.html.tmpl > public/index.html

rm -f temp.html temp_content temp_post_list posts.list temp_source temp_source_content temp_sidebar temp_sidebar_html temp_site_description temp_preprocessed.ms
