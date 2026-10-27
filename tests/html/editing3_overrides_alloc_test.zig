//! Lane editing3: recording and restoring the overrides under allocation
//! failure (std.testing.checkAllAllocationFailures): every allocation of
//! "record current states and values", "record current overrides" and
//! "restore states and values" goes through the command's scratch arena,
//! and a failure anywhere unwinds without leaking it.
const std = @import("std");
const html = @import("html");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const helpers = @import("edges_node_holders_helpers.zig");

const execcommand = html.execcommand;
const common = execcommand.common;
const overrides = execcommand.overrides;
const Instance = runtime.Instance;

const Context = struct {
    page: helpers.Page,
    document: *Instance,
    selection: *Instance,
};

/// One round: a fresh `<b><i>[foo]</i></b>bar` selection, the deletion's
/// record (from the start of the range), the next character's record of
/// the Document's overrides, and the restore - all on a scratch arena over
/// `allocator`.
fn recordAndRestore(allocator: std.mem.Allocator, context: *Context) !void {
    try context.page.run("setupHost();");
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var edit: common.Edit = .{ .document = context.document, .selection = context.selection, .allocator = context.document.ctx.allocator, .scratch = arena.allocator() };
    const start = (try edit.rangeStart()).?;
    const recorded = try overrides.recordCurrentStatesAndValues(&edit, start.node);
    // Restore with nothing formattable selected: the Document's overrides.
    try edit.collapseToEnd();
    try overrides.restoreStatesAndValues(&edit, recorded);
    // The next character's record of them, then their restore onto a
    // selected character.
    const current = try overrides.recordCurrentOverrides(&edit);
    try context.page.run("selectChar();");
    try overrides.restoreStatesAndValues(&edit, current);
}

fn allocationFailures() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<div contenteditable id=host></div>';
        \\globalThis.setupHost = () => {
        \\  host.innerHTML = '<b><i>foo</i></b>bar';
        \\  const text = host.firstChild.firstChild.firstChild;
        \\  getSelection().setBaseAndExtent(text, 0, text, 3);
        \\};
        \\globalThis.selectChar = () => {
        \\  const text = host.lastChild;
        \\  getSelection().setBaseAndExtent(text, 0, text, 1);
        \\};
    );
    const document = page.browser.current_context.?.document_instance.?;
    const selection = (try interfaces.Document.call_getSelection(document)).?;
    var context: Context = .{ .page = page, .document = document, .selection = selection };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, recordAndRestore, .{&context});
}

test "recording and restoring the overrides unwinds every allocation failure" {
    try helpers.onFreshThread(allocationFailures);
}
