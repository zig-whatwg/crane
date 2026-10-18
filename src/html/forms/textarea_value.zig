//! HTML 4.10.11: the textarea's submission value, distinct from its API value.
//! https://html.spec.whatwg.org/multipage/form-elements.html#textarea-wrapping-transformation
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

/// Called only when constructing an entry list (HTML 4.10.22.4 step 5.10).
/// WebKit HTMLTextAreaElement::appendFormData and Blink AppendToFormData also
/// apply hard wrapping here, without changing the API value or selection.
pub fn submissionValue(allocator: std.mem.Allocator, textarea: *runtime.Instance) ![]u8 {
    // The API-value algorithm normalizes CRLF and CR to LF first.
    var value = try interfaces.HTMLTextAreaElement.get_value(textarea);
    defer value.deinit(textarea.ctx.allocator);
    var wrap = try interfaces.HTMLTextAreaElement.get_wrap(textarea);
    defer wrap.deinit(textarea.ctx.allocator);
    // Wrapping transformation step 1: only the Hard state inserts LFs.
    if (!std.ascii.eqlIgnoreCase(wrap.asSlice(), "hard")) return allocator.dupe(u8, value.asSlice());
    const cols = try interfaces.HTMLTextAreaElement.get_cols(textarea);
    return hardWrap(allocator, value.asSlice(), cols);
}

/// Implementation-defined wrapping: count code points, prefer the last ASCII
/// whitespace boundary within cols, otherwise break at cols. Preserve every
/// original byte and existing LF, and never split a WTF-8 sequence. Input is
/// the already newline-normalized API value; cols is the positive character
/// width (the reflected getter supplies its default of 20).
pub fn hardWrap(allocator: std.mem.Allocator, value: []const u8, cols: u32) ![]u8 {
    std.debug.assert(cols > 0);
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    try out.ensureTotalCapacity(allocator, value.len);
    var start: usize = 0;
    while (start < value.len) {
        var end = start;
        var count: u32 = 0;
        var whitespace_end: ?usize = null;
        while (end < value.len and value[end] != '\n' and count < cols) : (count += 1) {
            const byte = value[end];
            const length = std.unicode.utf8ByteSequenceLength(byte) catch 1;
            end += @min(length, value.len - end);
            if (std.ascii.isWhitespace(byte)) whitespace_end = end;
        }
        if (end == value.len or value[end] == '\n') {
            if (end < value.len) end += 1;
            try out.appendSlice(allocator, value[start..end]);
        } else {
            end = whitespace_end orelse end;
            try out.appendSlice(allocator, value[start..end]);
            try out.append(allocator, '\n');
        }
        start = end;
    }
    return out.toOwnedSlice(allocator);
}

test "hard wrapping preserves whitespace, existing newlines and exact-width lines" {
    const cases = [_]struct { []const u8, u32, []const u8 }{
        .{ "", 7, "" },
        .{ "hello world\nsecond line", 7, "hello \nworld\nsecond \nline" },
        .{ "ABCDEFGHIJKLMNOPQRSTUVWXYZ", 10, "ABCDEFGHIJ\nKLMNOPQRST\nUVWXYZ" },
        .{ "exact  len\nand then\nsome", 10, "exact  len\nand then\nsome" },
        .{ "\n\na\n\n", 1, "\n\na\n\n" },
        .{ "a b", 1, "a\n \nb" },
        .{ "é日😀x", 2, "é日\n😀x" },
        .{ "a\xed\xa0\x80b", 1, "a\n\xed\xa0\x80\nb" },
    };
    for (cases) |case| {
        const actual = try hardWrap(std.testing.allocator, case[0], case[1]);
        defer std.testing.allocator.free(actual);
        try std.testing.expectEqualStrings(case[2], actual);
        const again = try hardWrap(std.testing.allocator, actual, case[1]);
        defer std.testing.allocator.free(again);
        try std.testing.expectEqualStrings(actual, again);
    }
}
