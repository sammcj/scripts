// slack-dm-export-viewer.js
// A script to convert Slack DM JSON exports to HTML files with pagination
// First export your DM json by using https://github.com/rusq/slackdump

const fs = require('fs');
const path = require('path');

// Configuration
const config = {
    outputDir: '.', // Directory to save the HTML file
    channelId: '', // Channel ID (will be set automatically)
    imagesDir: '', // Full path to images directory (will be set automatically)
    imagesRelativePath: '', // Relative path to images (for HTML src)
    paginationDays: 7, // Number of days per page
    avatarColors: {
        'USERONEID': '#2EB67D', // Users One
        'USERTWOID': '#E01E5A'  // User Two
    },
    defaultColor: '#4285F4'
};

// User information based on the JSON sample
const users = {
    'USERONEID': { name: 'Sam', initial: 'S' },
    'USERTWOID': { name: 'Ross', initial: 'R' }
};

// Format timestamp to human-readable format
function formatTimestamp(timestamp) {
    const date = new Date(parseFloat(timestamp) * 1000);

    // For today, show just the time
    const today = new Date();
    if (date.toDateString() === today.toDateString()) {
        return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }

    // For yesterday
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    if (date.toDateString() === yesterday.toDateString()) {
        return 'Yesterday ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }

    // For this week
    const sixDaysAgo = new Date(today);
    sixDaysAgo.setDate(sixDaysAgo.getDate() - 6);
    if (date >= sixDaysAgo) {
        const options = { weekday: 'long' };
        return date.toLocaleDateString([], options) + ' ' +
               date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }

    // For older dates
    return date.toLocaleDateString([], {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    }) + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

// Format a date for display
function formatDateRange(startDate, endDate) {
    const options = { year: 'numeric', month: 'short', day: 'numeric' };
    return `${startDate.toLocaleDateString([], options)} - ${endDate.toLocaleDateString([], options)}`;
}

// Process message text for emoji, URLs, etc.
function processMessageText(text) {
    if (!text) return '';

    // Handle emoji shortcodes
    const emojiMap = {
        ':disappointed:': '😞',
        ':stuck_out_tongue:': '😛',
        ':+1:': '👍',
        ':smile:': '😄',
        ':grinning:': '😀',
        ':laughing:': '😆',
        ':sweat_smile:': '😅',
        ':joy:': '😂',
        ':slightly_smiling_face:': '🙂',
        ':upside_down_face:': '🙃',
        ':wink:': '😉',
        ':blush:': '😊',
        ':innocent:': '😇',
        ':heart_eyes:': '😍'
    };

    for (const code in emojiMap) {
        text = text.replace(new RegExp(code, 'g'), emojiMap[code]);
    }

    // Handle URLs
    text = text.replace(
        /(https?:\/\/[^\s]+)/g,
        '<a href="$1" target="_blank" rel="noopener noreferrer">$1</a>'
    );

    return text;
}

// Format file size (e.g., 1.5 MB)
function formatFileSize(bytes) {
    if (!bytes) return '0 B';
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}

// Generate HTML for a message
function generateMessageHTML(message, prevMessage, pageIndex) {
    const userId = message.user;
    const user = users[userId] || { name: 'Unknown User', initial: '?' };
    const timestamp = formatTimestamp(message.ts);
    const processedText = processMessageText(message.text);

    // Check if this is a continuation from the same user (within 5 minutes)
    const isSameUser = prevMessage && prevMessage.user === userId;
    const isCloseInTime = prevMessage &&
                          (parseFloat(message.ts) - parseFloat(prevMessage.ts) < 300); // 5 minutes
    const isContinuation = isSameUser && isCloseInTime;

    let html = '';

    // If it's a new day, add a divider
    if (prevMessage) {
        const prevDate = new Date(parseFloat(prevMessage.ts) * 1000);
        const currDate = new Date(parseFloat(message.ts) * 1000);

        if (prevDate.toDateString() !== currDate.toDateString()) {
            html += `<div class="message-divider">${currDate.toDateString()}</div>`;
        }
    }

    // Start message div
    if (isContinuation) {
        html += `<div class="slack-message same-user-no-avatar" data-ts="${message.ts}" data-page="${pageIndex}">`;
    } else {
        html += `<div class="slack-message" data-ts="${message.ts}" data-page="${pageIndex}">`;
        html += `<div class="slack-avatar user-${userId}">${user.initial}</div>`;
    }

    // Message content
    html += `<div class="slack-message-content">`;

    // Only add the header if it's not a continuation
    if (!isContinuation) {
        html += `<div class="slack-message-header">`;
        html += `<span class="slack-username">${user.name}</span>`;
        html += `<span class="slack-timestamp">${timestamp}</span>`;
        html += `</div>`;
    }

    // Message text
    html += `<div class="slack-text">${processedText}</div>`;

    // Handle files/images if any
    if (message.files && message.files.length > 0) {
        message.files.forEach(file => {
            if (file.mimetype && file.mimetype.startsWith('image/')) {
                // It's an image
                // Construct image path without duplicating the channel ID
                const imageFileName = `${file.id}-${file.name}`;
                const imagePath = `${config.imagesRelativePath}${imageFileName}`;

                html += `<div class="slack-image-container">`;
                html += `<img class="slack-image" src="${imagePath}"
                        alt="${file.name}" title="${file.name}" />`;
                html += `<div class="slack-image-info">${file.name}</div>`;
                html += `</div>`;
            } else {
                // It's a file
                html += `<div class="slack-file">`;
                html += `<div class="slack-file-title">${file.name || 'File'}</div>`;
                html += `<div>${file.pretty_type || 'File'} · ${formatFileSize(file.size)}</div>`;
                html += `</div>`;
            }
        });
    }

    html += `</div></div>`;

    return html;
}

// Generate the complete HTML document
function generateHTML(data) {
    const dmName = users[data.messages[0]?.user]?.name || 'Users One';
    const dmName2 = users[data.messages[1]?.user]?.name || 'Users Two';

    // Sort messages by timestamp
    const messages = data.messages
        .filter(msg => msg.type === 'message')
        .sort((a, b) => parseFloat(a.ts) - parseFloat(b.ts));

    // Group messages by page (7-day periods)
    const pages = [];
    const pageRanges = [];  // Store page date ranges for display

    if (messages.length > 0) {
        let firstMessageTime = parseFloat(messages[0].ts) * 1000;
        let startDate = new Date(firstMessageTime);
        let endDate = new Date(startDate);
        endDate.setDate(endDate.getDate() + config.paginationDays - 1);

        let currentPage = [];

        messages.forEach(message => {
            const messageTime = parseFloat(message.ts) * 1000;
            const messageDate = new Date(messageTime);

            // If this message is beyond the current page's end date, start a new page
            if (messageDate > endDate) {
                // Save the current page and its date range
                pages.push(currentPage);
                pageRanges.push({
                    startDate: new Date(startDate),
                    endDate: new Date(endDate)
                });

                // Calculate new start and end dates for the next page
                startDate = new Date(endDate);
                startDate.setDate(startDate.getDate() + 1);
                endDate = new Date(startDate);
                endDate.setDate(endDate.getDate() + config.paginationDays - 1);

                currentPage = [];
            }

            currentPage.push(message);
        });

        // Add the last page
        if (currentPage.length > 0) {
            pages.push(currentPage);
            pageRanges.push({
                startDate: new Date(startDate),
                endDate: new Date(endDate)
            });
        }
    }

    // Generate CSS for user avatar colors
    let avatarColorCSS = '';
    for (const userId in users) {
        const color = config.avatarColors[userId] || config.defaultColor;
        avatarColorCSS += `.user-${userId} { background-color: ${color}; }\n`;
    }

    // Generate message HTML for each page
    const pagesHTML = [];

    pages.forEach((pageMessages, pageIndex) => {
        let html = '';
        let prevMessage = null;

        pageMessages.forEach(message => {
            html += generateMessageHTML(message, prevMessage, pageIndex);
            prevMessage = message;
        });

        pagesHTML.push(html);
    });

    // Generate page navigation HTML
    let paginationHTML = '';
    if (pages.length > 1) {
        paginationHTML = `
        <div class="pagination">
            <button id="prev-page" disabled>&laquo; Previous</button>
            <div class="page-indicator">
                <span id="current-page-indicator">Page 1 of ${pages.length}</span>
                <select id="page-selector">
        `;

        // Add options for each page
        for (let i = 0; i < pages.length; i++) {
            const dateRange = formatDateRange(
                pageRanges[i].startDate,
                pageRanges[i].endDate
            );
            paginationHTML += `<option value="${i}">${dateRange}</option>`;
        }

        paginationHTML += `
                </select>
            </div>
            <button id="next-page">Next &raquo;</button>
        </div>
        `;
    }

    // Generate the full HTML document
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Slack DM with ${dmName} & ${dmName2}</title>
    <style>
        :root {
            --slack-purple: #4A154B;
            --slack-sidebar: #3F0E40;
            --slack-text: #1D1C1D;
            --slack-border: #DDDDDD;
            --slack-hover: #F8F8F8;
            --slack-timestamp: #616061;
            --slack-link: #1264A3;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #FFFFFF;
            color: var(--slack-text);
            line-height: 1.5;
        }

        .slack-app {
            display: flex;
            flex-direction: column;
            height: 100vh;
        }

        .slack-header {
            background-color: var(--slack-purple);
            color: white;
            padding: 8px 16px;
            display: flex;
            align-items: center;
            height: 38px;
        }

        .slack-header-back {
            margin-right: 12px;
            color: rgba(255, 255, 255, 0.7);
            font-size: 18px;
        }

        .slack-header-title {
            font-weight: bold;
            font-size: 18px;
            margin-left: 8px;
        }

        .slack-header-icons {
            margin-left: auto;
            display: flex;
            align-items: center;
        }

        .slack-header-icon {
            margin-left: 16px;
            color: rgba(255, 255, 255, 0.7);
            font-size: 20px;
        }

        .slack-conversation {
            flex: 1;
            overflow-y: auto;
            padding: 16px;
        }

        .slack-message {
            display: flex;
            margin-bottom: 16px;
            padding: 2px 0;
        }

        .slack-avatar {
            width: 36px;
            height: 36px;
            border-radius: 4px;
            margin-right: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: bold;
            color: white;
        }

        .slack-message-content {
            flex: 1;
        }

        .slack-message-header {
            margin-bottom: 4px;
            display: flex;
            align-items: baseline;
        }

        .slack-username {
            font-weight: bold;
            margin-right: 8px;
        }

        .slack-timestamp {
            color: var(--slack-timestamp);
            font-size: 12px;
        }

        .slack-text {
            white-space: pre-wrap;
            word-wrap: break-word;
        }

        .slack-image-container {
            margin-top: 8px;
        }

        .slack-image {
            max-width: 400px;
            max-height: 300px;
            border-radius: 4px;
            border: 1px solid var(--slack-border);
            cursor: pointer;
        }

        .slack-image-info {
            font-size: 12px;
            color: var(--slack-timestamp);
            margin-top: 4px;
        }

        .slack-file {
            margin-top: 8px;
            padding: 12px;
            border: 1px solid var(--slack-border);
            border-radius: 4px;
            background-color: #F8F8F8;
            cursor: pointer;
        }

        .slack-file-title {
            font-weight: bold;
            color: var(--slack-link);
        }

        .slack-search {
            padding: 16px;
            border-top: 1px solid var(--slack-border);
            display: flex;
            align-items: flex-start;
        }

        .search-container {
            width: 100%;
            display: flex;
            flex-wrap: wrap;
            align-items: center;
        }

        #search-input {
            flex: 1;
            min-width: 200px;
            height: 36px;
            border: 1px solid var(--slack-border);
            border-radius: 4px;
            padding: 0 12px;
            margin-right: 8px;
            font-size: 14px;
        }

        #search-button {
            height: 38px;
            padding: 0 16px;
            background-color: var(--slack-purple);
            color: white;
            border: none;
            border-radius: 4px;
            font-weight: bold;
            cursor: pointer;
        }

        .search-navigation {
            display: flex;
            align-items: center;
            margin-top: 8px;
            width: 100%;
        }

        #prev-result, #next-result {
            width: 36px;
            height: 36px;
            border: 1px solid var(--slack-border);
            background-color: white;
            border-radius: 4px;
            cursor: pointer;
            font-size: 18px;
            display: flex;
            align-items: center;
            justify-content: center;
            margin-right: 8px;
        }

        #search-status {
            margin: 0 12px;
            color: var(--slack-timestamp);
            min-width: 80px;
        }

        #clear-search {
            margin-left: auto;
            height: 36px;
            padding: 0 12px;
            background-color: #F8F8F8;
            border: 1px solid var(--slack-border);
            border-radius: 4px;
            cursor: pointer;
        }

        mark {
            background-color: #FFFF00;
            padding: 2px 0;
        }

        mark.current {
            background-color: #FFA500;
        }

        button:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }

        .slack-reaction {
            display: inline-block;
            margin-right: 8px;
            margin-top: 6px;
            background-color: #F8F8F8;
            border: 1px solid var(--slack-border);
            border-radius: 16px;
            padding: 2px 6px;
            font-size: 12px;
        }

        .slack-reaction-emoji {
            margin-right: 4px;
        }

        .slack-reaction-count {
            font-weight: bold;
        }

        .same-user-no-avatar {
            margin-left: 48px;
            margin-top: -12px;
        }

        .message-divider {
            display: flex;
            align-items: center;
            margin: 24px 0;
            color: var(--slack-timestamp);
        }

        .message-divider::before,
        .message-divider::after {
            content: "";
            flex: 1;
            border-bottom: 1px solid var(--slack-border);
        }

        .message-divider::before {
            margin-right: 16px;
        }

        .message-divider::after {
            margin-left: 16px;
        }

        .emoji {
            font-family: "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol";
        }

        /* Pagination styles */
        .pagination {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 10px 16px;
            border-bottom: 1px solid var(--slack-border);
            background-color: #F8F8F8;
        }

        .pagination button {
            padding: 8px 16px;
            background-color: white;
            border: 1px solid var(--slack-border);
            border-radius: 4px;
            cursor: pointer;
        }

        .pagination button:hover:not(:disabled) {
            background-color: #F0F0F0;
        }

        .page-indicator {
            display: flex;
            flex-direction: column;
            align-items: center;
        }

        #current-page-indicator {
            margin-bottom: 4px;
            font-weight: bold;
        }

        #page-selector {
            padding: 4px;
            border: 1px solid var(--slack-border);
            border-radius: 4px;
            background-color: white;
        }

        /* Page display */
        .page {
            display: none;
        }

        .page.active {
            display: block;
        }

        /* User-specific avatar colors */
        ${avatarColorCSS}
    </style>
