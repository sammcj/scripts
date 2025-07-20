// ==UserScript==
// @name         Bybit Position Table Sorter + Distance Calculator + Symbol Highlighter
// @namespace    http://tampermonkey.net/
// @version      1.5
// @description  Add sorting functionality, distance-to-exit column, and highlight current symbol in Bybit position tables
// @author       You
// @match        https://www.bybit.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    function extractNumber(text) {
        if (!text || text === '--') {
            return 0;
        }
        // Remove currency symbols, spaces, commas, and crypto suffixes like USDT, BTC, ETH, AUD
        var cleaned = text.replace(/[,\s£$€¥₹]/g, '').replace(/\b(USDT|BTC|ETH|AUD|USD|EUR|GBP)\b/gi, '');
        var match = cleaned.match(/-?\d+\.?\d*/);
        if (match) {
            return parseFloat(match[0]);
        } else {
            return 0;
        }
    }

    function extractPercentage(text) {
        if (!text || text === '--') {
            return 0;
        }
        var match = text.match(/-?\d+\.?\d*(?=%)/);
        if (match) {
            return parseFloat(match[0]);
        } else {
            return 0;
        }
    }

    function getCurrentSymbolFromURL() {
        var url = window.location.href;
        // Match patterns like /trade/usdt/XLMUSDT or /XLMUSDT at the end of URL
        var symbolMatch = url.match(/\/([A-Z0-9]+)(?:\?|$)/);
        if (symbolMatch) {
            return symbolMatch[1];
        }

        // Alternative pattern for different URL structures
        var altMatch = url.match(/\/trade\/[^\/]+\/([A-Z0-9]+)/);
        if (altMatch) {
            return altMatch[1];
        }

        return null;
    }

    function highlightSymbolRows(table) {
        var currentSymbol = getCurrentSymbolFromURL();
        if (!currentSymbol) {
            // console.log('No symbol found in URL');
            return;
        }

        // console.log('Highlighting rows for symbol:', currentSymbol);

        var dataRows = table.querySelectorAll('tbody tr, tr[data-index]');

        for (var i = 0; i < dataRows.length; i++) {
            var row = dataRows[i];

            // Skip header rows
            if (row.parentNode.tagName === 'THEAD') {
                continue;
            }

            // Remove existing highlighting first
            row.classList.remove('symbol-highlighted');
            row.style.backgroundColor = '';
            row.style.border = '';

            // Find the symbol in the first column (typically Symbol/Contracts column)
            var symbolCell = row.children[0];
            if (symbolCell) {
                var cellText = symbolCell.textContent.trim();

                // Match exact symbol or symbol within contract notation (e.g., "XLMUSDT" in "XLMUSDT-USD")
                if (cellText === currentSymbol ||
                    cellText.indexOf(currentSymbol) === 0 ||
                    cellText.includes(currentSymbol + '-') ||
                    cellText.includes(currentSymbol + 'USDT') ||
                    cellText.includes(currentSymbol + 'USD')) {

                    // console.log('Highlighting row for symbol match:', cellText);

                    // Apply highlighting
                    row.classList.add('symbol-highlighted');
                    row.style.backgroundColor = 'rgba(0, 212, 170, 0.15)';
                    row.style.border = '2px solid rgba(0, 212, 170, 0.6)';
                    row.style.borderRadius = '4px';

                    // Add a subtle animation
                    row.style.transition = 'all 0.3s ease';
                }
            }
        }
    }

    function calculateDistanceToExit(row) {
        var markPriceCell = row.children[4]; // Mark Price column
        var liqPriceCell = row.children[5];  // Liq Price column
        var tpslCell = row.children[10];     // TP/SL column

        if (!markPriceCell || !liqPriceCell || !tpslCell) {
            // console.log('Missing cells for distance calculation');
            return "N/A";
        }

        var markPrice = extractNumber(markPriceCell.textContent);
        var liqPrice = extractNumber(liqPriceCell.textContent);

        // console.log('Mark Price:', markPrice, 'Liq Price:', liqPrice);

        if (markPrice === 0) {
            return "N/A";
        }

        // Extract stop loss from TP/SL column (format: "-- / SL" or "TP / SL")
        var tpslText = tpslCell.textContent;
        var stopLoss = null;

        // Look for stop loss after the slash
        var slMatch = tpslText.match(/\/\s*([0-9.]+)/);
        if (slMatch) {
            stopLoss = parseFloat(slMatch[1]);
        }

        // console.log('TP/SL text:', tpslText, 'Stop Loss:', stopLoss);

        // Calculate distances
        var distanceToLiq = Math.abs((markPrice - liqPrice) / markPrice * 100);
        var distanceToSL = stopLoss ? Math.abs((markPrice - stopLoss) / markPrice * 100) : Infinity;

        // console.log('Distance to Liq:', distanceToLiq, 'Distance to SL:', distanceToSL);

        // Return the smaller distance (closer to current price)
        var minDistance = Math.min(distanceToLiq, distanceToSL);

        if (minDistance === Infinity) {
            return distanceToLiq.toFixed(2) + "% (Liq)";
        } else if (distanceToSL < distanceToLiq) {
            return minDistance.toFixed(2) + "% (SL)";
        } else {
            return minDistance.toFixed(2) + "% (Liq)";
        }
    }

    function getSortValue(cell, columnIndex) {
        var text = cell.textContent.trim();
        var percentMatch;

        // Check if this is the distance column by looking for our custom attribute
        var table = cell.closest('table');
        var headers = table.querySelectorAll('thead th');
        var isDistanceColumn = false;
        var columnHeader = '';

        if (headers[columnIndex]) {
            if (headers[columnIndex].hasAttribute('data-distance-column')) {
                isDistanceColumn = true;
            }
            columnHeader = headers[columnIndex].textContent.toLowerCase();
        }

        if (isDistanceColumn) {
            // For distance column, extract the percentage number
            return extractNumber(text);
        }

        // Check if this is a P&L column by header text
        if (columnHeader.includes('p&l') || columnHeader.includes('pnl') || columnHeader.includes('unrealized')) {
            // For P&L columns, prioritise the USDT/currency value over percentage
            return extractNumber(text);
        }

        // Check if this contains percentage in parentheses (like P&L columns often do)
        percentMatch = text.match(/\(([+-]?\d+\.?\d*)%\)/);
        if (percentMatch && (text.includes('USDT') || text.includes('AUD') || text.includes('USD'))) {
            // This looks like a P&L cell with both currency and percentage - use currency value
            return extractNumber(text);
        }

        // Default handling based on column position
        switch(columnIndex) {
            case 0:
                return text.toLowerCase();
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 9:
                return extractNumber(text);
            case 8:
                // This was the old P&L column handling - now handled above more generically
                percentMatch = text.match(/\(([+-]?\d+\.?\d*)%\)/);
                if (percentMatch) {
                    return parseFloat(percentMatch[1]);
                } else {
                    return extractNumber(text);
                }
            default:
                // For any other column, try to extract number first, fall back to text
                var numValue = extractNumber(text);
                if (numValue !== 0 || text === '0' || text === '--') {
                    return numValue;
                } else {
                    return text.toLowerCase();
                }
        }
    }

    function sortTable(table, columnIndex, ascending) {
        if (typeof ascending === 'undefined') {
            ascending = true;
        }

        var tbody = table.querySelector('tbody');
        var rows = Array.prototype.slice.call(tbody.querySelectorAll('tr'));
        var currentSymbol = getCurrentSymbolFromURL();

        // Separate highlighted (current symbol) rows from others
        var highlightedRows = [];
        var normalRows = [];

        for (var i = 0; i < rows.length; i++) {
            var row = rows[i];
            var isHighlighted = false;

            if (currentSymbol && row.children[0]) {
                var cellText = row.children[0].textContent.trim();
                if (cellText === currentSymbol ||
                    cellText.indexOf(currentSymbol) === 0 ||
                    cellText.includes(currentSymbol + '-') ||
                    cellText.includes(currentSymbol + 'USDT') ||
                    cellText.includes(currentSymbol + 'USD')) {
                    isHighlighted = true;
                }
            }

            if (isHighlighted) {
                highlightedRows.push(row);
            } else {
                normalRows.push(row);
            }
        }

        // Sort both groups separately
        function sortRowGroup(rowGroup) {
            rowGroup.sort(function(a, b) {
                var aCell = a.children[columnIndex];
                var bCell = b.children[columnIndex];

                var aVal = getSortValue(aCell, columnIndex);
                var bVal = getSortValue(bCell, columnIndex);

                if (typeof aVal === 'string') {
                    if (ascending) {
                        return aVal.localeCompare(bVal);
                    } else {
                        return bVal.localeCompare(aVal);
                    }
                } else {
                    if (ascending) {
                        return aVal - bVal;
                    } else {
                        return bVal - aVal;
                    }
                }
            });
        }

        sortRowGroup(highlightedRows);
        sortRowGroup(normalRows);

        // Append highlighted rows first, then normal rows
        for (var i = 0; i < highlightedRows.length; i++) {
            tbody.appendChild(highlightedRows[i]);
        }
        for (var i = 0; i < normalRows.length; i++) {
            tbody.appendChild(normalRows[i]);
        }

        // Re-apply symbol highlighting after sorting
        highlightSymbolRows(table);
    }

    function updateSortIndicators(headers, sortedColumn, ascending) {
        for (var i = 0; i < headers.length; i++) {
            var header = headers[i];
            var indicator = header.querySelector('.sort-indicator');
            if (indicator) {
                indicator.remove();
            }

            // Only add indicator if we have a valid sorted column
            if (sortedColumn >= 0 && i === sortedColumn) {
                var arrow = document.createElement('span');
                arrow.className = 'sort-indicator';
                if (ascending) {
                    arrow.textContent = '↑ ';
                } else {
                    arrow.textContent = '↓ ';
                }
                arrow.style.color = '#00d4aa';
                arrow.style.fontWeight = 'bold';
                arrow.style.fontSize = '12px';
                arrow.style.marginRight = '3px';

                // Insert at the beginning instead of end to avoid hide button
                header.insertBefore(arrow, header.firstChild);
            }
        }
    }

    function addDistanceColumn(table) {
        // console.log('Adding distance column...');

        // Check if distance column already exists
        var existingDistanceHeader = table.querySelector('th[data-distance-column]');
        if (existingDistanceHeader) {
            // console.log('Distance column already exists, skipping');
            return;
        }

        // console.log('Table structure:', table.outerHTML.substring(0, 500));

        // Add header right after TP/SL column
        var headerRow = table.querySelector('thead tr');
        if (headerRow) {
            var newHeader = document.createElement('th');
            newHeader.textContent = 'Exit %';
            newHeader.style.minWidth = '70px';
            newHeader.style.maxWidth = '80px';
            newHeader.style.width = '75px';
            newHeader.style.textAlign = 'center';
            newHeader.style.fontSize = '11px';
            newHeader.style.fontWeight = 'bold';
            newHeader.style.color = '#ff6b6b';
            newHeader.style.padding = '4px 2px';
            newHeader.setAttribute('data-distance-column', 'true');

            // Find TP/SL column and insert after it
            var tpslHeader = null;
            for (var j = 0; j < headerRow.children.length; j++) {
                var headerText = headerRow.children[j].textContent;
                if (headerText.indexOf('TP/SL') !== -1) {
                    tpslHeader = headerRow.children[j];
                    break;
                }
            }

            if (tpslHeader && tpslHeader.nextSibling) {
                headerRow.insertBefore(newHeader, tpslHeader.nextSibling);
                // console.log('Added header column after TP/SL');
            } else if (tpslHeader) {
                // If TP/SL is the last column, append after it
                headerRow.appendChild(newHeader);
                // console.log('Added header column at end (TP/SL was last)');
            } else {
                // Fallback - append at end if can't find TP/SL
                headerRow.appendChild(newHeader);
                // console.log('Added header column at end (TP/SL not found)');
            }
        }

        // Try different selectors to find rows
        var dataRows = table.querySelectorAll('tbody tr');
        // console.log('tbody tr found:', dataRows.length);

        if (dataRows.length === 0) {
            dataRows = table.querySelectorAll('tr[data-index]');
            // console.log('tr[data-index] found:', dataRows.length);
        }

        if (dataRows.length === 0) {
            dataRows = table.querySelectorAll('tr');
            // console.log('All tr found:', dataRows.length);
        }

        for (var k = 0; k < dataRows.length; k++) {
            var row = dataRows[k];

            // Skip header rows
            if (row.parentNode.tagName === 'THEAD') {
                // console.log('Skipping header row', k);
                continue;
            }

            // console.log('Processing row', k, 'with', row.children.length, 'columns');

            var newCell = document.createElement('td');
            newCell.style.textAlign = 'center';
            newCell.style.fontSize = '10px';
            newCell.style.fontWeight = 'bold';
            newCell.style.padding = '4px 2px';
            newCell.style.maxWidth = '80px';
            newCell.style.width = '75px';
            newCell.setAttribute('data-distance-cell', 'true');

            try {
                var distance = calculateDistanceToExit(row);
                // console.log('Calculated distance for row', k, ':', distance);
                newCell.textContent = distance;
            } catch (error) {
                console.error('Error calculating distance for row', k, ':', error);
                newCell.textContent = 'Error';
            }

            // Colour coding based on distance
            var percentValue = extractNumber(newCell.textContent);
            if (percentValue < 5) {
                newCell.style.color = '#ff4444';
                newCell.style.backgroundColor = 'rgba(255, 68, 68, 0.1)';
            } else if (percentValue < 15) {
                newCell.style.color = '#ff8800';
                newCell.style.backgroundColor = 'rgba(255, 136, 0, 0.1)';
            } else {
                newCell.style.color = '#00d4aa';
                newCell.style.backgroundColor = 'rgba(0, 212, 170, 0.1)';
            }

            // Find TP/SL cell and insert after it
            var tpslCell = null;
            for (var m = 0; m < row.children.length; m++) {
                var cellText = row.children[m].textContent;
                if (cellText.indexOf('/') !== -1 && (cellText.indexOf('--') !== -1 || /\d/.test(cellText))) {
                    // This looks like a TP/SL cell (contains / and either -- or numbers)
                    tpslCell = row.children[m];
                    break;
                }
            }

            if (tpslCell && tpslCell.nextSibling) {
                row.insertBefore(newCell, tpslCell.nextSibling);
            } else if (tpslCell) {
                // If TP/SL is the last cell, append after it
                row.appendChild(newCell);
            } else {
                // Fallback - append at end if can't find TP/SL
                row.appendChild(newCell);
            }
        }
        // console.log('Finished adding distance column');
    }

    function addDistanceColumnData(table) {
        var dataRows = table.querySelectorAll('tbody tr, tr[data-index]');
        // console.log('Adding distance data to', dataRows.length, 'rows');

        for (var i = 0; i < dataRows.length; i++) {
            var row = dataRows[i];

            // Skip header rows
            if (row.parentNode.tagName === 'THEAD') {
                continue;
            }

            var newCell = document.createElement('td');
            newCell.style.textAlign = 'center';
            newCell.style.fontSize = '10px';
            newCell.style.fontWeight = 'bold';
            newCell.style.padding = '4px 2px';
            newCell.style.maxWidth = '80px';
            newCell.style.width = '75px';
            newCell.setAttribute('data-distance-cell', 'true');

            try {
                var distance = calculateDistanceToExit(row);
                // console.log('Calculated distance for row', i, ':', distance);
                newCell.textContent = distance;
            } catch (error) {
                console.error('Error calculating distance for row', i, ':', error);
                newCell.textContent = 'Error';
            }

            // Colour coding based on distance
            var percentValue = extractNumber(newCell.textContent);
            if (percentValue < 5) {
                newCell.style.color = '#ff4444';
                newCell.style.backgroundColor = 'rgba(255, 68, 68, 0.1)';
            } else if (percentValue < 15) {
                newCell.style.color = '#ff8800';
                newCell.style.backgroundColor = 'rgba(255, 136, 0, 0.1)';
            } else {
                newCell.style.color = '#00d4aa';
                newCell.style.backgroundColor = 'rgba(0, 212, 170, 0.1)';
            }

            // Find TP/SL cell and insert after it
            var tpslCell = null;
            for (var ii = 0; ii < row.children.length; ii++) {
                var cellText = row.children[ii].textContent;
                if (cellText.indexOf('/') !== -1 && (cellText.indexOf('--') !== -1 || /\d/.test(cellText))) {
                    // This looks like a TP/SL cell (contains / and either -- or numbers)
                    tpslCell = row.children[ii];
                    break;
                }
            }

            if (tpslCell && tpslCell.nextSibling) {
                row.insertBefore(newCell, tpslCell.nextSibling);
            } else if (tpslCell) {
                // If TP/SL is the last cell, append after it
                row.appendChild(newCell);
            } else {
                // Fallback - append at end if can't find TP/SL
                row.appendChild(newCell);
            }
        }
    }

    function makeHeadersSortable(table) {
        var headers = table.querySelectorAll('thead th');
        var lastSortedColumn = -1;
        var lastSortAscending = true;

        // Store references for clearing sort later
        table.sortState = {
            lastSortedColumn: lastSortedColumn,
            lastSortAscending: lastSortAscending,
            clearSort: function() {
                // console.log('Clearing sort');
                lastSortedColumn = -1;
                lastSortAscending = true;
                updateSortIndicators(headers, -1, true);

                // Update stored state
                table.sortState.lastSortedColumn = lastSortedColumn;
                table.sortState.lastSortAscending = lastSortAscending;
                // console.log('Sort cleared');
            }
        };

        for (var i = 0; i < headers.length; i++) {
            var header = headers[i];
            // Include all columns including our distance column (skip only action columns at very end)
            if (i >= 20) continue; // Increased limit to include distance column

            header.style.cursor = 'pointer';
            header.style.userSelect = 'none';

            header.addEventListener('mouseenter', function() {
                if (!this.querySelector('.sort-indicator')) {
                    this.style.backgroundColor = 'rgba(0, 212, 170, 0.1)';
                }
            });

            header.addEventListener('mouseleave', function() {
                if (!this.querySelector('.sort-indicator')) {
                    this.style.backgroundColor = '';
                }
            });

            (function(index) {
                header.addEventListener('click', function(e) {
                    // Check if click was on hide button or its children
                    var target = e.target;
                    var isHideButton = false;

                    // Check if clicked element or its parents are hide buttons
                    while (target && target !== header) {
                        if (target.classList && (
                            target.classList.contains('bb__colum-close-icon') ||
                            target.classList.contains('bb__colum-drag-icon') ||
                            target.classList.contains('bb__colum-sort-icon') ||
                            target.tagName === 'svg' && target.parentNode.classList.contains('bb__colum-close-icon')
                        )) {
                            isHideButton = true;
                            break;
                        }
                        target = target.parentNode;
                    }

                    // Don't sort if clicking on Bybit's buttons
                    if (isHideButton) {
                        // console.log('Clicked on Bybit button, ignoring sort');
                        return;
                    }

                    e.preventDefault();
                    e.stopPropagation();

                    var ascending;
                    if (lastSortedColumn === index) {
                        ascending = !lastSortAscending;
                    } else {
                        ascending = true;
                    }

                    sortTable(table, index, ascending);
                    updateSortIndicators(headers, index, ascending);

                    lastSortedColumn = index;
                    lastSortAscending = ascending;

                    // Update stored state
                    table.sortState.lastSortedColumn = lastSortedColumn;
                    table.sortState.lastSortAscending = lastSortAscending;
                });
            })(i);
        }
    }

    function initSorting() {
        var tables = document.querySelectorAll('table');

        for (var i = 0; i < tables.length; i++) {
            var table = tables[i];
            var firstHeader = table.querySelector('thead th');
            var hasPositionColumns = false;

            if (firstHeader) {
                var headerText = table.querySelector('thead').textContent;
                hasPositionColumns = headerText.indexOf('Contracts') !== -1 ||
                                   headerText.indexOf('Symbol') !== -1 ||
                                   headerText.indexOf('Unrealized P&L') !== -1;
            }

            if (hasPositionColumns && !table.hasAttribute('data-sorting-enabled')) {
                // Add the distance column first
                if (!table.hasAttribute('data-distance-added')) {
                    addDistanceColumn(table);
                    table.setAttribute('data-distance-added', 'true');

                    // Retry adding distance data after a delay if no rows were found
                    setTimeout(function() {
                        var dataRows = table.querySelectorAll('tbody tr, tr[data-index]');
                        if (dataRows.length > 0) {
                            // console.log('Found data rows on retry, updating distance column...');
                            // Remove old empty cells and re-add with data
                            var existingCells = table.querySelectorAll('td:last-child');
                            for (var ii = 0; ii < existingCells.length; ii++) {
                                if (existingCells[ii].textContent === '' || existingCells[ii].textContent === 'Error') {
                                    existingCells[ii].remove();
                                }
                            }
                            addDistanceColumnData(table);
                        }
                    }, 2000);
                }

                makeHeadersSortable(table);
                table.setAttribute('data-sorting-enabled', 'true');

                // Apply symbol highlighting
                highlightSymbolRows(table);

                // console.log('Bybit Sorter: Added sorting, distance column, and symbol highlighting to position table');
            }
        }
    }

    // Monitor URL changes to update highlighting when user switches symbols
    var lastUrl = window.location.href;
    function checkForUrlChange() {
        if (window.location.href !== lastUrl) {
            lastUrl = window.location.href;
            // console.log('URL changed, updating symbol highlighting');
            setTimeout(function() {
                var tables = document.querySelectorAll('table[data-sorting-enabled]');
                for (var i = 0; i < tables.length; i++) {
                    highlightSymbolRows(tables[i]);
                }
            }, 500);
        }
    }

    // Initialize immediately
    initSorting();

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function() {
            initSorting();
        });
    }

    // Initialize after a delay to catch slow-loading tables
    setTimeout(function() {
        initSorting();
    }, 1000);

    // Initialize after longer delay for very slow connections
    setTimeout(function() {
        initSorting();
    }, 3000);

    // More frequent checks in the first 10 seconds
    var earlyCheckCount = 0;
    var earlyChecker = setInterval(function() {
        initSorting();
        earlyCheckCount++;
        if (earlyCheckCount >= 10) { // Check 10 times over 5 seconds
            clearInterval(earlyChecker);
        }
    }, 500);

    var observer = new MutationObserver(function(mutations) {
        var shouldReinit = false;

        for (var i = 0; i < mutations.length; i++) {
            var mutation = mutations[i];
            if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
                for (var ii = 0; ii < mutation.addedNodes.length; ii++) {
                    var node = mutation.addedNodes[ii];
                    if (node.nodeType === 1) {
                        if (node.tagName === 'TABLE' || node.querySelector('table')) {
                            shouldReinit = true;
                            break;
                        }
                        // Also check for table rows being added (data loading)
                        if (node.tagName === 'TR' || node.querySelector('tr')) {
                            shouldReinit = true;
                            break;
                        }
                    }
                }
                if (shouldReinit) break;
            }
        }

        if (shouldReinit) {
            setTimeout(initSorting, 100);
            // Also check again after a longer delay in case more data loads
            setTimeout(initSorting, 1000);
        }
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true
    });

    // Check for URL changes periodically and also update highlighting
    setInterval(function() {
        checkForUrlChange();
        // Also refresh highlighting on existing tables periodically
        var tables = document.querySelectorAll('table[data-sorting-enabled]');
        for (var i = 0; i < tables.length; i++) {
            highlightSymbolRows(tables[i]);
        }
    }, 2000);

    var style = document.createElement('style');
    style.textContent = `
        .sort-indicator {
            margin-right: 3px;
            font-size: 12px;
            color: #00d4aa !important;
            font-weight: bold !important;
        }
        th[data-sorting-enabled="true"]:hover {
            background-color: rgba(0, 212, 170, 0.1) !important;
        }
        th[data-distance-column] {
            min-width: 70px !important;
            max-width: 80px !important;
            width: 75px !important;
            padding: 4px 2px !important;
        }
        td[data-distance-cell] {
            min-width: 70px !important;
            max-width: 80px !important;
            width: 75px !important;
            padding: 4px 2px !important;
            font-size: 10px !important;
        }
        .symbol-highlighted {
            background-color: rgba(0, 212, 170, 0.15) !important;
            border: 2px solid rgba(0, 212, 170, 0.6) !important;
            border-radius: 4px !important;
            transition: all 0.3s ease !important;
        }
        .symbol-highlighted:hover {
            background-color: rgba(0, 212, 170, 0.25) !important;
            border-color: rgba(0, 212, 170, 0.8) !important;
        }
    `;
    document.head.appendChild(style);

})();
