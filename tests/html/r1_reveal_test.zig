//! Lane rendering1 B2: HTML 7.4.6.3 "reveal" at update the rendering step 6 -
//! pagereveal fires once per activation, before that frame's animation frame
//! callbacks, and a shown document gets the rendering opportunity that
//! reveals it even when no script asked for a frame.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

fn pumpUntil(page: helpers.Page, condition: []const u8, turns: usize) !void {
    var turn: usize = 0;
    while (turn < turns) : (turn += 1) {
        _ = try page.browser.runEventLoopBlocking(5);
        const value = try page.evaluate(condition);
        defer std.testing.allocator.free(value);
        if (std.mem.eql(u8, value, "true")) return;
    }
    const value = try page.evaluate(condition);
    defer std.testing.allocator.free(value);
    std.debug.print("condition never held: {s} -> {s}\n", .{ condition, value });
    return error.ConditionNeverHeld;
}

fn revealBeforeTheFirstCallbacks() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // A new document in a frame: its listeners are in place before it is
    // shown, and it asks for one animation frame.
    try page.run(
        \\globalThis.child = document.createElement('iframe');
        \\child.srcdoc = `<!doctype html><script>
        \\  parent.log = [];
        \\  addEventListener('pagereveal', e => parent.log.push('pagereveal:' + e.constructor.name + ':' + e.viewTransition));
        \\  requestAnimationFrame(() => parent.log.push('rAF'));
        \\  requestAnimationFrame(() => requestAnimationFrame(() => { parent.log.push('rAF2'); parent.done = true; }));
        \\<\/script>`;
        \\globalThis.done = false;
        \\document.body.appendChild(child);
    );
    try pumpUntil(page, "done", 400);
    const result = try page.evaluate("log.join()");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("pagereveal:PageRevealEvent:null,rAF,rAF2", result);
}

test "pagereveal fires once, before the first frame's animation frame callbacks" {
    try helpers.onFreshThread(revealBeforeTheFirstCallbacks);
}

fn revealWithoutAnimationFrames() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // Nothing in the frame asks for an animation frame: the document's being
    // shown is enough to give it the rendering opportunity that reveals it.
    try page.run(
        \\globalThis.revealed = 0;
        \\globalThis.child = document.createElement('iframe');
        \\child.srcdoc = `<!doctype html><script>
        \\  addEventListener('pagereveal', () => parent.revealed++);
        \\<\/script>`;
        \\document.body.appendChild(child);
    );
    try pumpUntil(page, "revealed === 1", 400);
    // Once per activation: later frames do not reveal it again.
    try page.run(
        \\globalThis.later = false;
        \\child.contentWindow.requestAnimationFrame(() => requestAnimationFrame(() => { later = true; }));
    );
    try pumpUntil(page, "later", 400);
    const result = try page.evaluate("String(revealed)");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("1", result);
}

test "a shown document is revealed without any animation frame request, and only once" {
    try helpers.onFreshThread(revealWithoutAnimationFrames);
}
