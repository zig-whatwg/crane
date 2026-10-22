//! Shared byte decoding and XHTML DTD names for XML documents and WPT metadata.
//! Engine-free: the document builder and the manifest reader must agree on
//! the characters in a response, without importing DOM into harness tests.
const std = @import("std");
const xml = @import("xml");
const sniffing = @import("html_encoding_sniffing");
const html_entities = @import("html_entities");
const bom = @import("encoding").bom;

pub const Decoded = struct {
    /// The document's characters, UTF-8, owned by the caller's allocator.
    text: []u8,
    /// The encoding they were decoded from: the document's encoding.
    encoding: sniffing.Encoding,
};

/// An XML document's bytes as characters. The encoding is, in the order
/// browsers take them (HTML §7.5.3 "the actual HTTP headers ... are the ones
/// that must be used when determining the character encoding according to
/// the rules given in the above specifications"; RFC 7303 §3; XML Appendix
/// F): a byte order mark; the transport's charset (`transport`); UTF-16
/// detected from "<?" with no mark; the XML declaration's encoding; else
/// UTF-8. Null where the declaration names an encoding there is none of -
/// libxml2's fatal "Unsupported encoding", a parse that fails.
pub fn decodeBytes(allocator: std.mem.Allocator, bytes: []const u8, transport: ?sniffing.Encoding) !?Decoded {
    const encoding = chooseEncoding(bytes, transport) orelse return null;
    return .{ .text = try sniffing.decode(allocator, bytes, encoding), .encoding = encoding };
}

/// XML 1.0 §4.3.3: malformed encoded input is fatal for document loading.
/// WebKit's XMLDocumentParser::doWrite checks decoder.sawError; Gecko's
/// nsScanner::Append uses DecodeToUTF16WithoutReplacement for XML. Keep
/// decodeBytes's replacement behavior for XMLHttpRequest document responses.
pub fn decodeDocumentBytes(allocator: std.mem.Allocator, bytes: []const u8, transport: ?sniffing.Encoding) !?Decoded {
    const encoding = chooseEncoding(bytes, transport) orelse return null;
    const input = if (bom.sniff(bytes)) |found| bytes[bom.length(found)..] else bytes;
    // Preserve the existing allocation and fast path for ordinary UTF-8.
    if (encoding == sniffing.utf_8) {
        if (!std.unicode.utf8ValidateSlice(input)) return null;
        return .{ .text = try allocator.dupe(u8, input), .encoding = encoding };
    }
    var decoder = encoding.newDecoder();
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    var buffer: [4096]u8 = undefined;
    var position: usize = 0;
    while (true) {
        // decodeToUtf8 exposes the decoder's fatal status; it never inserts
        // replacement characters. Its state carries partial output chunks.
        const result = decoder.decodeToUtf8(input[position..], &buffer, true);
        if (result.status == .malformed) return null;
        position += result.bytes_consumed;
        try output.appendSlice(allocator, buffer[0..result.bytes_written]);
        if (result.status == .input_empty) break;
    }
    return .{ .text = try output.toOwnedSlice(allocator), .encoding = encoding };
}

fn chooseEncoding(bytes: []const u8, transport: ?sniffing.Encoding) ?sniffing.Encoding {
    // Encoding's BOM sniff.
    if (std.mem.startsWith(u8, bytes, "\xEF\xBB\xBF")) return sniffing.utf_8;
    if (std.mem.startsWith(u8, bytes, "\xFE\xFF")) return sniffing.lookup("utf-16be").?;
    if (std.mem.startsWith(u8, bytes, "\xFF\xFE")) return sniffing.lookup("utf-16le").?;
    if (transport) |chosen| return chosen;
    // XML Appendix F.1: "<?" in UTF-16 with no byte order mark.
    if (std.mem.startsWith(u8, bytes, "\x3C\x00\x3F\x00")) return sniffing.lookup("utf-16le").?;
    if (std.mem.startsWith(u8, bytes, "\x00\x3C\x00\x3F")) return sniffing.lookup("utf-16be").?;
    const label = xml.declaredEncoding(bytes) orelse return sniffing.utf_8;
    const declared = sniffing.lookup(label) orelse return null;
    // A declaration read as ASCII is not in UTF-16, whatever it says (as
    // HTML's prescan treats one).
    if (declared == sniffing.lookup("utf-16le").? or declared == sniffing.lookup("utf-16be").?) return sniffing.utf_8;
    return declared;
}

/// HTML §14.2: the named character references the XHTML DTDs declare - the
/// HTML ones - for a document whose doctype names one of them.
pub fn htmlNamedReference(name: []const u8) ?[]const u21 {
    var buffer: [64]u8 = undefined;
    if (name.len + 1 > buffer.len) return null;
    @memcpy(buffer[0..name.len], name);
    buffer[name.len] = ';';
    const key = buffer[0 .. name.len + 1];
    const table = html_entities.entities;
    var low: usize = 0;
    var high: usize = table.len;
    while (low < high) {
        const mid = low + (high - low) / 2;
        switch (std.mem.order(u8, table[mid].name, key)) {
            .eq => return table[mid].codepoints,
            .lt => low = mid + 1,
            .gt => high = mid,
        }
    }
    return null;
}
