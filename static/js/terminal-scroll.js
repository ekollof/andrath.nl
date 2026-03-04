/**
 * terminal-scroll.js
 *
 * Makes scrolling feel like a terminal:
 *   - Mouse wheel and keyboard (j/k/arrows/PgUp/PgDn/Home/End) snap to
 *     whole line increments based on the document's computed line-height.
 *   - Scroll is animated smoothly but only lands on line boundaries.
 */

(function () {
    'use strict';

    // Compute the line height from the body's computed style.
    // Falls back to 24px if we can't determine it.
    function getLineHeight() {
        var lh = parseFloat(window.getComputedStyle(document.body).lineHeight);
        return isNaN(lh) || lh < 8 ? 24 : lh;
    }

    // Snap a raw scroll target to the nearest line boundary.
    function snapToLine(target, lineH) {
        return Math.round(target / lineH) * lineH;
    }

    // Clamp to valid scroll range.
    function clamp(v, lo, hi) {
        return v < lo ? lo : v > hi ? hi : v;
    }

    function maxScroll() {
        return document.documentElement.scrollHeight - window.innerHeight;
    }

    // --- Animated scroll to a snapped position ---
    var animFrame = null;
    var currentTarget = null;

    function animateTo(target) {
        var lineH = getLineHeight();
        target = clamp(snapToLine(target, lineH), 0, maxScroll());

        if (currentTarget === target) return;
        currentTarget = target;

        if (animFrame) cancelAnimationFrame(animFrame);

        function step() {
            var cur = window.scrollY;
            var dist = currentTarget - cur;
            if (Math.abs(dist) < 0.5) {
                window.scrollTo(0, currentTarget);
                animFrame = null;
                return;
            }
            // Ease: move 30% of remaining distance per frame (~16ms).
            window.scrollTo(0, cur + dist * 0.3);
            animFrame = requestAnimationFrame(step);
        }
        animFrame = requestAnimationFrame(step);
    }

    // --- Wheel handler ---
    // Each wheel tick scrolls exactly N lines (usually 3).
    window.addEventListener('wheel', function (e) {
        e.preventDefault();

        var lineH  = getLineHeight();
        var lines  = 3; // lines per notch
        var delta  = e.deltaY;

        // Normalise delta: deltaMode 0 = px, 1 = lines, 2 = pages
        var pxDelta;
        if (e.deltaMode === 1) {
            pxDelta = delta * lineH;
        } else if (e.deltaMode === 2) {
            pxDelta = delta * window.innerHeight;
        } else {
            // pixel mode — snap the raw px delta to a whole number of lines
            pxDelta = (delta > 0 ? 1 : -1) * Math.max(lineH, Math.abs(delta));
        }

        var start  = currentTarget !== null ? currentTarget : window.scrollY;
        var target = start + Math.sign(pxDelta) * lines * lineH;
        animateTo(target);
    }, { passive: false });

    // --- Keyboard handler ---
    // Supplements (not replaces) the vim-nav script: arrow keys and page keys
    // go through the snapped animator so they land on line boundaries too.
    window.addEventListener('keydown', function (e) {
        // Don't hijack if focus is in an input/textarea.
        var tag = document.activeElement && document.activeElement.tagName;
        if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return;

        var lineH   = getLineHeight();
        var pageH   = Math.floor(window.innerHeight / lineH) * lineH;
        var start   = currentTarget !== null ? currentTarget : window.scrollY;
        var target  = null;

        switch (e.key) {
            case 'ArrowDown': case 'j': target = start + lineH;   break;
            case 'ArrowUp':   case 'k': target = start - lineH;   break;
            case 'PageDown':  case ' ': target = start + pageH;   break;
            case 'PageUp':              target = start - pageH;   break;
            case 'Home':      case 'g': target = 0;               break;
            case 'End':       case 'G': target = maxScroll();     break;
            default: return;
        }

        // Only prevent default for keys we handle; let others bubble.
        e.preventDefault();
        animateTo(target);
    });

}());
