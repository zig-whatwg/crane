//! Modal membership uses the existing Document-owned top-layer entries.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const helpers = @import("edges_node_holders_helpers.zig");

fn member(document: *runtime.Instance, comptime id: []const u8) !*runtime.Instance {
    return (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned(id))).?;
}

fn mixedRemoval() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<dialog id=a></dialog><div id=p popover></div><dialog id=b></dialog>'");
    const document = page.browser.current_context.?.document_instance.?;
    const first = try member(document, "a");
    const popover = try member(document, "p");
    const last = try member(document, "b");
    for ([_][3]usize{ .{ 0, 1, 2 }, .{ 0, 2, 1 }, .{ 1, 0, 2 }, .{ 1, 2, 0 }, .{ 2, 0, 1 }, .{ 2, 1, 0 } }) |order| {
        var state = dom.top_layer.State.init(std.testing.allocator, document);
        defer state.deinit();
        const a = try state.addModal(first);
        const p = try state.pin(popover);
        p.showing = true;
        const b = try state.addModal(last);
        const ids = [_]usize{ a.id, p.id, b.id };
        var present = [_]bool{ true, true, true };
        try std.testing.expect(state.lastModal() == last);
        try std.testing.expect(state.find(first) == null);
        try std.testing.expect(state.find(popover) == p);
        for (order) |index| {
            present[index] = false;
            state.remove(ids[index]);
            const expected: ?*runtime.Instance = if (present[2]) last else if (present[0]) first else null;
            try std.testing.expect(state.lastModal() == expected);
            try std.testing.expectEqual(present[0], state.findModal(first) != null);
            try std.testing.expectEqual(present[2], state.findModal(last) != null);
        }
        try std.testing.expectEqual(@as(usize, 0), state.entries.items.len);
    }
}

fn allocationTrial(allocator: std.mem.Allocator, document: *runtime.Instance, first: *runtime.Instance, last: *runtime.Instance) !void {
    var state = dom.top_layer.State.init(allocator, document);
    defer state.deinit();
    _ = try state.addModal(first);
    _ = try state.addModal(last);
    try std.testing.expect(state.lastModal() == last);
}

fn allocationFailures() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<dialog id=a></dialog><dialog id=b></dialog>'; void document.getElementById('a'); void document.getElementById('b')");
    const document = page.browser.current_context.?.document_instance.?;
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationTrial, .{ document, try member(document, "a"), try member(document, "b") });
}

fn openAtTeardown() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<button id=previous>previous</button><dialog id=dialog tabindex=0></dialog>';
        \\document.getElementById('previous').focus();
        \\const dialog = document.getElementById('dialog');
        \\dialog.returnValue = 'owned value';
        \\dialog.showModal();
        \\TestUtils.gc();
    );
    const document = page.browser.current_context.?.document_instance.?;
    try std.testing.expect((try dom.top_layer.ofDocument(document, false)).?.lastModal() == try member(document, "dialog"));
}

fn removedOpen() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<button id=previous>previous</button><dialog id=dialog tabindex=0></dialog>';
        \\document.getElementById('previous').focus();
        \\let dialog = document.getElementById('dialog');
        \\dialog.returnValue = 'owned value';
        \\dialog.showModal();
        \\dialog.remove();
        \\if (!dialog.open || dialog.matches(':modal')) throw new Error('removal state');
        \\dialog = null;
    );
    try page.turn();
    try page.run("TestUtils.gc()");
    const document = page.browser.current_context.?.document_instance.?;
    try std.testing.expect((try dom.top_layer.ofDocument(document, false)).?.lastModal() == null);
}

test "modal popover modal entries can be removed in every order" {
    try helpers.onFreshThread(mixedRemoval);
}

test "modal add rolls back every allocation failure" {
    try helpers.onFreshThread(allocationFailures);
}

test "document teardown releases an open modal and its previous-focus hold" {
    try helpers.onFreshThread(openAtTeardown);
}

test "removing an open modal releases its state and previous-focus hold" {
    try helpers.onFreshThread(removedOpen);
}
