//! HTML 4.10.17 selectedcontent cloning and update microtasks.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const engine = @import("engine");
const associated = @import("../form_associated.zig");
const options = @import("options.zig");

/// The nearest ancestor select, without keeping an ancestor pointer.
pub fn nearestSelect(node: *runtime.Instance) ?*runtime.Instance {
    var ancestor = associated.parentOf(node);
    while (ancestor) |element| : (ancestor = associated.parentOf(element)) {
        if (element.stateAs(interfaces.HTMLSelectElement.State) != null) return element;
    }
    return null;
}

pub const Disabledness = struct { select: ?*runtime.Instance, disabled: bool };

/// Recalculate selectedcontent disabledness, steps 1–4. The owner stores
/// the flag only when the spec asks for recalculation, not on removal.
pub fn disabledness(content: *runtime.Instance) Disabledness {
    var select: ?*runtime.Instance = null;
    var ancestor = associated.parentOf(content);
    while (ancestor) |element| : (ancestor = associated.parentOf(element)) {
        if (element.stateAs(interfaces.HTMLSelectElement.State) != null) {
            if (select != null) return .{ .select = select, .disabled = true };
            select = element;
        } else if (element.stateAs(interfaces.HTMLOptionElement.State) != null or
            element.stateAs(interfaces.HTMLSelectedContentElement.State) != null) return .{ .select = select, .disabled = true };
    }
    return .{ .select = select, .disabled = false };
}

pub fn inserted(content: *runtime.Instance) void {
    const select = nearestSelect(content) orelse return;
    dom.form_controls.setSelectedcontentInterest(select, true) catch {};
}

/// Interest is only a fast-path scalar. It never names or holds a node.
pub fn refreshInterest(select: *runtime.Instance) void {
    var node = interfaces.Node.get_firstChild(select) catch null;
    while (node) |element| {
        if (element.stateAs(interfaces.HTMLSelectedContentElement.State) != null) {
            dom.form_controls.setSelectedcontentInterest(select, true) catch {};
            return;
        }
        node = associated.nextInTree(element, select, element.stateAs(interfaces.HTMLSelectElement.State) != null);
    }
    dom.form_controls.setSelectedcontentInterest(select, false) catch {};
}

fn selectedOption(select: *runtime.Instance) !?*runtime.Instance {
    const index = (try dom.form_controls.selectedIndex(select)) orelse return null;
    var list: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer list.deinit(select.ctx.allocator);
    try options.collect(select, select.ctx.allocator, &list);
    return if (index < list.items.len) list.items[index] else null;
}

fn nodeBase(node: *runtime.Instance) !*dom.NodeBase {
    return dom.instance_bridge.getNodeBase(node) orelse error.InvalidStateError;
}

/// Clone an option into selectedcontent, steps 1–3; clear, step 1.
/// Internal clone/replace algorithms keep the caller's CEReactions scope:
/// custom-element upgrades and reactions run after this native operation.
/// Blink HTMLSelectedContentElement::CloneContentsFromOptionElement also
/// clones every child before replacing the contents in one mutation batch.
fn cloneContents(content: *runtime.Instance, option: ?*runtime.Instance) !void {
    const parent = try nodeBase(content);
    const selected = option orelse return dom.mutation.replaceAll(@as(?*dom.NodeBase, null), parent);
    const document = (try interfaces.Node.get_ownerDocument(selected)) orelse return error.InvalidStateError;
    const fragment = try interfaces.Document.call_createDocumentFragment(document);
    const generation = runtime.SlabAllocator.generationOf(fragment);
    defer dom.node_creation.releaseIfUnwrapped(fragment, generation);
    var child = try interfaces.Node.get_firstChild(selected);
    while (child) |node| : (child = try interfaces.Node.get_nextSibling(node)) {
        _ = try dom.node_creation.clone(node, document, true, fragment);
    }
    try dom.mutation.replaceAll(@as(?*dom.NodeBase, try nodeBase(fragment)), parent);
}

/// Update a selectedcontent, steps 1–4. The caller checks multiple.
pub fn updateOne(select: *runtime.Instance, content: *runtime.Instance) !void {
    if (dom.selected_content.isDisabled(content)) return;
    try cloneContents(content, try selectedOption(select));
}

/// Update a select's descendant selectedcontent elements, steps 1–3.
/// Updating contents cannot change this traversal: those subtrees, option
/// subtrees and nested selects contain only disabled selectedcontent. The
/// internal DOM operations enqueue custom reactions instead of running them.
pub fn updateAll(select: *runtime.Instance) !void {
    if (!dom.form_controls.selectedcontentInterest(select)) return;
    if (associated.hasAttribute(select, "multiple")) return;
    const option = try selectedOption(select);
    var node = try interfaces.Node.get_firstChild(select);
    while (node) |element| {
        const content = element.stateAs(interfaces.HTMLSelectedContentElement.State) != null;
        const skip = content or element.stateAs(interfaces.HTMLSelectElement.State) != null or
            element.stateAs(interfaces.HTMLOptionElement.State) != null;
        if (content and !dom.selected_content.isDisabled(element)) try cloneContents(element, option);
        node = associated.nextInTree(element, select, skip);
    }
}

/// One spec microtask, never coalesced. Stable TaskHolds keep both captured
/// arguments until execution or the engine's dropped-reaction callback.
const Update = struct {
    allocator: std.mem.Allocator,
    select: dom.node_holds.TaskHold = .{},
    content: dom.node_holds.TaskHold = .{},
    one: bool,

    const steps: engine.PromiseReactionSteps = .{ .fulfilled = fulfilled, .dropped = dropped };

    fn destroy(self: *Update) void {
        self.content.release();
        self.select.release();
        self.allocator.destroy(self);
    }

    fn fulfilled(data: ?*anyopaque, _: runtime.JSValue) void {
        const self: *Update = @ptrCast(@alignCast(data.?));
        defer self.destroy();
        const select = self.select.get() orelse return;
        if (self.one) {
            const content = self.content.get() orelse return;
            updateOne(select, content) catch {};
        } else updateAll(select) catch {};
    }

    fn dropped(data: ?*anyopaque) void {
        const self: *Update = @ptrCast(@alignCast(data.?));
        self.destroy();
    }
};

/// Explicit allocation domain lets all-OOM tests cover the continuation.
/// The engine runs exactly one fulfilled/dropped callback after a successful
/// handoff; on error this function still owns and releases the record.
pub fn queueUpdate(allocator: std.mem.Allocator, select: *runtime.Instance, content: ?*runtime.Instance) !void {
    if (!select.ctx.hasEngine()) return;
    const update = try allocator.create(Update);
    update.* = .{ .allocator = allocator, .one = content != null };
    update.select.take(select);
    if (content) |element| update.content.take(element);
    errdefer update.destroy();
    try engine.queueRealmMicrotask(select.ctx, &Update.steps, update);
}
