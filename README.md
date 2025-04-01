# My Groff Blog

A minimalist blog built with groff on OpenBSD, designed for simplicity and lightweight performance. This blog uses groff to generate HTML content from `.ms` files, styled with a clean, retro-inspired CSS theme. It features a fixed sidebar with links and a responsive layout.

## Features

- **Lightweight:** Built with groff and minimal CSS/JS, ensuring fast load times.
- **Static Site:** No server-side processing; all pages are pre-generated HTML.
- **Responsive Design:** Adapts to mobile and desktop screens.
- **Customizable:** Easily configure the blog name, subtitle, colors, and sidebar links.
- **SEO-Friendly:** Includes meta tags for better search engine visibility.
- **Source Code View:** Each post and static page includes a "View Source" link to view the formatted `.ms` source as HTML.

## Prerequisites

To set up and run this blog, you'll need:

- OpenBSD (or another UNIX-like system with groff installed).
- **groff:** For processing `.ms` files into HTML. Install with `pkg_add groff` on OpenBSD.
- **ksh:** The Korn shell, used for the build script. Typically pre-installed on OpenBSD.
- A web server (e.g., `httpd` on OpenBSD) to serve the generated HTML files.
- A text editor to write `.ms` files (e.g., `vi`, `nano`).

## Setup Instructions

1. **Clone the Repository (if applicable):**

        git clone <repository-url>
        cd my-groff-blog

2. **Directory Structure:**

   Ensure your directory looks like this:

        .
        ├── blog.conf           # Configuration file (optional)
        ├── newpost.ksh         # Script to create new posts
        ├── publish.ksh         # Build script to generate the site
        ├── index.ms            # Index page description (groff .ms file)
        ├── pages/              # Static pages (e.g., bio.ms, contact.ms)
        │   ├── bio.ms
        │   └── contact.ms
        ├── posts/              # Blog posts (groff .ms files)
        │   ├── post1.ms
        │   └── post2.ms
        ├── sidebar.links       # Sidebar links configuration (optional)
        ├── static/             # Static assets (CSS, fonts, images)
        │   ├── css/
        │   │   └── base.css
        │   ├── fonts/
        │   │   ├── JetBrainsMono-Regular.woff2
        │   │   └── fontawesome-webfont.woff2
        │   └── images/
        │       └── profile.jpg
        ├── templates/          # HTML templates
        │   ├── index.html.tmpl
        │   ├── post.html.tmpl
        │   └── static.html.tmpl
        └── public/             # Generated output directory (created by build script)
            ├── YYYY/MM/DD/     # Blog posts (e.g., 2025/03/28/post1.html)
            ├── css/            # CSS files
            ├── fonts/          # Font files
            ├── images/         # Image files
            └── bio.html        # Static pages

3. **Install Dependencies:**

   On OpenBSD, ensure groff is installed:

        doas pkg_add groff

4. **Configure the Blog (Optional):**

   - Edit `blog.conf` to customize the blog name, colors, and subtitle:

            BLOG_NAME="My Groff Blog"
            THEME_FONT="JetBrains Mono"
            LIGHT_BG="#ffffff"
            LIGHT_FG="#000000"
            LIGHT_LINK="#1a73e8"
            DARK_BG="#1e1e1e"
            DARK_FG="#d4d4d4"
            DARK_LINK="#8ab4f8"
            SITE_SUBTITLE="A minimalist blog built with groff on OpenBSD"

   - Edit `sidebar.links` to customize the sidebar links (format: `type|url|label|icon`):

            link|https://x.com/yourusername|X: @yourusername|fa-twitter
            link|https://yourwebsite.com|My Website|fa-globe
            link|https://x.com/anotheruser|X: @anotheruser|fa-twitter

5. **Add a Profile Picture:**

   Place a `profile.jpg` file in `static/images/`. This will be displayed in the sidebar.

6. **Add a Favicon (Optional):**

   Place a `favicon.ico` file in `static/`. This will be used as the browser tab icon.

7. **Write Content:**

   - Add blog posts in the `posts/` directory as `.ms` files (e.g., `posts/post1.ms`):

            .TL
            A Minimalist Blog Post
            .AU
            Alex Smith
            .DA
            March 26, 2025
            .PP
            Welcome to my first post, written in groff on OpenBSD.

   - Edit `index.ms` for the index page description:

            .TL
            Welcome to My Groff Blog
            .PP
            This is a minimalist blog built with groff on OpenBSD. I share my thoughts on minimalist coding, UNIX philosophy, and the power of groff. Explore my posts, bio, and contact information below.

   - Add static pages (e.g., Bio, Contact) in the `pages/` directory as `.ms` files.

