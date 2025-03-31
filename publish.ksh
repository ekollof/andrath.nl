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

# Generate sidebar HTML: static pages first, then sidebar.links, then theme toggle
sidebar_html=""
# Add "Home" link at the top
sidebar_html="        <div class=\"sidebar-link\"><span class=\"fa fa-file-text\"></span> <a href=\"index.html\">Home</a></div>"

# Static pages section (excluding index.ms)
for page in "${pages[@]}"; do
    # Skip index.ms since it's now the "Home" link
    if [ "$(basename "$page" .ms)" = "index" ]; then
        continue
    fi
    # Preprocess the page to handle code snippets
    perl preprocess-code.pl "$page" > temp_preprocessed.ms
    title=$(sed -n '/^\.TL/{n;p;}' temp_preprocessed.ms)
    [ -z "$title" ] && title="Untitled Page"
    htmlfile="public/$(basename "$page" .ms).html"
    sourcefile="public/$(basename "$page" .ms).ms"
    groff -ms -mwww -Thtml temp_preprocessed.ms > temp.html
    # Normalize HTML output using normalize-html.pl
    perl normalize-html.pl temp.html > temp_normalized.html
    mv temp_normalized.html temp.html
    content=$(sed -n '/<body>/,/<\/body>/p' temp.html | sed '1d;$d' | sed '/<h1 align="center">/d' | sed 's|<p\(.*\)>\(.*\)</p>|<p\1 data-text="\2">\2</p>|g')
    printf '%s\n' "$content" > temp_content
    # Copy the source file
    cp "$page" "$sourcefile"
    # Fail if CONTENT_PLACEHOLDER is not found in the template
    if ! grep -q "CONTENT_PLACEHOLDER" templates/static.html.tmpl; then
        echo "Error: CONTENT_PLACEHOLDER placeholder not found in templates/static.html.tmpl" >&2
        exit 1
    fi
    # Substitute, reading template from templates/
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
        -e "s|{{SOURCE_LINK}}|<a href=\"$(basename "$sourcefile")\">View Source</a>|g" \
        templates/static.html.tmpl > "$htmlfile"
    sidebar_html="$sidebar_html        <div class=\"sidebar-link\"><span class=\"fa fa-file-text\"></span> <a href=\"$(basename "$htmlfile")\">$title</a></div>"
done

# Sidebar.links section (build into sidebar_html)
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
# Theme toggle section
sidebar_html="$sidebar_html        <div class=\"sidebar-link\"><select id=\"theme-toggle\">"
sidebar_html="$sidebar_html            <option value=\"default\">Default</option>"
sidebar_html="$sidebar_html            <option value=\"amber\">Amber VT220</option>"
sidebar_html="$sidebar_html            <option value=\"green\">IBM Green</option>"
sidebar_html="$sidebar_html        </select></div>"

# Wrap the sidebar_html in a <div class="sidebar-links-list">
sidebar_html="<div class=\"sidebar-links-list\">$sidebar_html</div>"

# Write sidebar_html to a temporary file
printf '%s\n' "$sidebar_html" > temp_sidebar_html

# Re-generate static pages with updated sidebar_html
for page in "${pages[@]}"; do
    # Skip index.ms since it's now the "Home" link
    if [ "$(basename "$page" .ms)" = "index" ]; then
        continue
    fi
    title=$(sed -n '/^\.TL/{n;p;}' "$page")
    [ -z "$title" ] && title="Untitled Page"
    htmlfile="public/$(basename "$page" .ms).html"
    sourcefile="public/$(basename "$page" .ms).ms"
    perl preprocess-code.pl "$page" > temp_preprocessed.ms
    groff -ms -mwww -Thtml temp_preprocessed.ms > temp.html
    # Normalize HTML output using normalize-html.pl
    perl normalize-html.pl temp.html > temp_normalized.html
    mv temp_normalized.html temp.html
    content=$(sed -n '/<body>/,/<\/body>/p' temp.html | sed '1d;$d' | sed '/<h1 align="center">/d' | sed 's|<p\(.*\)>\(.*\)</p>|<p\1 data-text="\2">\2</p>|g')
    printf '%s\n' "$content" > temp_content
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
        -e "s|{{SOURCE_LINK}}|<a href=\"$(basename "$sourcefile")\">View Source</a>|g" \
        templates/static.html.tmpl > "$htmlfile"
done
#
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
} > public/vars.css

# Copy static files to public (but not templates)
for file in $(find static/ -type f -print | xargs); do
    if [ -f "$file" ]; then
        cp "$file" public/ || echo "Failed to copy $file" >&2
    else
        echo "Missing file: $file" >&2
    fi
done

