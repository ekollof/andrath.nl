# andrath.nl — AI Assistant Instructions

A custom static site generator written entirely in OpenBSD KornShell (`ksh`),
using `groff` (with the `ms` and `www` macro packages) as the post authoring
format, Perl for pre/post-processing, and hand-rolled HTML templates.
No Node, Ruby, Python, or third-party SSG framework is involved.

---

## Hard Requirements

- All shell code **must** run on OpenBSD `/bin/ksh` (pdksh-derived).
  - No bash arrays, no `[[ ]]`, no `$(( ))` on strings, no `local`, no process
    substitution, no `{a,b}` brace expansion, no `$'...'` quoting.
  - Use POSIX `for f in glob/*; do` loops instead of arrays.
  - Test with `/bin/ksh publish.ksh` before committing.
- HTML output must be valid and render correctly in modern browsers.
- All absolute URLs in feeds and sitemaps must use `$SITE_URL` (no trailing
  slash) from `blog.conf`.

---

## Repository Layout

```
andrath.nl/
├── blog.conf                   Site config (name, URL, colors, theme)
├── publish.ksh                 Build orchestrator — sources all lib/ modules
├── newpost.ksh                 Scaffold a new post .ms file
├── macros.ms                   Custom groff macros (sourced by all .ms files)
├── index.ms                    Homepage description blurb (groff .ms)
├── sidebar.links               Pipe-delimited external sidebar links
├── normalize-html.pl           Perl: fixes whitespace in groff <code> blocks
├── preprocess-code.pl          Perl: converts .CODE/.ENDCODE to groff .HTML
├── serve.py                    Dev server: serves public/ on localhost:8000
│                               Uses SO_REUSEADDR and directory= (no chdir)
│                               so it survives publish.ksh wiping public/.
├── lib/
│   ├── helpers.ksh             Date parsing, groff pipeline, month name utils
│   ├── assets.ksh              Copies static/, generates vars.css, sidebar HTML
│   ├── pages.ksh               Builds static pages from pages/*.ms
│   ├── posts.ksh               Builds per-post HTML, source views, prev/next
│   ├── feeds.ksh               Builds index.html, rss.xml, atom.xml, sitemap.xml
│   ├── tags.ksh                Builds public/tags/<tag>.html pages
│   └── archives.ksh            Builds year/month archive index pages
├── templates/
│   ├── post.html.tmpl          Individual posts and their _source.html views
│   ├── static.html.tmpl        Static pages (bio, contact) and their source views
│   ├── index.html.tmpl         Homepage
│   ├── archive.html.tmpl       Year and year/month archive listings
│   ├── tag.html.tmpl           Per-tag post listings
│   ├── rss.xml.tmpl            RSS 2.0 feed
│   ├── atom.xml.tmpl           Atom 1.0 feed
│   └── sitemap.xml.tmpl        XML sitemap
├── posts/                      Blog post sources (*.ms)
├── pages/                      Static page sources (*.ms) — index.ms is skipped
├── examples/
│   └── post1.ms                Annotated example demonstrating all macros
├── static/
│   ├── css/
│   │   ├── base.css            Primary stylesheet: layout, CRT effects, typography
│   │   ├── giscus-terminal.css Custom Giscus comment widget theme
│   │   ├── prism.css           PrismJS Twilight syntax highlighting theme
│   │   └── font-awesome.min.css FontAwesome 4.x
│   ├── js/
│   │   ├── crt-effects.js      Canvas CRT overlay (phosphor ghosting, scanlines,
│   │   │                       noise bands, flicker, horizontal jitter)
│   │   ├── terminal-print.js   9600 baud content streaming animation
│   │   ├── terminal-scroll.js  Line-snapped smooth scrolling; exports
│   │   │                       window.terminalScrollBy / terminalScrollTo
│   │   ├── vim-navigation.js   Vim keys: j/k/g/G scroll, h/l horizontal,
│   │   │                       n/p cycle links, Enter follow, Escape clear
│   │   └── prism.js            PrismJS bundled highlighter + custom troff grammar
│   ├── fonts/
│   │   ├── spleen-12x24.woff2  Spleen 2.2.0 bitmap monospace (primary font)
│   │   │                       Must render at exactly 18pt with anti-aliasing OFF
│   │   ├── JetBrainsMono-Regular.woff2
│   │   └── fontawesome-webfont.*
│   └── images/
│       ├── favicon.ico
│       ├── profile.jpg
│       └── puffy.png
├── public/                     Build output (web root, wiped on every full build)
└── webhook/
    ├── webhook.pl              Perl HTTP daemon: validates GitHub HMAC, runs build
    └── README.md
```

