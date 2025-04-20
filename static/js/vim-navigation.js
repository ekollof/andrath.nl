/**
 * vim-navigation.js
 * Adds vim-style keyboard navigation to web pages (h,j,k,l keys)
 */

document.addEventListener('DOMContentLoaded', function() {
    let scrollAmount = 60; // px to scroll per key press
    let linkHighlightIndex = -1;
    let links = [];
    
    // Collect all links on the page
    function gatherLinks() {
        links = Array.from(document.querySelectorAll('a'));
        return links.length > 0;
    }
    
    // Highlight a link at specified index
    function highlightLink(index) {
        // First remove any existing highlight
        if (linkHighlightIndex >= 0 && linkHighlightIndex < links.length) {
            links[linkHighlightIndex].classList.remove('vim-highlighted-link');
        }
        
        // Set new index and add highlight
        linkHighlightIndex = index;
        
        // Highlight the link if index is valid
        if (linkHighlightIndex >= 0 && linkHighlightIndex < links.length) {
            links[linkHighlightIndex].classList.add('vim-highlighted-link');
            // Scroll to link if not in viewport
            links[linkHighlightIndex].scrollIntoView({
                behavior: 'smooth',
                block: 'nearest'
            });
        }
    }
    
    // Handle keyboard events
    document.addEventListener('keydown', function(e) {
        // Skip if user is typing in an input, textarea, etc.
        if (e.target.tagName === 'INPUT' || 
            e.target.tagName === 'TEXTAREA' || 
            e.target.isContentEditable) {
            return;
        }
        
        switch (e.key) {
            // Left - move left
            case 'h':
                window.scrollBy({
                    left: -scrollAmount,
                    behavior: 'smooth'
                });
                break;
                
            // Down - move down
            case 'j':
                window.scrollBy({
                    top: scrollAmount,
                    behavior: 'smooth'
                });
                break;
                
            // Up - move up
            case 'k':
                window.scrollBy({
                    top: -scrollAmount,
                    behavior: 'smooth'
                });
                break;
                
            // Right - move right
            case 'l':
                window.scrollBy({
                    left: scrollAmount,
                    behavior: 'smooth'
                });
                break;
                
            // n - next link
            case 'n':
                if (links.length === 0) {
                    if (!gatherLinks()) return;
                }
                highlightLink((linkHighlightIndex + 1) % links.length);
                break;
                
            // p - previous link
            case 'p':
                if (links.length === 0) {
                    if (!gatherLinks()) return;
                }
                highlightLink((linkHighlightIndex - 1 + links.length) % links.length);
                break;
                
            // Enter - follow highlighted link
            case 'Enter':
                if (linkHighlightIndex >= 0 && linkHighlightIndex < links.length) {
                    links[linkHighlightIndex].click();
                    e.preventDefault();
                }
                break;
                
            // Escape - clear link highlight
            case 'Escape':
                highlightLink(-1);
                break;
        }
    });

    // Initialize: gather links on page load
    gatherLinks();
});