.ig COMMENT

IMGLNK [image] [href] [desc] [align] [height] [width]

Turn image into a link.

.COMMENT
.de IMGLNK
. HTML <a href="\\$2" alt="\\$3">
. MPIMG \\$4 -G 10px \\$1 \\$5 \\$6
. HTML </a>
..