---

## Build Pipeline

`ksh publish.ksh` rebuilds the entire site:

1. Source `blog.conf`, validate dependencies, source all `lib/` modules.
2. Wipe `public/` (or preserve it if `INCREMENTAL=1`).
3. `build_assets` — copy `static/` → `public/`, write `public/css/vars.css`.
4. `build_sidebar` — write `temp_sidebar_html` for template injection.
5. `build_pages` — render `pages/*.ms` → `public/*.html` + `*_source.html`.
6. `process_ms index.ms` → `temp_site_description`.
7. Sort `posts/*.ms` by `.DA` date → `posts.sorted`.
8. `build_posts` — render each post, generate source views, prev/next nav.
9. `build_feeds` — sort post list, write `index.html`, `rss.xml`, `atom.xml`, `sitemap.xml`.
10. `build_tags` — write `public/tags/<tag>.html` from `tag.data`.
11. `build_archives` — write year/month archive pages from `archive.data`.

Optional env vars:
- `DRAFTS=1` — include posts with `.DRAFT` macro.
- `INCREMENTAL=1` — skip re-rendering posts whose `.html` is newer than `.ms`.

A webhook fires on `git push` running `git pull && ./publish.ksh` on the
server automatically — no manual deploy needed.

---

## Templates and Placeholders

Templates use `{{TOKEN}}` substituted by `sed`. Multi-line content (sidebar,
post list, post body, RSS items) is injected with `sed`'s `/{{TOKEN}}/r file`
+ `/{{TOKEN}}/d` pattern.

Key tokens:

| Token | Set by | Used in |
|---|---|---|
| `{{BLOG_NAME}}` | `blog.conf` | all templates |
| `{{SITE_URL}}` | `blog.conf` | all templates |
| `{{TITLE}}` | `.TL` macro | post/static |
| `{{AUTHOR}}` | `.AU` macro | post |
| `{{DATE}}` | `.DA` macro | post |
| `{{SUMMARY}}` | `.SUMMARY` macro | post `<meta>` |
| `{{PAGE_TYPE}}` | build scripts | `<body class="">` |
| `{{TIMESTAMP}}` | Unix timestamp | asset cache-bust URLs |
| `{{READ_TIME}}` | word count / 200 | post |
| `{{TAG_LINKS}}` | `.TAG` macro | post |
| `{{SIDEBAR_HTML}}` | `build_sidebar` | all page templates |
| `{{PREV_LINK}}` / `{{NEXT_LINK}}` | `posts.ksh` | post |
| `{{SOURCE_LINK}}` | build scripts | post/static |
| `CONTENT_PLACEHOLDER` | `process_ms` output | post/static body |
| `{{POST_LIST}}` | `feeds.ksh` | index/archive/tag |
| `{{RSS_ITEMS}}` / `{{ATOM_ENTRIES}}` | `feeds.ksh` | feeds |
| `{{SITEMAP_URLS}}` | all modules | sitemap |

`{{PAGE_TYPE}}` values:
- empty string — normal post
- `source-page` — `_source.html` views (both posts and pages)
- `static-page` — rendered static pages

---

## Macros (`macros.ms`)

Every `.ms` file starts with `.so macros.ms` then `.MS`.

| Macro | Purpose |
|---|---|
| `.TL` | Post title (next line is the text) |
| `.AU` | Author name |
| `.DA` | Date line: `Month DD, YYYY [HH:MM:SS]` — English month names only |
| `.SUMMARY` | Post excerpt for meta/RSS (next line is the text) |
| `.TAG` | Space-separated tags (next line is the list) |
| `.DRAFT` | Mark post as draft; skipped unless `DRAFTS=1` |
| `.PP` / `.LP` | Paragraph (indented / flush) |
| `.SH` | Unnumbered section heading |
| `.NH [n]` | Numbered section heading (level n, default 1) |
| `.ULS` / `.ULE` | Open/close unordered list |
| `.LI` | List item |
| `.DS` / `.DE` | Display block (monospace, no-fill) |
| `.CODE [lang]` / `.ENDCODE` | Fenced code block with Prism syntax highlighting |
| `.CMD` | Inline bold monospace (command names) |
| `.NOTE` | Info callout box (`callout-note`) |
| `.WARNING` | Warning callout box (`callout-warning`) |
| `.TIP` | Tip callout box (`callout-tip`) |
| `.DETAILS` / `.ENDDETAILS` | Collapsible `<details>` block |
| `.URL` | Hyperlink: `.URL https://example.com "Label"` |
| `.PSPIC` | Embed image |
| `.IMGLNK` | Image wrapped in a hyperlink |

