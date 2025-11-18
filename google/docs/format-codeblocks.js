/**
 * Google Docs Codeblock Formatter Script
 *
 * ## Problem
 *
 * When you paste markdown content into Google Docs, codeblocks (text between ``` markers) often get formatted with:
 * - Extra space before paragraphs
 * - Extra space after paragraphs
 * - 1.15x or 1.5x line spacing
 *
 * This wastes a lot of vertical space in your document.
 *
 * ## Solution
 *
 * This script finds all codeblocks in your document and applies compact formatting:
 * - Single line spacing (1.0)
 * - No space before paragraph (0pt)
 * - No space after paragraph (0pt)
 *
 * ## Installation
 *
 * 1. Open your Google Doc
 * 2. Go to Extensions → Apps Script
 * 3. Delete any default code in the editor
 * 4. Copy and paste the entire contents of format-codeblocks.js into the editor
 * 5. Click the Save icon (💾) and give your project a name (e.g., "Codeblock Formatter")
 * 6. Close the Apps Script tab and refresh your Google Doc
 * 7. You should now see a new menu called "Codeblock Formatting" in the menu bar
 *
 * ## Usage
 *
 * ### Format All Codeblocks
 *
 * 1. Click Codeblock Formatting → Format All Codeblocks
 * 2. The script will find all text between ``` markers and apply compact formatting
 * 3. A dialog will show how many paragraphs were formatted
 *
 * ### Format Selected Codeblocks (Alternative)
 *
 * 1. Select the text containing codeblocks you want to format
 * 2. Click Codeblock Formatting → Format Selected Codeblocks
 * 3. Currently this processes the whole document, but could be refined to only process selected codeblocks
 */

/**
 * Formats all codeblocks in the entire document
 */
function formatAllCodeblocks() {
  const doc = DocumentApp.getActiveDocument();
  const body = doc.getBody();

  const result = formatCodeblocksInBody(body);

  if (result.codeblockCount === 0) {
    DocumentApp.getUi().alert('No codeblocks found in document.\n\nCodeblocks should be marked with ``` on separate lines.\n\nTo debug: Go to Extensions → Apps Script → View → Logs to see what was detected.');
    return;
  }

  showResult(result.paragraphCount, result.codeblockCount);
}

/**
 * Formats codeblocks in selected text only
 */
function formatSelectedCodeblocks() {
  const doc = DocumentApp.getActiveDocument();
  const selection = doc.getSelection();

  if (!selection) {
    DocumentApp.getUi().alert('Please select text containing codeblocks first.\n\nCodeblocks should be marked with ``` on separate lines.\n\nNote: Currently this function processes the whole document.');
    return;
  }

  const elements = selection.getRangeElements();
  if (elements.length === 0) {
    DocumentApp.getUi().alert('No text selected');
    return;
  }

  // For selection, we still process the whole document but could be refined
  const body = doc.getBody();
  const result = formatCodeblocksInBody(body);

  if (result.codeblockCount === 0) {
    DocumentApp.getUi().alert('No codeblocks found in document.\n\nCodeblocks should be marked with ``` on separate lines.\n\nTo debug: Go to Extensions → Apps Script → View → Logs to see what was detected.');
    return;
  }

  showResult(result.paragraphCount, result.codeblockCount);
}

/**
 * Checks if a line is a codeblock delimiter (``` or ```language)
 */
function isCodeblockDelimiter(text) {
  const trimmed = text.trim();

  // Check for ``` or ```language (e.g., ```javascript, ```python, etc.)
  if (trimmed.startsWith('```')) {
    return true;
  }

  // Also check for possible variations with different backtick characters
  // that Google Docs might use
  if (trimmed.match(/^[`´]{3,}/)) {
    return true;
  }

  return false;
}

/**
 * Formats codeblocks in the document body
 * Iterates through paragraphs and tracks when inside a codeblock
 */
function formatCodeblocksInBody(body) {
  const paragraphs = body.getParagraphs();
  let inCodeblock = false;
  let paragraphCount = 0;
  let codeblockCount = 0;

  Logger.log('Total paragraphs to process: ' + paragraphs.length);

  for (let i = 0; i < paragraphs.length; i++) {
    const paragraph = paragraphs[i];
    const text = paragraph.getText();
    const trimmedText = text.trim();

    // Log first few characters for debugging
    if (trimmedText.length > 0) {
      Logger.log('Paragraph ' + i + ': "' + trimmedText.substring(0, Math.min(20, trimmedText.length)) + '..." (length: ' + trimmedText.length + ')');
    }

    // Check if this paragraph is a codeblock delimiter
    if (isCodeblockDelimiter(text)) {
      Logger.log('Found codeblock delimiter at paragraph ' + i + ': "' + trimmedText + '"');

      if (!inCodeblock) {
        // Start of codeblock
        inCodeblock = true;
        codeblockCount++;
        Logger.log('Starting codeblock #' + codeblockCount);
      } else {
        // End of codeblock
        inCodeblock = false;
        Logger.log('Ending codeblock');
      }
      continue; // Don't format the delimiter lines themselves
    }

    // If we're inside a codeblock, format this paragraph
    if (inCodeblock) {
      try {
        formatCodeblockParagraph(paragraph);
        paragraphCount++;
        Logger.log('Formatted paragraph ' + i + ' inside codeblock');
      } catch (e) {
        Logger.log('Error formatting paragraph ' + i + ': ' + e.message);
      }
    }
  }

  Logger.log('Formatting complete. Paragraphs: ' + paragraphCount + ', Codeblocks: ' + codeblockCount);

  return {
    paragraphCount: paragraphCount,
    codeblockCount: codeblockCount
  };
}

/**
 * Applies codeblock formatting to a paragraph
 */
function formatCodeblockParagraph(paragraph) {
  // Set line spacing to 1.0 (single spacing)
  paragraph.setLineSpacing(1.0);

  // Remove space before paragraph
  paragraph.setSpacingBefore(0);

  // Remove space after paragraph
  paragraph.setSpacingAfter(0);
}

/**
 * Shows result dialogue
 */
function showResult(paragraphCount, codeblockCount) {
  const message = paragraphCount > 0
    ? `Successfully formatted ${paragraphCount} paragraphs in ${codeblockCount} codeblock(s)`
    : 'No paragraphs found within codeblocks';

  Logger.log(message);
  DocumentApp.getUi().alert(message);
}

/**
 * Adds menu items to Google Docs
 */
function onOpen() {
  DocumentApp.getUi()
    .createMenu('Codeblock Formatting')
    .addItem('Format All Codeblocks', 'formatAllCodeblocks')
    .addItem('Format Selected Codeblocks', 'formatSelectedCodeblocks')
    .addToUi();
}
