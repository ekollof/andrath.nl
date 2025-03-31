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
