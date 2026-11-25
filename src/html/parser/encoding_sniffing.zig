//! HTML §13.2.3 "The input byte stream": determining the character encoding
//! of a document's bytes and decoding them into the input stream.
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#determining-the-character-encoding
//!
//! - `sniff`: the encoding sniffing algorithm (§13.2.3.2) - BOM, the
//!   transport layer, the prescan, a same-origin parent's encoding, the
//!   default - with its confidence.
//! - `MetaAttributes`: the prescan's steps for a meta element's attributes
//!   (the "<meta" branch, steps 6-16), `utf16XmlDeclaration` (the prescan's
//!   step 2) and `getXmlEncoding` ("get an XML encoding").
//! - `extractFromMetaContent`: the algorithm for extracting a character
//!   encoding from a meta element (HTML §2.5.x, urls-and-fetching).
//! - `transportEncoding`: the charset parameter of a Content-Type, through the
//!   MIME Sniffing parser.
//! - `decode`: Encoding "decode" to the UTF-8 the input stream holds.
//!
//! Browser deviation, stated (golden rule 2): the prescan's byte scan is the
//! one Chrome, Firefox and Safari share instead - a tokenizer-based scan for
//! meta elements while the head section lasts or until 1024 characters
//! (src/html/parser/meta_charset_scan.zig, in html_core, which holds the
//! tokenizer this module does not); its result reaches `sniff` as
//! `Inputs.prescanned`. While streaming, the navigation parser decodes and
//! parses chunks immediately once BOM and XML-declaration checks finish,
//! running the meta scan chunk by chunk ahead of decoding and switching the
//! decoder on the fly when a late `<meta charset>` arrives (Blink's
//! `TextResourceDecoder::Decode` + `Document::SetEncodingData`,
//! HTML §13.2.3.2 step 3 & §13.2.3.4 step 5). No meta past the scan window
//! changes the encoding: Blink and WebKit have no tree-builder reload path,
//! and html/syntax/charset/after-head-after-1kb.html is a mismatch in all
//! three (whatwg/html#6962, open, describes the shared behaviour).

const std = @import("std");
const encoding_mod = @import("encoding");
const mimesniff = @import("mimesniff");

const enc = encoding_mod.encoding;

/// An encoding, as the Encoding Standard's tables define them.
pub const Encoding = *const enc.Encoding;

/// HTML "confidence": tentative while a meta element may still change the
/// encoding; certain once nothing can. ("Irrelevant" is for documents not
/// decoded from bytes, which never reach this module.)
pub const Confidence = enum { tentative, certain };

pub const Result = struct {
    encoding: Encoding,
    confidence: Confidence,
};

/// Out-of-band inputs to the sniffing algorithm.
pub const Inputs = struct {
    /// Step 4: the encoding the transport layer specifies (a Content-Type
    /// charset that names a supported encoding; `transportEncoding`).
    transport: ?Encoding = null,
    /// Step 6: the container document's encoding, when the document is in a
    /// child navigable whose container document is same origin with it. The
    /// caller checks the origins; this step excludes UTF-16BE/LE.
    parent: ?Encoding = null,
    /// Step 5: what the prescan found - the browsers' meta scan
    /// (meta_charset_scan.zig), which the caller runs over the bytes - or
    /// null. Null too for a text document, whose bytes are text, not markup
    /// to prescan ("loading a text document" leaves the conversion to the
    /// type's own rules: a BOM, its charset, the default).
    prescanned: ?Encoding = null,
};

/// Step 9: the implementation-defined default - windows-1252, the table's
/// "all other locales" row (the locale Crane assumes is en).
/// encoding/sniffing.html pins it: "No (UTF-8) sniffing allowed".
pub const default_encoding: Encoding = &enc.WINDOWS_1252;

/// UTF-8, the encoding of a document nothing else set one for.
pub const utf_8: Encoding = &enc.UTF_8;

