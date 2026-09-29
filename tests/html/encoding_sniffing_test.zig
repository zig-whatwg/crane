//! HTML §13.2.3.2 "determining the character encoding": the encoding sniffing
//! algorithm, the prescan of a byte stream, "get an XML encoding", the
//! algorithm for extracting a character encoding from a meta element, the
//! transport layer's charset, §13.2.3.4 "change the encoding" steps 1-4, and
//! the decode that feeds the input stream.
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#determining-the-character-encoding

const std = @import("std");
const testing = std.testing;
const sniffing = @import("html_core").parser.encoding_sniffing;

fn nameOf(result: ?sniffing.Encoding) []const u8 {
    return if (result) |e| sniffing.canonicalName(e) else "(failure)";
}

fn expectPrescan(bytes: []const u8, expected: ?[]const u8) !void {
    const got = sniffing.prescan(bytes);
    if (expected) |name| {
        testing.expectEqualStrings(name, nameOf(got)) catch |err| {
            std.debug.print("prescan of \"{s}\"\n", .{bytes});
            return err;
        };
    } else if (got) |e| {
        std.debug.print("prescan of \"{s}\" gave {s}, expected failure\n", .{ bytes, sniffing.canonicalName(e) });
        return error.TestExpectedFailure;
    }
}

// --- the prescan ---------------------------------------------------------

test "prescan: <meta charset>" {
    try expectPrescan("<meta charset=\"big5\">", "Big5");
    try expectPrescan("<!doctype html><html><head><meta charset=shift_jis>", "Shift_JIS");
    try expectPrescan("<META CHARSET='EUC-KR'>", "EUC-KR");
    try expectPrescan("<meta/charset=gbk>", "GBK");
}

test "prescan: http-equiv content-type needs the pragma" {
    try expectPrescan("<meta http-equiv=\"Content-Type\" content=\"text/html; charset=iso-8859-2\">", "ISO-8859-2");
    try expectPrescan("<meta content=\"text/html; charset=iso-8859-2\" http-equiv=content-type>", "ISO-8859-2");
    // Step 12: need pragma without got pragma.
    try expectPrescan("<meta content=\"text/html; charset=iso-8859-2\">", null);
    // http-equiv of another kind.
    try expectPrescan("<meta http-equiv=refresh content=\"charset=gbk\">", null);
}

test "prescan: charset wins over content, and a repeated attribute is skipped" {
    try expectPrescan("<meta charset=gbk content=\"charset=big5\" http-equiv=content-type>", "GBK");
    // Step 7: the second charset attribute is ignored.
    try expectPrescan("<meta charset=gbk charset=big5>", "GBK");
    // content first: charset replaces it and need pragma becomes false.
    try expectPrescan("<meta content=\"charset=big5\" charset=euc-jp>", "EUC-JP");
}

test "prescan: an unknown label is failure for that meta, and scanning goes on" {
    try expectPrescan("<meta charset=nonsense><meta charset=koi8-r>", "KOI8-R");
}

test "prescan: UTF-16 becomes UTF-8, x-user-defined becomes windows-1252" {
    try expectPrescan("<meta charset=utf-16le>", "UTF-8");
    try expectPrescan("<meta charset=utf-16>", "UTF-8");
    try expectPrescan("<meta charset=x-user-defined>", "windows-1252");
}

test "prescan: comments, other tags and markup declarations are skipped" {
    try expectPrescan("<!-- <meta charset=gbk> --><meta charset=big5>", "Big5");
    // "<!-->" ends at once: the two dashes may be those of "<!--".
    try expectPrescan("<!--><meta charset=big5>", "Big5");
    // Attributes of other tags are consumed, so a quoted ">" cannot end them.
    try expectPrescan("<div title=\"<meta charset=gbk>\"><meta charset=big5>", "Big5");
    try expectPrescan("<!doctype html><?pi x><meta charset=euc-kr>", "EUC-KR");
    try expectPrescan("</p><meta charset=euc-kr>", "EUC-KR");
    // "<meta" must be followed by a space or slash.
    try expectPrescan("<metax charset=gbk>", null);
}

test "prescan: attribute value syntax" {
    try expectPrescan("<meta charset = 'gbk'>", "GBK");
    try expectPrescan("<meta   charset\t=\n\"gbk\"  >", "GBK");
    // Unquoted values end at whitespace or ">".
    try expectPrescan("<meta charset=big5 foo>", "Big5");
}

