const std = @import("std");
const selector = @import("selector");

test "CE2 selectors: validity pseudo classes parse with class specificity" {
    inline for (.{ ":valid", ":invalid" }) |input| {
        var tokenizer = selector.Tokenizer.init(std.testing.allocator, input);
        var parser = try selector.parser.Parser.init(std.testing.allocator, &tokenizer);
        defer parser.deinit();
        var parsed = try parser.parse();
        defer parsed.deinit();
        try std.testing.expectEqual(@as(usize, 1), parsed.selectors.len);
        try std.testing.expectEqual(@as(u32, 1), parsed.selectors[0].calculateSpecificity().class);
    }
}
