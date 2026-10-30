//! HTML light dismiss step 3 preserves the target while no dialog is open.
const std = @import("std");
const dom = @import("dom");
const html = @import("html");
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const browser_mod = @import("browser");
const helpers = @import("edges_node_holders_helpers.zig");

fn emptyPointerupPreservesNextPress() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<button id=outside>Outside</button><dialog id=a closedby=any><button id=inside>Inside</button></dialog><dialog id=b closedby=any></dialog>';
        \\const a = document.getElementById('a');
        \\const b = document.getElementById('b');
        \\a.show();
    );
    const document = page.browser.current_context.?.document_instance.?;
    const inside = (try dom.selector_matching.querySelector(document, "#inside")).?;
    const outside = (try dom.selector_matching.querySelector(document, "#outside")).?;
    const state = (try dom.top_layer.ofDocument(document, false)).?;
    var pointer: html.user_input.Pointer = .{};
    html.user_input.pointerMove(&pointer, inside, .{});
    html.user_input.pointerDown(&pointer, 0, .{});
    try page.run("a.close()");
    try std.testing.expect(state.lastOpenDialog() == null);
    html.user_input.pointerMove(&pointer, outside, .{});
    html.user_input.pointerUp(&pointer, 0, .{});

    // Step 3 skips both target writes while the list is empty. The previous
    // target is observable if dialogs open during this next press.
    html.user_input.pointerDown(&pointer, 0, .{});
    try page.run("a.show(); b.show()");
    html.user_input.pointerMove(&pointer, inside, .{});
    html.user_input.pointerUp(&pointer, 0, .{});
    try page.run(
        \\if (!a.open) throw new Error('remembered dialog closed');
        \\if (b.open) throw new Error('empty-list pointerup discarded the target needed to close B');
    );
    try std.testing.expect(state.dialog_pointerdown_target.get() == null);
}

fn emptyPointerdownPreservesTarget() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<button id=outside>Outside</button><dialog id=a closedby=any><button id=inside>Inside</button></dialog>';
        \\document.getElementById('a').show();
    );
    const document = page.browser.current_context.?.document_instance.?;
    const dialog = (try dom.selector_matching.querySelector(document, "#a")).?;
    const inside = (try dom.selector_matching.querySelector(document, "#inside")).?;
    const outside = (try dom.selector_matching.querySelector(document, "#outside")).?;
    const state = (try dom.top_layer.ofDocument(document, false)).?;
    var pointer: html.user_input.Pointer = .{};
    html.user_input.pointerMove(&pointer, inside, .{});
    html.user_input.pointerDown(&pointer, 0, .{});
    try page.run("document.getElementById('a').close()");
    try std.testing.expect(state.lastOpenDialog() == null);
    try std.testing.expect(state.dialog_pointerdown_target.get() == dialog);

    // Invoke the exact production algorithm with the closed-list state.
    // This pins step 3 independently of the preceding pointerup case.
    html.dialog.lightDismiss(outside, true);
    try std.testing.expect(state.dialog_pointerdown_target.get() == dialog);
    // Removal releases the node; the separate removed marker preserves the
    // gesture mismatch without retaining a detached subtree.
    try page.run("document.getElementById('a').remove()");
    try std.testing.expect(state.dialog_pointerdown_target.get() == null);
}

test "empty-list pointerup preserves a target used after dialogs open during the next press" {
    try helpers.onFreshThread(emptyPointerupPreservesNextPress);
}

test "empty-list pointerdown does not overwrite the remembered dialog" {
    try helpers.onFreshThread(emptyPointerdownPreservesTarget);
}

fn removalDoesNotDismissAnotherDialog() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<button id=outside>Outside</button><dialog id=b closedby=any></dialog><dialog id=a closedby=any><button id=inside>Inside</button></dialog>';
        \\const a = document.getElementById('a');
        \\const b = document.getElementById('b');
        \\b.show(); a.show();
    );
    const document = page.browser.current_context.?.document_instance.?;
    const inside = (try dom.selector_matching.querySelector(document, "#inside")).?;
    const outside = (try dom.selector_matching.querySelector(document, "#outside")).?;
    const state = (try dom.top_layer.ofDocument(document, false)).?;
    var pointer: html.user_input.Pointer = .{};
    html.user_input.pointerMove(&pointer, inside, .{});
    html.user_input.pointerDown(&pointer, 0, .{});
    try page.run("a.remove()");
    try std.testing.expect(state.dialog_pointerdown_target.get() == null);
    html.user_input.pointerMove(&pointer, outside, .{});
    html.user_input.pointerUp(&pointer, 0, .{});
    try page.run(
        \\if (!a.open) throw new Error('removal closed A');
        \\if (!b.open) throw new Error('removing the remembered dialog dismissed B');
    );
    html.user_input.pointerDown(&pointer, 0, .{});
    html.user_input.pointerUp(&pointer, 0, .{});
    try page.run("if (b.open) throw new Error('fresh outside click did not dismiss B')");
}

