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
 *
 * ## Debugging
 *
 * If codeblocks aren't being detected, check the logs:
 * 1. Go to Extensions → Apps Script
 * 2. Click "View" → "Logs" (or press Ctrl+Enter after running)
 * 3. The logs will show:
 *    - All paragraphs in your document
 *    - Character codes for potential delimiters (standard ` is code 96)
 *    - Which delimiters were matched
 *
 * The script detects codeblocks marked with three or more of the same quote-like character.
 * It supports standard backticks (`) and various Unicode variants that Google Docs might use.
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

  if (trimmed.length === 0) {
    return false;
  }

  // Log character codes for the first 5 characters to help debug
  if (trimmed.length >= 3) {
    const charCodes = [];
    for (let i = 0; i < Math.min(5, trimmed.length); i++) {
      charCodes.push(trimmed.charCodeAt(i));
    }
    Logger.log('  First chars: "' + trimmed.substring(0, 5) + '" char codes: [' + charCodes.join(', ') + ']');
  }

  // Check for ``` or ```language (e.g., ```javascript, ```python, etc.)
  // Standard backtick is U+0060 (96)
  if (trimmed.startsWith('```')) {
    Logger.log('  -> Matched standard backticks');
    return true;
  }

  // Check for various Unicode backtick-like characters that Google Docs might use
  // Including: ` (U+0060), ´ (U+00B4), ʻ (U+02BB), ʼ (U+02BC), ˋ (U+02CB), ˊ (U+02CA), ' (U+2018), ' (U+2019)
  const backtickPattern = /^[`´ʻʼˋˊ'']{3,}/;
  if (trimmed.match(backtickPattern)) {
    Logger.log('  -> Matched Unicode backtick variant');
    return true;
  }

  // Also check if first 3+ characters are all the same and could be a backtick
  if (trimmed.length >= 3) {
    const firstChar = trimmed.charAt(0);
    const first3Same = trimmed.charAt(0) === trimmed.charAt(1) && trimmed.charAt(1) === trimmed.charAt(2);

    // Check if it's any kind of quote-like character (char codes 96, 180, 700-730, 8216-8219)
    const charCode = trimmed.charCodeAt(0);
    const isQuoteLike = charCode === 96 || charCode === 180 ||
                        (charCode >= 700 && charCode <= 730) ||
                        (charCode >= 8216 && charCode <= 8219);

    if (first3Same && isQuoteLike) {
      Logger.log('  -> Matched 3+ identical quote-like characters (code: ' + charCode + ')');
      return true;
    }
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

  Logger.log('========================================');
  Logger.log('Starting codeblock detection');
  Logger.log('Total paragraphs to process: ' + paragraphs.length);
  Logger.log('========================================');

  for (let i = 0; i < paragraphs.length; i++) {
    const paragraph = paragraphs[i];
    const text = paragraph.getText();
    const trimmedText = text.trim();

    // Log ALL paragraphs, even empty ones
    if (trimmedText.length === 0) {
      Logger.log('Paragraph ' + i + ': <empty>');
    } else {
      Logger.log('Paragraph ' + i + ': "' + trimmedText.substring(0, Math.min(30, trimmedText.length)) + '..." (length: ' + trimmedText.length + ')');
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

  Logger.log('========================================');
  Logger.log('Formatting complete!');
  Logger.log('Codeblocks found: ' + codeblockCount);
  Logger.log('Paragraphs formatted: ' + paragraphCount);
  Logger.log('========================================');

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
