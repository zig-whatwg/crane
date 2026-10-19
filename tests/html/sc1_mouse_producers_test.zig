//! Keep the user-input and test-driver MouseEvent producer paths working.
const std = @import("std");
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const input = @import("html").user_input;
const helpers = @import("edges_node_holders_helpers.zig");

fn mouseProducers() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<button id="sc1-target">target</button><span id="sc1-related"></span>';
        \\globalThis.sc1MouseLog = [];
        \\for (const type of ['mouseover', 'mousemove', 'mousedown', 'mouseup', 'click']) {
        \\  document.getElementById('sc1-target').addEventListener(type, event => {
        \\    sc1MouseLog.push([event.type, event instanceof MouseEvent, event.isTrusted,
        \\      event.bubbles, event.cancelable, event.composed, event.view === window,
        \\      event.button, event.buttons, event.detail, event.ctrlKey, event.shiftKey,
        \\      event.altKey, event.metaKey, event.relatedTarget && event.relatedTarget.id].join('|'));
        \\    if (event.type === 'mousedown') event.preventDefault();
        \\  });
        \\}
    );
    const document = page.browser.current_context.?.document_instance.?;
    const target = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("sc1-target"))).?;
    const related = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("sc1-related"))).?;
    // test_driver's selectable-option path calls fireMouseEvent directly;
    // pointerMove/Down/Up use the same producer for compatibility events.
    const modifiers: input.Modifiers = .{ .ctrl = true, .shift = true, .alt = true, .meta = true };
    try std.testing.expect(!input.fireMouseEvent(target, "mousedown", modifiers, 2, 5, 3, related));
    const result = try page.evaluate("sc1MouseLog.join(',')");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("mousedown|true|true|true|true|true|true|2|5|3|true|true|true|true|sc1-related", result);
    try page.run("sc1MouseLog.length = 0;");
    var pointer: input.Pointer = .{};
    input.pointerMove(&pointer, target, .{});
    input.pointerDown(&pointer, 0, .{});
    input.pointerUp(&pointer, 0, .{});
    input.fireSyntheticClick(target, .{});
    try page.run(
        \\for (const type of ['mouseover', 'mousemove', 'mousedown', 'mouseup', 'click']) {
        \\  if (!sc1MouseLog.some(line => line.startsWith(type + '|true|true|true|true|true|true|')))
        \\    throw new Error('missing or malformed producer: ' + type + ': ' + sc1MouseLog.join(','));
        \\}
        \\const legacy = document.createEvent('MouseEvents');
        \\const receiver = new EventTarget();
        \\let rejected = false;
        \\try { receiver.dispatchEvent(legacy); } catch (e) { rejected = e.name === 'InvalidStateError'; }
        \\if (!rejected) throw new Error('legacy event initialized too early');
        \\legacy.initMouseEvent('legacy', true, true, window, 4, 1, 2, 3, 4,
        \\  false, false, false, false, 1, null);
        \\if (legacy.clientX !== 3 || legacy.button !== 1 || legacy.buttons !== 0 ||
        \\    legacy.movementX !== 0 || legacy.composed || !receiver.dispatchEvent(legacy))
        \\  throw new Error('legacy mouse initialization');
    );
}

test "MouseEvent producer retains trusted flags, dictionary fields and pointer compatibility events" {
    try helpers.onFreshThread(mouseProducers);
}