/// windows-1252, the encoding the meta scan reads the bytes with before any
/// is known (Blink's HTMLMetaCharsetParser decodes with Latin1Encoding(),
/// which is windows-1252): one character a byte.
pub const windows_1252: Encoding = &enc.WINDOWS_1252;

/// Encoding "get an encoding": the encoding `label` names, or null.
pub fn lookup(label: []const u8) ?Encoding {
    return encoding_mod.getEncoding(label);
}

/// The encoding's name as the Encoding Standard spells it - what
/// `document.characterSet` returns. (The tables' `name` fields are
/// lowercased for most encodings.)
pub fn canonicalName(e: Encoding) []const u8 {
    const names = .{
        .{ &enc.UTF_8, "UTF-8" },                   .{ &enc.IBM866, "IBM866" },
        .{ &enc.ISO_8859_2, "ISO-8859-2" },         .{ &enc.ISO_8859_3, "ISO-8859-3" },
        .{ &enc.ISO_8859_4, "ISO-8859-4" },         .{ &enc.ISO_8859_5, "ISO-8859-5" },
        .{ &enc.ISO_8859_6, "ISO-8859-6" },         .{ &enc.ISO_8859_7, "ISO-8859-7" },
        .{ &enc.ISO_8859_8, "ISO-8859-8" },         .{ &enc.ISO_8859_8_I, "ISO-8859-8-I" },
        .{ &enc.ISO_8859_10, "ISO-8859-10" },       .{ &enc.ISO_8859_13, "ISO-8859-13" },
        .{ &enc.ISO_8859_14, "ISO-8859-14" },       .{ &enc.ISO_8859_15, "ISO-8859-15" },
        .{ &enc.ISO_8859_16, "ISO-8859-16" },       .{ &enc.KOI8_R, "KOI8-R" },
        .{ &enc.KOI8_U, "KOI8-U" },                 .{ &enc.MACINTOSH, "macintosh" },
        .{ &enc.WINDOWS_874, "windows-874" },       .{ &enc.WINDOWS_1250, "windows-1250" },
        .{ &enc.WINDOWS_1251, "windows-1251" },     .{ &enc.WINDOWS_1252, "windows-1252" },
        .{ &enc.WINDOWS_1253, "windows-1253" },     .{ &enc.WINDOWS_1254, "windows-1254" },
        .{ &enc.WINDOWS_1255, "windows-1255" },     .{ &enc.WINDOWS_1256, "windows-1256" },
        .{ &enc.WINDOWS_1257, "windows-1257" },     .{ &enc.WINDOWS_1258, "windows-1258" },
        .{ &enc.X_MAC_CYRILLIC, "x-mac-cyrillic" }, .{ &enc.GBK, "GBK" },
        .{ &enc.GB18030, "gb18030" },               .{ &enc.BIG5, "Big5" },
        .{ &enc.EUC_JP, "EUC-JP" },                 .{ &enc.ISO_2022_JP, "ISO-2022-JP" },
        .{ &enc.SHIFT_JIS, "Shift_JIS" },           .{ &enc.EUC_KR, "EUC-KR" },
        .{ &enc.REPLACEMENT, "replacement" },       .{ &enc.UTF_16BE, "UTF-16BE" },
        .{ &enc.UTF_16LE, "UTF-16LE" },             .{ &enc.X_USER_DEFINED, "x-user-defined" },
    };
    inline for (names) |entry| {
        if (e == entry[0]) return entry[1];
    }
    return e.name;
}

pub fn isUtf16(e: Encoding) bool {
    return e == &enc.UTF_16BE or e == &enc.UTF_16LE;
}

// =============================================================================
// The encoding sniffing algorithm
// =============================================================================

