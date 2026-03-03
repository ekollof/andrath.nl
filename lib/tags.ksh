# lib/tags.ksh — generate per-tag index pages
# Sourced by publish.ksh; relies on globals: BLOG_NAME, TIMESTAMP,
# temp_sidebar_html already written.
# Reads: tag.data (written by posts.ksh).
# Writes: public/tags/<tag>.html.

build_tags() {
    mkdir -p public/tags

    [ -f tag.data ] || return

    # Collect unique tag names (strip commas from split tokens)
    all_tags=""
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

    rm -f tag.data
}
