# andrath.nl

A minimalist static blog generator built with groff on OpenBSD. Posts are written in groff `.ms` format, converted to HTML by a single `publish.ksh` build script, and served as a fully static site with no server-side processing.

## Features

- **Groff-powered:** Content is written in `.ms` format and converted to HTML via groff.
- **Fully static:** No database, no CMS, no server-side processing.
- **Chronological prev/next navigation:** Posts are sorted by date; footer breadcrumbs always follow chronological order.
- **RSS feed:** Generates `public/rss.xml` (RSS 2.0 with Atom self-link) including full post content. Autodiscovery `<link>` tags are present on all pages.
- **Source view:** Each post and static page includes a "View Source" link exposing the raw `.ms` source as HTML.
- **Themed terminal aesthetic:** Green or amber terminal color scheme, configurable via `blog.conf`.
- **Vim-style keyboard navigation:** `j`/`k` to scroll, `g`/`G` to jump top/bottom.
- **Customizable sidebar:** Static pages are added automatically; external links come from `sidebar.links`.
- **Cache busting:** All asset URLs include a `?timestamp` query string.

## Prerequisites

- OpenBSD (or another UNIX-like system with a compatible `ksh` and `groff`).
- **groff** — install with `doas pkg_add groff` on OpenBSD.
- **Perl** — for `preprocess-code.pl` and `normalize-html.pl` (pre-installed on OpenBSD).
- A web server to serve `public/` (e.g. OpenBSD `httpd`, nginx, Apache).

## Directory Structure

```
.
├── blog.conf               # Site configuration
├── newpost.ksh             # Interactive new-post scaffolder
├── publish.ksh             # Build script — generates the entire site
├── macros.ms               # Shared groff macros
├── index.ms                # Homepage description blurb (groff .ms)
├── preprocess-code.pl      # Pre-processor for code blocks
├── normalize-html.pl       # Post-processor to clean groff HTML output
├── serve.py                # Local dev server
├── sidebar.links           # Pipe-delimited external sidebar links
├── pages/                  # Static pages (bio.ms, contact.ms, …)
├── posts/                  # Blog posts (.ms files)
├── static/                 # Source assets (CSS, JS, fonts, images)
│   ├── css/
│   ├── js/
│   ├── fonts/
│   └── images/
├── templates/              # HTML/XML templates
│   ├── index.html.tmpl
│   ├── post.html.tmpl
│   ├── static.html.tmpl
│   └── rss.xml.tmpl
└── public/                 # Generated output (serve this directory)
    ├── YYYY/MM/DD/         # Blog posts
    ├── rss.xml             # RSS feed
    ├── index.html
    ├── css/ js/ fonts/ images/
    └── *.html              # Static pages
```

## Configuration — `blog.conf`

```sh
BLOG_NAME="My Blog"
SITE_URL="https://example.com"         # Used for RSS item URLs
SITE_SUBTITLE="A short tagline"
THEME_FONT="Spleen"                    # Web font name
TERMINAL_THEME="green"                 # "green" or "amber"

# Color variables (used to generate public/css/vars.css)
LIGHT_BG="#0c0c0c"
LIGHT_FG="#33ff33"
LIGHT_LINK="#3377ff"
DARK_BG="#0c0c0c"
DARK_FG="#33ff33"
DARK_LINK="#3377ff"
```

`SITE_URL` must not have a trailing slash. It is used to build absolute URLs in `rss.xml`.

## Sidebar links — `sidebar.links`

One entry per line, pipe-delimited:

```
type|https://example.com|Label text|fa-icon-name
```

Example:

```
link|https://github.com/youruser|GitHub|fa-github
link|https://youtube.com/@yourchannel|YouTube|fa-youtube
```

