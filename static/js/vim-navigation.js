/**
 * vim-navigation.js
 * Vim-style keyboard navigation: h/j/k/l scroll, g/G top/bottom,
 * n/p cycle links, Enter follows highlighted link, Escape clears.
 *
 * Scroll calls go through window.terminalScrollBy / window.terminalScrollTo
 * (provided by terminal-scroll.js) so they snap to line boundaries.
 * Falls back to plain scrollBy if terminal-scroll.js isn't loaded.
 */

document.addEventListener('DOMContentLoaded', function () {
    var scrollAmount = 60; // px for h/l horizontal scroll
    var linkHighlightIndex = -1;
    var links = [];

    function scrollBy(lines) {
        if (window.terminalScrollBy) {
            window.terminalScrollBy(lines);
        } else {
            var lh = parseFloat(window.getComputedStyle(document.body).lineHeight) || 24;
            window.scrollBy({ top: lines * lh, behavior: 'smooth' });
        }
    }

    function scrollTo(pos) {
        if (window.terminalScrollTo) {
            window.terminalScrollTo(pos);
        } else {
            window.scrollTo({ top: pos === 'top' ? 0 : document.documentElement.scrollHeight, behavior: 'smooth' });
        }
    }

    function gatherLinks() {
        links = Array.from(document.querySelectorAll('a'));
        return links.length > 0;
    }

    function highlightLink(index) {
        if (linkHighlightIndex >= 0 && linkHighlightIndex < links.length) {
            links[linkHighlightIndex].classList.remove('vim-highlighted-link');
        }
        linkHighlightIndex = index;
        if (linkHighlightIndex >= 0 && linkHighlightIndex < links.length) {
            links[linkHighlightIndex].classList.add('vim-highlighted-link');
            links[linkHighlightIndex].scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        }
    }

    document.addEventListener('keydown', function (e) {
        if (e.target.tagName === 'INPUT' ||
            e.target.tagName === 'TEXTAREA' ||
            e.target.isContentEditable) {
            return;
        }

        switch (e.key) {
            case 'j': scrollBy(1);       break;
            case 'k': scrollBy(-1);      break;
            case 'g': scrollTo('top');   break;
            case 'G': scrollTo('bottom');break;

            case 'h':
                window.scrollBy({ left: -scrollAmount, behavior: 'smooth' });
                break;
            case 'l':
                window.scrollBy({ left: scrollAmount, behavior: 'smooth' });
                break;

            case 'n':
                if (links.length === 0) { if (!gatherLinks()) return; }
                highlightLink((linkHighlightIndex + 1) % links.length);
                break;
            case 'p':
                if (links.length === 0) { if (!gatherLinks()) return; }
                highlightLink((linkHighlightIndex - 1 + links.length) % links.length);
                break;

            case 'Enter':
                if (linkHighlightIndex >= 0 && linkHighlightIndex < links.length) {
                    links[linkHighlightIndex].click();
                    e.preventDefault();
                }
                break;
            case 'Escape':
                highlightLink(-1);
                break;
        }
    });

    gatherLinks();
});
