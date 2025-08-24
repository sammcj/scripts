// ==UserScript==
// @name         Claude.ai Mermaid White Background
// @namespace    http://tampermonkey.net/
// @version      4.0
// @description  Changes Mermaid diagram backgrounds from dark to white
// @author       smcleod
// @match        https://claude.ai/*
// @match        https://www.claudeusercontent.com/*
// @match        https://claudeusercontent.com/*
// @grant        none
// @run-at       document-start
// ==/UserScript==

(function() {
    'use strict';

    const isInIframe = window.location.hostname.includes('claudeusercontent.com');
    const isMainPage = window.location.hostname.includes('claude.ai');

    // Throttling to prevent excessive calls
    let lastExecution = 0;
    let isFixing = false;
    const throttleDelay = 250; // Minimum time between executions

    console.log('Mermaid script running on:', window.location.hostname, 'isInIframe:', isInIframe);

    // Debounced function to prevent excessive calls
    function throttledFixMermaid() {
        const now = Date.now();
        if (isFixing || (now - lastExecution) < throttleDelay) {
            return;
        }

        lastExecution = now;
        isFixing = true;

        requestAnimationFrame(() => {
            fixMermaidBackgrounds();
            isFixing = false;
        });
    }

    // More efficient Mermaid background fixing
    function fixMermaidBackgrounds() {
        // Use more specific selectors to reduce search scope
        const mermaidSelectors = [
            '#mermaid',
            '.mermaid',
            'div[id="mermaid"]',
            'div[class*="mermaid"]'
        ];

        let elementsFound = false;

        for (const selector of mermaidSelectors) {
            const elements = document.querySelectorAll(selector);

            if (elements.length > 0) {
                elementsFound = true;
                console.log('Found', elements.length, 'Mermaid elements with selector:', selector);

                elements.forEach(element => {
                    // Quick check to avoid unnecessary work
                    if (element.dataset.mermaidFixed === 'true') {
                        return;
                    }

                    const computedStyle = window.getComputedStyle(element);
                    const isDarkBackground = computedStyle.backgroundColor === 'rgb(40, 44, 52)';

                    if (isDarkBackground || element.className.includes('282')) {
                        element.style.setProperty('background-color', 'white', 'important');
                        element.dataset.mermaidFixed = 'true'; // Mark as fixed
                        console.log('Fixed Mermaid background for:', element);

                        // Fix internal elements more efficiently
                        const internalElements = element.querySelectorAll('.edgeLabel, .labelBkg');
                        internalElements.forEach(internal => {
                            const internalStyle = window.getComputedStyle(internal);
                            if (internalStyle.backgroundColor === 'rgb(40, 44, 52)') {
                                internal.style.setProperty('background-color', 'white', 'important');
                            }
                        });
                    }
                });

                // If we found elements with one selector, no need to continue
                break;
            }
        }

        return elementsFound;
    }

    // Inject optimised CSS
    function injectCSS() {
        // Check if CSS already injected
        if (document.querySelector('[data-userscript="mermaid-white-bg-v4"]')) {
            return;
        }

        const css = `
            /* Force white background for main Mermaid containers */
            #mermaid,
            .mermaid,
            div[id="mermaid"],
            div[class*="mermaid"] {
                background-color: white !important;
            }

            /* Fix Mermaid UI elements */
            #mermaid .edgeLabel,
            #mermaid .labelBkg,
            .mermaid .edgeLabel,
            .mermaid .labelBkg {
                background-color: white !important;
            }

            /* Target specific dark elements */
            #mermaid .edgeLabel p[style*="background-color: #282C34"],
            #mermaid .edgeLabel rect[style*="background-color: #282C34"],
            .mermaid .edgeLabel p[style*="background-color: #282C34"],
            .mermaid .edgeLabel rect[style*="background-color: #282C34"],
            #mermaid .icon-shape[style*="background-color: #282C34"],
            #mermaid .image-shape[style*="background-color: #282C34"],
            .mermaid .icon-shape[style*="background-color: #282C34"],
            .mermaid .image-shape[style*="background-color: #282C34"] {
                background-color: white !important;
                fill: white !important;
            }
        `;

        const style = document.createElement('style');
        style.innerHTML = css;
        style.setAttribute('data-userscript', 'mermaid-white-bg-v4');

        const target = document.head || document.documentElement;
        if (target) {
            target.appendChild(style);
            console.log('CSS injected into', target.tagName);
        }
    }

    // Much more targeted observer
    function setupObserver() {
        const observer = new MutationObserver((mutations) => {
            let shouldFix = false;

            // More efficient mutation checking
            for (const mutation of mutations) {
                if (mutation.type === 'childList') {
                    // Only check if added nodes might contain mermaid elements
                    for (const node of mutation.addedNodes) {
                        if (node.nodeType === 1) {
                            const element = node;
                            if (element.id === 'mermaid' ||
                                element.classList?.contains('mermaid') ||
                                element.querySelector?.('#mermaid, .mermaid')) {
                                shouldFix = true;
                                break;
                            }
                        }
                    }
                } else if (mutation.type === 'attributes') {
                    const target = mutation.target;
                    if (target.id === 'mermaid' ||
                        target.classList?.contains('mermaid') ||
                        (mutation.attributeName === 'style' && target.closest('#mermaid, .mermaid'))) {
                        shouldFix = true;
                    }
                }

                if (shouldFix) break;
            }

            if (shouldFix) {
                throttledFixMermaid();
            }
        });

        // More targeted observation scope
        const targetElement = document.body || document.documentElement;
        if (targetElement) {
            observer.observe(targetElement, {
                childList: true,
                subtree: true,
                attributes: true,
                attributeFilter: ['class', 'style', 'id'] // Only watch relevant attributes
            });
            console.log('Optimised observer setup on', targetElement.tagName);
        }

        return observer;
    }

    // Initialisation with smart timing
    function init() {
        console.log('Optimised Mermaid background fixer initialising on:', window.location.hostname);

        // Inject CSS immediately
        injectCSS();

        // Initial fix
        fixMermaidBackgrounds();

        // Set up efficient observer
        setupObserver();

        // Smart fallback - only if we haven't found any mermaid elements yet
        let fallbackAttempts = 0;
        const maxFallbackAttempts = 3;

        const smartFallback = () => {
            if (fallbackAttempts >= maxFallbackAttempts) {
                return; // Stop trying after max attempts
            }

            fallbackAttempts++;
            const found = fixMermaidBackgrounds();

            if (!found && fallbackAttempts < maxFallbackAttempts) {
                // Only continue if we haven't found any mermaid elements
                setTimeout(smartFallback, 1000 * fallbackAttempts);
            }
        };

        // Start smart fallback
        setTimeout(smartFallback, 500);

        console.log('Optimised Mermaid background fixer initialised');
    }

    // Context-aware initialisation
    if (isInIframe) {
        // In iframe, start immediately but with smart fallbacks
        init();
    } else if (isMainPage) {
        // On main page, wait for appropriate moment
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', init);
        } else {
            init();
        }
    }

    // Single load event listener as final fallback
    window.addEventListener('load', () => {
        setTimeout(throttledFixMermaid, 1000);
    }, { once: true }); // Only fire once

})();
