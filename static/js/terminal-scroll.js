/**
 * terminal-scroll.js
 *
 * Makes scrolling feel like a terminal:
 *   - Mouse wheel snaps to whole line increments.
 *   - Arrow keys and Page Up/Down/Home/End go through the same snapped animator.
 *   - j/k/g/G are left to vim-navigation.js; it calls window.terminalScrollBy()
 *     so those keys also benefit from line-snapping.
 *
 * Exports: window.terminalScrollBy(lines) — scroll by N lines through the
 *          snapped animator. vim-navigation.js uses this.
 */

(function () {
    'use strict';

    function getLineHeight() {
        var lh = parseFloat(window.getComputedStyle(document.body).lineHeight);
        return isNaN(lh) || lh < 8 ? 24 : lh;
    }

    function snapToLine(target, lineH) {
        return Math.round(target / lineH) * lineH;
    }

    function clamp(v, lo, hi) {
        return v < lo ? lo : v > hi ? hi : v;
    }

    function maxScroll() {
        return document.documentElement.scrollHeight - window.innerHeight;
    }

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
            window.scrollTo(0, cur + dist * 0.3);
            animFrame = requestAnimationFrame(step);
        }
        animFrame = requestAnimationFrame(step);
    }

    // Public API for vim-navigation.js
    window.terminalScrollBy = function (lines) {
        var lineH  = getLineHeight();
        var start  = currentTarget !== null ? currentTarget : window.scrollY;
        animateTo(start + lines * lineH);
    };
    window.terminalScrollTo = function (pos) {
        animateTo(pos === 'top' ? 0 : maxScroll());
    };

    // --- Wheel handler ---
    window.addEventListener('wheel', function (e) {
        e.preventDefault();

        var lineH = getLineHeight();
        var delta = e.deltaY;
        var pxDelta;
        if (e.deltaMode === 1) {
            pxDelta = delta * lineH;
        } else if (e.deltaMode === 2) {
            pxDelta = delta * window.innerHeight;
        } else {
            pxDelta = (delta > 0 ? 1 : -1) * Math.max(lineH, Math.abs(delta));
        }

        var start = currentTarget !== null ? currentTarget : window.scrollY;
        animateTo(start + Math.sign(pxDelta) * 3 * lineH);
    }, { passive: false });

    // --- Arrow / Page keys only (j/k/g/G handled by vim-navigation.js) ---
    window.addEventListener('keydown', function (e) {
        var tag = document.activeElement && document.activeElement.tagName;
        if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return;

        var lineH  = getLineHeight();
        var pageH  = Math.floor(window.innerHeight / lineH) * lineH;
        var start  = currentTarget !== null ? currentTarget : window.scrollY;
        var target = null;

        switch (e.key) {
            case 'ArrowDown': target = start + lineH;  break;
            case 'ArrowUp':   target = start - lineH;  break;
            case 'PageDown':  target = start + pageH;  break;
            case 'PageUp':    target = start - pageH;  break;
            case ' ':         target = start + pageH;  break;
            default: return;
        }

        e.preventDefault();
        animateTo(target);
    });

}());
