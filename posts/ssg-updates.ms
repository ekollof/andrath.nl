.so macros.ms
.MS
.TL
SSG updates
.AU
Emiel Kollof
.DA
March 04, 2026 08:40:11
.TAG
website, ssg, update
.PP
I guess when I said update, I meant update. This is what has changed in the SSH that's running this site:
.SH
RSS & Atom syndication (lib/feeds.ksh)
.PP
Added public/rss.xml with full post body in <description> as CDATA. Atom feed also added as part of the larger infrastructure commit.
.SH
Tags, archives, sitemap & OG meta (lib/tags.ksh, lib/archives.ksh)
.PP
Tag pages (/tags/*.html), a chronological archive page, sitemap.xml, and Open Graph <meta> tags on posts for social sharing previews.
.SH
Reading time
.PP
Estimated reading time calculated from word count and displayed on each post.
.SH
Callout macros
.PP
New groff macros added for callout/note blocks in post source.
.SH
Refactor: publish.ksh split into library modules
.PP
publish.ksh broken out into sourced modules under lib/: helpers.ksh, posts.ksh, pages.ksh, feeds.ksh, tags.ksh, archives.ksh, assets.ksh.
.SH 
Comments: commentbox.io → giscus
.PP
.ULS
.LI
Replaced commentbox.io with giscus (GitHub Discussions-backed). Styled to match the terminal theme, with the input box moved above the comment list.
.LI
Giscus custom theme (static/css/giscus-terminal.css) - Terminal green colour palette and VT323 font, with !important overrides to beat Tailwind's font-family rules.
.ULE
.SH
Spleen font fix (static/fonts/spleen-12x24.woff2)
.PP
Replaced a corrupted woff2 with the real file from the Spleen 2.2.0 release tarball. Added font-smooth: never / -webkit-font-smoothing: none to prevent blurry rendering (Spleen is a bitmap font that must render without anti-aliasing).
.SH
Unicode fix (lib/helpers.ksh)
.PP
Added -k -K utf-8 to the groff invocation so non-ASCII characters are passed through correctly.
.SH
9600 baud terminal print effect (static/js/terminal-print.js)
.PP
Streams .post-content at 960 chars/sec on load. Space/Enter/click skips the animation. Added to post.html.tmpl and static.html.tmpl.
.SH
CRT visual effects
.PP
.ULS
.LI
.B CSS
(static/css/base.css): scanline grid overlay, vignette, green phosphor bloom, text-shadow glow on body and h1.
.LI 
.B JS
(static/js/crt-effects.js): canvas overlay with rolling scanline, noise bands, rare flicker, and horizontal jitter. Added to all 5 templates.
.ULE
