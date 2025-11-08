const std = @import("std");
const idna = @import("url").idna;
const punycode = @import("url").idna.punycode;

test "debug IDNA normalization" {
    const allocator = std.testing.allocator;

    // Test case: àא (U+00E0 LATIN SMALL LETTER A WITH GRAVE + U+05D0 HEBREW LETTER ALEF)
    const input = "à\u{05D0}";

    std.debug.print("\n=== IDNA Debug ===\n", .{});
    std.debug.print("Input: {s}\n", .{input});
    std.debug.print("Input bytes: ", .{});
    for (input) |byte| {
        std.debug.print("{X:0>2} ", .{byte});
    }
    std.debug.print("\n", .{});

    // Manually check what normalization does
    const norm = @import("url").idna.normalization;
    const normalized = try norm.normalize(allocator, input);
    defer allocator.free(normalized);

    std.debug.print("Normalized: {s}\n", .{normalized});
    std.debug.print("Normalized bytes: ", .{});
    for (normalized) |byte| {
        std.debug.print("{X:0>2} ", .{byte});
    }
    std.debug.print("\n", .{});

    // Try punycode encoding directly
    const pc = @import("url").idna.punycode;
    const encoded = try pc.encode(allocator, normalized);
    defer allocator.free(encoded);

    std.debug.print("Punycode: xn--{s}\n", .{encoded});
    std.debug.print("Expected: xn--0ca24w\n", .{});

    // Try full domainToASCII
    const result = try idna.domainToASCII(allocator, input, false);
    defer allocator.free(result);

    std.debug.print("domainToASCII: {s}\n", .{result});
}
