//! HTML option disabledness suppresses trusted clicks, not dispatchEvent.
const std = @import("std");
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const input = @import("html").user_input;
const helpers = @import("edges_node_holders_helpers.zig");

fn disabledClicks() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.clicks = [];
        \\const select = document.createElement('select');
        \\select.size = 3;
        \\const direct = document.createElement('option');
        \\direct.id = 'direct'; direct.disabled = true;
        \\const descendant = document.createElement('span');
        \\descendant.id = 'descendant'; direct.append(descendant);
        \\const group = document.createElement('optgroup');
        \\group.disabled = true;
        \\const grouped = document.createElement('option');
        \\grouped.id = 'grouped'; group.append(grouped);
        \\const wrapper = document.createElement('div');
        \\const wrapped = document.createElement('option');
        \\wrapped.id = 'wrapped';
        \\wrapper.append(wrapped); group.append(wrapper);
        \\select.append(direct, group); document.body.append(select);
        \\const disabledSelect = document.createElement('select');
        \\disabledSelect.disabled = true;
        \\const enabled = document.createElement('option');
        \\enabled.id = 'enabled'; disabledSelect.append(enabled);
        \\document.body.append(disabledSelect);
        \\for (const option of [direct, grouped, wrapped, enabled]) {
        \\  option.addEventListener('click', event => clicks.push(event.isTrusted));
        \\}
    );
    const document = page.browser.current_context.?.document_instance.?;
    for ([_][]const u8{ "direct", "descendant", "grouped", "wrapped", "enabled" }) |id| {
        const option = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned(id))).?;
        var pointer: input.Pointer = .{};
        input.pointerMove(&pointer, option, .{});
        input.pointerDown(&pointer, 0, .{});
        input.pointerUp(&pointer, 0, .{});
    }
    const count = try page.evaluate("clicks.length");
    defer std.testing.allocator.free(count);
    try std.testing.expectEqualStrings("0", count);
    try page.run(
        \\for (const id of ['direct', 'grouped', 'wrapped', 'enabled']) {
        \\  const option = document.getElementById(id);
        \\  option.dispatchEvent(new MouseEvent('click'));
        \\  option.click();
        \\}
        \\if (clicks.length !== 8 || clicks.some(Boolean)) throw new Error('synthetic dispatch was suppressed');
    );
}

test "disabled options suppress trusted clicks including through optgroup wrappers" {
    try helpers.onFreshThread(disabledClicks);
}
