# Google Docs Codeblock Formatter

An Apps Script that automatically formats codeblocks in Google Docs to have compact spacing, removing the excess whitespace that Google Docs adds by default.

## Problem

When you paste markdown content into Google Docs, codeblocks (text between ` ``` ` markers) often get formatted with:
- Extra space before paragraphs
- Extra space after paragraphs
- 1.15x or 1.5x line spacing

This wastes a lot of vertical space in your document.

## Solution

This script finds all codeblocks in your document and applies compact formatting:
- **Single line spacing** (1.0)
- **No space before paragraph** (0pt)
- **No space after paragraph** (0pt)

## Installation

1. Open your Google Doc
2. Go to **Extensions** → **Apps Script**
3. Delete any default code in the editor
4. Copy and paste the entire contents of `format-codeblocks.js` into the editor
5. Click the **Save** icon (💾) and give your project a name (e.g., "Codeblock Formatter")
6. Close the Apps Script tab and **refresh your Google Doc**
7. You should now see a new menu called **"Codeblock Formatting"** in the menu bar

## Usage

### Format All Codeblocks

1. Click **Codeblock Formatting** → **Format All Codeblocks**
2. The script will find all text between ` ``` ` markers and apply compact formatting
3. A dialog will show how many paragraphs were formatted

### Format Selected Codeblocks (Alternative)

1. Select the text containing codeblocks you want to format
2. Click **Codeblock Formatting** → **Format Selected Codeblocks**
3. Currently this processes the whole document, but could be refined to only process selected codeblocks

## Codeblock Format

Codeblocks should be marked with ` ``` ` on separate lines, like this:

```
function example() {
  console.log("Hello world");
  return true;
}
```

The script will:
- Detect the opening ` ``` ` line
- Format all paragraphs until the closing ` ``` ` line
- Skip the delimiter lines themselves

## Notes

- The script only formats paragraphs between ` ``` ` markers
- Empty codeblocks or inline code (single backticks) are not affected
- You can run the script multiple times safely - it will just reapply the same formatting
- The script uses DocumentApp API and processes paragraphs sequentially

## Comparison with Google Slides Script

This script is similar in structure to the `google/slides/normalise-indentation.js` script:
- Both add menu items via `onOpen()`
- Both offer options to process entire document or selection
- Both iterate through document elements and apply formatting
- Uses DocumentApp instead of SlidesApp

## Troubleshooting

**"No codeblocks found"**: Make sure your codeblocks are marked with ` ``` ` on separate lines (not inline backticks)

**Menu doesn't appear**: Refresh the Google Doc page after installing the script

**Script doesn't work**: Check the Apps Script logs via Extensions → Apps Script → Execution log
