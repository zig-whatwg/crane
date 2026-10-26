//! Font Loading (FontFaceSet.check()/load() font strings) and substitution
//! functions (lane vars1): the font string parses with no element, so
//! nothing can substitute var(), env() or random-item() there - each stays a
//! syntax error, as before var()/env() became pending values in style.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

test "a font string with an arbitrary substitution function is a syntax error" {
    for ([_][]const u8{ "12px env(safe-area-inset-top) serif", "env(x) 12px serif", "12px E\\6ev(x) serif", "var(--size) serif", "12px random-item(--k, serif, monospace)" }) |input| {
        if (try css.font_request.parseForFontLoading(.{ .allocator = testing.allocator }, input)) |result| {
            var owned = result;
            owned.deinit();
            std.debug.print("accepted: {s}\n", .{input});
            return error.UnexpectedFont;
        }
    }
    // Unchanged otherwise.
    var ok = (try css.font_request.parseForFontLoading(.{ .allocator = testing.allocator }, "12px serif")).?;
    ok.deinit();
}
