#!/bin/bash

# Build script for "Mastering Motoko: The Definitive Guide to Decentralized Application Engineering on the Internet Computer"
# This script combines all chapters into a single markdown file

set -e

OUTPUT_FILE="mastering-motoko-complete.md"
TEMP_FILE="temp_book.md"

echo "Building 'Mastering Motoko!' book..."

# Remove existing output file
if [ -f "$OUTPUT_FILE" ]; then
    rm "$OUTPUT_FILE"
fi

# Create title page
cat > "$TEMP_FILE" << 'EOF'
# Mastering Motoko

**The Definitive Guide to Decentralized Application Engineering on the Internet Computer**

---

EOF

# Add table of contents
cat >> "$TEMP_FILE" << 'EOF'
## Table of Contents

- **Preface**
- **Foreword**
- **Chapter 1**: Introduction to the Internet Computer Protocol
- **Chapter 2**: Motoko Fundamentals
- **Chapter 3**: Type System and Safety
- **Chapter 4**: Motoko Memory Architecture
- **Chapter 5**: Identity and Access Control
- **Chapter 6**: Tokenomics and Ledger Integration
- **Chapter 7**: Autonomous Subscriptions via Timers
- **Chapter 8**: Asynchronous Safety and Reentrancy
- **Chapter 9**: External Integrations
- **Chapter 11**: Frontend Integration & Asset Storage
- **Chapter 12**: The Economics of Deployment
- **Chapter 13**: The Service Nervous System (SNS)
- **Chapter 14**: Troubleshooting and Best Practices
- **Resources**: Official Documentation and Links

---

EOF

# Function to add chapter with page break
add_chapter() {
    local file=$1
    local title=$2
    
    if [ -f "$file" ]; then
        echo "Adding $title..."
        echo "" >> "$TEMP_FILE"
        echo "---" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        cat "$file" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
    else
        echo "Warning: $file not found, skipping $title"
    fi
}

# Add all chapters in order
add_chapter "preface.md" "Preface"
add_chapter "foreword.md" "Foreword"
add_chapter "chapter-01.md" "Chapter 1"
add_chapter "chapter-02.md" "Chapter 2"
add_chapter "chapter-03.md" "Chapter 3"
add_chapter "chapter-04.md" "Chapter 4"
add_chapter "chapter-05.md" "Chapter 5"
add_chapter "chapter-06.md" "Chapter 6"
add_chapter "chapter-07.md" "Chapter 7"
add_chapter "chapter-08.md" "Chapter 8"
add_chapter "chapter-09.md" "Chapter 9"
add_chapter "chapter-10.md" "Chapter 10"
add_chapter "chapter-11.md" "Chapter 11"
add_chapter "chapter-12.md" "Chapter 12"
add_chapter "chapter-13.md" "Chapter 13"
add_chapter "chapter-14.md" "Chapter 14"
add_chapter "resources.md" "Resources"

# Add final footer
cat >> "$TEMP_FILE" << 'EOF'

---

## About This Book

This book was created to provide a comprehensive guide to motoko! smart contract development on ICP. It covers everything from basic concepts to advanced production patterns.

### Technical Specifications

- **dfx! Version**: 0.29.2
- **Target Environment**: WebAssembly (WASM)
- **Blockchain Framework**: Internet Computer Protocol (ICP)

### Contributing

This book is designed to be a living resource for the motoko! community. For updates, corrections, or contributions, please refer to the project repository: https://github.com/niklabh/motokobook.

### License

This work is intended for educational purposes and represents best practices as of the publication date. Smart contract development involves financial risks, and readers should conduct thorough testing and security audits before deploying contracts in production environments.

---

*End of Book*

EOF

# Move temp file to final output
mv "$TEMP_FILE" "$OUTPUT_FILE"

# Generate statistics
TOTAL_LINES=$(wc -l < "$OUTPUT_FILE")
TOTAL_WORDS=$(wc -w < "$OUTPUT_FILE")
TOTAL_CHARS=$(wc -c < "$OUTPUT_FILE")

echo ""
echo "✅ Book compilation complete!"
echo ""
echo "📊 Statistics:"
echo "   File: $OUTPUT_FILE"
echo "   Lines: $(printf "%'d" $TOTAL_LINES)"
echo "   Words: $(printf "%'d" $TOTAL_WORDS)"
echo "   Characters: $(printf "%'d" $TOTAL_CHARS)"
echo "   Size: $(du -h "$OUTPUT_FILE" | cut -f1)"
echo ""

# Check if pandoc is available for additional formats
if command -v pandoc &> /dev/null; then
    echo "📚 Generating additional formats..."
    
    # Generate PDF (requires LaTeX)
    if command -v pdflatex &> /dev/null; then
        echo "   Generating PDF..."
        pandoc "$OUTPUT_FILE" -o "mastering-motoko-complete.pdf" \
            --pdf-engine=pdflatex \
            --variable geometry:margin=1in \
            --variable fontsize=11pt \
            --variable documentclass=book \
            --toc \
            2>/dev/null && echo "   ✅ PDF generated: mastering-motoko-complete.pdf" || echo "   ❌ PDF generation failed"
    fi
    
    # Generate EPUB
    echo "   Generating EPUB..."
    pandoc "$OUTPUT_FILE" -o "mastering-motoko-complete.epub" \
        --toc \
        --metadata title="Mastering Motoko! The Definitive Guide to Decentralized Application Engineering on the Internet Computer" \
        --metadata author="Nikhil Ranjan" \
        2>/dev/null && echo "   ✅ EPUB generated: mastering-motoko-complete.epub" || echo "   ❌ EPUB generation failed"
    
    # Generate HTML
    echo "   Generating HTML..."
    pandoc "$OUTPUT_FILE" -o "mastering-motoko-complete.html" \
        --toc \
        --standalone \
        --css=style.css \
        --metadata title="Mastering Motoko!" \
        2>/dev/null && echo "   ✅ HTML generated: mastering-motoko-complete.html" || echo "   ❌ HTML generation failed"
    
else
    echo ""
    echo "💡 Install pandoc to generate additional formats (PDF, EPUB, HTML):"
    echo "   macOS: brew install pandoc"
    echo "   Ubuntu: sudo apt-get install pandoc"
    echo "   For PDF: also install texlive-latex-base texlive-latex-recommended"
fi

echo ""
echo "🎉 Build complete! The comprehensive motoko! guide is ready."
echo ""
echo "📖 To read the book:"
echo "   cat $OUTPUT_FILE"
echo "   # or open in your favorite markdown viewer"
echo ""
echo "🚀 Ready to start building production-ready smart contracts with motoko!"