/// HTML §13.2.3.2 "encoding sniffing algorithm" over `bytes`, all of the
/// document's bytes.
pub fn sniff(bytes: []const u8, inputs: Inputs) Result {
    // Step 1: BOM sniffing - certain.
    if (encoding_mod.bom.sniff(bytes)) |found| return .{
        .encoding = switch (found) {
            .utf8 => &enc.UTF_8,
            .utf16be => &enc.UTF_16BE,
            .utf16le => &enc.UTF_16LE,
        },
        .confidence = .certain,
    };
    // Step 2 (a user override) and step 3 (waiting for bytes) do not apply:
    // there is no user, and every byte is here.
    // Step 4: the transport layer's encoding - certain.
    if (inputs.transport) |transport| return .{ .encoding = transport, .confidence = .certain };
    // Step 5: the prescan - tentative.
    if (inputs.prescanned) |found| return .{ .encoding = found, .confidence = .tentative };
    // Step 6: a same-origin container document's encoding, unless UTF-16.
    if (inputs.parent) |parent| {
        if (!isUtf16(parent)) return .{ .encoding = parent, .confidence = .tentative };
    }
    // Steps 7-8 (history, autodetection) are optional; Crane does neither,
    // as the spec discourages autodetecting network resources.
    // Step 9: the default.
    return .{ .encoding = default_encoding, .confidence = .tentative };
}

/// The encoding the transport layer specifies: the charset parameter of the
/// MIME type `content_type` parses to (MIME Sniffing's parser, so quoting,
/// the first charset winning and a stray byte in another parameter are its
/// rules), when it names an encoding. Null otherwise.
pub fn transportEncoding(allocator: std.mem.Allocator, content_type: []const u8) ?Encoding {
    var mime = (mimesniff.parseMimeType(allocator, content_type) catch return null) orelse return null;
    defer mime.deinit();
    const charset = std.unicode.utf8ToUtf16LeStringLiteral("charset");
    for (mime.parameters.entries.items()) |entry| {
        if (!std.mem.eql(u16, entry.key, charset)) continue;
        // A label is ASCII; anything wider names no encoding.
        // Encoding "get an encoding", step 1, permits arbitrarily long
        // surrounding ASCII whitespace. Do not truncate the MIME parameter.
        const label = allocator.alloc(u8, entry.value.len) catch return null;
        defer allocator.free(label);
        for (entry.value, 0..) |unit, i| {
            if (unit > 0x7F) return null;
            label[i] = @intCast(unit);
        }
        return lookup(label);
    }
    return null;
}

// =============================================================================
// Prescan a byte stream to determine its encoding: the meta element's steps
// =============================================================================

/// The prescan's step 2: bytes that start like an XML declaration in UTF-16
/// ("<?x" in UTF-16LE or BE) are that encoding.
pub fn utf16XmlDeclaration(bytes: []const u8) ?Encoding {
    if (std.mem.startsWith(u8, bytes, "\x3C\x00\x3F\x00\x78\x00")) return &enc.UTF_16LE;
    if (std.mem.startsWith(u8, bytes, "\x00\x3C\x00\x3F\x00\x78")) return &enc.UTF_16BE;
    return null;
}

