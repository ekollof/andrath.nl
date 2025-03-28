.MS
.TL
The case for static sites
.AU
Alex Smith
.DA
March 28, 2025
.PP
You probably don't need a database for your website.
.SH
The problem with content management systems
.PP
Look at a random site for some company. Usually it has a few pages, a blog, and
a contact form. The blog is the only part that changes, and it's updated
infrequently. The rest of the site is static. But the site is built on a
content management system (CMS) like WordPress or Drupal. These systems are
overkill for a site that's mostly static. They require a database, which adds
complexity and overhead. They're also a security risk. If the CMS isn't kept up
to date, it can be hacked. And they're slow. Every time a page is requested,
the CMS has to generate it from the database. This takes time, especially if
the database is large. Of course you can implement caching, but isn't that just
a band-aid?
.PP
Even a blog can be done statically, as evidenced by this site. This blog is
built using templates and it generates webpages using a static site generator.
I write the pages using groff, and a publishing script converts them to HTML,
adds links, markup, styling and all other necessary elements. The result is a
aethetically pleasing, fast, and secure site.
.PP
You don't have to build your own, there are other engines out there that are
probably way faster and more capable than this hacked up piece of crap, but I
built this as a challenge for myself and to teach myself groff in the meantime.
.PP
The result, whatever static site engine you choose, is a site that's fast,
secure, and will run on a potato. Also, good luck trying to exploit a static
site, you'll have a bad time.
.PP
So why are people insisting creating basically a static site with a CMS? I
often hear that it's because the client wants to be able to update the site
with some snazzy web interface. But you can literally do that with a static
site by e.g. processing some Markdown, or even take text from a word document
and process that as page content. An editor doesn't need to concern themselves
with the layout of the site, that's the job of the designer. The editor just
writes text and the site generator does the rest.
.SH
The counter-argument, and why it's still silly.
.PP
There are uses for dynamic sites. When you have a lot of data that changes
and needs to be acted upon in real time, a database is necessary. Things like
social networks, forums, and e-commerce sites need a database. There are absolutely
some use cases for dynamic sites, but I'd venture to say that 8 out of 10 sites
are just wasting cpu and storage by being backed by a database.
.PP
Most things commonly regarded for needing a database can be done through javascript
on the browser. Client side scripting can talk to an API do "magic" things like
comments on blog posts, or even a chat system. There is actually no excuse to fetch
static content from a database. Your webserver has a perfect database for storing
static data, called a filesystem. It's superfast key-value storage. Has literal
man-centuries hours of battle testing. Maybe you should use it.
.PP
Okay, enough ranting. I'll see you guys around.


