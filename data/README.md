# Data Files

This directory contains data files used by WHATWG spec implementations.

## Structure

- **`encoding/indexes/`** - Encoding lookup tables
  - `index-ibm866.txt` - IBM866 encoding index reference

- **`url/idna/`** - IDNA Unicode data tables
  - (To be added: UnicodeData.txt, IdnaMappingTable.txt, etc.)

## Usage

### In Source Code

Data files can be embedded at compile-time using `@embedFile`:

```zig
// Example usage in encoding implementation
const index_data = @embedFile("../../data/encoding/indexes/index-ibm866.txt");
```

### In Build Tools

Data files are processed by tools in `tools/` to generate Zig lookup tables:

```bash
# Generate encoding indices (Python)
python tools/encoding/generate_encoding.py

# Generate IDNA tables (Zig)
zig build-exe tools/url/generate_idna_tables.zig
./generate_idna_tables

# Download Public Suffix List
bash tools/url/download_unicode_data.sh
```

## Updating Data

### Encoding Indices

Download from [Encoding Standard](https://encoding.spec.whatwg.org/):
- IBM866: https://encoding.spec.whatwg.org/index-ibm866.txt
- Big5: https://encoding.spec.whatwg.org/index-big5.txt
- GB18030: https://encoding.spec.whatwg.org/index-gb18030.txt
- JIS0208: https://encoding.spec.whatwg.org/index-jis0208.txt
- EUC-KR: https://encoding.spec.whatwg.org/index-euc-kr.txt

### IDNA Unicode Data

Download from [Unicode](https://unicode.org/):
- UnicodeData.txt: https://www.unicode.org/Public/UNIDATA/UnicodeData.txt
- IdnaMappingTable.txt: https://www.unicode.org/Public/idna/latest/IdnaMappingTable.txt
