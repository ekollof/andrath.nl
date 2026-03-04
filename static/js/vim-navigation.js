/**
 * vim-navigation.js
 * Vim-style keyboard navigation: n/p cycle links, Enter follows, Escape clears.
 * j/k/arrows/g/G/Page keys are handled by terminal-scroll.js.
 * h/l still scroll horizontally (useful on source pages).
 */

document.addEventListener('DOMContentLoaded', function () {
    var scrollAmount = 60; // px per h/l press
    var linkHighlightIndex = -1;
    var links = [];

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
            // Horizontal scroll (terminal-scroll.js doesn't touch these)
            case 'h':
                window.scrollBy({ left: -scrollAmount, behavior: 'smooth' });
                break;
            case 'l':
                window.scrollBy({ left: scrollAmount, behavior: 'smooth' });
                break;

            // Link cycling
            case 'n':
                if (links.length === 0) { if (!gatherLinks()) return; }
                highlightLink((linkHighlightIndex + 1) % links.length);
                break;
            case 'p':
                if (links.length === 0) { if (!gatherLinks()) return; }
                highlightLink((linkHighlightIndex - 1 + links.length) % links.length);
                break;

            // Follow / clear highlighted link
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