/// The prescan's "<meta" branch, steps 2-16, over one meta element's
/// attributes as `add` is given them in order: the encoding the element
/// declares, or null (the prescan then goes on to the next element).
///
/// The meta scan (meta_charset_scan.zig) hands over the tokenizer's
/// attributes - names lowercased, character references decoded, a repeated
/// name already dropped - where the spec's byte scan collected its own.
pub const MetaAttributes = struct {
    // 2-5. Of the attribute list, only whether it holds the three names
    // step 9 acts on matters: a repeat of any other name does nothing.
    seen_http_equiv: bool = false,
    seen_content: bool = false,
    seen_charset: bool = false,
    got_pragma: bool = false,
    need_pragma: ?bool = null,
    charset_set: bool = false,
    /// Null while set: failure.
    charset: ?Encoding = null,

    /// Steps 6-10 for the attribute `name` (lowercase) with `value`.
    pub fn add(self: *MetaAttributes, name: []const u8, value: []const u8) void {
        // 7-9. A name already in the list is skipped; otherwise it is added
        // and its step runs.
        if (std.mem.eql(u8, name, "http-equiv")) {
            if (self.seen_http_equiv) return;
            self.seen_http_equiv = true;
            if (std.ascii.eqlIgnoreCase(value, "content-type")) self.got_pragma = true;
        } else if (std.mem.eql(u8, name, "content")) {
            if (self.seen_content) return;
            self.seen_content = true;
            if (extractFromMetaContent(value)) |found| {
                if (!self.charset_set) {
                    self.charset_set = true;
                    self.charset = found;
                    self.need_pragma = true;
                }
            }
        } else if (std.mem.eql(u8, name, "charset")) {
            if (self.seen_charset) return;
            self.seen_charset = true;
            self.charset_set = true;
            self.charset = lookup(value);
            self.need_pragma = false;
        }
        // 10. Back to attributes.
    }

    /// Steps 11-16, once the attributes are done.
    pub fn encoding(self: *const MetaAttributes) ?Encoding {
        // 11. Processing.
        const need = self.need_pragma orelse return null;
        // 12.
        if (need and !self.got_pragma) return null;
        // 13.
        const found = self.charset orelse return null;
        // 14-16.
        if (isUtf16(found)) return &enc.UTF_8;
        if (found == &enc.X_USER_DEFINED) return &enc.WINDOWS_1252;
        return found;
    }
};

/// "Get an XML encoding" over `bytes`: every byte the caller has, not only
/// the prescan's first 1024 - Chrome, Firefox and Safari honour a
/// declaration whose ">" is the 1025th byte (html/syntax/xmldecl/xmldecl-2.html
/// kilobyte-plus-one-*.htm, wpt.fyi at 2358bd4835: all three pass; Blink's
/// TextResourceDecoder::CheckForXMLCharset waits for the ">" however far).
pub fn getXmlEncoding(bytes: []const u8) ?Encoding {
    // 1-2.
    if (!std.mem.startsWith(u8, bytes, "<?xml")) return null;
    // 3.
    const declaration_end = std.mem.indexOfScalar(u8, bytes, '>') orelse return null;
    // 4. (Within the declaration; a later "encoding" is not part of it.)
    var position = std.mem.indexOf(u8, bytes[0..declaration_end], "encoding") orelse return null;
    // 5.
    position += "encoding".len;
    // 6.
    while (position < bytes.len and bytes[position] <= 0x20) position += 1;
    // 7.
    if (position >= bytes.len or bytes[position] != '=') return null;
    // 8-9.
    position += 1;
    while (position < bytes.len and bytes[position] <= 0x20) position += 1;
    // 10-11.
    if (position >= bytes.len) return null;
    const quote = bytes[position];
    if (quote != '"' and quote != '\'') return null;
    // 12-13.
    position += 1;
    const end = std.mem.indexOfScalarPos(u8, bytes, position, quote) orelse return null;
    // 14-15.
    const potential = bytes[position..end];
    for (potential) |b| if (b <= 0x20) return null;
    // 16-18.
    const found = lookup(potential) orelse return null;
    return if (isUtf16(found)) &enc.UTF_8 else found;
}

// =============================================================================
// The algorithm for extracting a character encoding from a meta element
// =============================================================================

fn isAsciiWhitespace(c: u8) bool {
    return c == 0x09 or c == 0x0A or c == 0x0C or c == 0x0D or c == 0x20;
}

