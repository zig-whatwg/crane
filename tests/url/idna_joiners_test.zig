//! UTS #46 CheckJoiners validates ContextJ, not ContextO.
const std = @import("std");
const idna = @import("url").idna;

fn accepts(input: []const u8) !void {
    const result = try idna.domainToASCII(std.testing.allocator, input, false);
    defer std.testing.allocator.free(result);
}

test "IDNA rejects ZWNJ and ZWJ without joining context" {
    for ([_][]const u8{ "a\u{200c}b", "a\u{200d}b", "\u{0627}\u{200c}\u{0628}", "\u{0628}\u{200c}a", "\u{0628}a\u{200c}\u{0628}" }) |input| {
        if (idna.domainToASCII(std.testing.allocator, input, false)) |unexpected| {
            std.testing.allocator.free(unexpected);
            return error.TestUnexpectedResult;
        } else |err| {
            try std.testing.expect(err == error.ContextError);
        }
    }
}

test "IDNA accepts virama and joining-type ContextJ" {
    try accepts("\u{0915}\u{094d}\u{200c}");
    try accepts("\u{0915}\u{094d}\u{200d}");
    try accepts("\u{0628}\u{200c}\u{0628}");
    try accepts("\u{0628}\u{064e}\u{200c}\u{064e}\u{0628}");
}

test "URL IDNA does not enforce ContextO" {
    try accepts("a\u{00b7}b");
    try accepts("\u{30fb}");
}
