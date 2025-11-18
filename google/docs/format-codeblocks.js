/**
 * Google Docs Codeblock Formatter Script
 *
 * Install to a doc via: Extensions -> Apps Script -> Paste the following code into the code editor and save, then go back to your doc and refresh the page
 * Formats codeblocks (text between ``` markers) with:
 * - Single line spacing (1.0)
 * - No space before paragraph
 * - No space after paragraph
 *
 * Options:
 * - Entire document
 * - Selected text only
 */

/**
 * Formats all codeblocks in the entire document
 */
function formatAllCodeblocks() {
  const doc = DocumentApp.getActiveDocument();
  const body = doc.getBody();

  const result = formatCodeblocksInBody(body);

  if (result.codeblockCount === 0) {
    DocumentApp.getUi().alert('No codeblocks found in document.\n\nCodeblocks should be marked with ``` on separate lines.');
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
    DocumentApp.getUi().alert('Please select text containing codeblocks first.\n\nCodeblocks should be marked with ``` on separate lines.');
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
    DocumentApp.getUi().alert('No codeblocks found in document.\n\nCodeblocks should be marked with ``` on separate lines.');
    return;
  }

  showResult(result.paragraphCount, result.codeblockCount);
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

  for (let i = 0; i < paragraphs.length; i++) {
    const paragraph = paragraphs[i];
    const text = paragraph.getText().trim();

    // Check if this paragraph is a codeblock delimiter
    if (text.startsWith('```')) {
      if (!inCodeblock) {
        // Start of codeblock
        inCodeblock = true;
        codeblockCount++;
      } else {
        // End of codeblock
        inCodeblock = false;
      }
      continue; // Don't format the delimiter lines themselves
    }

    // If we're inside a codeblock, format this paragraph
    if (inCodeblock) {
      try {
        formatCodeblockParagraph(paragraph);
        paragraphCount++;
      } catch (e) {
        Logger.log('Error formatting paragraph: ' + e.message);
      }
    }
  }

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
