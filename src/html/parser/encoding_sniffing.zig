//! HTML §13.2.3 "The input byte stream": determining the character encoding
//! of a document's bytes and decoding them into the input stream.
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#determining-the-character-encoding
//!
//! - `sniff`: the encoding sniffing algorithm (§13.2.3.2) - BOM, the
//!   transport layer, the prescan, a same-origin parent's encoding, the
//!   default - with its confidence.
//! - `prescan`: "prescan a byte stream to determine its encoding" with "get an
//!   attribute" and "get an XML encoding".
//! - `extractFromMetaContent`: the algorithm for extracting a character
//!   encoding from a meta element (HTML §2.5.x, urls-and-fetching).
//! - `transportEncoding`: the charset parameter of a Content-Type, through the
//!   MIME Sniffing parser.
//! - `encodingToChangeTo`: §13.2.3.4 "change the encoding" steps 1-4; the
//!   parser driver runs steps 5-6, since only it holds the input stream.
//! - `decode`: Encoding "decode" to the UTF-8 the input stream holds.
//!
//! Crane has a response's whole body before parsing starts, so the
//! algorithm's "bytes available so far" are all of them, and the prescan's
//! end condition is the 1024 bytes the spec encourages.

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
    /// Step 5 runs: false for a text document, whose bytes are text, not
    /// markup to prescan ("loading a text document" leaves the conversion to
    /// the type's own rules: a BOM, its charset, the default).
    prescan: bool = true,
};

/// Step 9: the implementation-defined default - windows-1252, the table's
/// "all other locales" row (the locale Crane assumes is en).
/// encoding/sniffing.html pins it: "No (UTF-8) sniffing allowed".
pub const default_encoding: Encoding = &enc.WINDOWS_1252;

/// UTF-8, the encoding of a document nothing else set one for.
pub const utf_8: Encoding = &enc.UTF_8;

/// The prescan's end condition: "User agents are encouraged to only prescan
/// the first 1024 bytes."
pub const prescan_limit = 1024;

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