/// HTML "algorithm for extracting a character encoding from a meta element",
/// given the content attribute's value `s`.
///
/// Spec: https://html.spec.whatwg.org/multipage/urls-and-fetching.html#algorithm-for-extracting-a-character-encoding-from-a-meta-element
pub fn extractFromMetaContent(s: []const u8) ?Encoding {
    // 1.
    var position: usize = 0;
    while (true) {
        // 2. Loop: the next "charset", ASCII case-insensitively.
        const found = indexOfIgnoreCase(s, position, "charset") orelse return null;
        position = found + "charset".len;
        // 3.
        while (position < s.len and isAsciiWhitespace(s[position])) position += 1;
        // 4. Not "=": back to the loop, just before that character.
        if (position >= s.len or s[position] != '=') continue;
        // 5.
        position += 1;
        while (position < s.len and isAsciiWhitespace(s[position])) position += 1;
        // 6.
        if (position >= s.len) return null;
        const c = s[position];
        if (c == '"' or c == '\'') {
            const close = std.mem.indexOfScalarPos(u8, s, position + 1, c) orelse return null;
            return lookup(s[position + 1 .. close]);
        }
        var end = position;
        while (end < s.len and !isAsciiWhitespace(s[end]) and s[end] != ';') end += 1;
        return lookup(s[position..end]);
    }
}

fn indexOfIgnoreCase(haystack: []const u8, start: usize, needle: []const u8) ?usize {
    if (haystack.len < needle.len) return null;
    var i = start;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.ascii.eqlIgnoreCase(haystack[i..][0..needle.len], needle)) return i;
    }
    return null;
}

// =============================================================================
// Decode
// =============================================================================

/// Encoding "decode" of `bytes` with `encoding` as the fallback, to UTF-8
/// owned by `allocator`: a BOM decides the encoding and is removed; errors
/// become U+FFFD ("replacement" error mode).
///
/// Spec: https://encoding.spec.whatwg.org/#decode
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8, encoding: Encoding) ![]u8 {
    var chosen = encoding;
    var input = bytes;
    // 1-2. BOM sniffing.
    if (encoding_mod.bom.sniff(bytes)) |found| {
        chosen = switch (found) {
            .utf8 => &enc.UTF_8,
            .utf16be => &enc.UTF_16BE,
            .utf16le => &enc.UTF_16LE,
        };
        input = bytes[encoding_mod.bom.length(found)..];
    }
    // Valid UTF-8 decodes to itself.
    if (chosen == &enc.UTF_8 and std.unicode.utf8ValidateSlice(input)) return allocator.dupe(u8, input);
    return decodeWith(allocator, input, chosen);
}

/// Encoding "UTF-8 decode" of `bytes`, to UTF-8 owned by `allocator`: a
/// leading UTF-8 byte order mark is dropped, no other byte order mark or
/// label changes the encoding, errors become U+FFFD.
///
/// Spec: https://encoding.spec.whatwg.org/#utf-8-decode
pub fn utf8Decode(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    // 1-2. Peek three bytes; if they are 0xEF 0xBB 0xBF, read them.
    const input = if (std.mem.startsWith(u8, bytes, "\xEF\xBB\xBF")) bytes[3..] else bytes;
    // 3. Process the queue with an instance of UTF-8's decoder.
    if (std.unicode.utf8ValidateSlice(input)) return allocator.dupe(u8, input);
    return decodeWith(allocator, input, &enc.UTF_8);
}

/// The length of the byte order mark `bytes` start with, or 0.
pub fn bomLength(bytes: []const u8) usize {
    const found = encoding_mod.bom.sniff(bytes) orelse return 0;
    return encoding_mod.bom.length(found);
}

/// Whether `bytes` are a proper prefix of a byte order mark (UTF-8's, or
/// UTF-16BE's or LE's): the next byte decides whether there is one.
pub fn mayStartBom(bytes: []const u8) bool {
    const boms = [_][]const u8{ "\xEF\xBB\xBF", "\xFE\xFF", "\xFF\xFE" };
    for (boms) |bom| {
        if (bytes.len < bom.len and std.mem.startsWith(u8, bom, bytes)) return true;
    }
    return false;
}