test "prescan: stops at 1024 bytes, then tries an XML declaration" {
    var buf: [1100]u8 = undefined;
    @memset(&buf, ' ');
    const tail = "<meta charset=gbk>";
    @memcpy(buf[buf.len - tail.len ..], tail);
    try expectPrescan(&buf, null);
    // A meta that starts before 1024 and ends after it also runs out.
    var cut: [1024]u8 = undefined;
    @memset(&cut, ' ');
    @memcpy(cut[1024 - 10 ..], "<meta char");
    try expectPrescan(&cut, null);
}

test "get an XML encoding" {
    try expectPrescan("<?xml version=\"1.0\" encoding=\"windows-1251\"?>", "windows-1251");
    try expectPrescan("<?xml encoding = 'euc-jp' ?>", "EUC-JP");
    try expectPrescan("<?xml version=\"1.0\" encoding=\"utf-16\"?>", "UTF-8");
    // Not at the very start.
    try expectPrescan(" <?xml encoding=\"gbk\"?>", null);
    // A space inside the name.
    try expectPrescan("<?xml encoding=\"gb k\"?>", null);
}

test "prescan: UTF-16 XML declaration prefixes" {
    try expectPrescan("<\x00?\x00x\x00", "UTF-16LE");
    try expectPrescan("\x00<\x00?\x00x", "UTF-16BE");
}

// --- extracting a character encoding from a meta element -----------------

test "extract an encoding from a meta content value" {
    try testing.expectEqualStrings("GBK", nameOf(sniffing.extractFromMetaContent("text/html; charset=gbk")));
    try testing.expectEqualStrings("GBK", nameOf(sniffing.extractFromMetaContent("text/html;CHARSET = \"gbk\"")));
    try testing.expectEqualStrings("Big5", nameOf(sniffing.extractFromMetaContent("charset='big5'")));
    try testing.expectEqualStrings("Big5", nameOf(sniffing.extractFromMetaContent("charset=big5;x")));
    // "charset" not followed by "=": the loop goes on to the next one.
    try testing.expectEqualStrings("EUC-KR", nameOf(sniffing.extractFromMetaContent("charsetx charset=euc-kr")));
    // An unmatched quote returns nothing.
    try testing.expect(sniffing.extractFromMetaContent("charset=\"gbk") == null);
    try testing.expect(sniffing.extractFromMetaContent("text/html") == null);
    try testing.expect(sniffing.extractFromMetaContent("charset=") == null);
}

// --- the transport layer ---------------------------------------------------

test "the transport layer's charset comes from the MIME type's charset parameter" {
    const a = testing.allocator;
    try testing.expectEqualStrings("GBK", nameOf(sniffing.transportEncoding(a, "text/html;charset=gbk")));
    try testing.expectEqualStrings("GBK", nameOf(sniffing.transportEncoding(a, "text/html; charset=\"gbk\"")));
    // The first charset parameter wins.
    try testing.expectEqualStrings("GBK", nameOf(sniffing.transportEncoding(a, "text/html;charset=gbk;charset=windows-1255")));
    // A byte above 0x7F in another parameter does not stop the parse.
    try testing.expectEqualStrings("GBK", nameOf(sniffing.transportEncoding(a, "text/html;test=\xff;charset=gbk")));
    // Not a label, no parameter, not a MIME type.
    try testing.expect(sniffing.transportEncoding(a, "text/html;charset=gbk(") == null);
    try testing.expect(sniffing.transportEncoding(a, "text/html") == null);
    try testing.expect(sniffing.transportEncoding(a, "charset=gbk") == null);
}

// --- the encoding sniffing algorithm -------------------------------------

test "sniff: a BOM is certain and beats everything" {
    const r = sniffing.sniff("\xEF\xBB\xBF<meta charset=gbk>", .{ .transport = sniffing.lookup("big5") });
    try testing.expectEqualStrings("UTF-8", sniffing.canonicalName(r.encoding));
    try testing.expectEqual(sniffing.Confidence.certain, r.confidence);
    const le = sniffing.sniff("\xFF\xFEa\x00", .{});
    try testing.expectEqualStrings("UTF-16LE", sniffing.canonicalName(le.encoding));
}

test "sniff: the transport layer is certain and beats the prescan" {
    const r = sniffing.sniff("<meta charset=utf-8>", .{ .transport = sniffing.lookup("gbk") });
    try testing.expectEqualStrings("GBK", sniffing.canonicalName(r.encoding));
    try testing.expectEqual(sniffing.Confidence.certain, r.confidence);
}

