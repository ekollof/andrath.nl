/**
 * terminal-print.js
 *
 * Simulates receiving post content over a 9600 baud serial connection.
 * 9600 baud, 8N1 = 960 bytes/sec = ~960 chars/sec.
 * One character every ~1.042ms.
 *
 * HTML tags and entities are emitted instantly (they're framing overhead,
 * not visible characters). Only visible text characters consume baud budget.
 *
 * Press Space, Enter, or click anywhere to skip the animation.
 */

(function () {
    'use strict';

    var BAUD        = 9600;
    var BITS        = 10;          // 8 data + 1 start + 1 stop
    var CHARS_SEC   = BAUD / BITS; // 960
    var MS_PER_CHAR = 1000 / CHARS_SEC; // ~1.042ms

    var content = document.querySelector('.post-content');
    if (!content) return;

    // Grab the fully-rendered HTML, hide it, prepare a container to stream into.
    var originalHTML = content.innerHTML;
    content.innerHTML = '';

    var done = false;
    var skipRequested = false;

    function finish() {
        if (done) return;
        done = true;
        content.innerHTML = originalHTML;
        // Re-run Prism on the now-complete content.
        if (window.Prism) Prism.highlightAllUnder(content);
        removeSkipListeners();
    }

    function skip() {
        skipRequested = true;
        finish();
    }

    // Skip listeners — space, enter, or any click on the page body.
    function onKey(e) {
        if (e.key === ' ' || e.key === 'Enter') { e.preventDefault(); skip(); }
    }
    function onClick() { skip(); }

    function removeSkipListeners() {
        document.removeEventListener('keydown', onKey);
        document.removeEventListener('click', onClick);
    }

    document.addEventListener('keydown', onKey);
    document.addEventListener('click', onClick);

    // -------------------------------------------------------------------------
    // Walk the original HTML as a stream of tokens:
    //   - HTML tags  (<...>)         — zero char cost, emit instantly
    //   - HTML entities (&...;)      — one char cost
    //   - Plain text characters      — one char cost each
    // -------------------------------------------------------------------------
    var tokens = [];

    (function tokenise(html) {
        var i = 0, len = html.length;
        while (i < len) {
            if (html[i] === '<') {
                // Collect full tag
                var end = html.indexOf('>', i);
                if (end === -1) end = len - 1;
                tokens.push({ type: 'tag', value: html.slice(i, end + 1) });
                i = end + 1;
            } else if (html[i] === '&') {
                // Collect full entity
                var semi = html.indexOf(';', i);
                if (semi !== -1 && semi - i <= 10) {
                    tokens.push({ type: 'char', value: html.slice(i, semi + 1) });
                    i = semi + 1;
                } else {
                    tokens.push({ type: 'char', value: html[i] });
                    i++;
                }
            } else {
                tokens.push({ type: 'char', value: html[i] });
                i++;
            }
        }
    }(originalHTML));

    // -------------------------------------------------------------------------
    // Stream tokens into the DOM, batching characters to match baud rate.
    // We use setTimeout scheduling: accumulate a batch covering ~16ms (one
    // animation frame worth) then schedule the next tick.
    // -------------------------------------------------------------------------
    var tokenIndex  = 0;
    var accumulated = '';   // pending HTML string not yet written to DOM
    var charDebt    = 0;    // fractional character debt carried between ticks

    var TICK_MS      = 16;                          // target ~60fps scheduling
    var CHARS_PER_TICK = CHARS_SEC * TICK_MS / 1000; // ~15.36 chars per tick

    function tick() {
        if (skipRequested || done) return;
        if (tokenIndex >= tokens.length) { finish(); return; }

        var budget = CHARS_PER_TICK + charDebt;
        var used   = 0;

        while (tokenIndex < tokens.length && (used < budget || tokens[tokenIndex].type === 'tag')) {
            var tok = tokens[tokenIndex++];
            accumulated += tok.value;
            if (tok.type === 'char') used++;
        }

        charDebt = budget - used;
        content.innerHTML = accumulated;

        // Re-highlight code blocks incrementally (only if Prism loaded).
        // Throttle: only re-highlight when we hit a closing </code> token.
        // Full highlight at finish() anyway.

        setTimeout(tick, TICK_MS);
    }

    // Small initial delay so the page layout settles before we start streaming.
    setTimeout(tick, 80);

}());
