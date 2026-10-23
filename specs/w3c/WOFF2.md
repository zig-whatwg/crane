
[![W3C](https://www.w3.org/StyleSheets/TR/2021/logos/W3C){height="48"
width="72"}](https://www.w3.org/)

# WOFF File Format 2.0

[W3C Recommendation](https://www.w3.org/standards/types#REC), 08 August
2024

More details about this document

This version:
: <https://www.w3.org/TR/2024/REC-WOFF2-20240808/>

Latest version:
: <https://www.w3.org/TR/WOFF2/>

Previous Version:
: <https://www.w3.org/TR/2022/REC-WOFF2-20220310/>

Latest editor\'s draft:
: <https://w3c.github.io/woff/woff2/>

History:
: <https://www.w3.org/standards/history/WOFF2>

Implementation Report:
: <https://www.w3.org/Fonts/WG/WOFF2/Implementation.html>
: <https://w3c.github.io/woff/woff2/ImpRpt/>

Editor:
: Vladimir Levantovsky (W3C Invited Experts)

Previous Editor:
: Raph Levien (Google)

Feedback:
: [WOFF & WOFF2 issues](https://github.com/w3c/woff/issues)

Errata:
: <https://www.w3.org/Fonts/REC-WOFF2-20240808-errata.html>

[Copyright](https://www.w3.org/policies/#copyright) © 2024 [World Wide
Web Consortium](https://www.w3.org/). [W3C]^®^
[liability](https://www.w3.org/policies/#Legal_Disclaimer),
[trademark](https://www.w3.org/policies/#W3C_Trademarks) and [permissive
document license](https://www.w3.org/copyright/software-license/) rules
apply.

------------------------------------------------------------------------

## Abstract

Based on experience with WOFF 1.0, which is widely deployed, this
specification was developed to provide improved compression and thus
lower use of network bandwidth, while still allowing fast decompression
even on mobile devices. This is achieved by combining a content-aware
preprocessing step and improved entropy coding, compared to the Flate
compression used in WOFF 1.0.

## Status of This Document

*This section describes the status of this document at the time of its
publication. A list of current W3C publications and the latest revision
of this technical report can be found in the [W3C technical reports
index](https://www.w3.org/TR/) at https://www.w3.org/TR/.*

W3C recommends the wide deployment of this specification as a standard
for the Web.

This document was published by the [Web Fonts Working
Group](https://www.w3.org/groups/wg/webfonts) as a Recommendation using
the [Recommendation
track](https://www.w3.org/policies/process/20231103/#recs-and-notes).

A W3C Recommendation is a specification that, after extensive
consensus-building, is endorsed by [W3C] and its Members, and has commitments
from Working Group members to [royalty-free
licensing](https://www.w3.org/policies/patent-policy/#sec-Requirements)
for implementations.

The WOFF 2.0 specification is implemented in all major browsers, and is
widely used on production websites. It supports the entirety of the
TrueType and OpenType specifications, including Variable fonts,
Chromatic fonts, and font Collections.

A complete [list of changes](#changes-since-2021) to this document since
the last publication is available.

Supporting material, including results of compression measurements, may
be found in the companion [WOFF 2.0 Evaluation
Report](https://www.w3.org/TR/WOFF20ER/). The Working Group has [created
tests](https://github.com/w3c/woff2-compiled-tests) for WOFF2
[encoders](/Fonts/WG/wiki/TestPlan20-AuthoringTool "TestPlan20-AuthoringTool"),
[decoders](/Fonts/WG/wiki/TestPlan20-Decoder "TestPlan20-Decoder"),
[browsers](/Fonts/WG/wiki/TestPlan20-UserAgent "TestPlan20-UserAgent"),
and for [the format
itself](/Fonts/WG/wiki/TestPlan20-Format "TestPlan20-Format") (a WOFF2
validator). The source to build these tests is [available on
GitHub](https://github.com/w3c/woff2-tests).

An [Implementation
Report](https://www.w3.org/Fonts/WG/WOFF2/Implementation.html) is
available. Note that, for OpenType Collections (previously, TrueType
Collections) while there are two tested implementations of encoding and
of decoding, no user agent is yet shown to *use* them after decoding.
Browser support for font collections is expected to improve, and once it
does WOFF 2.0 already has the needed support.

Please send comments about this document as [GitHub
issues](https://github.com/w3c/woff/issues).

This document was produced by a group operating under the [W3C Patent
Policy](https://www.w3.org/policies/patent-policy/). W3C maintains a
[public list of any patent
disclosures](https://www.w3.org/groups/wg/webfonts/ipr/){rel="disclosure"}
made in connection with the deliverables of the group; that page also
includes instructions for disclosing a patent. An individual who has
actual knowledge of a patent which the individual believes contains
[Essential
Claim(s)](https://www.w3.org/policies/patent-policy/#def-essential) must
disclose the information in accordance with [section 6 of the W3C Patent
Policy](https://www.w3.org/policies/patent-policy/#sec-Disclosure).

For the Brotli compression scheme used in WOFF 2.0, Google has made an
[Royalty Free licensing
commitment](https://www.w3.org/standards/licensing/#google-incs-additional-licensing-information-for-the-web-fonts-working-group-specifications)
for use in this specification.

For WOFF 2.0, Monotype Imaging has made a [Royalty Free licensing
commitment](https://www.w3.org/standards/licensing/#monotype-imaging-incs-additional-licensing-information-for-the-web-fonts-working-group-specification-woff-file-format-20)
for use in this specification.

This document is governed by the [03 November 2023 W3C Process
Document](https://www.w3.org/policies/process/20231103/).

## Table of Contents

1. [[1. ]Introduction](#Introduction)
 1. [[1.1. ]Notational Conventions](#Notation)
2. [[2. ]General Requirements](#General)
3. [[3. ]Overall file structure and basic data
 types](#FileStructure)
 1. [[3.1. ]Data types](#DataTypes)
 2. [[3.2. ]WOFF2 Header](#woff20Header)
4. [[4. ]Font directory](#font_directory)
 1. [[4.1. ]Table directory format](#table_dir_format)
 2. [[4.2. ]Collection directory
 format](#collection_dir_format)
5. [[5. ]Compressed data format](#table_format)
 1. [[5.1. ]Transformed glyf table
 format](#glyf_table_format)
 2. [[5.2. ]Decoding of variable-length X and Y
 coordinates](#triplet_decoding)
 3. [[5.3. ]Transformed loca table
 format](#loca_table_format)
 4. [[5.4. ]Transformed hmtx table
 format](#hmtx_table_format)
 5. [[5.5. ]Table order constraints](#table_order)
6. [[6. ]Extended Metadata Block](#Metadata)
7. [[7. ]Private Data Block](#Private)
8. [[A. ]Internet Media Type Registration](#IMT)
9. [[B. ]Changes](#changes)
10. [[C. ]Security and Privacy
 Considerations](#security-privacy-considerations)
11. [[D. ]References](#References)
 1. [[D.1 ]Normative References](#normative)
 2. [[D.2 ]Informative References](#informative)

## [1. ]Introduction

This document specifies the WOFF2 font packaging format. This format was
designed to provide a reasonably easy-to-implement compression of font
data with significantly better compression than previous techniques,
suitable for use with CSS [\@font-face] rules. The improvement in
compression rates, compared to previously developed WOFF 1.0 format
\[[WOFF1](#ref-woff10)\] are realized due to improved entropy coding and
font data preprocessing and optimization step that reduces built-in
redundancy of various font data structures. The details about WOFF 2.0
development history can be found in the WOFF 2.0 Evaluation Report
\[[WOFF2ER](#ref-woff20er)\].

### [1.1 ]Notational Conventions

The all-uppercase key words \"MUST\", \"MUST NOT\", \"REQUIRED\",
\"SHALL\", \"SHALL NOT\", \"SHOULD\", \"SHOULD NOT\", \"RECOMMENDED\",
\"MAY\", and \"OPTIONAL\" in this document are to be interpreted as
described in RFC 2119 \[[RFC2119](#ref-RFC-2119)\]. If these words occur
in lower- or mixed case, they should be interpreted in accordance with
their normal English meaning.

This document includes sections of text that are called out as \"Notes\"
and set off from the main text of the specification. These notes are
intended as informative explanations or clarifications, to serve as
hints or guides to implementers and users, but are not part of the
normative text.

This document also uses hexadecimal numerical notation \"0x\...\" to
define the constant binary values such as magic number or tag values,
bitfields / flags format and mask values used in pseudo-code bitwise
operators.

## [2. ]General Requirements

The primary purpose of the WOFF2 format is to efficiently package fonts
linked to Web documents by means of CSS [\@font-face] rules. User
agents supporting the WOFF2 file format for linked fonts must respect
the requirements of the CSS3 Fonts specification
(\[[CSS3-Fonts](#ref-CSS3-Fonts)\] [Section 4.1: The \@font-face
rule](https://www.w3.org/TR/css-fonts-3/#font-face-rule)). In
particular, [such linked fonts are only available to the documents that
reference them; they MUST NOT be made available to other applications or
documents on the user\'s system].

The input font file may contain a number of various font data tables
described in the clause 5 of the \[[OFF](#ref-OFF)\] specification. The
order of the tables in a font file may differ and, while the entries in
the table directory have to be sorted in ascending order by tags, the
actual tables can be presented in a font file in arbitrary order.

When WOFF2 file is decompressed, the decoder must sort the entries in
the table directory in ascending alphabetical order by table tags and
should arrange the table order in a font file according to the
Recommendations (subclause 8.1 \"Optimized table ordering\") of the
\[[OFF](#ref-OFF)\].

## [3. ]Overall file structure and basic data types

The structure of WOFF2 files is similar to that of SFNT and WOFF 1.0
font files, in that there is a header followed by a table directory,
followed by the data for those tables. The SFNT structure is described
fully in the TrueType \[[TrueType](#ref-TTF)\], OpenType
\[[OpenType](#ref-OTF)\], and ISO \"Open Font Format\"
\[[OFF](#ref-OFF)\] specifications. However, WOFF2 differs in some
important aspects from SFNT. Most notably, the data for the font tables
is compressed in a single data stream comprising all the font tables.
Similar to WOFF 1.0 format, the optional extended metadata and private
data blocks are each presented as separate blocks of data, and are
concatenated together into the WOFF 2.0 file. The compression algorithm
used for both the compressed font data stream and extended metadata
block is Brotli \[[Brotli](#ref-Brotli)\].

A complete WOFF2 file consists of several blocks of data: a 48-byte
header, immediately followed (in this order) by a variable-size Table
Directory, an optional Collection Directory (present only if the input
font file is a font collection), a compressed font data block, an
optional block of Extended Metadata, and an optional block of Private
Data. Except for padding with a maximum of three null bytes in places
where 4-byte alignment of a table length or block offset is specified,
[there MUST NOT be any extraneous data between the data blocks or WOFF2
header and table directory, or beyond the last such block or
table]. If such extraneous data is
present [ a conforming user agent MUST reject the file as
invalid]. The file [MUST also
be rejected as invalid if the offsets and lengths of any data blocks or
font tables indicate overlapping byte ranges of the file, or ranges that
would extend beyond the end of the file].

+----------------------------------------------------------------------+
| WOFF2 File |
+======================+===============================================+
| WOFF2Header  | File header with basic font type and version, |
| | along with offsets to metadata and private |
| | data blocks. |
+----------------------+-----------------------------------------------+
| TableDirectory  | Directory of font tables, containing size and |
| | other info.   |
+----------------------+-----------------------------------------------+
| CollectionDirectory  | An optional table containing the font |
| | fragment descriptions of font collection |
| | entries.   |
+----------------------+-----------------------------------------------+
| CompressedFontData  | Contents of font tables, compressed for |
| | storage in the WOFF2 file.   |
+----------------------+-----------------------------------------------+
| ExtendedMetadata  | An optional block of extended metadata, |
| | represented in XML format and compressed for |
| | storage in the WOFF2 file. |
+----------------------+-----------------------------------------------+
| PrivateData  | An optional block of private data for the |
| | font designer, foundry, or vendor to use.   |
+----------------------+-----------------------------------------------+

### [3.1. ]Data types

+----------------------------------------------------------------------+
| Data Types |
+==============+=======================================================+
| UInt8  | 8-bit unsigned integer.  |
+--------------+-------------------------------------------------------+
| Int16  | 16-bit signed integer in 2\'s complement format, |
| | stored big-endian.  |
+--------------+-------------------------------------------------------+
| UInt16  | 16-bit unsigned integer, stored big-endian.  |
+--------------+-------------------------------------------------------+
| UInt32  | 32-bit unsigned integer, stored big-endian.  |
+--------------+-------------------------------------------------------+
| 255UInt16  | Variable-length encoding of a 16-bit unsigned integer |
| | for optimized intermediate font data storage.  |
+--------------+-------------------------------------------------------+
| UIntBase128  | Variable-length encoding of 32-bit unsigned |
| | integers.  |
+--------------+-------------------------------------------------------+

#### 255UInt16 Data Type

255UInt16 is a variable-length encoding of an unsigned integer in the
range 0 to 65535 inclusive. This data type is intended to be used as
intermediate representation of various font values, which are typically
expressed as UInt16 but represent relatively small values. Depending on
the encoded value, the length of the data field may be one to three
bytes, where the value of the first byte either represents the small
value itself or is treated as a code that defines the format of the
additional byte(s). The \"C-like\" pseudo-code describing how to read
the 255UInt16 format is presented below:

``` def

 Read255UShort( data )
 {
 UInt8 code;
 UInt16 value, value2;

 const oneMoreByteCode1 = 255;
 const oneMoreByteCode2 = 254;
 const wordCode = 253;
 const lowestUCode = 253;

 code = data.getNextUInt8();
 if ( code == wordCode ) {
 /* Read two more bytes and concatenate them to form UInt16 value*/
 value = data.getNextUInt8();
 value <<= 8;
 value &= 0xff00;
 value2 = data.getNextUInt8();
 value |= value2 & 0x00ff;
 }
 else if ( code == oneMoreByteCode1 ) {
 value = data.getNextUInt8();
 value = (value + lowestUCode);
 }
 else if ( code == oneMoreByteCode2 ) {
 value = data.getNextUInt8();
 value = (value + lowestUCode*2);
 }
 else {
 value = code;
 }
 return value;
 }

```

Note that the encoding is not unique. For example, the value 506 can be
encoded as \[255, 253\], \[254, 0\], and \[253, 1, 250\]. An encoder may
produce any of these, and [ a decoder MUST accept them
all]. An encoder should
choose shorter encodings, and must be consistent in choice of encoding
for the same value, as this will tend to compress better.

#### UIntBase128 Data Type

UIntBase128 is a different variable length encoding of unsigned
integers, suitable for values up to 2^32^-1. A UIntBase128 encoded
number is a sequence of bytes for which the most significant bit is set
for all but the last byte, and clear for the last byte. The number
itself is base 128 encoded in the lower 7 bits of each byte. Thus, a
decoding procedure for a UIntBase128 is: start with value = 0. Consume a
byte, setting value = old value times 128 + (byte bitwise-and 127).
Repeat last step until the most significant bit of byte is false.

UIntBase128 encoding format allows a possibility of sub-optimal
encoding, where e.g. the same numerical value can be represented with
variable number of bytes (utilizing leading \'zeros\'). For example, the
value 63 could be encoded as either one byte 0x3F or two (or more)
bytes: \[0x80, 0x3f\]. An encoder must not allow this to happen and must
produce shortest possible encoding. A decoder [ MUST reject the font
file if it encounters a UintBase128-encoded value with leading zeros (a
value that starts with the byte 0x80), if UintBase128-encoded sequence
is longer than 5 bytes, or if a UintBase128-encoded value exceeds
2^32^-1]. The \"C-like\"
pseudo-code describing how to read the UIntBase128 format is presented
below:

``` def

 bool ReadUIntBase128( data, *result )
 {
 UInt32 accum = 0;

 for (i = 0; i < 5; i++) {
 UInt8 data_byte = data.getNextUInt8();

 // No leading 0's
 if (i == 0 && data_byte == 0x80) return false;

 // If any of top 7 bits are set then << 7 would overflow
 if (accum & 0xFE000000) return false;

 *accum = (accum << 7) | (data_byte & 0x7F);

 // Spin until most significant bit of data byte is false
 if ((data_byte & 0x80) == 0) {
 *result = accum;
 return true;
 }
 }
 // UIntBase128 sequence exceeds 5 bytes
 return false;
 }

```

### [3.2. ]WOFF2 Header

The WOFF 2.0 header includes an identifying signature and provides the
information about the compressed and uncompressed sizes of encapsulated
font data. It also indicates the specific kind of font data included in
the WOFF 2.0 file, font version number and provides offsets to
additional data blocks included in the file.

+----------------------------------------------------------------------+
| WOFF2 Header |
+========+=====================+=======================================+
| UInt32 | signature | 0x774F4632 [\'wOF2\'] |
+--------+---------------------+---------------------------------------+
| UInt32 | flavor | The \"sfnt version\" of the input |
| | | font. |
+--------+---------------------+---------------------------------------+
| UInt32 | length | Total size of the WOFF file. |
+--------+---------------------+---------------------------------------+
| UInt16 | numTables | Number of entries in directory of |
| | | font tables. |
+--------+---------------------+---------------------------------------+
| UInt16 | reserved | Reserved; set to 0. |
+--------+---------------------+---------------------------------------+
| UInt32 | totalSfntSize | Total size needed for the |
| | | uncompressed font data, including the |
| | | sfnt header,\ |
| | | directory, and font tables (including |
| | | padding). |
+--------+---------------------+---------------------------------------+
| UInt32 | totalCompressedSize | Total length of the compressed data |
| | | block. |
+--------+---------------------+---------------------------------------+
| UInt16 | majorVersion | Major version of the WOFF file. |
+--------+---------------------+---------------------------------------+
| UInt16 | minorVersion | Minor version of the WOFF file. |
+--------+---------------------+---------------------------------------+
| UInt32 | metaOffset | Offset to metadata block, from |
| | | beginning of WOFF file. |
+--------+---------------------+---------------------------------------+
| UInt32 | metaLength | Length of compressed metadata block. |
+--------+---------------------+---------------------------------------+
| UInt32 | metaOrigLength | Uncompressed size of metadata block. |
+--------+---------------------+---------------------------------------+
| UInt32 | privOffset | Offset to private data block, from |
| | | beginning of WOFF file. |
+--------+---------------------+---------------------------------------+
| UInt32 | privLength | Length of private data block. |
+--------+---------------------+---------------------------------------+

The interpretation of the WOFF2 Header is the same as the WOFF Header in
\[[WOFF1](#ref-woff10)\], with the addition of one new
[totalCompressedSize] field. [The [signature] field in the
WOFF2 header MUST contain the value of 0x774F4632
(\'wOF2\')], which distinguishes it
from WOFF 1.0 files. [If the field does not contain this value, user
agents MUST reject the file as invalid]. A valid WOFF 2.0 file [ MUST have the reserved field set
to \'zero\'], a decoder
[MUST NOT reject a downloaded font file if the reserved header value is
not zero]. User agents
[MUST NOT reject correctly decoded font file if the resulting font file
size doesn\'t match the [totalSfntSize ] value encoded as part of
the WOFF2 header].

The \"totalSfntSize\" value in the WOFF2 Header is intended to be used
for reference purposes only. It may represent the size of the
uncompressed input font file, but if the transformed \'glyf\' and
\'loca\' tables are present, the uncompressed size of the reconstructed
tables and the total decompressed font size may differ substantially
from the original total size specified in the WOFF2 Header.

## [4. ]Font directory

The font directory section consists of the table directory, containing a
single entry for each unique font table in the input font file, and may
also include an optional collection directory table, when the input font
file is a font collection.

### [4.1. ]Table directory format

The table directory is an array of WOFF2 table directory entries, as
defined below. The directory follows immediately after the WOFF2 file
header; therefore, there is no explicit offset in the header pointing to
this block. Its size is dependent on the exact content; thus, the best
strategy for decoding is to process the file as a stream, rather than
trying to access it randomly. Each table directory entry specifies the
original size of a single font data table and, for those tables where an
additional transform has been applied, the size of the transformed
table. Transformed tables are identified by their \'flags\' field that
combines known table tags (bits 0-5, see \"Known Table Tags\") and
transformation version number (bits 6 and 7, see the description below)
defining the applied transform. The combination of the table tag and the
transform version number defines the exact transform that was applied to
a table, currently defined transforms are specified in details in
[clause 5](#table_format) of this specification.

Contrary to the way how table directory entries are specified in the
original input font file (where table directory entries are sorted in
ascending alphabetical order), the WOFF2 table directory entries define
the physical order of tables in which they have been processed and
encoded as part of the compressed font data stream. It is a decoder
responsibility to sort and reorder the reconstructed table directory
when the font file is decompressed.

In order to simplify the font decoding process an encoder [ MUST reorder
the transformed tables so that the associated \'glyf\' and \'loca\'
tables are always present as a pair, with \'loca\' table following the
\'glyf\' table]. Please keep
in mind that the entry for transformed \'loca\' table is just a
placeholder indicating the size required to reconstruct the table while
consuming no bytes of the data stream. Therefore, the requirement for
the \'loca\' table entry to immediately follow the transformed \'glyf\'
table in the table directory makes it easier to implement the \'loca\'
table reconstruction step when the reverse transform (see [subclause
5.1](#glyf_table_format) for details) is being applied to the \'glyf\'
table. For more details on table order constraints see [subclause
5.5](#table_order).

The format of each individual table directory entry is as follows:

+--------------------------------------------------------------------+
| TableDirectoryEntry |
+=============+=================+====================================+
| UInt8 | flags | table type and flags |
+-------------+-----------------+------------------------------------+
| UInt32 | tag | 4-byte tag (optional) |
+-------------+-----------------+------------------------------------+
| UIntBase128 | origLength | length of original table |
+-------------+-----------------+------------------------------------+
| UIntBase128 | transformLength | transformed length (if applicable) |
+-------------+-----------------+------------------------------------+

The interpretation of the flags field is as follows. Bits \[0..5\]
contain an index to the \"known tag\" table, which represents tags
likely to appear in fonts. If the tag is not present in this table, then
the value of this bit field is 63. Bits 6 and 7 indicate the
preprocessing transformation version number (0-3) that was applied to
each table. For all tables in a font, except for \'glyf\' and \'loca\'
tables, transformation version 0 indicates the [null] transform
where the original table data is passed directly to the Brotli
compressor for inclusion in the compressed data stream. For \'glyf\' and
\'loca\' tables, transformation version 3 indicates the [null]
transform where the original table data was passed directly to the
Brotli compressor without applying any pre-processing defined in
[subclause 5.1](#glyf_table_format) and [subclause
5.3](#loca_table_format). The transformed table formats and their
associated transformation version numbers are described in details in
[clause 5](#table_format) of this specification.

If multiple transformation versions are defined for a given table, an
encoder should normally choose the transformation version that results
in the smallest transformed table length, unless the reduction is so
slight as to be insignificant.

Where more than one transformation version is defined for a given table
tag, an encoder may use any of the defined transformations that is
applicable to the input data; a decoder [MUST be prepared to accept any
of the defined transformations]. [ If a decoder encounters a table entry that specifies an
unknown transformation version number the entire font MUST be
rejected] as it
cannot be correctly decoded.

Whether a font table is encoded with a known table tag or explicitly
including the four-byte tag has no semantical significance; it is simply
a choice of encoding intended to improve compression efficiency.
Similarly, whether a particular four-byte tag is present or not in the
\"Known Table Tags\" table is not a normative statement about whether
such tags should be included in web fonts.The encoder [MUST use known
table flag when encoding an input font table with a tag that is listed
in the \"Known Table Tags\" table].

There is a predefined extension mechanism for any custom table tag that
is not included in the known tag list (or for any new standard tags that
may be defined in the future). If bits \[0..5\] of the flags byte have
the value 63 (0x3f), then following the flag byte is a 4-byte arbitrary
tag value. Otherwise, the tag field is omitted in the
TableDirectoryEntry structure, and is derived from bits \[0..5\] of the
flag byte from the fixed Known Table Tags table, given below. The
decoder [MAY accept a table entry defined using a custom table tag even
if the tag that follows is identified as one of the kown table
tags].

+-----------------------------------------------------------------------------+
| Known Table Tags |
+=======+=======+=======+=======+=======+=======+=======+=====================+
| Flag | Tag | Flag | Tag | Flag | Tag | Flag | Tag |
+-------+-------+-------+-------+-------+-------+-------+---------------------+
| 0 | cmap | 16 | EBLC | 32 | CBDT | 48 | gvar |
+-------+-------+-------+-------+-------+-------+-------+---------------------+
| 1 | head | 17 | gasp | 33 | CBLC | 49 | hsty |
+-------+-------+-------+-------+-------+-------+-------+---------------------+
| 2 | hhea | 18 | hdmx | 34 | COLR | 50 | just |
+-------+-------+-------+-------+-------+-------+-------+---------------------+
| 3 | hmtx | 19 | kern | 35 | CPAL | 51 | lcar |
+-------+-------+-------+-------+-------+-------+-------+---------------------+
| 4 | maxp | 20 | LTSH | 36 | SVG | 52 | mort |
+-------+-------+-------+-------+-------+-------+-------+---------------------+
| 5 | name | 21 | PCLT | 37 | sbix | 53 | morx |
+-------+-------+-------+-------+-------+-------+-------+---------------------+
| 6 | OS/2 | 22 | VDMX | 38 | acnt | 54 | opbd |
+-------+-------+-------+-------+-------+-------+-------+---------------------+
| 7 | post | 23 | vhea | 39 | avar | 55 | prop |
+-------+-------+-------+-------+-------+-------+-------+---------------------+
| 8 | cvt | 24 | vmtx | 40 | bdat | 56 | trak |
+-------+-------+-------+-------+-------+-------+-------+---------------------+
| 9 | fpgm | 25 | BASE | 41 | bloc | 57 | Zapf |
+-------+-------+-------+-------+-------+-------+-------+---------------------+
| 10 | glyf | 26 | GDEF | 42 | bsln | 58 | Silf |
+-------+-------+-------+-------+-------+-------+-------+---------------------+
| 11 | loca | 27 | GPOS | 43 | cvar | 59 | Glat |
+-------+-------+-------+-------+-------+-------+-------+---------------------+
| 12 | prep | 28 | GSUB | 44 | fdsc | 60 | Gloc |
+-------+-------+-------+-------+-------+-------+-------+---------------------+
| 13 | CFF | 29 | EBSC | 45 | feat | 61 | Feat |
+-------+-------+-------+-------+-------+-------+-------+---------------------+
| 14 | VORG | 30 | JSTF | 46 | fmtx | 62 | Sill |
+-------+-------+-------+-------+-------+-------+-------+---------------------+
| 15 | EBDT | 31 | MATH | 47 | fvar | 63 | arbitrary tag |
| | | | | | | | follows |
+-------+-------+-------+-------+-------+-------+-------+---------------------+

Please note that according to the [SFNT-based font format
specifications](#References) all table tags should consist of four
characters. Table tags with less than four letters, such as \'[cvt
]\' (tag value 0x63767420) are padded with trailing spaces.

Following the flags (and the optional tag field) are one or two length
values, each in UIntBase128 unsigned integer encoding. The origLength
field specifies the length of the table in an uncompressed version of
the font. For tables that are subjected to additional
[transformations](#table_format), [ the transformLength field that
specifies the length of the transformed version of the table MUST be
included].

The transformLength field is present in the table directory entry if,
and only if, the table has been processed by a non-null transform prior
to Brotli compression. For tables that are not transformed, no
transformLength field is present in the directory entry.

The field containing the transformed length provides information about
the transformed table size prior to it being compressed by
\[[Brotli](#ref-Brotli)\]. This field is optional and is present only
for certain tables (see below the description of the \"Compressed data
format\"). Please note that while the transformed length can be relied
upon to determined the decompressed table size, the original table
length of the transformed font table should be treated with caution.

The reconstruction process of transformed tables guarantees preserving
the functionality of the tables but may produce binary results that are
different from the original data. For example, \'glyf\' table records
may have outline point coordinates encoded using one- or two-byte
format, and the repetitive values can either be explicitly duplicated in
the coordinate stream or omitted (which would be indicated by the flags
byte of the control point). Therefore, various representations of glyph
outline points are possible that would produce identical rendering
results; however, the binary data of reconstructed glyph records may
differ significantly from the original data. See subclause 5.3.3 of the
ISO \"Open Font Format\" \[[OFF](#ref-OFF)\] specification for details.

For this reason, the value of the origLength field of transformed table
should be treated only as a reference and should not be relied upon in
making memory allocation decisions when the WOFF2 data is decoded.

### [4.2. ]Collection directory format

The collection directory is present only if the input font is a
collection; i.e. if the value of the [WOFF2 file header](#woff20Header)
\"flavor\" field is set to 0x74746366 (\'ttcf\'). If present, the
collection directory follows immediately after the table directory. The
collection directory consists of a CollectionHeader and one or more
CollectionFontEntry records.

If input font is a collection, the [table directory](#table_dir_format)
contains a single entry for each unique table in the entire collection,
regardless of whether a table is shared among different fonts in a
collection or not. Thus, the table directory for a font collection
compressed with WOFF2 comprises all tables from all fonts contained in
the font collection file.

The Collection directory starts with the Collection Header followed by
an array of Collection Font Entries.

+----------------------------------------------------------------------+
| CollectionHeader |
+===========+==========+===============================================+
| UInt32 | version | The Version of the TTC Header in the original |
| | | font. |
+-----------+----------+-----------------------------------------------+
| 255UInt16 | numFonts | The number of fonts in the collection. |
+-----------+----------+-----------------------------------------------+

Collection font entries specify each font in the collection (defined by
CollectionHeader \"numFonts\" field). The format of each individual
collection font entry is as follows:

+----------------------------------------------------------------------+
| CollectionFontEntry |
+===========+====================+=====================================+
| 255UInt16 | numTables | The number of tables in this font |
+-----------+--------------------+-------------------------------------+
| UInt32 | flavor | The \"sfnt version\" of the font |
+-----------+--------------------+-------------------------------------+
| 255UInt16 | index\[numTables\] | The index identifying an entry in |
| | | the Table Directory for each table |
| | | in this font (where the index of |
| | | the first Table Directory entry is |
| | | zero.) |
+-----------+--------------------+-------------------------------------+

A table whose offset is referred to by multiple Offset Tables in the
original collection is considered \"shared\". An encoder [ MUST emit a
single TableDirectoryEntry for each unique font table defined by its
offset], regardless
of whether that table is shared among multiple fonts in a collection or
not. I.e., if a collection contains multiple fonts with their
corresponding Table Records referencing shared font tables with the same
offsets, [ the table data in the WOFF2 compressed data stream MUST NOT
be duplicated].

If an input font file is a font collection that contains multiple unique
[glyf] and [loca] tables, the
[transformations](#glyf_table_format) described for the [glyf] and
[loca] tables [MUST be applied to each pair of the
tables].Sharing of
[glyf] and [loca] tables is allowed and encouraged (this is
one of the major benefits of a font collection); however, it is possible
that font collections may have two or more pairs of the [glyf] /
[loca] tables that may not be shared. When the tables are shared,
an encoder [MUST verify that both tables are shared and that both form
an associated pair (if more than one pair of [glyf] / [loca]
tables are present)] and
[MUST reject a collection containing fonts that share only one of either
[glyf] or [loca]] table.

An encoder, when processing a font collection, [ MUST preserve the same
order of the nested fonts as they are in the input font
collection] and [MUST
record the index of the matching TableDirectoryEntry into the
CollectionFontEntry for each
font].

A decoder [MUST restore the collection with the same number of fonts and
their corresponding Offset
Tables]. The
Offset Tables for each font that comprises the output font collection
file [ MUST have either the same [numTables] as the input
collection, or one less if DSIG was present in the original input Offset
Table. If the value of the version field for the TTC Header in the
CollectionHeader is set to \"2.0\", a decoder MUST either set the TTC
Header fields {ulDsigTag, ulDsigLength, ulDsigOffset} in the output
collection to [null] or convert the TTC header format to version 1
(0x00010000)].

A decoder, when processing a font collection, [ MUST recreate the same
order of the nested fonts as they were in the input
collection]. The tables
within each nested font can be reordered. When processing a font
collection with multiple pairs of \'glyf\'/\'loca\' tables present, a
decoder [ MUST check CollectionFontEntry indices to make sure that
referenced \'glyf\' and \'loca\' tables are paired with each other, and
MUST reject a font collection if a mismatch in table pairing is
found]. For more
details about table pairs see the [table directory](#table_dir_format)
format description. A conforming user agent [MUST be able to load and
use properly formatted font collection file generated by a WOFF2
decoder.]

## [5. ]Compressed data format

The CompressedFontData field in a WOFF2 file contains the concatenation
of data for each table in the font, in the order that entries appear in
the WOFF2 [table directory](#table_dir_format). [There MUST NOT be any
extraneous data between the table entries in the decompressed data
stream as defined by the table directory]. If such extraneous data is present [ a conforming user agent MUST
reject the file as invalid].
[The CompressedFontData stream MUST be compressed using the Brotli
compression algorithm
\[[Brotli](#ref-Brotli)\]]. If the decompression of the data block fails for any reason, the
WOFF2 file is invalid and [ MUST NOT be
loaded].

The process of decoding the table data in a WOFF2 font file can be
specified by decompressing the byte-level compression of the
CompressedFontData field, yielding a \"table data block\", then applying
additional decoding steps as described below. An actual implementation
is free to combine these steps or perform some of the steps in an
incremental or streaming fashion, but the results must be consistent
with the sequential process as specified here.

Certain tables (such as [glyf], [loca] and [hmtx] tables,
identified by their corresponding tags), are subject to additional
transforms. If a font table is not transformed, then the table data
appears in the compressed stream in literal form, and occupies
origLength bytes of the table data block. Whether or not the table is
transformed, and the version number of the applied transform is defined
by the two most significant flag bits (see [subclause
4.1](#table_dir_format) for details), and the table data must be
additionally processed by a transformation specified below. In this
case, the transformed table occupies transformLength bytes of the table
data block.

[The decompressed and reconstructed table data MUST be stored in the
format specified by the \[[OFF](#ref-OFF)\]
specification.] [Each
reconstructed table directory entry MUST contain a valid \'checkSum\'
value, the decoder MUST recalculate the checkSum value for each decoded
table.] Also, due to
modifying transforms applied to [glyf] and [loca] tables, [the
decoder MUST recalculate the [checkSumAdjustment] value of the
entire font and MUST store the updated value in the [head]
table.]

The known table flag values should not be relied upon in determining the
presence of transformed tables, it is feasible that e.g. the [glyf]
table can be represented in the table directory with either flag = 10
and no tag, or with flag = 63 and \'glyf\' tag that follows. The
combination of flags value that defines a transform version number and
the table tag should be used to determine the applied transform.

[The sum of the origLength (for non-transformed tables) and
transformLength (for transformed tables) fields in the table directory
MUST equal the size of the font data block after it has been
decompressed using
\[[Brotli](#ref-Brotli)\]].If the size of the decompressed font data block doesn\'t match the
sum of lengths defined in the table directory as described above, [ the
WOFF2 file MUST NOT be loaded].

According to the curent version of the WOFF2, a transform can be applied
to three types of tables: [glyf], representing outline data,
[loca], representing the offsets of the individual glyphs within a
[glyf] table, and [hmtx], representing glyph horizontal
metrics, if these tables are present in a font. An authoring tool can
use any applicable transforms taking into consideration additional
constraints specified in [subclause 5.3](#loca_table_format) and
[subclause 5.5](#table_order). The [glyf] table transformation is
specified in [subclause 5.1](#glyf_table_format), the [loca] table
transformation is specified in [subclause 5.3](#loca_table_format), and
the [hmtx] table transformation is specified in [subclause
5.4](#hmtx_table_format).

CFF table processing and de-subroutinization.

The majority of OpenType fonts with CFF outlines have CFF data
subroutinized for more compact data storage. The experiments conducted
as part of WOFF2 development and evaluation have shown that Brotli
compression technology works more efficiently and produces better
compression gains for WOFF2 fonts if the CFF outline data is
de-subroutinized prior to WOFF2 encoding - this will on average reduce
the compressed data size by 5-10%. However, the CFF de-subroutinization
will, at the same time, increase the output file size by \~10%.

Since the CFF pre-processing / de-subroutinization is considered an
external step that can be implemented prior to WOFF2 encoding, it is not
covered by this specification. Font producers have an opportunity to
optimize their production process to either reduce the compressed font
size for fastest webfont data transfer at the expense of increasing the
output CFF font size (which will also improve rendering performance) or
to keep subroutinized CFF data to minimize input/output font size.

The WOFF 2.0 transformations applied to certain tables are designed to
reduce and/or eliminate the built-in redundancies of the SFNT format and
restructure the font data stream for more efficient entropy encoding. As
a result, the reconstructed font data will retain the exact
functionality of the input font file, but due to certain possible
encoding variations (such as various levels of optimization of outline
point coordinates in the \'glyf\' table, and/or difference in offset
calculations of the \'loca\' table) different WOFF2 decoders may produce
an output file that will not be a bitwise match to the input font file.
The font tables of the input font file may also be subjected to
reordering operations, which may take place either as a part of the
encoding process or the tables can be reordered by a decoder to comply
with the recommended table order defined by the \[[OFF](#ref-OFF)\]
specification -- as a result, even if the content of the font data
tables is not affected, the table offsets may change. The differences in
binary font data (however minor, due to significant extent to decoder
optimizations and table reordering) between encoded and decoded font
data structures will invalidate the \'DSIG\' table, if one is present.
Therefore, the compliant WOFF2 encoder [MUST remove the DSIG table from
an input font data], prior to
applying transformations and entropy coding steps.

The WOFF 2.0 encoders [MUST also set bit 11 of the \'flags\' field of
the [head] table] (see
\[[OFF](#ref-OFF)\] specification) to indicate that a recreated font
file was subjected to lossless modifying transform.

### [5.1. ]Transformed [glyf] table format

The [glyf] table data can be presented in the WOFF2 file in one of
two formats defined by the transformation version number (encoded in the
table directory flag bits, see [subclause 4.1](#table_dir_format) for
details). The transformation version \"3\" defines a null transform
where the content of the [glyf] table is presented in its original,
unmodified format. The transformation version \"0\", specified below, is
optional and can be applied to eliminate certain redundancies in the
[glyf] table data.

The version \"0\" of the [glyf] table transformation (as defined by
the table directory flag bits, see [subclause 4.1](#table_dir_format)
for details) specified in this subclause is intended to reduce redundant
information and provide a more efficient encoding of the actual TrueType
outlines of glyphs. The modified transformation is based on a similar
transformation described in MicroType Express \[[MTX](#ref-mtx)\]
specification. The reference to MTX is informative; the details of the
modified transformation are stated below and this section is normative.

While [glyf] table transformation preserves the functionality and
fidelity of rendering for every glyph in a font, it will most likely
result in producing a new set of glyph records that will not be a binary
match to the original font. According to the encoding rules specified in
subclause 5.3.3 of \[[OFF](#ref-OFF)\], there may be multiple valid
reconstructions of a glyph record. It is possible that depending on the
context and on the level of optimizations being applied to reconstructed
[glyf] table data, the size of the reconstructed table may be
greater than, less than, or equal to the original size of the
[glyf] table of the input font compressed by WOFF2. Neither this
specification nor the \[[OFF](#ref-OFF)\] standard mandate specific
optimizations being applied on the font data; therefore, it is the
responsibility of WOFF2 decoder implementations to make sure that an
adequate amount of memory is allocated when glyph records are being
reconstructed from the WOFF2 file -- the original [glyf] table size
supplied as an origLength value for the transformed [glyf] table
can only be used as a reference point.

Regardless of the implementation details of the glyph record
reconstruction process and the level of optimizations applied to
reconstructed \'glyf\' table data [User Agents MUST NOT reject correctly
decoded font file if the size of the reconstructed \'glyf\' table
doesn\'t match the [origLength] value encoded as part of the
\'glyf\' table entry in WOFF2 Table
Directory].

For greater compression effectiveness, the [glyf] table is split
into several substreams, to group like data together. The transformed
table consists of a number of fields specifying the size of each of the
substreams, followed by the substreams in sequence. During the decoding
process the reverse transformation takes place, where data from various
separate substreams are recombined to create a complete glyph record for
each entry of the original [glyf] table.

+---------------------------------------------------------------------+
| Transformed [glyf] Table |
+=============+===========================+===========================+
| Data Type | Semantic | Description and value |
| | | type (if applicable) |
+-------------+---------------------------+---------------------------+
| UInt16 | reserved | 0x0000 |
+-------------+---------------------------+---------------------------+
| UInt16 | optionFlags | Bit 0: if set, indicates |
| | | the presence of the |
| | | overlapSimpleBitmap\[\] |
| | | bit array. Bits 1-15: |
| | | Reserved. |
+-------------+---------------------------+---------------------------+
| UInt16 | numGlyphs | Number of glyphs |
+-------------+---------------------------+---------------------------+
| UInt16 | indexFormat | Offset format for |
| | | [loca] table, should |
| | | be consistent with |
| | | [indexToLocFormat] |
| | | of the original |
| | | [head] table (see |
| | | \[[OFF](#ref-OFF)\] |
| | | specification) |
+-------------+---------------------------+---------------------------+
| UInt32 | nContourStreamSize | Size of nContour stream |
| | | in bytes |
+-------------+---------------------------+---------------------------+
| UInt32 | nPointsStreamSize | Size of nPoints stream in |
| | | bytes |
+-------------+---------------------------+---------------------------+
| UInt32 | flagStreamSize | Size of flag stream in |
| | | bytes |
+-------------+---------------------------+---------------------------+
| UInt32 | glyphStreamSize | Size of glyph stream in |
| | | bytes (a stream of |
| | | variable-length encoded |
| | | values, see description |
| | | below) |
+-------------+---------------------------+---------------------------+
| UInt32 | compositeStreamSize | Size of composite stream |
| | | in bytes (a stream of |
| | | variable-length encoded |
| | | values, see description |
| | | below) |
+-------------+---------------------------+---------------------------+
| UInt32 | bboxStreamSize | Size of bbox data in |
| | | bytes representing |
| | | combined length of |
| | | bboxBitmap (a packed bit |
| | | array) and bboxStream (a |
| | | stream of Int16 values) |
+-------------+---------------------------+---------------------------+
| UInt32 | instructionStreamSize | Size of instruction |
| | | stream (a stream of UInt8 |
| | | values) |
+-------------+---------------------------+---------------------------+
| Int16 | nContourStream\[\] | Stream of Int16 values |
| | | representing number of |
| | | contours for each glyph |
| | | record |
+-------------+---------------------------+---------------------------+
| 255UInt16 | nPointsStream\[\] | Stream of values |
| | | representing number of |
| | | outline points for each |
| | | contour in glyph records |
+-------------+---------------------------+---------------------------+
| UInt8 | flagStream\[\] | Stream of UInt8 values |
| | | representing flag values |
| | | for each outline point. |
+-------------+---------------------------+---------------------------+
| Vary | glyphStream\[\] | Stream of bytes |
| | | representing point |
| | | coordinate values using |
| | | variable length encoding |
| | | format (defined in |
| | | [subclause |
| | | 5.2](#triplet_decoding)) |
+-------------+---------------------------+---------------------------+
| Vary | compositeStream\[\] | Stream of bytes |
| | | representing component |
| | | flag values and |
| | | associated composite |
| | | glyph data |
+-------------+---------------------------+---------------------------+
| UInt8 | bboxBitmap\[\] | Bitmap (a numGlyphs-long |
| | | bit array) indicating |
| | | explicit bounding boxes |
+-------------+---------------------------+---------------------------+
| Int16 | bboxStream\[\] | Stream of Int16 values |
| | | representing glyph |
| | | bounding box data |
+-------------+---------------------------+---------------------------+
| UInt8 | instructionStream\[\] | Stream of UInt8 values |
| | | representing a set of |
| | | instructions for each |
| | | corresponding glyph |
+-------------+---------------------------+---------------------------+
| UInt8 | overlapSimpleBitmap\[\] | A numGlyphs-long bit |
| | | array that provides |
| | | values for the overlap |
| | | flag \[bit 6\] for each |
| | | simple glyph. (Flag |
| | | values for composite |
| | | glyphs are already |
| | | encoded as part of the |
| | | compositeStream\[\]). |
+-------------+---------------------------+---------------------------+

The format is best characterized by describing the decoding process,
especially indications of what are valid and invalid data. Note also
that this format specifies the decoded result at the semantic level, not
specific byte streams.

Included in the Transformed [glyf] Table is a [bboxBitmap]
indicating for each glyph whether it contains an explicitly encoded
bounding box, or whether the bounding box is to be inferred from the
coordinate values. The relevant computations to determine the bounding
box status must be performed by both an encoder and a decoder. For each
simple glyph, [ an encoder MUST calculate the the xMin, yMin, xMax and
yMax coordinate values using all outline points (both on- and off-curve
points) and compare the calculated values with the encoded bounding box
info for the glyph. If the glyph bounding box info matches the
calculated values, an encoder MUST omit the bounding box
info]. Otherwise, [if
the calculated bounding box values do not equal the glyph values encoded
in a font, an encoder MUST set the corresponding [bboxBitmap] flag
and record the original bounding box values in the
[bboxStream].]
For glyphs records that contain zero contours, [ an encoder MUST check
that the glyph bounding box values are all zeros and, if this condition
is not met, MUST reject an input font as
invalid.] For either an
empty glyph or a glyph with zero contours, [ an encoder MUST always
clear the corresponding [bboxBitmap]
flag.] For a composite glyph,
[ an encoder MUST always set the corresponding [bboxBitmap] flag
and record the original bounding box values in the
[bboxStream].]

[A decoder MUST perform similar calculations if the bounding box is to
be inferred. For a given glyph, when a corresponding bit in
[bboxBitmap] is not set, the xMin, yMin, xMax and yMax values MUST
be calculated at the time of decoding using all outline point
coordinates]. The total number
of bytes in [bboxBitmap] is equal to 4 \* floor((numGlyphs + 31) /
32). The bits are packed so that glyph number 0 corresponds to the most
significant bit of the first byte, glyph number 7 corresponds to the
least significant bit of the first byte, glyph number 8 corresponds to
the most significant bit of the second byte, and so on. A bit=1 value
indicates an explicitly set bounding box.

Upon reading the Transformed [glyf] Table, the decoding process
iterates one glyph at a time. For each glyph, it reads zero or more
bytes from each of the streams referenced in the Transformed [glyf]
Table. Also, at the point of reconstructing a glyph, a decoder needs to
store for each glyph the corresponding offset in the new reconstructed
glyph table, and this data will collectively become the contents of the
reconstructed [loca] table (see [subclause 5.3](#loca_table_format)
below for more information about the reconstruction of the [loca]
table).

#### Reconstruction of Glyph Records

The reconstruction process begins by performing the following step to
determine the encoded glyph type (simple, composite or empty glyph):

Read a Int16 from the nContour stream. Store this in the
numberOfContours field in the reconstructed TrueType glyph. The
interpretation of the field is the same as the TrueType spec; if it is
zero, the glyph is empty. If it is positive, the glyph is simple and the
value represents the number of contours in the outline. If the nContour
value is equal to -1 (0xffff), then the glyph is composite.

#### Decoding of Empty Glyphs

Reconstruction of an empty glyph (when nContour = 0) is a simple step
that involves incrementing the glyph record count and creating a new
entry in the [loca] table where [loca\[n\] = loca\[n-1\]]. If
the [bboxBitmap] flag indicates that the bounding box values are
explicitly encoded in the [bboxStream] the decoder [ MUST reject
WOFF2 file as invalid].

#### Decoding of Simple Glyphs

For a simple glyph (when nContour \> 0), the process continues as
follows:

1. Read numberOfContours 255UInt16 values from the nPoints stream. Each
 of these is the number of points of that contour. Convert this into
 the endPtsOfContours\[\] array by computing the cumulative sum, then
 subtracting one. For example, if the values in the stream are \[2,
 4\], then the endPtsOfContours array is \[1, 5\]. Also, the sum of
 all the values in the array is the total number of points in the
 glyph, nPoints. In the example given, the value of nPoints is 6.
2. Read nPoints UInt8 values from the flags stream. Each corresponds to
 one point in the reconstructed glyph outline. The interpretation of
 the flag byte is described in details in [subclause
 5.2](#triplet_decoding).
3. For each point (i.e. nPoints times), read a number of point
 coordinate bytes from the glyph stream. The number of point
 coordinate bytes is a function of the flag byte read in the previous
 step: for (flag \< 0x7f) in the range 0 to 83 inclusive, it is one
 byte. In the range 84 to 119 inclusive, it is two bytes. In the
 range 120 to 123 inclusive, it is three bytes, and in the range 124
 to 127 inclusive, it is four bytes. Decode these bytes according to
 the procedure specified in the [subclause 5.2](#triplet_decoding) to
 reconstruct delta-x and delta-y values of the glyph point
 coordinates. Store these delta-x and delta-y values in the
 reconstructed glyph using the standard TrueType glyph encoding
 \[[OFF](#ref-OFF)\] subclause 5.3.3.
4. Read one 255UInt16 value from the glyph stream, which is
 instructionLength, the number of instruction bytes.
5. Read instructionLength bytes from instructionStream, and store these
 in the reconstituted glyph as instructions.

The optionFlags field bit 0 indicates the presence of the additional
overlapSimpleBitmap\[\] bit array. All other bits are reserved and
should be cleared. If all simple glyphs of the input font have
OVERLAP_SIMPLE flags set to zero, [ the encoder MUST clear bit 0 of the
optionFlags field and omit the overlapSimpleBitmap\[\] bit
array]. If at least one of the simple
glyphs in the input font have the flags bit 6 set, [ the encoder must
set the optionFlags bit 0 to \"1\", and MUST create the additional
overlapSimpleBitmap\[\] bit array where the corresponding bits MUST be
set to the values of the flag bit 6 of each simple glyph in the input
font].

The decoder [ MUST check the optionFlags bit0
value] to determine whether
the additional overlapSimpleBitmap\[\] is included as part of the
transformed \'glyf\' table. If the additional overlapSimpleBitmap\[\]
bit array is not present, upon reconstruction of the simple glyphs flags
[ the decoder MUST set all OVERLAP_SIMPLE flag values to
zero]. If overlapSimpleBitmap\[\]
is included, the decoder [ MUST use overlapSimpleBitmap\[\] bit settings
to reconstruct OVERLAP_SIMPLE flag values, and set the corresponding
overlapSimpleBitmap\[\] bit value as flag bit 6 on the first flag byte
for each simple glyph of the output
font].

#### Decoding of Composite Glyphs

For a composite glyph (nContour == -1), the following steps take the
place of steps 1-5 above:

1a. Read a UInt16 from compositeStream. This is interpreted as a
component flag word as in the TrueType spec. Based on the flag values,
there are between 4 and 14 additional argument bytes, interpreted as
glyph index, arg1, arg2, and optional scale or affine matrix.

2a. Read the number of argument bytes as determined in step 1a from the
composite stream, and store these in the reconstructed glyph. If the
flag word read in step 1a has the FLAG_MORE_COMPONENTS bit (bit 5) set,
go back to step 1a.

3a. If any of the flag words had the FLAG_WE_HAVE_INSTRUCTIONS bit (bit
8) set, then read the instructions from the glyph and store them in the
reconstructed glyph, using the same process as described in steps 4 and
5 above.

#### Decoding of Bounding Boxes

For both simple and composite glyphs, if the corresponding bit in the
bounding box bit vector is set, then additionally read 4 Int16 values
from the bbox stream, representing xMin, yMin, xMax, and yMax,
respectively, and record these into the corresponding fields of the
reconstructed glyph. For simple glyphs, if the corresponding bit in the
bounding box bit vector is not set, then derive the bounding box by
computing the minimum and maximum x and y coordinates in the outline,
and storing that.

[ A composite glyph MUST have an explicitly supplied bounding
box]. The motivation is
that computing bounding boxes is more complicated, and would require
resolving references to component glyphs taking into account composite
glyph instructions and the specified scales of individual components,
which would conflict with a purely streaming implementation of font
decoding. [A decoder MUST check for presence of the bounding box info as
part of the composite glyph record and MUST NOT load a font file with
the composite bounding box data
missing].

### [5.2. ]Decoding of variable-length X and Y coordinates

[Simple glyph](#SimpleGlyph) data structure defines all contours that
comprise a glyph outline, which are presented by a sequence of on- and
off-curve coordinate points. These point coordinates are encoded as
delta values representing the incremental values between the previous
and current corresponding X and Y coordinates of a point, the first
point of each outline is relative to (0,0) point. To minimize the size
of the dataset of point coordinate values, each point is presented as a
(flag, xCoordinate, yCoordinate) triplet. The flag value is stored in a
separate data stream and the coordinate values are stored as part of the
glyph data stream using a variable-length encoding format consuming a
total of 2-5 bytes per point.

The most significant bit of a flag indicates whether the point is on- or
off-curve point (if the most significant bit is 0, then the point is
on-curve), the remaining seven bits of the flag determine the format of
X and Y coordinate values and specify 128 possible combinations of
indices that have been assigned taking into consideration typical
statistical distribution of data found in TrueType fonts. When X and Y
coordinate values are recorded using nibbles (either 4 bits per
coordinate or 12 bits per coordinate) the bits are packed in the byte
stream with most significant bit of X coordinate first, followed by the
value for Y coordinate (most significant bit first). As a result, the
size of the glyph dataset is significantly reduced, and the grouping of
the similar values (flags, coordinates) in separate and contiguous data
streams allows more efficient application of the entropy coding applied
as the second stage of encoding process.

Each of the 128 index values define the following properties and
specified in details in the table below:

- Byte count (total number of bytes used for this set of coordinate
 values including one byte for \'flag\' value).
- Number of bits used to represent X coordinate value (X bits).
- Number of bits used to represent Y coordinate value (Y bits).
- An additional incremental amount to be added to X bits value (delta
 X).
- An additional incremental amount to be added to Y bits value (delta
 Y).
- The sign of X coordinate value (X sign).
- The sign of Y coordinate value (Y sign).

Please note that "Byte Count" field reflects total size of the triplet
(flag, xCoordinate, yCoordinate), including 'flag' value that is encoded
in a separate stream.

+----------------------------------------------------------------------------+
| Triplet Encoding |
+=======+============+========+========+=========+=========+========+========+
| Index | Byte Count | X bits | Y bits | Delta X | Delta Y | X sign | Y sign |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 0 | 2 | 0 | 8 | N/A | 0 | N/A | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 1 | | | | | 0 | | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 2 | | | | | 256 | | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 3 | | | | | 256 | | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 4 | | | | | 512 | | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 5 | | | | | 512 | | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 6 | | | | | 768 | | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 7 | | | | | 768 | | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 8 | | | | | 1024 | | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 9 | | | | | 1024 | | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 10 | 2 | 8 | 0 | 0 | N/A | \- | N/A |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 11 | | | | 0 | | \+ | |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 12 | | | | 256 | | \- | |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 13 | | | | 256 | | \+ | |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 14 | | | | 512 | | \- | |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 15 | | | | 512 | | \+ | |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 16 | | | | 768 | | \- | |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 17 | | | | 768 | | \+ | |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 18 | | | | 1024 | | \- | |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 19 | | | | 1024 | | \+ | |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 20 | 2 | 4 | 4 | 1 | 1 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 21 | | | | | 1 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 22 | | | | | 1 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 23 | | | | | 1 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 24 | | | | | 17 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 25 | | | | | 17 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 26 | | | | | 17 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 27 | | | | | 17 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 28 | | | | | 33 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 29 | | | | | 33 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 30 | | | | | 33 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 31 | | | | | 33 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 32 | | | | | 49 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 33 | | | | | 49 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 34 | | | | | 49 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 35 | | | | | 49 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 36 | 2 | 4 | 4 | 17 | 1 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 37 | | | | | 1 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 38 | | | | | 1 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 39 | | | | | 1 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 40 | | | | | 17 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 41 | | | | | 17 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 42 | | | | | 17 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 43 | | | | | 17 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 44 | | | | | 33 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 45 | | | | | 33 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 46 | | | | | 33 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 47 | | | | | 33 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 48 | | | | | 49 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 49 | | | | | 49 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 50 | | | | | 49 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 51 | | | | | 49 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 52 | 2 | 4 | 4 | 33 | 1 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 53 | | | | | 1 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 54 | | | | | 1 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 55 | | | | | 1 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 56 | | | | | 17 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 57 | | | | | 17 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 58 | | | | | 17 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 59 | | | | | 17 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 60 | | | | | 33 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 61 | | | | | 33 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 62 | | | | | 33 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 63 | | | | | 33 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 64 | | | | | 49 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 65 | | | | | 49 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 66 | | | | | 49 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 67 | | | | | 49 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 68 | 2 | 4 | 4 | 49 | 1 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 69 | | | | | 1 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 70 | | | | | 1 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 71 | | | | | 1 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 72 | | | | | 17 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 73 | | | | | 17 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 74 | | | | | 17 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 75 | | | | | 17 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 76 | | | | | 33 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 77 | | | | | 33 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 78 | | | | | 33 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 79 | | | | | 33 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 80 | | | | | 49 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 81 | | | | | 49 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 82 | | | | | 49 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 83 | | | | | 49 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 84 | 3 | 8 | 8 | 1 | 1 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 85 | | | | | 1 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 86 | | | | | 1 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 87 | | | | | 1 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 88 | | | | | 257 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 89 | | | | | 257 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 90 | | | | | 257 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 91 | | | | | 257 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 92 | | | | | 513 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 93 | | | | | 513 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 94 | | | | | 513 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 95 | | | | | 513 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 96 | 3 | 8 | 8 | 257 | 1 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 97 | | | | | 1 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 98 | | | | | 1 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 99 | | | | | 1 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 100 | | | | | 257 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 101 | | | | | 257 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 102 | | | | | 257 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 103 | | | | | 257 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 104 | | | | | 513 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 105 | | | | | 513 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 106 | | | | | 513 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 107 | | | | | 513 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 108 | 3 | 8 | 8 | 513 | 1 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 109 | | | | | 1 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 110 | | | | | 1 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 111 | | | | | 1 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 112 | | | | | 257 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 113 | | | | | 257 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 114 | | | | | 257 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 115 | | | | | 257 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 116 | | | | | 513 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 117 | | | | | 513 | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 118 | | | | | 513 | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 119 | | | | | 513 | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 120 | 4 | 12 | 12 | 0 | 0 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 121 | | | | | | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 122 | | | | | | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 123 | | | | | | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 124 | 5 | 16 | 16 | 0 | 0 | \- | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 125 | | | | | | \+ | \- |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 126 | | | | | | \- | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+
| 127 | | | | | | \+ | \+ |
+-------+------------+--------+--------+---------+---------+--------+--------+

For additional information and background on the triplet encoding please
see section 5.11 of the MTX proposal \[[MTX](#ref-mtx)\].

### [5.3. ]Transformed [loca] table format

The [loca] table data can be presented in the WOFF2 file in one of
two formats defined by the transformation version number (encoded in the
table directory flag bits, see [subclause 4.1](#table_dir_format) for
details). The transformation version \"3\" defines a null transform
where the content of the [loca] table is presented in its original,
unmodified format. The transformation version \"0\", although optional,
[MUST be applied to the [loca] table data whenever [glyf]
table data is transformed.] In other words, both [glyf] and [loca] tables
must either be present in their transformed format or with null
transform applied to both tables.

The version \"0\" of the [loca] table transformation (as defined by
the table directory flag bits, see [subclause 4.1](#table_dir_format)
for details) is specified below.

[ The transformLength of the transformed [loca] table MUST always
be zero]. [ The
origLength MUST be the appropriate size] (determined by numGlyphs+1, times the size per glyph,
where that size per glyph is two bytes when [indexFormat] (defined
in [subclause 5.1. Transformed glyf table format](#glyf_table_format))
is zero, otherwise four bytes). If the transformLength of the
transformed [loca] table is not equal to zero, or if the encoded
origLength does not match the calculated size defined above [the decoder
MUST reject the WOFF2 file as invalid].

[ The [loca] table MUST be reconstructed when the [glyf] table
is decoded]. The process for
reconstructing the [loca] table is specified in [subclause
5.1](#glyf_table_format) as part of the transformed [glyf] table
decoding process. For reconstructed glyph records, [ a decoder MUST
store the corresponding offsets for individual glyphs using a format
that is indicated by the [indexFormat] field of the Transformed
[glyf] Table].

### [5.4. ]Transformed [hmtx] table format

The [hmtx] table data can be presented in the WOFF2 file in one of
two formats defined by the transformation version number (encoded in the
table directory flag bits, see [subclause 4.1](#table_dir_format) for
details). The transformation version \"0\" defines a null transform
where the content of the [hmtx] table is presented in its original,
unmodified format. The transformation version \"1\", specified below, is
optional and can be applied to eliminate certain redundancies in the
[hmtx] table data.

The transformation version \"1\" exploits the built-in redundancy of the
TrueType glyphs where the outlines of the glyphs designed according to
the TrueType recommendations would likely have their left side bearing
values equal to xMin value of the glyph bounding box. The [hmtx]
table format is specified in subclause 5.2.4 of \[[OFF](#ref-OFF)\] and
includes two arrays of left side bearing information for proportional
and monospaced glyph runs. Each of these arrays can be eliminated from
the original input font data and reconstructed from the glyph bounding
box information if certain conditions are met.

+--------------------------------------------------------------------------------------------+
| Transformed [hmtx] table format |
+=========================+=========================+========================================+
| Data Type | Semantic | Description and value type (if |
| | | applicable) |
+-------------------------+-------------------------+----------------------------------------+
| UInt8 | Flags | Bitfield indicating the specific |
| | | details of the applied transform:\ |
| | | Bit 0 - when set, indicates that |
| | | lsb\[\] array is not present and needs |
| | | to be reconstructed from the xMin |
| | | values in the [glyf] table;\ |
| | | Bit 1 - when set, indicates that |
| | | leftSideBearing\[\] array is not |
| | | present and needs to be reconstructed |
| | | from the xMin values in the |
| | | [glyf] table.\ |
| | | When [hmtx] transform is |
| | | indicated by the table directory, the |
| | | [Flags (bits 0 or 1 or both) MUST be |
| | | set]. Bits 2-7 are reserved |
| | | and [MUST be |
| | | zero]. |
+-------------------------+-------------------------+----------------------------------------+
| UInt16 | advanceWidth\[\] | Stream of Uint16 values representing |
| | | the advanceWidth values of the |
| | | horizontal metrics array for |
| | | proportional glyphs. The stream size |
| | | is equal to [numOfHMetrics] |
| | | defined in the [hhea] table. |
+-------------------------+-------------------------+----------------------------------------+
| Int16 | lsb\[\] | Stream of Int16 values representing |
| | | the left side bearing values of the |
| | | horizontal metrics array for |
| | | proportional glyphs. The stream is |
| | | present only if the bit 0 of the |
| | | \"Flags\" field is not set, otherwise |
| | | this stream is missing. The stream |
| | | size is equal to [numOfHMetrics] |
| | | defined by the [hhea] table. |
+-------------------------+-------------------------+----------------------------------------+
| Int16 | leftSideBearing\[\] | Stream of Int16 values representing |
| | | the left side bearing values of the |
| | | horizontal metrics array for |
| | | monospaced glyphs. The stream is |
| | | present only if the bit 1 of the |
| | | \"Flags\" field is not set, otherwise |
| | | this stream is missing. The stream |
| | | size is equal to [(numGlyphs - |
| | | numOfHMetrics)]. |
+-------------------------+-------------------------+----------------------------------------+

The transformation version 1 described in this subclause is optional and
can only be used when an input font is TrueType-flavoured (i.e. has a
[glyf] table), and when the leftSideBearing values for each glyph
in the proportional or monospaced glyph runs encoded in the [hmtx]
table exactly match the corresponding xMin values in the [glyf]
table. A special case needs to be checked when an encoded
leftSideBearing value corresponds to an empty glyph, where [hmtx]
table transform can only be applied if leftSideBearing of an empty glyph
is set to zero.

If the [hmtx] table transform is both applicable and desired, the
encoder [ MUST check that leftSideBearing values match the xMin values
of the glyph bounding box for every glyph in a font (or check that
leftSideBearing == 0 for an empty glyph) and, for font collections, this
check MUST be performed on every corresponding pair of [glyf] and
[hmtx] tables]. If
the conditions are met for each of the proportional or monospaced glyph
runs [ the encoder MUST set [hmtx] transform version number to
\"1\", MUST eliminate the corresponding array from the [hmtx] table
and MUST set the appropriate Flags bits.] In font collections that have shared [hmtx] table,
[the match between xMin values of glyph bounding boxes and the
lsftSideBearing values MUST be checked for all combinations of shared
[hmtx] and various [glyf]
tables], and if there
is a mismatch [the [hmtx] table transform MUST NOT be
applied].

When the table directory flags indicate that the [hmtx] transform
is applied, the User Agent [MUST check the Flags values and MUST reject
the WOFF2 file if Flags are invalid]. The decoder [ MUST reconstruct the lsb\[\] and/or
leftSideBearing\[\] arrays from the xMin values provided by the glyph
bounding box information from the [glyf]
table].

### [5.5. ]Table order constraints

The following constraints on valid WOFF2 files are intended to
facilitate a memory-efficient WOFF 2.0 file transfer and decoding
process.

[ The [loca] table MUST follow the [glyf] table in the table
directory. When WOFF2 file contains individually encoded font file, the
table directory MAY contain other tables inserted between [glyf]
and [loca] tables; however when WOFF2 contains a font collection
file each [loca] table MUST immediately follow its corresponding
[glyf] table]. For example,
the following order of tables: [\'cmap\', \'glyf\', \'hhea\', \'hmtx\',
\'loca\', \'maxp\' \...] is acceptable for individually encoded
font files; however, font collection files must have [glyf / loca]
tables paired with each other, although they don\'t have to be ordered
as a contiguous block of tables, e.g.: [\'cmap\', \'glyf\', \'loca\',
\'hhea\', \'hmtx\', \'glyf\', \'loca\', \'maxp\', \'post\' \...]
would be acceptable. Additional constraints on the [loca] table are
given in [subclause 5.3](#loca_table_format).

## [6. ]Extended Metadata Block

[ The WOFF2 file MAY contain a block of extended
metadata]. The interpretation
of this block is exactly the same as \[[WOFF 1](#ref-woff10)\].

However, while in a WOFF 1 file the extended metadata block is stored
with zlib compression, [in a WOFF2 file the metadata MUST be stored
compressed with \[[Brotli](#ref-Brotli)\] as a separate stream, if
present.]. The
rationale of this change is to minimize the total number of byte-level
compression algorithms needed to implement WOFF2, and also because
Brotli is expected to achieve better compression ratios than zlib in
most cases.

[The metadata block MUST follow immediately after the compressed font
data stream]. The
beginning of the metadata block [MUST always be 4-byte aligned; when
extended metadata is present, the end of the compressed data block must
be padded with up to three null bytes if needed to reach a 4-byte
boundary]. [If the metadata
block is the last block in the WOFF file, there SHOULD be no additional
padding after the end of the block].

## [7. ]Private Data Block

[The WOFF2 file MAY include a block of arbitrary data], allowing font creators to include whatever information
they wish. [ The content of this data MUST NOT affect font usage or load
behavior of user agents]. User
agents should make no assumptions about the content of a private block;
it may (for example) contain ASCII or Unicode text, or some
vendor-defined binary data, and it may be compressed or encrypted, but
it has no publicly defined format. Conformant user agents will not
assume anything about the structure of this data. Only the font
developer or vendor responsible for the private block is expected to
understand its contents.

[The private data block, if present, MUST be the last block in the WOFF
file, following the compressed font data stream and the extended
metadata block, if one is present].
[The private data block MUST begin on a 4-byte boundary in the WOFF
file, with up to three null bytes inserted as padding after any
preceding block, if needed to ensure this]. [The end of the private data block MUST correspond to the
end of the WOFF2 file].

------------------------------------------------------------------------

## [A. ] Internet Media Type Registration

This appendix registers a new Internet Media type, under the [font]
top level type \[[RFC8081](#ref-RFC-8081)\]. This appendix is in
conformance with [BCP 13](http://www.ietf.org/rfc/rfc4288.txt) and
[W3CRegMedia](https://www.w3.org/2002/06/registering-mediatype.html).

WOFF 2.0

:

 Type name:

 : font

 Subtype name:

 : woff2

 Required parameters:

 : None.

 Optional parameters:

 : None.

 Encoding considerations:

 : Binary.

 Interoperability considerations:

 : WOFF 2.0 is an improvement on WOFF 1.0. The two formats have
 different Internet Media Types and may be used in parallel.

 Published specification:

 : This media type registration is extracted from the [WOFF 2.0
 specification](https://www.w3.org/TR/WOFF2/) at W3C.

 Applications that use this media type:

 : WOFF 2.0 is used by Web browsers, often in conjunction with HTML
 and CSS.

 Additional information:

 :

 Magic number(s):
 : The signature field in the WOFF header MUST contain the
 \"magic number\" 0x774F4632 (\'wOF2\')

 File extension(s):
 : woff2

 Macintosh file type code(s):
 : (no code specified)

 Macintosh Universal Type Identifier code:
 : [org.w3c.woff2]{style="font-family: monospace"}

 \@font-face Format:
 : woff2

 Fragment Identifiers
 : See Section 4.2 of \[[RFC8081](#ref-RFC-8081)\]

 Person & email address to contact for further information:

 : Chris Lilley (www-font@w3.org).

 Intended usage:

 : COMMON

 Restrictions on usage:

 : None

 Author:

 : The WOFF2 specification is a work product of the World Wide Web
 Consortium\'s WebFonts Working Group.

 Change controller:

 : The W3C has change control over this specification.

## [B. ]Changes

This appendix is *informative*.

### Changes since the [W3C Recommendation](https://www.w3.org/TR/2022/REC-WOFF2-20220310/) of 10 March 2022

- Previous [Proposed Correction
 1](https://www.w3.org/TR/2022/REC-WOFF2-20220310/#p1) has been made
 normative.
- Previous [Proposed Correction
 2](https://www.w3.org/TR/2022/REC-WOFF2-20220310/#p2) has been made
 normative.

### Changes since the [W3C Recommendation](https://www.w3.org/TR/2021/REC-WOFF2-20210706/) of 06 July 2021

- Previous Candidate Corrections 1, 3 5 and 6 were deemed editorial and
 have been merged
- Previous Candidate Correction 2, concerning the symple glyph overlap
 flag, is now [Proposed Correction
 1](https://www.w3.org/TR/2022/REC-WOFF2-20220310/#p1)
- Previous Candidate Correction 4, concerning polarity of on-curve flag
 bit, is now [Proposed Correction
 2](https://www.w3.org/TR/2022/REC-WOFF2-20220310/#p2)
- References updated to most current versions

### Changes since the [Recommendation](https://www.w3.org/TR/2018/REC-WOFF2-20180301/) of 01 March 2018

- Candidate Correction 1: [for a
 typo](https://www.w3.org/TR/2021/REC-WOFF2-20210706/#c1)
- Candidate Correction 2: [preserve optional symple glyph overlap
 flag](https://www.w3.org/TR/2021/REC-WOFF2-20210706/#c2)
- Candidate Correction 3: [definition of the UInt32 type was
 omitted](https://www.w3.org/TR/2021/REC-WOFF2-20210706/#c3)
- Candidate Correction 4: [polarity of on-curve flag
 bit](https://www.w3.org/TR/2021/REC-WOFF2-20210706/#c4)
- Candidate Correction 5: [typo in list
 numbering](https://www.w3.org/TR/2021/REC-WOFF2-20210706/#c5)
- (Editorial) updated IETF links

### Changes since the [Candidate Recommendation](https://www.w3.org/TR/2016/CR-WOFF2-20160315/) of 15 March 2016

- Updated the Brotli reference from an Internet Draft to Informational
 RFC.
- Updated the font top-level type reference from an internet Draft to
 Proposed Standard RFC.
- Mention of fragment identifiers updated to conform to RFC 8081 (the
 normative definition), resulting in a change to the Internet Media
 Type appendix and deletion of a requirement to maintain order in font
 collections.
- CSS Fonts 3 was used normatively (*must*), so moved from Informative
 to Normative references section.

### Changes since the [Working Draft](https://www.w3.org/TR/2015/WD-WOFF2-20150414/) of 14 April 2015

- Added a note describing the reasons for possible variations of
 reconstructed glyf table data and clarified that determining an
 adequate size of memory allocations for reconstructed glyf table data
 is a responsibility of WOFF2 decoder implementations.
- Added a note describing the optional pre-processing step that can be
 applied to OpenType CFF fonts, where the process of CFF data
 de-subroutinization can be applied prior to WOFF2 encoding to minimize
 the compressed font size.
- Removed the notion of \"nominal size\" for decompressed WOFF 2.0 font
 since the font size can vary dramatically based on applied data
 optimization steps, and removed conformance requirements associated
 with the decoder memory allocations and the original glyf table size
 definition.
- Added transformation version indication in Table directory flags and
 added new subclause 5.4 with the description of the \'hmtx\' table
 transform.
- Updated transformation version indication in Table directory flags
 adding null trnsform provisions for \'glyf\' and \'loca\' tables,
 added clarifications for transform of shared \'hmtx\' table.
- Added pseudo-code for UIntBase128 data type, various editorial
 updates.
- Updated the description of empty glyph reconstruction process in
 \'glyf\' table transform, added additional check in the \'hmtx\'
 transform for left side bearing value of an empty glyph, minor
 editorial updates.
- Added new confromance requirements for testing mismatch conditions
 where total font size and the original size of the \'glyf\' table
 differ from the sizes declared as part of the WOFF2 file header or
 table directory.
- Added Considerations for Security and Privacy appendix.
- Referenced new font/\* top level type being developed at IETF, trimmed
 Internet Media Type registration appendix to just WOFF 2.0.

### Changes since the [First Public Working Draft](https://www.w3.org/TR/2014/WD-WOFF2-20140508/) of May 8, 2014

- Clarified that the spec mandates table directory sorting, while the
 table order itself should follow the OpenType/OFF recommended order.
- Added requirements for decoders to accept any possible encoding
 variations for 255UInt16 data type, recommend that encoders produced
 shorter 255UInt16 byte sequences whenever possible.
- Replaced the table-based description of the 255UInt16 data type with
 pseudo-code.
- Added conformance requirements for UIntBase128 data type.
- Added conformance requirements to WOFF 2.0 Header description
 mandating the reserved value to be set to zero.
- Added recommendation and conformance requirement for WOFF 2.0 encoders
 to remove DSIG table and set the flag (bit 11) of the font \'head\'
 table.
- Added conformance requirement for decoders to store glyph record
 offsets in compliance with the specified indexFormat.
- Added conformance requirements to mandate implicit glyph bounding box
 calculations.
- Clarified the \"Transformed \'glyf\' table\" content adding explicit
 references to every data stream and their overall order.
- Modified the \"Transformed \'glyf\' table\" subclause adding detailed
 description of the glyph reconstruction process for empty, simple and
 composite glyphs.
- Added support for font collections in WOFF 2.0. As part of font
 collection support, added new requirement to encode \'glyf\' and
 \'loca\' tables as pairs, with \'loca\' immediately following the
 \'glyf\' table.
- Removed the conformance requirements for data type definitions and
 reclassified certain user agent requirements as decoder specific.
- Clarified the meaning of the uncompressed font data size.
- Clarified the differences in bounding box calculations for simple and
 composite glyphs.
- Added 4-byte alignment requirements for Extended Metadata and Private
 data blocks to match WOFF 1.0 Recommendation requirements.
- Added new appendix A with the draft text of top-level media type
 registration for a new \'font\' type.
- Added this \"Changes\" appendix.

## [C. ]Considerations for Security and Privacy

This appendix is *informative*.

The W3C TAG is developing a [Self-Review Questionnaire: Security and
Privacy](https://w3ctag.github.io/security-questionnaire/) for editors
of specifications to informatively answer.

Per the [Questions to
Consider](https://w3ctag.github.io/security-questionnaire/#questions)

1. Does this specification deal with personally-identifiable
 information?

 No.

2. Does this specification deal with high-value data?

 No. Credit card information and the like is not stored in WOFF2.

3. Does this specification introduce new state for an origin that
 persists across browsing sessions?

 No. Specifically, WOFF2 fonts are only available to the documents
 that reference them; they [do not
 persist](#conform-css3font-available) for use by other applications
 or documents on the user\'s system.

4. Does this specification expose persistent, cross-origin state to the
 web?

 No.

5. Does this specification expose any other data to an origin that it
 doesn't currently have access to?

 No.

6. Does this specification enable new script execution/loading
 mechanisms?

 No. WOFF2 fonts do not contain, or link to, scripts.

7. Does this specification allow an origin access to a user's location?

 No.

8. Does this specification allow an origin access to sensors on a
 user's device?

 No.

9. Does this specification allow an origin access to aspects of a
 user's local computing environment?

 No. WOFF2 fonts are typically generated and stored on a server, and
 have no access to the user environment when generated. Once
 decompressed, they contain no active code and cannot inspect the
 user environment.

10. Does this specification allow an origin access to other devices?

 No.

11. Does this specification allow an origin some measure of control over
 a user agent's native UI?

 No.

12. Does this specification expose temporary identifiers to the web?

 No.

13. Does this specification distinguish between behavior in first-party
 and third-party contexts?

 No.

14. How should this specification work in the context of a user agent's
 \"incognito\" mode?

 No differently.

15. Does this specification persist data to a user's local device?

 No.

16. Does this specification have a \"Security Considerations\" and
 \"Privacy Considerations\" section?

 Yes.

17. Does this specification allow downgrading default security
 characteristics?

 No.

The Security section of the [font] top level type
\[[RFC8081](#ref-RFC-8081)\] contains additional security-related
information relevant to WOFF2.

WOFF2 uses Brotli compression. The Security Considerations section of
the Brotli specification \[[Brotli](#ref-Brotli)\] should be consulted,
in addition to this appendix.

------------------------------------------------------------------------

## [D. ]References

### [D.1 ]Normative References

\[WOFF1\]
: [WOFF File Format
 1.0](https://www.w3.org/TR/2012/REC-WOFF-20121213/) Jonathan Kew,
 Tal Leming, Erik van Blokland, Editors. World Wide Web Consortium,
 13 December 2012. The latest version of the WOFF specification is
 available at
 [http://www.w3.org/TR/WOFF/](https://www.w3.org/TR/WOFF/)\

\[OFF\]
: [Open Font Format
 specification](https://standards.iso.org/ittf/PubliclyAvailableStandards/c074461_ISO_IEC_14496-22_2019.zip)
 (ISO/IEC 14496-22:2019). together with [Amendment 1: Color font
 technology and other
 updates](https://standards.iso.org/ittf/PubliclyAvailableStandards/c078865_ISO_IEC_14496-22_2019_Amd_1_2020(en).zip)

\[Brotli\]
: [Brotli Compressed Data Format, RFC
 7932](https://datatracker.ietf.org/doc/html/rfc7932) J. Alakuijala
 and Z. Szabadka, Editors. Internet Engineering Task Force,
 Informational, July 2016.

\[RFC2119\]
: [RFC 2119:](https://datatracker.ietf.org/doc/html/rfc2119) Key words
 for use in RFCs to Indicate Requirement Levels. S. Bradner, Editor.
 Internet Engineering Task Force, Best Current practice, March 1997.

\[RFC8081\]
: [The font Top Level Type, RFC
 8081](https://datatracker.ietf.org/doc/html/rfc8081) C. Lilley,
 (Editor). Internet Engineering Task Force, Proposed Standard,
 February 2017.

\[CSS3-Fonts\]
: [CSS Fonts Module Level 3](https://www.w3.org/TR/css-fonts-3/), John
 Daggett, Myles C. Maxfield, Chris Lilley (Editors). World Wide Web
 Consortium Recommendation, 2018. The latest version of CSS3 Fonts is
 available at
 [http://www.w3.org/TR/css-fonts-3/](https://www.w3.org/TR/css-fonts-3/)

### [D.2 ]Informative References

\[WOFF2ER\]
: [WOFF 2.0 Evaluation Report](https://www.w3.org/TR/WOFF20ER/) Chris
 Lilley, Editor. World Wide Web Consortium, 2015.\

\[OpenType\]
: [Microsoft OpenType
 specification](http://www.microsoft.com/typography/otspec/).
 OpenType is a registered trademark of Microsoft Corporation.

\[TrueType\]
: [Apple TrueType Reference
 manual](https://developer.apple.com/fonts/TrueType-Reference-Manual/).
 Apple, 2014. TrueType is a registered trademark of Apple, Inc.

\[MTX\]
: [MicroType® Express (MTX) Font
 Format](https://www.w3.org/submissions/2008/SUBM-MTX-20080305/)
 Sarah Martin, Al Ristow, Steve Martin, Vladimir Levantovsky, and
 Christopher Chapman. W3C Member Submission, 5 March 2008.

[[↑]](#title)
