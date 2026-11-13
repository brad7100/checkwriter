#!/bin/bash

# Generate PDF comparison of before/after check printing

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HTML_FILE="$SCRIPT_DIR/test-check-comparison.html"
OUTPUT_PDF="$SCRIPT_DIR/check-print-comparison.pdf"

echo "Generating PDF comparison..."

# Use Chrome headless to generate PDF
/usr/local/bin/google-chrome \
  --headless \
  --disable-gpu \
  --print-to-pdf="$OUTPUT_PDF" \
  --no-margins \
  "file://$HTML_FILE"

if [ $? -eq 0 ]; then
    echo "✅ PDF generated successfully: $OUTPUT_PDF"
    echo "File size: $(du -h "$OUTPUT_PDF" | cut -f1)"
else
    echo "❌ Failed to generate PDF"
    exit 1
fi