### Updating the Prism grammar when adding new macros

The Prism syntax highlighter has a custom `troff` grammar appended at the
**bottom of `static/js/prism.js`**. When a new macro is added to `macros.ms`,
add its name to the `macro-known` token's alternation regex so it is
highlighted as a keyword in the source viewer:

```js
'macro-known': {
    pattern: /^\.(TL|AU|DA|PP|LP|SH|NH|ULS|ULE|LI|DS|DE|URL|PSPIC|IMGLNK|
               MS|so|TAG|SUMMARY|DRAFT|CODE|ENDCODE|CMD|NOTE|WARNING|TIP|
               DETAILS|ENDDETAILS)\b/m,
    alias: 'keyword'
},
```

---

## groff Pipeline (`lib/helpers.ksh` — `process_ms`)

```
preprocess-code.pl   →   groff -ms -mwww -Thtml -k -K utf-8   →   normalize-html.pl
    ↓                         ↓                                          ↓
.CODE/.ENDCODE           Unicode-safe                            fix code block
converted to             HTML output                             whitespace
.HTML directives
```

`-k -K utf-8` is required — without it groff mangles non-ASCII characters.

The `<body>` content is extracted with `sed`, stripping the `<body>` tags,
removing the auto-generated `<h1>` title (templates render it separately),
and adding `data-text="…"` attributes to `<p>` tags for the CRT terminal-print
animation.

---

## CSS Architecture

`public/css/vars.css` is **generated at build time** from `blog.conf` — it
defines the authoritative `:root {}` CSS custom properties. Do not hardcode
theme colors elsewhere; use `var(--fg)`, `var(--bg)`, `var(--link)`, etc.

`base.css` defines the CRT terminal aesthetic:
- `body::before` — CSS scanline grid (3px rows + 3px phosphor columns) + vignette + green bloom
- `body` — phosphor glow `text-shadow`, Spleen font at 18px, anti-aliasing disabled
- `body.source-page .main` — `max-width: none` so wide code lines don't cause page scrollbars
- `pre.source-code` — `overflow-x: auto` for horizontal scrolling within the code block

`crt-effects.js` adds a canvas overlay on top of the CSS effects:
- Phosphor ghosting (offscreen decay buffer, 18% per frame)
- Rolling scanline (0.4 px/frame)
- Noise bands (~8s average)
- Full-screen flicker (~20s average)
- Horizontal jitter on `.main` (~15s average)

---

## JavaScript Loading Order

All five scripts must load in this order (they depend on each other):

```html
<script src="/js/prism.js?{{TIMESTAMP}}"></script>
<script src="/js/vim-navigation.js?{{TIMESTAMP}}"></script>
<script src="/js/terminal-scroll.js?{{TIMESTAMP}}"></script>
<script src="/js/terminal-print.js?{{TIMESTAMP}}"></script>  <!-- posts/pages only -->
<script src="/js/crt-effects.js?{{TIMESTAMP}}"></script>
```

`vim-navigation.js` calls `window.terminalScrollBy` / `window.terminalScrollTo`
which are exported by `terminal-scroll.js`.

---

## Fonts

- **Spleen** (`spleen-12x24.woff2`) — bitmap font, must be used at exactly
  **18px** with `-webkit-font-smoothing: none` and `font-smooth: never`.
  Any anti-aliasing makes it render as blurry Courier New.
- **VT323** — loaded from Google Fonts via `@import` in `base.css`; used as
  fallback and in Giscus comments.
- **JetBrains Mono** — self-hosted; available but not primary.

---

## Comments (Giscus)

Comments are powered by [giscus](https://giscus.app/) (GitHub Discussions),
configured in `templates/post.html.tmpl`. The custom theme is loaded from
`/css/giscus-terminal.css` which overrides GitHub Primer CSS variables with
the site's CRT green palette and VT323 font.

---

## Deployment

A webhook in `webhook/webhook.pl` listens for GitHub push events, validates
the HMAC-SHA256 signature, and runs `git pull && ./publish.ksh`. No manual
deploy steps are needed after `git push`.