/// Whether `bytes`, at the start of an HTML byte stream with no BOM and no
/// transport encoding, still need more bytes before XML-declaration sniffing
/// (`utf16XmlDeclaration` and `getXmlEncoding`) can conclude: a proper prefix
/// of UTF-16LE/BE `<?x` or ASCII `<?xml`, or an ASCII `<?xml` whose closing
/// `>` has not arrived yet (Blink's `TextResourceDecoder::CheckForXMLCharset`,
/// `third_party/blink/renderer/core/html/parser/text_resource_decoder.cc:259-295`).
pub fn mayStartXmlDeclaration(bytes: []const u8) bool {
    const prefixes = [_][]const u8{
        "\x3C\x00\x3F\x00\x78\x00",
        "\x00\x3C\x00\x3F\x00\x78",
        "<?xml",
    };
    for (prefixes) |prefix| {
        if (bytes.len < prefix.len and std.mem.startsWith(u8, prefix, bytes)) return true;
    }
    if (std.mem.startsWith(u8, bytes, "<?xml") and std.mem.indexOfScalar(u8, bytes, '>') == null) {
        return true;
    }
    return false;
}

/// Reverse a `windows-1252`-decoded UTF-8 string back to its original bytes
/// (0x00..0xFF), using the Encoding Standard's exact windows-1252 bijection.
/// Returns `null` if any code point is outside the windows-1252 image (e.g.
/// inserted by a character reference or script), matching the safety guard of
/// Blink's `Document::SetEncodingData` while preserving 0x80..0x9F losslessly.
pub fn windows1252Reverse(allocator: std.mem.Allocator, utf8_text: []const u8) !?[]u8 {
    if (!std.unicode.utf8ValidateSlice(utf8_text)) return null;
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.ensureTotalCapacity(allocator, utf8_text.len);
    var view = std.unicode.Utf8View.initUnchecked(utf8_text);
    var iter = view.iterator();
    while (iter.nextCodepoint()) |cp| {
        const b = windows1252Byte(cp) orelse {
            out.deinit(allocator);
            return null;
        };
        try out.append(allocator, b);
    }
    return try out.toOwnedSlice(allocator);
}

fn windows1252Byte(cp: u21) ?u8 {
    if (cp <= 0x7F or (cp >= 0xA0 and cp <= 0xFF)) return @intCast(cp);
    return switch (cp) {
        0x20AC => 0x80,
        0x0081 => 0x81,
        0x201A => 0x82,
        0x0192 => 0x83,
        0x201E => 0x84,
        0x2026 => 0x85,
        0x2020 => 0x86,
        0x2021 => 0x87,
        0x02C6 => 0x88,
        0x2030 => 0x89,
        0x0160 => 0x8A,
        0x2039 => 0x8B,
        0x0152 => 0x8C,
        0x008D => 0x8D,
        0x017D => 0x8E,
        0x008F => 0x8F,
        0x0090 => 0x90,
        0x2018 => 0x91,
        0x2019 => 0x92,
        0x201C => 0x93,
        0x201D => 0x94,
        0x2022 => 0x95,
        0x2013 => 0x96,
        0x2014 => 0x97,
        0x02DC => 0x98,
        0x2122 => 0x99,
        0x0161 => 0x9A,
        0x203A => 0x9B,
        0x0153 => 0x9C,
        0x009D => 0x9D,
        0x017E => 0x9E,
        0x0178 => 0x9F,
        else => null,
    };
}

/// Decode `input` with `encoding`'s decoder, without BOM sniffing, errors as
/// U+FFFD. Owned by `allocator`.
pub fn decodeWith(allocator: std.mem.Allocator, input: []const u8, encoding: Encoding) ![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.ensureTotalCapacity(allocator, input.len + input.len / 2);
    var stream = StreamDecoder.init(encoding);
    try stream.decodeInto(allocator, &out, input, true);
    return out.toOwnedSlice(allocator);
}