test "sniff: the prescan is tentative, then the parent's, then the default" {
    const pre = sniffing.sniff("<meta charset=big5>", .{ .parent = sniffing.lookup("gbk") });
    try testing.expectEqualStrings("Big5", sniffing.canonicalName(pre.encoding));
    try testing.expectEqual(sniffing.Confidence.tentative, pre.confidence);

    const parent = sniffing.sniff("<p>x", .{ .parent = sniffing.lookup("gbk") });
    try testing.expectEqualStrings("GBK", sniffing.canonicalName(parent.encoding));
    try testing.expectEqual(sniffing.Confidence.tentative, parent.confidence);

    // Step 6 excludes a UTF-16 parent.
    const utf16_parent = sniffing.sniff("<p>x", .{ .parent = sniffing.lookup("utf-16le") });
    try testing.expectEqualStrings("windows-1252", sniffing.canonicalName(utf16_parent.encoding));

    // Step 9: windows-1252 - the table's "all other locales" row, and what
    // encoding/sniffing.html expects ("No (UTF-8) sniffing allowed").
    const default = sniffing.sniff("<p>\xC3\xA9", .{});
    try testing.expectEqualStrings("windows-1252", sniffing.canonicalName(default.encoding));
    try testing.expectEqual(sniffing.Confidence.tentative, default.confidence);
}

// --- change the encoding ---------------------------------------------------

test "change the encoding, steps 1-4" {
    const utf16 = sniffing.lookup("utf-16le").?;
    const gbk = sniffing.lookup("gbk").?;
    const w1252 = sniffing.lookup("windows-1252").?;
    // Step 1: already UTF-16 - ignored.
    try testing.expect(sniffing.encodingToChangeTo(utf16, gbk) == null);
    // Step 2: UTF-16 becomes UTF-8.
    try testing.expectEqualStrings("UTF-8", sniffing.canonicalName(sniffing.encodingToChangeTo(w1252, utf16).?));
    // Step 3: x-user-defined becomes windows-1252 - which is the current one.
    try testing.expect(sniffing.encodingToChangeTo(w1252, sniffing.lookup("x-user-defined").?) == null);
    // Step 4: identical.
    try testing.expect(sniffing.encodingToChangeTo(gbk, gbk) == null);
    try testing.expectEqualStrings("GBK", sniffing.canonicalName(sniffing.encodingToChangeTo(w1252, gbk).?));
}

// --- decoding ----------------------------------------------------------------

fn expectDecode(bytes: []const u8, label: []const u8, expected: []const u8) !void {
    const out = try sniffing.decode(testing.allocator, bytes, sniffing.lookup(label).?);
    defer testing.allocator.free(out);
    try testing.expectEqualStrings(expected, out);
}

test "decode: legacy encodings to UTF-8" {
    try expectDecode("\xA1\xB1", "big5", "\u{00A7}");
    try expectDecode("a\xE9b", "windows-1252", "a\u{00E9}b");
    try expectDecode("\x82\xA0", "shift_jis", "\u{3042}");
    // Big5 pointers above the BMP decode to a surrogate pair in UTF-16; the
    // UTF-8 must be the scalar value, not two encoded surrogates.
    try expectDecode("\x87\x40", "big5", "\u{43F0}");
    try expectDecode("\x88\x62", "big5", "\u{00CA}\u{0304}");
    try expectDecode("\x87\x45", "big5", "\u{27267}");
}

test "decode: errors become U+FFFD and decoding goes on" {
    // windows-1253 0xAA is unmapped.
    try expectDecode("a\xAAb\xAAc", "windows-1253", "a\u{FFFD}b\u{FFFD}c");
    // A lone UTF-8 lead byte, then ASCII: maximal subpart.
    try expectDecode("a\xE2\x82b", "utf-8", "a\u{FFFD}b");
    try expectDecode("\xFF", "utf-8", "\u{FFFD}");
}

test "decode: a BOM decides and is removed" {
    try expectDecode("\xEF\xBB\xBFa\xC3\xA9", "windows-1252", "a\u{00E9}");
    try expectDecode("\xFE\xFF\x00a\x00b", "utf-8", "ab");
    try expectDecode("\xFF\xFEa\x00", "utf-8", "a");
}