fn isUtf16(e: Encoding) bool {
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
    if (inputs.prescan) {
        if (prescan(bytes)) |found| return .{ .encoding = found, .confidence = .tentative };
    }
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
// Prescan a byte stream to determine its encoding
// =============================================================================

/// "Prescan a byte stream to determine its encoding", with the end condition
/// at `prescan_limit` bytes. Running out of bytes (or reaching the end
/// condition) aborts it with "get an XML encoding" of the same bytes.
pub fn prescan(bytes: []const u8) ?Encoding {
    const window = bytes[0..@min(bytes.len, prescan_limit)];
    return prescanWindow(window) catch getXmlEncoding(window);
}

const OutOfBytes = error{OutOfBytes};

fn at(bytes: []const u8, position: usize) OutOfBytes!u8 {
    if (position >= bytes.len) return error.OutOfBytes;
    return bytes[position];
}

fn isSpace(b: u8) bool {
    return b == 0x09 or b == 0x0A or b == 0x0C or b == 0x0D or b == 0x20;
}

fn isAsciiAlpha(b: u8) bool {
    return (b >= 'A' and b <= 'Z') or (b >= 'a' and b <= 'z');
}

fn startsWithAt(bytes: []const u8, position: usize, prefix: []const u8) bool {
    return position + prefix.len <= bytes.len and std.mem.eql(u8, bytes[position..][0..prefix.len], prefix);
}

fn prescanWindow(bytes: []const u8) OutOfBytes!?Encoding {
    // Step 1.
    var position: usize = 0;
    // Step 2: UTF-16 XML declarations.
    if (startsWithAt(bytes, 0, "\x3C\x00\x3F\x00\x78\x00")) return &enc.UTF_16LE;
    if (startsWithAt(bytes, 0, "\x00\x3C\x00\x3F\x00\x78")) return &enc.UTF_16BE;

    // Step 3: Loop. Running out of bytes here is the end of the loop.
    while (position < bytes.len) : (position += 1) { // Step 4: next byte.
        if (bytes[position] != '<') continue; // "Any other byte"

        if (startsWithAt(bytes, position, "<!--")) {
            // The first ">" preceded by two "-" after the "<"; the dashes
            // may be those of "<!--".
            const end = std.mem.indexOfPos(u8, bytes, position + 2, "-->") orelse return error.OutOfBytes;
            position = end + 2;
            continue;
        }

        switch (matchMeta(bytes, position)) {
            .yes => {
                if (try prescanMeta(bytes, &position)) |found| return found;
                continue;
            },
            // Whether this is the meta case depends on bytes not there.
            .need_more => return error.OutOfBytes,
            .no => {},
        }

        // "<", optionally "/", then an ASCII letter: a tag.
        const name_start = position + 1 + @as(usize, if (position + 1 < bytes.len and bytes[position + 1] == '/') 1 else 0);
        if (name_start < bytes.len and isAsciiAlpha(bytes[name_start])) {
            // 1. Advance to the next whitespace or ">" byte.
            position = name_start;
            while (true) {
                const b = try at(bytes, position);
                if (isSpace(b) or b == '>') break;
                position += 1;
            }
            // 2. Get attributes until none is found, then next byte.
            while (try getAttribute(bytes, &position)) |_| {}
            continue;
        }

        // "<!", "</", "<?": advance to the first ">" after the "<".
        if (position + 1 < bytes.len and (bytes[position + 1] == '!' or bytes[position + 1] == '/' or bytes[position + 1] == '?')) {
            position = std.mem.indexOfScalarPos(u8, bytes, position + 1, '>') orelse return error.OutOfBytes;
            continue;
        }
        // A "<" with nothing after it: out of bytes. Otherwise a "<" like
        // any other byte.
        if (position + 1 >= bytes.len) return error.OutOfBytes;
    }
    return error.OutOfBytes;
}

const Match = enum { yes, no, need_more };

/// Whether the bytes at `position` are "<meta" (ASCII case-insensitively)
/// followed by a space or slash.
fn matchMeta(bytes: []const u8, position: usize) Match {
    const pattern = "<meta";
    var i: usize = 0;
    while (i < pattern.len) : (i += 1) {
        if (position + i >= bytes.len) return .need_more;
        if (lower(bytes[position + i]) != pattern[i]) return .no;
    }
    if (position + pattern.len >= bytes.len) return .need_more;
    const after = bytes[position + pattern.len];
    return if (isSpace(after) or after == '/') .yes else .no;
}

/// The "<meta" branch of the prescan's loop, from `position.*` at the "<".
/// The encoding it returns, or null to go on at the next byte.
fn prescanMeta(bytes: []const u8, position: *usize) OutOfBytes!?Encoding {
    // 1. Advance to the space or slash after "<meta".
    position.* += 5;
    // 2-5. Of the attribute list, only whether it holds the three names
    // step 9 acts on matters: a repeat of any other name does nothing.
    var seen_http_equiv = false;
    var seen_content = false;
    var seen_charset = false;
    var got_pragma = false;
    var need_pragma: ?bool = null;
    var charset_set = false;
    var charset: ?Encoding = null; // null while set: failure

    // 6. Attributes.
    while (try getAttribute(bytes, position)) |attribute| {
        const name = attribute.name.slice();
        const value = attribute.value.slice();
        // 7-9. A name already in the list is skipped; otherwise it is added
        // and its step runs.
        if (std.mem.eql(u8, name, "http-equiv")) {
            if (seen_http_equiv) continue;
            seen_http_equiv = true;
            if (std.mem.eql(u8, value, "content-type")) got_pragma = true;
        } else if (std.mem.eql(u8, name, "content")) {
            if (seen_content) continue;
            seen_content = true;
            if (extractFromMetaContent(value)) |found| {
                if (!charset_set) {
                    charset_set = true;
                    charset = found;
                    need_pragma = true;
                }
            }
        } else if (std.mem.eql(u8, name, "charset")) {
            if (seen_charset) continue;
            seen_charset = true;
            charset_set = true;
            charset = lookup(value);
            need_pragma = false;
        }
        // 10. Back to attributes.
    }
    // 11. Processing.
    const need = need_pragma orelse return null;
    // 12.
    if (need and !got_pragma) return null;
    // 13.
    const found = charset orelse return null;
    // 14-16.
    if (isUtf16(found)) return &enc.UTF_8;
    if (found == &enc.X_USER_DEFINED) return &enc.WINDOWS_1252;
    return found;
}

/// "Get an attribute" collects the WHOLE lowercased value: content can have
/// a long MIME parameter before charset, and labels can have whitespace.
/// The caller bounds the whole prescan at 1024 bytes, not each attribute.
const SniffedString = struct {
    buf: [prescan_limit]u8 = undefined,
    len: usize = 0,
    overflow: bool = false,

    fn append(self: *SniffedString, b: u8) void {
        if (self.len < self.buf.len) {
            self.buf[self.len] = b;
            self.len += 1;
        } else self.overflow = true;
    }

    fn slice(self: *const SniffedString) []const u8 {
        // An overlong string must match nothing: give back a string no name
        // or label equals.
        if (self.overflow) return "\x00overflow";
        return self.buf[0..self.len];
    }
};

const Attribute = struct {
    name: SniffedString = .{},
    value: SniffedString = .{},
};

fn lower(b: u8) u8 {
    return if (b >= 'A' and b <= 'Z') b + 0x20 else b;
}

/// "Get an attribute" from `position.*`: the attribute, or null when there
/// is none (a ">" was reached; `position.*` stays on it).
fn getAttribute(bytes: []const u8, position: *usize) OutOfBytes!?Attribute {
    // 1. Skip whitespace and "/".
    while (true) {
        const b = try at(bytes, position.*);
        if (isSpace(b) or b == '/') position.* += 1 else break;
    }
    // 2. ">": there is none.
    if (try at(bytes, position.*) == '>') return null;
    // 3.
    var attribute = Attribute{};
    // 4-5. The name.
    while (true) {
        const b = try at(bytes, position.*);
        if (b == '=' and attribute.name.len > 0) {
            position.* += 1;
            return try attributeValue(bytes, position, &attribute);
        }
        if (isSpace(b)) break; // to "spaces"
        if (b == '/' or b == '>') return attribute;
        attribute.name.append(lower(b));
        position.* += 1;
    }
    // 6. Spaces.
    while (isSpace(try at(bytes, position.*))) position.* += 1;
    // 7.
    if (try at(bytes, position.*) != '=') return attribute;
    // 8.
    position.* += 1;
    return try attributeValue(bytes, position, &attribute);
}

/// "Get an attribute" steps 9-12, from `position.*` just past the "=".
fn attributeValue(bytes: []const u8, position: *usize, attribute: *Attribute) OutOfBytes!Attribute {
    // 9. Skip whitespace.
    while (isSpace(try at(bytes, position.*))) position.* += 1;
    // 10.
    const first = try at(bytes, position.*);
    if (first == '"' or first == '\'') {
        while (true) {
            position.* += 1;
            const b = try at(bytes, position.*);
            if (b == first) {
                position.* += 1;
                return attribute.*;
            }
            attribute.value.append(lower(b));
        }
    }
    if (first == '>') return attribute.*;
    attribute.value.append(lower(first));
    position.* += 1;
    // 11-12.
    while (true) {
        const b = try at(bytes, position.*);
        if (isSpace(b) or b == '>') return attribute.*;
        attribute.value.append(lower(b));
        position.* += 1;
    }
}

/// "Get an XML encoding" over `bytes`.
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
// Change the encoding
// =============================================================================

/// HTML §13.2.3.4 "change the encoding" steps 1-4, for a parser decoding
/// with `current` that met `requested` in a meta element: the encoding to
/// change to, or null when the confidence just becomes certain and nothing
/// changes. Steps 5-6 are the parser driver's.
pub fn encodingToChangeTo(current: Encoding, requested: Encoding) ?Encoding {
    // 1. Decoding UTF-16: the new encoding is ignored.
    if (isUtf16(current)) return null;
    var new = requested;
    // 2.
    if (isUtf16(new)) new = &enc.UTF_8;
    // 3.
    if (new == &enc.X_USER_DEFINED) new = &enc.WINDOWS_1252;
    // 4. Identical (every encoding is its own table here).
    if (new == current) return null;
    return new;
}

/// Whether `bytes` decode to themselves - the same Unicode interpretation -
/// in both `a` and `b`: true when they are ASCII other than ESC (which
/// ISO-2022-JP reads as an escape) and neither encoding is UTF-16 or
/// replacement. A conservative form of change the encoding step 5's "all the
/// bytes up to the last byte converted by the current decoder have the same
/// Unicode interpretations in both the current encoding and the new
/// encoding".
pub fn sameInterpretation(bytes: []const u8, a: Encoding, b: Encoding) bool {
    for ([_]Encoding{ a, b }) |e| {
        if (isUtf16(e) or e == &enc.REPLACEMENT) return false;
    }
    for (bytes) |byte| {
        if (byte >= 0x80 or byte == 0x1B) return false;
    }
    return true;
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

/// Decode `input` with `encoding`'s decoder, without BOM sniffing, errors as
/// U+FFFD. Owned by `allocator`.
pub fn decodeWith(allocator: std.mem.Allocator, input: []const u8, encoding: Encoding) ![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.ensureTotalCapacity(allocator, input.len + input.len / 2);

    var decoder = encoding.newDecoder();
    var units: [4096]u16 = undefined;
    // A high surrogate at the end of one chunk whose low half is in the next.
    var pending_high: ?u16 = null;
    var position: usize = 0;
    while (true) {
        const result = decoder.decode(input[position..], &units, true);
        position += result.bytes_consumed;
        try appendUtf16(allocator, &out, units[0..result.code_units_written], &pending_high);
        switch (result.status) {
            .input_empty => break,
            .output_full => continue,
            .malformed => {
                // "Replacement" error mode: U+FFFD, then carry on after the
                // error's bytes with a decoder in its initial state (the
                // decoders that report errors - UTF-8 and single-byte - hold
                // no state across one).
                try flushPending(allocator, &out, &pending_high);
                try out.appendSlice(allocator, "\u{FFFD}");
                const skip: usize = if (result.error_length > 0) result.error_length else 1;
                position = @min(position + skip, input.len);
                decoder = encoding.newDecoder();
                if (position >= input.len) {
                    // The end of the queue, to a fresh decoder, emits nothing.
                    break;
                }
            },
        }
    }
    try flushPending(allocator, &out, &pending_high);
    return out.toOwnedSlice(allocator);
}

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
