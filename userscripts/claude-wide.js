// ==UserScript==
// @name         Claude.ai Chat Width Expander
// @namespace    http://tampermonkey.net/
// @version      1.0
// @description  Increases the maximum width of the chat column on Claude.ai
// @author       smcleod
// @match        https://claude.ai/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    // Function to apply wider chat styles
    function applyWiderChat() {
        // Create or update the custom style element
        let styleElement = document.getElementById('claude-width-expander-styles');
        if (!styleElement) {
            styleElement = document.createElement('style');
            styleElement.id = 'claude-width-expander-styles';
            document.head.appendChild(styleElement);
        }

        // CSS to override the width constraints
        styleElement.textContent = `
            /* Increase max width for main chat container */
            .flex-1.flex.flex-col.gap-3.px-4.max-w-3xl.mx-auto.w-full {
                max-width: 50vw !important;
            }

            /* Alternative selector in case the structure changes */
            .max-w-3xl {
                max-width: 50vw !important;
            }

            /* Ensure message content uses the available space */
            .font-claude-message {
                max-width: none !important;
            }

            /* Adjust code blocks and other content to use more space */
            .font-claude-message pre {
                max-width: none !important;
            }

            /* Ensure user messages also get wider */
            .font-user-message {
                max-width: none !important;
            }

            /* Make sure the input area also expands */
            .sticky.bottom-0.mx-auto.w-full {
                max-width: 50vw !important;
            }
        `;
    }

    // Apply styles immediately
    applyWiderChat();

    // Re-apply styles when the page content changes (for SPA navigation)
    const observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
            if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
                // Check if new chat content was added
                const hasRelevantContent = Array.from(mutation.addedNodes).some(node => {
                    if (node.nodeType === Node.ELEMENT_NODE) {
                        return node.classList && (
                            node.classList.contains('max-w-3xl') ||
                            node.querySelector('.max-w-3xl')
                        );
                    }
                    return false;
                });

                if (hasRelevantContent) {
                    applyWiderChat();
                }
            }
        });
    });

    // Start observing the document for changes
    observer.observe(document.body, {
        childList: true,
        subtree: true
    });

    // Also re-apply on URL changes (for SPA navigation)
    let currentUrl = location.href;
    setInterval(function() {
        if (location.href !== currentUrl) {
            currentUrl = location.href;
            setTimeout(applyWiderChat, 100); // Small delay to allow page to load
        }
    }, 1000);

    console.log('Claude.ai Chat Width Expander loaded');
})();