FontAwesome 4 icon names — see [fontawesome.com/v4](https://fontawesome.com/v4/icons/).

## Writing Posts

### With the scaffolder (recommended)

```sh
./newpost.ksh "My Post Title"
```

This creates `posts/my-post-title.ms` with your name (from GECOS), the current date in English (`LC_ALL=en_US.UTF-8` is enforced so month names are always English regardless of your locale), and prompts to open it in `$EDITOR`.

### Manually

Create a `.ms` file in `posts/`:

```troff
.so macros.ms
.MS
.TL
My Post Title
.AU
Your Name
.DA
March 15, 2025 14:30:00
.PP
Post body starts here.
```

**Important:** The `.DA` date must use English month names (`January`…`December`) and the format `Month DD, YYYY HH:MM:SS`. The time component is optional but recommended for stable sort order when multiple posts share the same date.

## Building the Site

```sh
./publish.ksh
```

What the build script does:

1. Wipes `public/` and recreates asset directories.
2. Generates `public/css/vars.css` from `blog.conf`.
3. Copies `static/` assets into `public/css/`, `public/js/`, etc.
4. Processes `pages/*.ms` through groff → `public/*.html` (two passes to bootstrap the sidebar).
5. **Sorts all posts by date (ascending)** into `sorted_posts`, then for each post:
   - Runs groff → HTML, applies `normalize-html.pl`.
   - Writes `public/YYYY/MM/DD/<slug>.html`, `…_source.html`, and `….ms`.
   - Computes chronologically correct prev/next links.
   - Appends a sorted entry to `posts.list.unsorted` and saves per-post HTML for the RSS feed.
6. Sorts `posts.list.unsorted` descending → `posts.list` (newest first for the index).
7. Generates `public/index.html` from `templates/index.html.tmpl`.
8. Generates `public/rss.xml` from `templates/rss.xml.tmpl` with full post content in each `<description>` CDATA block.

## RSS Feed

The feed is generated at `public/rss.xml` on every build. It includes:

- All posts in reverse-chronological order.
- Full post HTML body inside `<description><![CDATA[…]]></description>`.
- RFC 2822 `<pubDate>` derived from the post's `.DA` date.
- An Atom `<atom:link rel="self">` pointing to `$SITE_URL/rss.xml`.

All HTML pages include an autodiscovery tag:

```html
<link rel="alternate" type="application/rss+xml" title="…" href="/rss.xml">
```

## Serving Locally

```sh
python3 serve.py
```

Opens on `http://localhost:8000` by default.

## Deploying

Copy `public/` to your web root:

```sh
doas cp -r public/* /var/www/htdocs/
doas rcctl enable httpd
doas rcctl start httpd
```

A webhook script is available in `webhook/` for automated deployment on git push — see [`webhook/README.md`](webhook/README.md).

## Templates

Templates live in `templates/` and use `{{TOKEN}}` placeholders replaced by `publish.ksh` via `sed`. Multi-line content (sidebar, post body, post list, RSS items) is injected with `sed`'s `/pattern/r file` directive.

| Template | Output | Key tokens |
|---|---|---|
| `index.html.tmpl` | `public/index.html` | `{{POST_LIST}}`, `{{SITE_DESCRIPTION_GROFF}}`, `{{SIDEBAR_HTML}}` |
| `post.html.tmpl` | `public/YYYY/MM/DD/*.html` | `{{PREV_LINK}}`, `{{NEXT_LINK}}`, `{{SOURCE_LINK}}` |
| `static.html.tmpl` | `public/*.html` | `{{SOURCE_LINK}}` |
| `rss.xml.tmpl` | `public/rss.xml` | `{{RSS_ITEMS}}`, `{{BUILD_DATE}}`, `{{SITE_URL}}` |

## Troubleshooting

- **Wrong post order in nav:** Ensure `.DA` dates use English month names and the format `Month DD, YYYY`. The `newpost.ksh` scaffolder enforces this automatically.
- **Post in `public/0000/00/00/`:** The month name in `.DA` wasn't recognised. Check spelling — only full English month names are supported.
- **Build errors:** Confirm groff and Perl are installed and `templates/`, `static/`, and `macros.ms` are present.
- **RSS items missing:** Verify `SITE_URL` is set in `blog.conf` (no trailing slash).
- **404 on assets:** Make sure `static/images/profile.jpg` and `static/favicon.ico` exist.

## License

MIT — use, modify, and distribute freely.
