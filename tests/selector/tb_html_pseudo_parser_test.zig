const std = @import("std");
const selector = @import("selector");

test "HTML state pseudo-classes parse case-insensitively with class specificity" {
    for ([_][]const u8{ ":checked", ":CHECKED", ":default", ":indeterminate", ":required", ":optional", ":in-range", ":out-of-range", ":placeholder-shown", ":autofill", ":-webkit-autofill", ":user-valid", ":user-invalid", ":open", ":popover-open", ":modal", ":playing", ":paused", ":seeking", ":buffering", ":stalled", ":muted", ":volume-locked", ":heading", ":heading(1, 3, +6, -1, 9)", ":DIR(rtl)" }) |input| {
        var tokenizer = selector.Tokenizer.init(std.testing.allocator, input);
        var parser = try selector.Parser.init(std.testing.allocator, &tokenizer);
        defer parser.deinit();
        var parsed = try parser.parse();
        defer parsed.deinit();
        try std.testing.expectEqual(@as(usize, 1), parsed.selectors.len);
        try std.testing.expectEqual(@as(u32, 1), parsed.selectors[0].calculateSpecificity().class);
    }
}

test "heading takes a nonempty comma-separated list of integer tokens" {
    for ([_][]const u8{ ":heading()", ":heading(1,)", ":heading(,1)", ":heading(1 2)", ":heading(1.0)", ":heading(1e0)", ":heading(one)", ":heading(1px)", ":heading(- 1)", ":heading(+-1)", ":heading(--1)", "-1", ":state(-1)" }) |input| {
        var tokenizer = selector.Tokenizer.init(std.testing.allocator, input);
        var parser = try selector.Parser.init(std.testing.allocator, &tokenizer);
        defer parser.deinit();
        if (parser.parse()) |value| {
            var unexpected = value;
            unexpected.deinit();
            return error.ExpectedInvalidSelector;
        } else |_| {}
    }
}
