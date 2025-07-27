// ==UserScript==
// @name         SubMute, quickly add a subreddit to your muted list
// @namespace    https://github.com/sammcj/scripts/blob/master/userscripts/submute.js
// @version      1.0.0
// @description  Adds a mute button to each subreddit in r/all and r/popular for quick muting
// @author       sammcj
// @match        *://www.reddit.com/*
// @match        *://reddit.com/*
// @grant        none
// @run-at       document-end
// @updateURL    https://github.com/sammcj/scripts/blob/master/userscripts/submute.js
// @downloadURL  https://github.com/sammcj/scripts/blob/master/userscripts/submute.js
// @supportURL   https://github.com/sammcj/scripts/issues
// ==/UserScript==

(function() {
    'use strict';

    // Inject CSS styles
    const injectStyles = () => {
        if (document.getElementById('submute-styles')) return;

        const styles = `
            .submute-button {
                background-color: #ff4500 !important;
                border: none !important;
                color: white !important;
                padding: 4px 8px !important;
                cursor: pointer !important;
                border-radius: 4px !important;
                font-size: 12px !important;
                margin-left: 8px !important;
                transition: background-color 0.3s !important;
                font-family: Arial, sans-serif !important;
                font-weight: bold !important;
                text-transform: none !important;
                line-height: 1 !important;
                height: 24px !important;
                min-width: 60px !important;
                display: inline-flex !important;
                align-items: center !important;
                justify-content: center !important;
                position: relative !important;
                z-index: 10000 !important;
                pointer-events: auto !important;
            }
            .submute-button:hover {
                background-color: #e03d00 !important;
            }
            .submute-button:disabled {
                background-color: #666 !important;
                cursor: not-allowed !important;
            }
        `;

        const styleSheet = document.createElement('style');
        styleSheet.id = 'submute-styles';
        styleSheet.textContent = styles;
        document.head.appendChild(styleSheet);
    };

    const createMuteControl = (subreddit) => {
        const button = document.createElement('button');
        button.innerText = 'Mute Sub';
        button.className = 'submute-button';
        button.onclick = (e) => {
            e.preventDefault();
            e.stopPropagation();
            toggleSubredditMute(subreddit);
            button.disabled = true;
            button.innerText = 'Muted';
        };
        return button;
    };

    const toggleSubredditMute = async (subreddit) => {
        try {
            // Get the CSRF token and subreddit ID
            const csrfToken = getModhash();
            const subredditId = await getSubredditId(subreddit);

            if (!csrfToken || !subredditId) {
                return;
            }

            // Use Reddit's GraphQL API for muting
            const response = await fetch('/svc/shreddit/graphql', {
                method: 'POST',
                headers: {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    "operation": "UpdateSubredditMuteSettings",
                    "variables": {
                        "input": {
                            "subredditId": `t5_${subredditId}`
                        }
                    },
                    "csrf_token": csrfToken
                })
            });

            if (response.ok) {
                const responseData = await response.json();
                if (responseData.data && responseData.data.updateSubredditMuteSettings && responseData.data.updateSubredditMuteSettings.ok) {
                    // Success - subreddit muted
                }
            }
        } catch (error) {
            // Silent fail
        }
    };

    const getModhash = () => {
        // Try to get modhash from various sources
        const metaModhash = document.querySelector('meta[name="csrf-token"]');
        if (metaModhash) return metaModhash.getAttribute('content');

        // Try from window object
        if (window.reddit && window.reddit.modhash) return window.reddit.modhash;

        // Try from cookies
        const cookies = document.cookie.split(';');
        for (let cookie of cookies) {
            const [name, value] = cookie.trim().split('=');
            if (name === 'csrf_token') return value;
        }

        return '';
    };

    const getSubredditId = async (subredditName) => {
        try {
            const response = await fetch(`/r/${subredditName}/about.json`);
            const data = await response.json();
            return data.data.id;
        } catch (error) {
            return null;
        }
    };

    const initializeMuteControls = () => {
        const joinButtons = getJoinButtons();

        joinButtons.forEach((joinButton) => {
            if (hasExistingMuteControl(joinButton)) return;

            const postData = extractPostData(joinButton);
            if (!postData) return;

            const { container, subreddit } = postData;
            const muteButton = createMuteControl(subreddit);

            // Since we're working with subreddit links, find the actual join button in the same post
            const actualJoinButton = container.querySelector('shreddit-join-button[data-testid="credit-bar-join-button"]');

            if (actualJoinButton && actualJoinButton.parentNode) {
                // Insert next to the actual join button
                muteButton.style.cssText += `
                    margin-left: 4px !important;
                    display: inline-flex !important;
                `;
                actualJoinButton.parentNode.insertBefore(muteButton, actualJoinButton.nextSibling);
            } else {
                // Fallback: insert near the subreddit link
                const creditBarSpan = joinButton.closest('span[class*="flex items-center"]');
                if (creditBarSpan && creditBarSpan.parentNode) {
                    const wrapper = document.createElement('span');
                    wrapper.style.cssText = `
                        display: inline-flex !important;
                        margin-left: 8px !important;
                        align-items: center !important;
                    `;
                    wrapper.appendChild(muteButton);
                    creditBarSpan.parentNode.insertBefore(wrapper, creditBarSpan.nextSibling);
                }
            }
        });
    };

    const getJoinButtons = () => {
        // First, try to find subreddit links directly - this is more reliable
        const subredditLinks = document.querySelectorAll('a[data-testid="subreddit-name"]');
        if (subredditLinks.length > 0) {
            return subredditLinks;
        }

        // Try multiple selectors for join buttons
        const selectors = [
            'shreddit-join-button',
            'button[aria-label="Join"]',
            'button[data-testid="join-button"]',
            '.join-button',
            '[data-click-id="join"]'
        ];

        for (const selector of selectors) {
            const elements = document.querySelectorAll(selector);
            if (elements.length > 0) {
                return elements;
            }
        }

        // Fallback: look for any button containing "Join" text
        const allButtons = document.querySelectorAll('button');
        const joinButtons = Array.from(allButtons).filter(btn =>
            btn.textContent && btn.textContent.toLowerCase().includes('join')
        );

        if (joinButtons.length > 0) {
            return joinButtons;
        }

        // Last resort: look for any subreddit-related elements
        const fallbackSelectors = [
            'a[href*="/r/"]',
            '[class*="subreddit"]',
            '[data-subreddit-name]'
        ];

        for (const selector of fallbackSelectors) {
            const elements = document.querySelectorAll(selector);
            if (elements.length > 0) {
                return Array.from(elements).slice(0, 10); // Limit to first 10 to avoid too many
            }
        }

        return [];
    };

    const hasExistingMuteControl = (element) => {
        // Check if this element or its container already has a mute button
        const container = element.closest('shreddit-post') || element.closest('article');
        if (!container) return false;

        return container.querySelector('.submute-button') !== null;
    };

    const extractPostData = (element) => {
        // Find the post container
        const container = element.closest('shreddit-post') ||
                         element.closest('article') ||
                         element.closest('[data-testid="post-container"]') ||
                         element.closest('[class*="Post"]');

        if (!container) {
            return null;
        }

        // Try to find subreddit link in multiple ways
        let subredditLink = container.querySelector('a[data-testid="subreddit-name"]');

        if (!subredditLink) {
            // Try alternative selectors
            subredditLink = container.querySelector('a[href*="/r/"]') ||
                           container.querySelector('[data-subreddit-name]') ||
                           container.querySelector('[class*="subreddit"] a');
        }

        if (!subredditLink) {
            return null;
        }

        // Extract subreddit name
        let subreddit = '';

        if (subredditLink.hasAttribute('data-testid') && subredditLink.getAttribute('data-testid') === 'subreddit-name') {
            subreddit = subredditLink.innerText.replace(/^r\//, '').trim();
        } else if (subredditLink.href) {
            const match = subredditLink.href.match(/\/r\/([^\/]+)/);
            if (match) {
                subreddit = match[1];
            }
        } else if (subredditLink.hasAttribute('data-subreddit-name')) {
            subreddit = subredditLink.getAttribute('data-subreddit-name');
        }

        if (!subreddit) {
            return null;
        }

        return { container, subreddit };
    };

    const isTargetFeed = () => {
        const isAllUrl = /^https?:\/\/(www\.)?reddit\.com\/r\/all\/?/.test(window.location.href);
        const isPopularUrl = /^https?:\/\/(www\.)?reddit\.com\/r\/popular\/?/.test(window.location.href);
        const hasAllInPath = window.location.pathname.includes('/r/all');
        const hasPopularInPath = window.location.pathname.includes('/r/popular');
        return isAllUrl || isPopularUrl || hasAllInPath || hasPopularInPath;
    };

    let debounceTimeout;
    const debounce = (func, wait) => {
        clearTimeout(debounceTimeout);
        debounceTimeout = setTimeout(func, wait);
    };

    const handleNavigationChange = () => {
        if (isTargetFeed()) {
            debounce(() => {
                initializeMuteControls();
            }, 500);
        }
    };

    const setupNavigationWatcher = () => {
        // Handle modern navigation API
        if ('navigation' in window && window.navigation) {
            window.navigation.addEventListener('navigate', handleNavigationChange);
            window.navigation.addEventListener('navigatesuccess', handleNavigationChange);
        }

        // DOM mutation observer for dynamic content
        const observer = new MutationObserver((mutations) => {
            if (mutations.some((mutation) => mutation.addedNodes.length > 0)) {
                handleNavigationChange();
            }
        });

        observer.observe(document.body, {
            childList: true,
            subtree: true,
        });

        // URL change detection
        let lastUrl = window.location.href;
        new MutationObserver(() => {
            const currentUrl = window.location.href;
            if (currentUrl !== lastUrl) {
                lastUrl = currentUrl;
                handleNavigationChange();
            }
        }).observe(document.documentElement, { subtree: true, childList: true });
    };

    // Initialize the userscript
    const init = () => {
        injectStyles();
        setupNavigationWatcher();
        handleNavigationChange();
    };

    // Start when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

    // Additional event listeners for navigation
    window.addEventListener('load', handleNavigationChange);
    window.addEventListener('popstate', handleNavigationChange);
    window.addEventListener('pushstate', handleNavigationChange);
    window.addEventListener('replacestate', handleNavigationChange);

})();