</head>
<body>
    <div class="slack-app">
        <div class="slack-header">
            <div class="slack-header-back">←</div>
            <div class="slack-header-title">
                <span>${dmName}</span>
            </div>
            <div class="slack-header-icons">
                <div class="slack-header-icon">🔍</div>
                <div class="slack-header-icon">⋮</div>
            </div>
        </div>

        ${paginationHTML}

        <div class="slack-conversation" id="conversation-container">
            ${pagesHTML.map((pageHTML, i) =>
                `<div class="page${i === 0 ? ' active' : ''}" data-page="${i}">${pageHTML}</div>`
            ).join('')}
        </div>

        <div class="slack-search">
            <div class="search-container">
                <input type="text" id="search-input" placeholder="Search in conversation..." />
                <button id="search-button">Search</button>
                <div class="search-navigation">
                    <button id="prev-result" disabled>↑</button>
                    <span id="search-status">No results</span>
                    <button id="next-result" disabled>↓</button>
                    <button id="clear-search">Clear</button>
                </div>
            </div>
        </div>
    </div>

    <script>
        // Wait for the DOM to be fully loaded
        document.addEventListener('DOMContentLoaded', function() {
            // Image click functionality
            const images = document.querySelectorAll('.slack-image');
            images.forEach(function(img) {
                img.addEventListener('click', function() {
                    if (this.style.maxWidth === 'none') {
                        this.style.maxWidth = '400px';
                        this.style.maxHeight = '300px';
                    } else {
                        this.style.maxWidth = 'none';
                        this.style.maxHeight = 'none';
                    }
                });
            });

            // Pagination functionality
            const pages = document.querySelectorAll('.page');
            const totalPages = pages.length;

            // Page state
            let currentPage = 0;

            if (totalPages > 1) {
                const prevPageBtn = document.getElementById('prev-page');
                const nextPageBtn = document.getElementById('next-page');
                const pageSelector = document.getElementById('page-selector');
                const currentPageIndicator = document.getElementById('current-page-indicator');

                // Function to show a specific page
                function showPage(pageIndex) {
                    // Hide all pages
                    pages.forEach(page => page.classList.remove('active'));

                    // Show the selected page
                    pages[pageIndex].classList.add('active');

                    // Update current page
                    currentPage = pageIndex;

                    // Update page indicator
                    currentPageIndicator.textContent = \`Page \${currentPage + 1} of \${totalPages}\`;

                    // Update page selector
                    pageSelector.value = currentPage;

                    // Update button states
                    prevPageBtn.disabled = currentPage === 0;
                    nextPageBtn.disabled = currentPage === totalPages - 1;
                }

                // Event listeners for pagination
                prevPageBtn.addEventListener('click', function() {
                    if (currentPage > 0) {
                        showPage(currentPage - 1);
                    }
                });

                nextPageBtn.addEventListener('click', function() {
                    if (currentPage < totalPages - 1) {
                        showPage(currentPage + 1);
                    }
                });

                pageSelector.addEventListener('change', function() {
                    showPage(parseInt(this.value));
                });

                // Make showPage function globally available
                window.showPage = showPage;
            }

            // Search functionality - works across all pages
            const searchInput = document.getElementById('search-input');
            const searchButton = document.getElementById('search-button');
            const prevButton = document.getElementById('prev-result');
            const nextButton = document.getElementById('next-result');
            const clearButton = document.getElementById('clear-search');
            const searchStatus = document.getElementById('search-status');

            let marks = [];
            let currentMarkIndex = -1;

            // Perform search
            searchButton.addEventListener('click', performSearch);
            searchInput.addEventListener('keypress', function(e) {
                if (e.key === 'Enter') {
                    performSearch();
                }
            });

            // Navigation
            prevButton.addEventListener('click', function() {
                if (marks.length > 0) {
                    if (currentMarkIndex > 0) {
                        currentMarkIndex--;
                    } else {
                        currentMarkIndex = marks.length - 1;
                    }
                    highlightCurrentMark();
                }
            });

            nextButton.addEventListener('click', function() {
                if (marks.length > 0) {
                    if (currentMarkIndex < marks.length - 1) {
                        currentMarkIndex++;
                    } else {
                        currentMarkIndex = 0;
                    }
                    highlightCurrentMark();
                }
            });

            // Clear search
            clearButton.addEventListener('click', clearSearch);

            function performSearch() {
                // Clear previous search
                clearSearch(false);

                const searchTerm = searchInput.value.trim();
                if (!searchTerm) return;

                // Search across ALL pages, not just the visible one
                const allMessages = document.querySelectorAll('.slack-text');
                allMessages.forEach(function(message) {
                    // Process each message's content
                    const text = message.textContent;
                    let html = '';
                    let lastIndex = 0;

                    // Find all occurrences of the search term (case-insensitive)
                    let index = text.toLowerCase().indexOf(searchTerm.toLowerCase());
                    while (index !== -1) {
                        // Add text up to the match
                        html += text.substring(lastIndex, index);

                        // Add the match wrapped in a mark tag
                        html += '<mark>' + text.substring(index, index + searchTerm.length) + '</mark>';

                        // Move past this match
                        lastIndex = index + searchTerm.length;

                        // Find the next match
                        index = text.toLowerCase().indexOf(searchTerm.toLowerCase(), lastIndex);
                    }

                    // Add any remaining text
                    if (lastIndex < text.length) {
                        html += text.substring(lastIndex);
                    }

                    // Only update if there were actually matches
                    if (html !== text) {
                        message.innerHTML = html;
                    }
                });

                // Collect all the <mark> elements
                marks = document.querySelectorAll('mark');

                // Update UI based on search results
                if (marks.length > 0) {
                    currentMarkIndex = 0;
                    prevButton.disabled = marks.length <= 1;
                    nextButton.disabled = marks.length <= 1;
                    searchStatus.textContent = '1 of ' + marks.length;
                    highlightCurrentMark();
                } else {
                    searchStatus.textContent = 'No results';
                    prevButton.disabled = true;
                    nextButton.disabled = true;
                }
            }

            function highlightCurrentMark() {
                // Remove current class from all marks
                marks.forEach(function(mark) {
                    mark.classList.remove('current');
                });

                // Add current class to current mark
                if (currentMarkIndex >= 0 && currentMarkIndex < marks.length) {
                    const currentMark = marks[currentMarkIndex];
                    currentMark.classList.add('current');

                    // Figure out which page this mark is on
                    let messageContainer = currentMark.closest('.slack-message');
                    if (messageContainer) {
                        const pageIndex = parseInt(messageContainer.dataset.page);

                        // If we have pagination and need to switch pages
                        if (totalPages > 1) {
                            const currentVisiblePage = parseInt(document.querySelector('.page.active').dataset.page);

                            // Switch to the page containing this result if needed
                            if (currentVisiblePage !== pageIndex && window.showPage) {
                                // Use the pagination function to switch pages
                                window.showPage(pageIndex);
                            }
                        }
                    }

                    // Scroll to the mark
                    currentMark.scrollIntoView({
                        behavior: 'smooth',
                        block: 'center'
                    });

                    // Update status
                    searchStatus.textContent = (currentMarkIndex + 1) + ' of ' + marks.length;
                }
            }

            function clearSearch(resetInput = true) {
                // Remove all mark elements
                document.querySelectorAll('mark').forEach(function(mark) {
                    // Replace with just the text content
                    const text = mark.textContent;
                    const textNode = document.createTextNode(text);
                    mark.parentNode.replaceChild(textNode, mark);
                });

                // Clean up any empty text nodes and normalize the DOM
                document.querySelectorAll('.slack-text').forEach(function(elem) {
                    elem.normalize();
                });

                // Reset search state
                marks = [];
                currentMarkIndex = -1;

                // Reset UI
                prevButton.disabled = true;
                nextButton.disabled = true;
                searchStatus.textContent = 'No results';

                if (resetInput) {
                    searchInput.value = '';
                }
            }
        });
    </script>
</body>
</html>`;
}

// Main function to process the JSON and create the HTML file
function processSlackJSON(jsonFilePath) {
    try {
        // Create output directory if it doesn't exist
        if (!fs.existsSync(config.outputDir)) {
            fs.mkdirSync(config.outputDir, { recursive: true });
        }

        // Read and parse the JSON file
        const data = JSON.parse(fs.readFileSync(jsonFilePath, 'utf8'));

        // Set the channel ID
        config.channelId = data.channel_id || '';

        // Set paths for images
        const jsonDir = path.dirname(jsonFilePath);
        config.imagesDir = path.join(jsonDir, config.channelId);

        // The relative path for HTML should just be the channel ID folder
        config.imagesRelativePath = `${config.channelId}/`;

        // Check if images directory exists
        if (!fs.existsSync(config.imagesDir)) {
            console.warn(`Warning: Images directory not found at ${config.imagesDir}`);
            console.warn('Images will not be displayed correctly.');
        } else {
            console.log(`Images directory found at: ${config.imagesDir}`);
        }

        // Generate the HTML
        const html = generateHTML(data);

        // Write the HTML to a file
        const fileName = `slack-dm-${config.channelId || 'conversation'}.html`;
        const outputPath = path.join(config.outputDir, fileName);
        fs.writeFileSync(outputPath, html);

        console.log(`Success! HTML file created at: ${outputPath}`);
        return outputPath;
    } catch (error) {
        console.error('Error processing Slack JSON:', error);
        return null;
    }
}

// Check if the script is run directly
if (require.main === module) {
    const args = process.argv.slice(2);
    if (args.length === 0) {
        console.error('Please provide the path to the Slack JSON file.');
        console.log('Usage: node slack-dm-viewer.js path/to/slack-export.json');
    } else {
        processSlackJSON(args[0]);
    }
}

module.exports = { processSlackJSON };
