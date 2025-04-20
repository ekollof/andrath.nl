# Groff powered static blog generator.

Technology used:

- groff with `ms` and `www` for parsing.
- OpenBSD korn shell for generating the pages
- Modern CSS and HTML

Requirements:

- generated shell code *must* run on OpenBSD, avoid bashishms and GNU extensions, or newer concepts in e.g. ksh93 or mksh.
- Make sure the code parses correctly and will always run and generate correct html. There is an "old" ksh available in `/bin/ksh` to test with.
