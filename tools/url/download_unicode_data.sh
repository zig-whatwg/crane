#!/bin/bash
# Download Unicode 15.1.0 data files for IDNA/UTS46

set -e

UNICODE_VERSION="15.1.0"
DATA_DIR="data/unicode"

mkdir -p "$DATA_DIR"
cd "$DATA_DIR"

echo "Downloading Unicode $UNICODE_VERSION data files..."

# Core normalization data
echo "- UnicodeData.txt (1.8MB)"
curl -sL "https://www.unicode.org/Public/$UNICODE_VERSION/ucd/UnicodeData.txt" -o UnicodeData.txt

echo "- CompositionExclusions.txt"
curl -sL "https://www.unicode.org/Public/$UNICODE_VERSION/ucd/CompositionExclusions.txt" -o CompositionExclusions.txt

echo "- DerivedNormalizationProps.txt"
curl -sL "https://www.unicode.org/Public/$UNICODE_VERSION/ucd/DerivedNormalizationProps.txt" -o DerivedNormalizationProps.txt

# IDNA-specific data
echo "- IdnaMappingTable.txt"
curl -sL "https://www.unicode.org/Public/idna/$UNICODE_VERSION/IdnaMappingTable.txt" -o IdnaMappingTable.txt

# Bidi data
echo "- DerivedBidiClass.txt"
curl -sL "https://www.unicode.org/Public/$UNICODE_VERSION/ucd/extracted/DerivedBidiClass.txt" -o DerivedBidiClass.txt

echo ""
echo "✓ Downloaded all Unicode data files"
ls -lh