/// One registration allocation fails; later allocations still succeed, so
/// the watcher can be established. This allocator belongs to the Browser
/// for its whole lifetime, with std.testing.allocator checking its releases.
const RegistrationFailure = struct {
    child: std.mem.Allocator = std.testing.allocator,
    size: usize = 0,
    alignment: std.mem.Alignment = .@"1",
    armed: bool = false,
    failed: bool = false,

    fn allocator(self: *RegistrationFailure) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }

    fn arm(self: *RegistrationFailure, comptime T: type) void {
        self.size = @sizeOf(T);
        self.alignment = .of(T);
        self.armed = true;
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *RegistrationFailure = @ptrCast(@alignCast(ctx));
        if (self.armed and !self.failed and len == self.size and alignment == self.alignment) {
            self.failed = true;
            return null;
        }
        return self.child.rawAlloc(len, alignment, ra);
    }

    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) bool {
        const self: *RegistrationFailure = @ptrCast(@alignCast(ctx));
        return self.child.rawResize(memory, alignment, new_len, ra);
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) ?[*]u8 {
        const self: *RegistrationFailure = @ptrCast(@alignCast(ctx));
        return self.child.rawRemap(memory, alignment, new_len, ra);
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *RegistrationFailure = @ptrCast(@alignCast(ctx));
        self.child.rawFree(memory, alignment, ra);
    }
};

fn registrationFailureStillSetsWatcher(comptime failure: enum { state, entry }) !void {
    var failing: RegistrationFailure = .{};
    const browser = try browser_mod.Browser.init(failing.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    // Prime reflected-attribute storage while disconnected: no setup runs.
    try page.runScript(
        \\const dialog = document.createElement('dialog');
        \\dialog.id = 'd'; dialog.closedBy = 'any';
        \\dialog.open = true; dialog.open = false;
        \\document.body.append(dialog);
    );
    const document = page.document_instance.?;
    const dialog = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("d"))).?;
    const window = (try interfaces.Document.get_defaultView(document)).?;
    if (html.close_watchers.isActive(window, .dialog, dialog)) return error.UnexpectedInitialWatcher;
    if ((try dom.top_layer.ofDocument(document, false)) != null) return error.UnexpectedInitialTopLayer;
    if (failure == .entry) _ = try dom.top_layer.ofDocument(document, true);
    failing.arm(if (failure == .state) dom.top_layer.State else dom.top_layer.OpenDialog);
    const opened = interfaces.HTMLDialogElement.set_open(dialog, true);
    failing.armed = false;
    try opened;
    if (!failing.failed) return error.RegistrationAllocationDidNotFail;
    if (!try interfaces.HTMLDialogElement.get_open(dialog)) return error.DialogNotOpenAfterFault;
    // These checks prove the injected failure reached registration, rather
    // than another allocation with the same size and alignment.
    const layer = try dom.top_layer.ofDocument(document, false);
    if (failure == .state) {
        if (layer != null) return error.StateAllocationDidNotFail;
    } else {
        if (layer == null) return error.PreallocatedStateLost;
        if (layer.?.hasOpenDialog(dialog)) return error.OpenListRegistrationDidNotFail;
    }
    if (!html.close_watchers.isActive(window, .dialog, dialog)) return error.WatcherMissingAfterRegistrationFailure;
    html.close_watchers.close(window, .dialog, dialog);
    if (try interfaces.HTMLDialogElement.get_open(dialog)) return error.WatcherDidNotCloseDialog;
}

fn stateAllocationFailure() !void {
    registrationFailureStillSetsWatcher(.state) catch |err| {
        std.debug.print("dialog State allocation regression: {s}\n", .{@errorName(err)});
        return err;
    };
}

fn entryAllocationFailure() !void {
    registrationFailureStillSetsWatcher(.entry) catch |err| {
        std.debug.print("dialog entry allocation regression: {s}\n", .{@errorName(err)});
        return err;
    };
}

test "removing the remembered dialog keeps another dialog open until a fresh outside click" {
    try helpers.onFreshThread(removalDoesNotDismissAnotherDialog);
}

test "dialog watcher setup continues after top-layer State allocation fails" {
    try helpers.onFreshThread(stateAllocationFailure);
}

test "dialog watcher setup continues after open-list entry allocation fails" {
    try helpers.onFreshThread(entryAllocationFailure);
}