8. **Build the Site:**

   Run the build script to generate the HTML files:

        ./publish.ksh

   This will create the `public/` directory with all generated HTML, CSS, and assets.

9. **Serve the Site:**

   - Use OpenBSD's `httpd` to serve the `public/` directory:

            doas cp -r public/* /var/www/htdocs/
            doas rcctl enable httpd
            doas rcctl start httpd

   - Alternatively, use any web server (e.g., Nginx, Apache) or a local development server:

            cd public
            python3 -m http.server 8000

   - Open [http://localhost:8000](http://localhost:8000) (or your server's URL) in a browser to view the blog.

## Customization

- **Blog Name and Subtitle:** Edit `blog.conf` to change `BLOG_NAME` and `SITE_SUBTITLE`.
- **Colors:** Modify `blog.conf` to adjust `LIGHT_BG`, `LIGHT_FG`, `LIGHT_LINK`, `DARK_BG`, `DARK_FG`, and `DARK_LINK`.
- **Sidebar Links:** Edit `sidebar.links` to add or remove links.
- **Profile Picture:** Replace `static/images/profile.jpg` with your own image.
- **Favicon:** Add a `favicon.ico` to `static/`.

## File Structure

- `blog.conf`: Configuration file for blog settings (optional).
- `newpost.ksh`: Script to create new blog posts interactively.
- `publish.ksh`: Script to generate the static site.
- `index.ms`: Groff file for the index page description.
- `pages/`: Directory for static pages (e.g., `bio.ms`, `contact.ms`).
- `posts/`: Directory for blog posts (e.g., `post1.ms`).
- `sidebar.links`: Configuration file for sidebar links (optional).
- `static/`: Directory for static assets (CSS, fonts, images).
- `templates/`: Directory for HTML templates (`index.html.tmpl`, `post.html.tmpl`, `static.html.tmpl`).
- `public/`: Output directory for the generated site, with posts in `YYYY/MM/DD/` subdirectories.

## How It Works

1. **Content Creation:**

   - Blog posts and static pages are written in groff `.ms` format (e.g., `posts/post1.ms`, `pages/bio.ms`).
   - The index page description is written in `index.ms`.

2. **Build Process:**

   - The `publish.ksh` script:
     - Processes `.ms` files with groff to generate HTML.
     - Sorts posts by date (newest first) and places them in `public/YYYY/MM/DD/`.
     - Generates the sidebar with links from `sidebar.links` and static pages.
     - Applies HTML templates (`index.html.tmpl`, `post.html.tmpl`, `static.html.tmpl`) to create the final pages.
     - Copies static assets (CSS, fonts, images) to categorized subdirectories in `public/`.

3. **Styling:**

   - `base.css`: Main stylesheet for layout and styling.
   - `vars.css`: Defines color variables (generated from `blog.conf`).

4. **Output:**

   - The `public/` directory contains the static site, ready to be served by a web server.

## Adding a New Post

1. **Create a New Post:**

   Use the `newpost.ksh` script to generate a new `.ms` file in `posts/`:

        ./newpost.ksh "My New Post"

   This creates `posts/my-new-post.ms` with a template (title, author from GECOS, current date). Optionally, it prompts to open it in `$EDITOR` or `vi`.

2. **Run the Build Script:**

        ./publish.ksh

   The new post will appear in `public/YYYY/MM/DD/` (e.g., `public/2025/03/27/my-new-post.html`) and on the index page, sorted by date.

## Adding a New Static Page

1. **Create a New Static Page:**

   Create a new `.ms` file in the `pages/` directory (e.g., `pages/about.ms`):

        .TL
        About Me
        .PP
        I'm Alex, a minimalist coder who loves OpenBSD and groff.

2. **Run the Build Script:**

        ./publish.ksh

   The new page will be generated (e.g., `public/about.html`) with a "View Source" link to `public/about_source.html` and added to the sidebar.

## Troubleshooting

- **Missing Bullets:** The sidebar uses `<div>` and `<span>` elements instead of `<ul>` to avoid bullet rendering issues.
- **Theme Not Applying:** Ensure `amber.css` and `green.css` are in `static/css/`, and check the JavaScript console for errors.
- **Build Errors:** Ensure groff is installed and all required files (`index.ms`, `templates/`, `static/`) are present.
- **404 Errors:** Verify that all static assets (e.g., `profile.jpg`, `favicon.ico`) are in the `static/` directory.

## License

This project is licensed under the MIT License. Feel free to use, modify, and distribute it as you see fit.

## Acknowledgments

- Built with groff and OpenBSD.
- Fonts: JetBrains Mono and FontAwesome.
- Inspired by minimalist, UNIX-friendly design principles.
