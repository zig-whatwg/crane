//! Sanitizer configuration regression: no JavaScript engine is needed to
//! canonicalize the null dictionary or to own a modifier's input strings.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const fixture = @import("rf_fixture.zig");

test "Sanitizer null configuration has permissive defaults" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const sanitizer = try interfaces.Sanitizer.call_constructor(&page.ctx, .passed(runtime.JSValue.jsNull));
    defer runtime.Instance.deinit(sanitizer);
    const config = try interfaces.Sanitizer.call_get(sanitizer);
    try std.testing.expectEqual(@as(?bool, true), config.comments);
    try std.testing.expectEqual(@as(?bool, null), config.dataAttributes);
    try std.testing.expectEqual(@as(usize, 0), config.removeElements.?.len);
    try std.testing.expectEqual(@as(usize, 0), config.removeAttributes.?.len);
}

test "Sanitizer processing instruction modifiers canonicalize and report changes" {
    if (comptime !@hasDecl(interfaces.Sanitizer, "call_allowProcessingInstruction")) return error.MissingSanitizerBinding;
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const sanitizer = try interfaces.Sanitizer.call_constructor(&page.ctx, .passed(runtime.JSValue.jsNull));
    defer runtime.Instance.deinit(sanitizer);
    try std.testing.expect(try interfaces.Sanitizer.call_removeProcessingInstruction(sanitizer, .{ .domstring = fixture.str("target") }));
    try std.testing.expect(!try interfaces.Sanitizer.call_removeProcessingInstruction(sanitizer, .{ .domstring = fixture.str("target") }));
    const config = try interfaces.Sanitizer.call_get(sanitizer);
    try std.testing.expectEqualStrings("target", config.removeProcessingInstructions.?[0].sanitizer_processing_instruction.target.asSlice());
    try std.testing.expect(try interfaces.Sanitizer.call_allowProcessingInstruction(sanitizer, .{ .domstring = fixture.str("target") }));
    try std.testing.expect(!try interfaces.Sanitizer.call_allowProcessingInstruction(sanitizer, .{ .domstring = fixture.str("target") }));
}

test "Sanitizer javascript URLs default to permissive for null config and modifiers report changes" {
    if (comptime !@hasDecl(interfaces.Sanitizer, "call_setJavascriptURLs")) return error.MissingSanitizerBinding;
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const sanitizer = try interfaces.Sanitizer.call_constructor(&page.ctx, .passed(runtime.JSValue.jsNull));
    defer runtime.Instance.deinit(sanitizer);
    try std.testing.expectEqual(@as(?bool, true), (try interfaces.Sanitizer.call_get(sanitizer)).javascriptURLs);
    try std.testing.expect(!try interfaces.Sanitizer.call_setJavascriptURLs(sanitizer, true));
    try std.testing.expect(try interfaces.Sanitizer.call_setJavascriptURLs(sanitizer, false));
    try std.testing.expect(!try interfaces.Sanitizer.call_setJavascriptURLs(sanitizer, false));
}
