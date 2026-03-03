.ig COMMENT

IMGLNK [image] [href] [desc] [align] [height] [width]

Turn image into a link.

.COMMENT
.de IMGLNK
. HTML <a href="\\$2" alt="\\$3">
. MPIMG \\$4 -G 10px \\$1 \\$5 \\$6
. HTML </a>
..

.ig COMMENT

DA [date] [time]

Define the date for a post, with optional time (HH:MM:SS)
If time is not specified, it defaults to 00:00:00

.COMMENT
.de DA
.ds _post_date \\$1
.if \\n(.$ >1 .ds _post_time \\$2
.if \\n(.$ =1 .ds _post_time 00:00:00
..

.ig COMMENT

CMD [item]

Denote something as a unix command
.COMMENT

.de CMD
.B "\\f[CW]\\$1\\f[]"
..

.ig COMMENT

SUMMARY

Write a one-paragraph post summary (excerpt). Place it after .DA.
The text on the line following .SUMMARY is treated as the excerpt.
publish.ksh extracts it for meta descriptions, post-list excerpts, and feeds.
The macro itself renders the text as a normal paragraph so it is also
visible in the rendered post.

.COMMENT
.de SUMMARY
.PP
\\$*
..

.ig COMMENT

TAG [tag1] [tag2] ...

Declare space-separated tags for this post.
Tags are purely machine-readable metadata; the macro produces no output.
publish.ksh extracts them via:
  sed -n '/^\.TAG/{n;p;}'   (one TAG line whose body is the tag list)

.COMMENT
.de TAG
..

.ig COMMENT

DRAFT

Mark this post as a draft. publish.ksh skips it unless DRAFTS=1.
Produces no visible output.

.COMMENT
.de DRAFT
..

.ig COMMENT

NOTE [text]

Render a note/info callout box.

.COMMENT
.de NOTE
. HTML <aside class="callout callout-note">
. HTML <span class="callout-label">Note</span>
. PP
\\$*
. HTML </aside>
..

.ig COMMENT

WARNING [text]

Render a warning callout box.

.COMMENT
.de WARNING
. HTML <aside class="callout callout-warning">
. HTML <span class="callout-label">Warning</span>
. PP
\\$*
. HTML </aside>
..

.ig COMMENT

TIP [text]

Render a tip callout box.

.COMMENT
.de TIP
. HTML <aside class="callout callout-tip">
. HTML <span class="callout-label">Tip</span>
. PP
\\$*
. HTML </aside>
..

.ig COMMENT

DETAILS [summary-text]

Begin a collapsible <details> section. Must be closed with .ENDDETAILS.

.COMMENT
.de DETAILS
. HTML <details>
. HTML <summary>\\$*</summary>
..

.ig COMMENT

ENDDETAILS

Close a .DETAILS block.

.COMMENT
.de ENDDETAILS
. HTML </details>
..
