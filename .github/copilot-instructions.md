# Groff powered static blog generator.

Technology used:

- groff with `ms` and `www` for parsing.
- OpenBSD korn shell for generating the pages
- Modern CSS and HTML

Requirements:

- generated shell code *must* run on OpenBSD, avoid bashishms and GNU extensions, or newer concepts in e.g. ksh93 or mksh.
- Make sure the code parses correctly and will always run and generate correct html. There is an "old" ksh available in `/bin/ksh` to test with.

## Macros

Custom groff macros are defined in `macros.ms`. When a new macro is added there,
the `macro-known` token pattern in the Prism grammar at the **bottom of
`static/js/prism.js`** must also be updated to include it, so the source viewer
highlights it as a keyword. The pattern looks like:

```js
'macro-known': {
    pattern: /^\.(TL|AU|DA|PP|...)\b/m,
    alias: 'keyword'
},
```

Add the new macro name to the alternation list inside that regex.
