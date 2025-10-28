/**
 * Google Slides Indent Normalisation Script
 *
 * Install to a deck via: Extensions -> App Scripts -> Paste the following code into the code editor and save, then go back to your deck and refresh the page
 * Normalises paragraph indenting with consistent 0.87cm increments
 * Levels: 0.44, 1.31, 2.18, 3.05, 3.92 cm
 * Hanging indent: 0.24 cm
 *
 * Options:
 * - Entire presentation (all slides)
 * - Current slide only
 * - Selected text only
 */


/**
 * Normalises indents across all slides
 */
function normaliseAllSlides() {
  const presentation = SlidesApp.getActivePresentation();
  const slides = presentation.getSlides();

  const config = getIndentConfig();
  let updatedCount = 0;

  slides.forEach(slide => {
    updatedCount += processSlide(slide, config);
  });

  showResult(updatedCount, 'all slides');
}

/**
 * Normalises indents on current slide only
 */
function normaliseCurrentSlide() {
  const presentation = SlidesApp.getActivePresentation();
  const selection = presentation.getSelection();
  const currentPage = selection.getCurrentPage();

  if (!currentPage) {
    SlidesApp.getUi().alert('No slide selected');
    return;
  }

  const config = getIndentConfig();
  const updatedCount = processSlide(currentPage, config);

  showResult(updatedCount, 'current slide');
}

/**
 * Normalises indents on selected text only
 */
function normaliseSelection() {
  const presentation = SlidesApp.getActivePresentation();
  const selection = presentation.getSelection();
  const selectionType = selection.getSelectionType();

  if (selectionType !== SlidesApp.SelectionType.TEXT) {
    SlidesApp.getUi().alert('Please select some text first');
    return;
  }

  const config = getIndentConfig();
  const textRange = selection.getTextRange();

  if (!textRange || textRange.asString().trim().length === 0) {
    SlidesApp.getUi().alert('No text selected');
    return;
  }

  const updatedCount = processTextRange(textRange, config.levels, config.hanging);

  showResult(updatedCount, 'selected text');
}

/**
 * Gets indent configuration
 */
function getIndentConfig() {
  const CM_TO_PT = 28.3465;

  return {
    levels: [
      0.44 * CM_TO_PT,
      1.31 * CM_TO_PT,
      2.18 * CM_TO_PT,
      3.05 * CM_TO_PT,
      3.92 * CM_TO_PT
    ],
    hanging: 0.24 * CM_TO_PT
  };
}

/**
 * Processes all text elements in a slide
 */
function processSlide(slide, config) {
  let updatedCount = 0;
  const pageElements = slide.getPageElements();

  pageElements.forEach(element => {
    const elementType = element.getPageElementType();

    if (elementType === SlidesApp.PageElementType.SHAPE) {
      const shape = element.asShape();
      try {
        const textRange = shape.getText();
        if (textRange && textRange.asString().trim().length > 0) {
          updatedCount += processTextRange(textRange, config.levels, config.hanging);
        }
      } catch (e) {
        // Shape has no text, skip it
      }
    } else if (elementType === SlidesApp.PageElementType.TABLE) {
      const table = element.asTable();
      const numRows = table.getNumRows();
      const numCols = table.getNumColumns();

      for (let row = 0; row < numRows; row++) {
        for (let col = 0; col < numCols; col++) {
          try {
            const cell = table.getCell(row, col);
            const textRange = cell.getText();
            if (textRange && textRange.asString().trim().length > 0) {
              updatedCount += processTextRange(textRange, config.levels, config.hanging);
            }
          } catch (e) {
            // Cell has no text, skip it
          }
        }
      }
    }
  });

  return updatedCount;
}

/**
 * Shows result dialogue
 */
function showResult(count, scope) {
  Logger.log(`Updated ${count} paragraph styles in ${scope}`);
  SlidesApp.getUi().alert(`Successfully normalised indents on ${count} paragraphs in ${scope}`);
}

/**
 * Processes a text range and updates paragraph indenting
 */
function processTextRange(textRange, indentLevels, hangingIndent) {
  let count = 0;
  const CM_TO_PT = 28.3465;

  // Default Google Slides indent levels in points
  const DEFAULT_LEVELS = [
    0.64 * CM_TO_PT,
    1.91 * CM_TO_PT,
    3.17 * CM_TO_PT,
    4.45 * CM_TO_PT,
    5.71 * CM_TO_PT
  ];

  const text = textRange.asString();
  const paragraphRanges = [];
  let start = 0;

  // Split text into paragraphs manually
  const lines = text.split('\n');

  for (let i = 0; i < lines.length; i++) {
    if (i < lines.length - 1 || lines[i].length > 0) {
      const length = lines[i].length + (i < lines.length - 1 ? 1 : 0);

      if (length > 0) {
        const range = textRange.getRange(start, start + length);
        const style = range.getParagraphStyle();
        const currentIndent = style.getIndentStart();

        // Determine nesting level (0-4) by matching to closest default level
        let level = 0;

        if (currentIndent !== null && currentIndent > 0) {
          let minDiff = Math.abs(currentIndent - DEFAULT_LEVELS[0]);

          for (let j = 1; j < DEFAULT_LEVELS.length; j++) {
            const diff = Math.abs(currentIndent - DEFAULT_LEVELS[j]);
            if (diff < minDiff) {
              minDiff = diff;
              level = j;
            }
          }

          // If indent doesn't match defaults, calculate level from indent value
          if (minDiff > 5) {
            level = Math.min(
              Math.floor(currentIndent / (1.27 * CM_TO_PT)),
              indentLevels.length - 1
            );
          }
        }

        // Set the new indenting
        const indentStart = indentLevels[level];
        const indentFirstLine = indentStart - hangingIndent;

        style.setIndentStart(indentStart);
        style.setIndentFirstLine(indentFirstLine);

        count++;
      }

      start += length;
    }
  }

  return count;
}

/**
 * Adds menu items to Google Slides
 */
function onOpen() {
  SlidesApp.getUi()
    .createMenu('Formatting')
    .addItem('Normalise Indents - All Slides', 'normaliseAllSlides')
    .addItem('Normalise Indents - Current Slide', 'normaliseCurrentSlide')
    .addItem('Normalise Indents - Selection', 'normaliseSelection')
    .addToUi();
}
