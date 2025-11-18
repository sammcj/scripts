/**
 * Google Docs Codeblock Formatter Script
 *
 * ## Problem
 *
 * When you paste markdown content into Google Docs, codeblocks often get formatted with:
 * - Extra space before paragraphs
 * - Extra space after paragraphs
 * - 1.15x or 1.5x line spacing
 *
 * This wastes a lot of vertical space in your document.
 *
 * ## Solution
 *
 * This script detects codeblocks by their monospace font (Courier New, Consolas, etc.)
 * and applies compact formatting:
 * - Single line spacing (1.0)
 * - No space before paragraph (0pt)
 * - No space after paragraph (0pt)
 *
 * Note: The script detects code by font, not by ``` markers, since Google Docs
 * converts markdown delimiters to formatting when you paste.
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
 * 2. The script will find all paragraphs using monospace fonts and apply compact formatting
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
 *    - Font family for each paragraph
 *    - Which paragraphs were detected as code
 *
 * The script detects code by monospace fonts including:
 * Courier New, Consolas, Monaco, Menlo, Source Code Pro, Roboto Mono, etc.
 *
 * If your code isn't being detected, it might be using a non-monospace font.
 * Try manually changing the font to a monospace font in Google Docs first.
 */

/**
 * Formats all codeblocks in the entire document
 */
function formatAllCodeblocks() {
  const doc = DocumentApp.getActiveDocument();
  const body = doc.getBody();

  const result = formatCodeblocksInBody(body);

  if (result.codeblockCount === 0) {
    DocumentApp.getUi().alert('No codeblocks found in document.\n\nThe script detects code by monospace font (Courier New, Consolas, etc.).\n\nMake sure your code paragraphs use a monospace font.\n\nTo debug: Go to Extensions → Apps Script → View → Logs to see font details.');
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
    DocumentApp.getUi().alert('Please select text containing codeblocks first.\n\nThe script detects code by monospace font.\n\nNote: Currently this function processes the whole document.');
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
    DocumentApp.getUi().alert('No codeblocks found in document.\n\nThe script detects code by monospace font (Courier New, Consolas, etc.).\n\nMake sure your code paragraphs use a monospace font.\n\nTo debug: Go to Extensions → Apps Script → View → Logs to see font details.');
    return;
  }

  showResult(result.paragraphCount, result.codeblockCount);
}

/**
 * Checks if a paragraph is formatted as code (monospace font)
 */
function isCodeParagraph(paragraph) {
  try {
    const text = paragraph.getText();
    if (!text || text.trim().length === 0) {
      return false;
    }

    // Get the font family of the paragraph
    const textObj = paragraph.editAsText();
    const fontFamily = textObj.getFontFamily(0);

    Logger.log('  Font: "' + fontFamily + '"');

    // Check if it's a monospace font (common code fonts)
    const monospaceFonts = [
      'Courier New',
      'Courier',
      'Consolas',
      'Monaco',
      'Menlo',
      'Source Code Pro',
      'Roboto Mono',
      'Fira Code',
      'JetBrains Mono',
      'Anonymous Pro',
      'Liberation Mono',
      'Inconsolata',
      'Ubuntu Mono',
      'DejaVu Sans Mono',
      'Lucida Console'
    ];

    if (fontFamily) {
      const fontLower = fontFamily.toLowerCase();
      for (let i = 0; i < monospaceFonts.length; i++) {
        if (fontLower.indexOf(monospaceFonts[i].toLowerCase()) !== -1) {
          Logger.log('  -> Matched monospace font: ' + fontFamily);
          return true;
        }
      }

      // Also check if "mono" appears in font name
      if (fontLower.indexOf('mono') !== -1) {
        Logger.log('  -> Matched "mono" in font name: ' + fontFamily);
        return true;
      }
    }

    return false;
  } catch (e) {
    Logger.log('  Error checking font: ' + e.message);
    return false;
  }
}

/**
 * Formats codeblocks in the document body
 * Detects code by monospace font formatting
 */
function formatCodeblocksInBody(body) {
  const paragraphs = body.getParagraphs();
  let inCodeblock = false;
  let paragraphCount = 0;
  let codeblockCount = 0;

  Logger.log('========================================');
  Logger.log('Starting codeblock detection (by font)');
  Logger.log('Total paragraphs to process: ' + paragraphs.length);
  Logger.log('========================================');

  for (let i = 0; i < paragraphs.length; i++) {
    const paragraph = paragraphs[i];
    const text = paragraph.getText();
    const trimmedText = text.trim();

    // Log paragraph info
    if (trimmedText.length === 0) {
      Logger.log('Paragraph ' + i + ': <empty>');
    } else {
      Logger.log('Paragraph ' + i + ': "' + trimmedText.substring(0, Math.min(30, trimmedText.length)) + '..." (length: ' + trimmedText.length + ')');
    }

    // Check if this paragraph uses a monospace font (is code)
    const isCode = isCodeParagraph(paragraph);

    if (isCode) {
      if (!inCodeblock) {
        // Start of a new codeblock
        inCodeblock = true;
        codeblockCount++;
        Logger.log('  >>> Starting codeblock #' + codeblockCount);
      }

      // Format this code paragraph
      try {
        formatCodeblockParagraph(paragraph);
        paragraphCount++;
        Logger.log('  >>> Formatted paragraph ' + i);
      } catch (e) {
        Logger.log('  Error formatting paragraph ' + i + ': ' + e.message);
      }
    } else {
      // Not code - end codeblock if we were in one
      if (inCodeblock) {
        inCodeblock = false;
        Logger.log('  >>> Ending codeblock');
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