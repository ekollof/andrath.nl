# lib/posts.ksh — build post HTML, source pages, prev/next nav
# Sourced by publish.ksh; relies on globals: BLOG_NAME, SITE_URL, TIMESTAMP,
# DRAFTS, INCREMENTAL, sorted_posts, total_sorted.
# Writes: posts.list.unsorted, tag.data, archive.data, sitemap.urls (post entries),
#         rss_content_* temp files.

build_posts() {
    : > posts.list.unsorted
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

        [ "$year" = "0000" ] && echo "Warning: no valid date in $post" >&2

        num_to_month_name "$month" _mname
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

        # Reading time
        read_words=$(grep -v '^\.' "$post" | wc -w | tr -d ' ')
        read_mins=$(( (read_words + 199) / 200 ))
        [ "$read_mins" -lt 1 ] && read_mins=1
        read_time_str=" · ${read_mins} min read"

        # Tag links HTML
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
        { printf '<pre class="source-code"><code class="language-troff">\n'
          cat temp_source
          printf '</code></pre>\n'
        } > temp_source_content
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
        rm -f temp_source temp_source_content

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

        # Post HTML — skip groff pipeline if incremental and output is current
        if [ "$INCREMENTAL" = "1" ] && [ -f "$htmlfile" ] && [ "$htmlfile" -nt "$post" ]; then
            echo "  skip (unchanged): $post"
        else
            process_ms "$post" temp_content

            # Save content for RSS/Atom (feeds.ksh reads these)
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

            rm -f temp_tag_links temp_content
        fi

        echo "$sortable_date|$htmlfile|$title|$display_date|$author|$summary" >> posts.list.unsorted

        [ -n "$tags_raw" ] && echo "$sortable_date|$htmlfile|$title|$display_date|$tags_raw" >> tag.data

        echo "$sortable_date|$htmlfile|$title|$display_date|$year|$month" >> archive.data

        printf '  <url><loc>%s</loc><lastmod>%s</lastmod></url>\n' \
            "$post_url" "$year-$month-$day" >> sitemap.urls

        i=$((i + 1))
    done
}
