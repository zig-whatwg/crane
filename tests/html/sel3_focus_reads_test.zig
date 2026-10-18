//! Focus designation reads and the separate rendering-time fixup (Q42/Q43).
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const focus = @import("html").focus;
const helpers = @import("edges_node_holders_helpers.zig");

fn hiddenDesignation() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<input id="target">';
        \\globalThis.target = document.getElementById('target');
        \\target.focus();
        \\target.style.display = 'none';
    );
    const document = page.browser.current_context.?.document_instance.?;
    const target = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("target"))).?;
    const designation = dom.focused_area.get(document);
    // HTML activeElement step 1 and has-focus steps only read the designation.
    try std.testing.expectEqual(target, focus.activeElement(document).?);
    try std.testing.expect(focus.hasFocus(document));
    try std.testing.expect(std.meta.eql(designation, dom.focused_area.get(document)));
    // Update-the-rendering step 17, which the integrator's Q34 patch calls.
    try std.testing.expectEqual(@as(?*runtime.Instance, null), focus.focusedAreaOf(document));
    try std.testing.expectEqual((try interfaces.Document.get_body(document)).?, focus.activeElement(document).?);
}

test "activeElement preserves a hidden designation until rendering performs fixup" {
    try helpers.onFreshThread(hiddenDesignation);
}

fn blurHiddenDesignation() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<input id="old"><input id="next">';
        \\const old = document.getElementById('old');
        \\globalThis.oldBlurCount = 0;
        \\old.addEventListener('blur', () => ++oldBlurCount);
        \\old.focus();
        \\old.style.display = 'none';
        \\document.getElementById('next').focus();
    );
    const count = try page.evaluate("String(oldBlurCount)");
    defer std.testing.allocator.free(count);
    try std.testing.expectEqualStrings("1", count);
    const document = page.browser.current_context.?.document_instance.?;
    const next = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("next"))).?;
    try std.testing.expectEqual(next, focus.activeElement(document).?);
}

test "focusing another element blurs the hidden designation before rendering" {
    try helpers.onFreshThread(blurHiddenDesignation);
}

fn removedDesignation() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<input id="target">';
        \\globalThis.target = document.getElementById('target');
        \\target.focus();
        \\target.remove();
    );
    const document = page.browser.current_context.?.document_instance.?;
    try std.testing.expectEqual((try interfaces.Document.get_body(document)).?, focus.activeElement(document).?);
    const matches = try page.evaluate("String(target.matches(':focus') || target.matches(':focus-within'))");
    defer std.testing.allocator.free(matches);
    try std.testing.expectEqualStrings("false", matches);
}

test "removing a focused element is observed without a rendering update" {
    try helpers.onFreshThread(removedDesignation);
}
