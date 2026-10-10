//! Engine-free pieces of HTML's constraint validation API.
const std = @import("std");
const forms = @import("html").forms;
const testing = std.testing;

test "form constraint hooks" {
    testing.refAllDecls(@import("dom").form_controls);
}

test "custom validity normalizes newlines without changing other bytes" {
    const pairs = .{
        .{ "", "" },
        .{ "ordinary", "ordinary" },
        .{ "a\rb\r\nc\nd\r\r\n", "a\nb\nc\nd\n\n" },
        .{ "\x00\xed\xa0\x80\r\n\xf0\x9f\x98\x80", "\x00\xed\xa0\x80\n\xf0\x9f\x98\x80" },
    };
    inline for (pairs) |pair| {
        var message = try forms.normalizeMessage(testing.allocator, pair[0]);
        defer message.deinit(testing.allocator);
        try testing.expectEqualStrings(pair[1], message.asSlice());
    }
}

test "all constraint flags participate in validity, with missing flags false" {
    try testing.expect(forms.isValid(.{}));
    inline for (std.meta.fields(forms.ValidityFlags)) |field| {
        var flags = forms.ValidityFlags{};
        @field(flags, field.name) = true;
        try testing.expect(!forms.isValid(flags));
        @field(flags, field.name) = false;
        try testing.expect(forms.isValid(flags));
    }
}

test "custom validity replaces owned messages without leaking" {
    var state = forms.Validation{};
    defer state.custom_error.deinit(testing.allocator);
    try state.setCustomError(testing.allocator, "first\r\nmessage");
    try testing.expectEqualStrings("first\nmessage", state.custom_error.asSlice());
    try state.setCustomError(testing.allocator, "replacement\r");
    try testing.expectEqualStrings("replacement\n", state.custom_error.asSlice());
    try state.setCustomError(testing.allocator, "");
    try testing.expect(state.custom_error.isEmpty());
}

test "email constraints validate tokens and each DNS label boundary" {
    const cases = .{
        .{ "", false, false },
        .{ "a@b", false, false },
        .{ "..a..@b", false, false },
        .{ "!#$%&'*+/=?^_`{|}~-@a-b.example", false, false },
        .{ "a@b.", false, true },
        .{ "a@-b", false, true },
        .{ "a@b-", false, true },
        .{ "a@b..c", false, true },
        .{ "a@b,c@d", false, true },
        .{ "a@b, c@d", true, false },
        .{ "a@b,", true, true },
        .{ "a@b,,c@d", true, true },
        .{ "a@é", false, true },
    };
    inline for (cases) |case| try testing.expectEqual(case[2], forms.emailTypeMismatch(case[0], case[1]));
    const address = try testing.allocator.alloc(u8, 66);
    defer testing.allocator.free(address);
    @memcpy(address[0..2], "a@");
    @memset(address[2..], 'x');
    try testing.expect(!forms.emailTypeMismatch(address[0..65], false));
    try testing.expect(forms.emailTypeMismatch(address, false));
}

test "URL constraints require an absolute URL and release the parser's allocations" {
    const cases = .{
        .{ "", false },
        .{ "https://example.com/path?q=1#fragment", false },
        .{ "custom:opaque", false },
        .{ "mailto:user@example.com", false },
        .{ "/relative", true },
        .{ "https://[invalid]/", true },
    };
    inline for (cases) |case| try testing.expectEqual(case[1], try forms.urlTypeMismatch(testing.allocator, case[0]));
}

test "numeric steps preserve tiny remainders and ordinary decimal alignment" {
    try testing.expect(forms.numericStepMismatch(17, 0, 3e-15));
    try testing.expect(forms.numericStepMismatch(-17, 0, 3e-15));
    try testing.expect(!forms.numericStepMismatch(-12345678.9, 0, 1e-12));
    try testing.expect(!forms.numericStepMismatch(0.3, 0, 0.1));
    try testing.expect(!forms.numericStepMismatch(0.3, 0.1, 0.2));
    try testing.expect(forms.numericStepMismatch(0.4, 0.1, 0.2));
    try testing.expect(!forms.numericStepMismatch(0.3000000001, 0, 0.1));
}

test "color sanitization requires the whole CSS color and serializes opaque lower hex" {
    const cases = .{
        .{ " #FfF8 ", "#ffffff" },     .{ "rgb(1e100,0,0)", "#ff0000" },
        .{ "crimson", "#dc143c" },     .{ "rgba(255,0,0,0)", "#ff0000" },
        .{ "#ffffff;", "#000000" },    .{ "#ffffff\x00", "#000000" },
        .{ "not-a-color", "#000000" },
    };
    inline for (cases) |case| {
        const result = try forms.sanitizeColor(testing.allocator, case[0]);
        defer testing.allocator.free(result);
        try testing.expectEqualStrings(case[1], result);
    }
}
