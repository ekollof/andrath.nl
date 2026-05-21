.so macros.ms
.MS
.TL
Unknown terminal type
.AU
Emiel Kollof
.DA
May 21, 2026 11:01:55
.TAG
termcap, unix, terminal, curses
.NH
The problem
.PP
If you mess around with shiney new software, like newfangled terminals of the likes of
.CMD kitty(1)
or
.CMD ghostty(1)
, you might sometimes see this:
.DS
xterm-kitty: unknown terminal type
.DE
Which means hat TUI-applications will promptly give you the middle finger
because they have no clue about what your terminal can do. Then begins the song
and dance of
.CMD terminfo(1)
and
.CMD tic(1)
to get the terminfo stuff installed into your sessions so at least things like
.CMD vi(1)
will work.
.NH
The solution
.PP
Of course, a website. :)
.PP
.URL "https://terminfo.me/" "terminfo.me"
.PP
I've created this to have a one-liner I can paste into my terminal when I ever
encounter that dreaded error message. There is already quite a list of termcaps
on the page, and I invite everyone to make this more complete.
.PP
The script to install the termcaps should be safe, it won't execute as root,
and it has quite strict checksum checks built in, so changing it in flight
is very difficult. Of course you don't have to pipe it through
.CMD sh(1)
, it will work just fine when you download it, check the SHA256 checksum yourself
and inspect the script. Whatever floats your boat.
.PP
Please enjoy and I hope this service helps you out in some way, and maybe you can
help yourself as well by contributing!
.PP
Take care,
.PP
Andrath