/// Encoding's "decode" of a byte stream that arrives in pieces - a
/// navigation's response body - with `encoding`'s decoder, without BOM
/// sniffing, errors as U+FFFD. A byte sequence, or a UTF-16 surrogate pair,
/// split between two pieces decodes as one: the decoder keeps what it has
/// not finished until the next piece (Encoding "decode" step 4's "I/O queue"
/// read as items arrive; Blink's TextResourceDecoder::Decode feeds its codec
/// each received chunk the same way, flushing at the end).
pub const StreamDecoder = struct {
    encoding: Encoding,
    decoder: enc.Decoder,
    /// A high surrogate at the end of one piece whose low half is in the next.
    pending_high: ?u16 = null,
    /// Whether the UTF-8 decoder has bytes of an unfinished sequence.
    partial: bool = false,

    pub fn init(encoding: Encoding) StreamDecoder {
        return .{ .encoding = encoding, .decoder = encoding.newDecoder() };
    }

    /// Decode `input`, the stream's next bytes, appending UTF-8 to `out`.
    /// `last`: the stream ends with them - an unfinished sequence is an
    /// error (U+FFFD) rather than kept for more.
    pub fn decodeInto(self: *StreamDecoder, allocator: std.mem.Allocator, out: *std.ArrayListUnmanaged(u8), input: []const u8, last: bool) !void {
        // Valid UTF-8, with nothing pending, decodes to itself.
        if (self.encoding == &enc.UTF_8 and !self.partial and self.pending_high == null and std.unicode.utf8ValidateSlice(input)) {
            try out.appendSlice(allocator, input);
            return;
        }
        var units: [4096]u16 = undefined;
        var position: usize = 0;
        while (true) {
            const result = self.decoder.decodeReplacement(input[position..], &units, last);
            position += result.bytes_consumed;
            try appendUtf16(allocator, out, units[0..result.code_units_written], &self.pending_high);
            switch (result.status) {
                .input_empty => break,
                .output_full => continue,
                // Replacement mode retains restored bytes and handler state.
                // A malformed result here is the shared loop's no-progress guard.
                .malformed => return error.DecodingError,
            }
        }
        // Without `last` the UTF-8 decoder may hold the start of a sequence,
        // which the shortcut above must not skip.
        self.partial = switch (self.decoder.state) {
            .utf8 => |state| state.bytes_needed != 0,
            else => false,
        };
        if (last) try flushPending(allocator, out, &self.pending_high);
    }
};

fn flushPending(allocator: std.mem.Allocator, out: *std.ArrayListUnmanaged(u8), pending_high: *?u16) !void {
    if (pending_high.*) |_| {
        try out.appendSlice(allocator, "\u{FFFD}");
        pending_high.* = null;
    }
}

/// Append UTF-16 `units` to `out` as UTF-8, joining surrogate pairs (also
/// across chunks) and writing a lone surrogate as U+FFFD.
fn appendUtf16(allocator: std.mem.Allocator, out: *std.ArrayListUnmanaged(u8), units: []const u16, pending_high: *?u16) !void {
    for (units) |unit| {
        var cp: u21 = unit;
        if (pending_high.*) |high| {
            pending_high.* = null;
            if (unit >= 0xDC00 and unit <= 0xDFFF) {
                cp = 0x10000 + ((@as(u21, high) - 0xD800) << 10) + (unit - 0xDC00);
            } else {
                try out.appendSlice(allocator, "\u{FFFD}");
            }
        }
        if (cp >= 0xD800 and cp <= 0xDBFF) {
            pending_high.* = unit;
            continue;
        }
        if (cp >= 0xDC00 and cp <= 0xDFFF) cp = 0xFFFD;
        var buf: [4]u8 = undefined;
        const n = std.unicode.utf8Encode(cp, &buf) catch unreachable;
        try out.appendSlice(allocator, buf[0..n]);
    }
}