# Process index.ms with groff to generate the site description
if [ -f index.ms ]; then
    perl preprocess-code.pl index.ms > temp_preprocessed.ms
    groff -ms -mwww -Thtml temp_preprocessed.ms > temp.html
    # Normalize HTML output using normalize-html.pl
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

# Generate posts and collect entries for sorting
i=0
while [ "$i" -lt "$total_posts" ]; do
    post=${posts[$i]}
    title=$(sed -n '/^\.TL/{n;p;}' "$post")
    author=$(sed -n '/^\.AU/{n;p;}' "$post")
    date_line=$(sed -n '/^\.DA/{n;p;}' "$post")
    date=$(echo "$date_line" | awk '{$NF=""; print $0}' | sed 's/ $//')
    time=$(echo "$date_line" | awk '{print $NF}')
    # Check if time follows the expected format (HH:MM:SS), if not it's part of the date
    if ! echo "$time" | grep -qE '^[0-2][0-9]:[0-5][0-9]:[0-5][0-9]$'; then
        date="$date_line"
        time="00:00:00"
    fi
    htmlfile="public/$(basename "$post" .ms).html"
    sourcehtml="public/$(basename "$post" .ms)_source.html"
    sourcefile="public/$(basename "$post" .ms).ms"

    [ -z "$title" ] && title="Untitled"
    [ -z "$author" ] && author="Anonymous"
    [ -z "$date" ] && date="No Date"

    # Convert date to a sortable format (YYYY-MM-DD) for sorting
    if [ "$date" = "No Date" ]; then
        sortable_date="0000-00-00 00:00:00"
    else
        # Parse the date (e.g., "March 26, 2025") into YYYY-MM-DD
        # This is a simple approximation; assumes format "Month Day, Year"
        month=$(echo "$date" | awk '{print $1}')
        day=$(echo "$date" | awk '{print $2}' | tr -d ',')
        year=$(echo "$date" | awk '{print $3}')
        case "$month" in
            January) month_num="01" ;;
            February) month_num="02" ;;
            March) month_num="03" ;;
            April) month_num="04" ;;
            May) month_num="05" ;;
            June) month_num="06" ;;
            July) month_num="07" ;;
            August) month_num="08" ;;
            September) month_num="09" ;;
            October) month_num="10" ;;
            November) month_num="11" ;;
            December) month_num="12" ;;
            *) month_num="00" ;;
        esac
        [ "${#day}" -eq 1 ] && day="0$day"
        sortable_date="$year-$month_num-$day $time"
    fi

    # Copy the source file
    cp "$post" "$sourcefile"

    # Generate source page
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

    # Prev/Next links
    prev_link=""
    next_link=""
    if [ "$i" -gt 0 ]; then
        prev_i=$((i - 1))
        prev_file=$(basename "${posts[$prev_i]}" .ms).html
        prev_title=$(sed -n '/^\.TL/{n;p;}' "${posts[$prev_i]}")
        [ -z "$prev_title" ] && prev_title="Previous Post"
        prev_link="<a href=\"$prev_file\">← $prev_title</a>"
    fi
    if [ "$i" -lt "$((total_posts - 1))" ]; then
        next_i=$((i + 1))
        next_file=$(basename "${posts[$next_i]}" .ms).html
        next_title=$(sed -n '/^\.TL/{n;p;}' "${posts[$next_i]}")
        [ -z "$next_title" ] && next_title="Next Post"
        next_link="<a href=\"$next_file\">$next_title →</a>"
    fi

    # Generate post content and write to temp file
    perl preprocess-code.pl "$post" > temp_preprocessed.ms
    groff -ms -mwww -Thtml temp_preprocessed.ms > temp.html
    # Normalize HTML output using normalize-html.pl
    perl normalize-html.pl temp.html > temp_normalized.html
    mv temp_normalized.html temp.html
    content=$(sed -n '/<body>/,/<\/body>/p' temp.html | sed '1d;$d' | sed '/<h1 align="center">/d' | sed 's|<p\(.*\)>\(.*\)</p>|<p\1 data-text="\2">\2</p>|g')
    printf '%s\n' "$content" > temp_content

    # Substitute into template using temp files, reading from templates/
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

    # Write to a temporary file with sortable date for sorting
    echo "$sortable_date|$htmlfile|$title|$date" >> posts.list.unsorted
    i=$((i + 1))
done

# Sort posts by date (newest first) and generate the final posts.list
sort -r posts.list.unsorted | while IFS='|' read -r sortable_date htmlfile title date; do
    print "<li><a href=\"$(basename "$htmlfile")\">$title</a> - $date</li>" >> posts.list
done
rm -f posts.list.unsorted

# Generate index page with temp file for post list
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
