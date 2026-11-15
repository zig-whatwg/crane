//! HTML 4.10.17 the selectedcontent element: cloning the selected option, and
//! the select's queued update of its descendant selectedcontent elements
//! (HTML 4.10.7 "queue an update of a select's descendant selectedcontent
//! elements", with its "pending selectedcontent update" flag).
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const engine = @import("engine");
const associated = @import("../form_associated.zig");
const options = @import("options.zig");

const HTML_NAMESPACE = "http://www.w3.org/1999/xhtml";
const SVG_NAMESPACE = "http://www.w3.org/2000/svg";

/// The nearest ancestor select, without keeping an ancestor pointer.
pub fn nearestSelect(node: *runtime.Instance) ?*runtime.Instance {
    var ancestor = associated.parentOf(node);
    while (ancestor) |element| : (ancestor = associated.parentOf(element)) {
        if (element.stateAs(interfaces.HTMLSelectElement.State) != null) return element;
    }
    return null;
}

pub const Disabledness = struct { select: ?*runtime.Instance, disabled: bool };

/// Recalculate a selectedcontent element's disabledness, steps 1-3 and 5:
/// the nearest ancestor select (or null) and the disabled flag. The owner
/// stores both (its disabled flag and its cached select, step 4).
pub fn disabledness(content: *runtime.Instance) Disabledness {
    var select: ?*runtime.Instance = null;
    // 3. For each ancestor, in reverse tree order (nearest first):
    var ancestor = associated.parentOf(content);
    while (ancestor) |element| : (ancestor = associated.parentOf(element)) {
        if (element.stateAs(interfaces.HTMLSelectElement.State) != null) {
            // 3.1.1-3.1.2: the first select is the nearest; a second one
            // makes the selectedcontent disabled.
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

/// Interest is only a fast-path scalar: whether the select may have a
/// descendant selectedcontent element. It never names or holds a node.
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

/// Clone step 3's element kinds: an HTML script, frame, iframe, embed or
/// object element, or an SVG script element.
fn isOmitted(node: *dom.NodeBase) bool {
    if (node.node_type != dom.NodeBase.ELEMENT_NODE) return false;
    const element: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return false));
    const data = dom.element_data.of(element) orelse return false;
    const namespace = data.namespaceSlice() orelse return false;
    const local = data.localName();
    if (std.mem.eql(u8, namespace, SVG_NAMESPACE)) return std.mem.eql(u8, local, "script");
    if (!std.mem.eql(u8, namespace, HTML_NAMESPACE)) return false;
    for ([_][]const u8{ "script", "frame", "iframe", "embed", "object" }) |name| {
        if (std.mem.eql(u8, local, name)) return true;
    }
    return false;
}

/// Clone steps 3: the omitted elements among `parent`'s shadow-including
/// descendants, in shadow-including tree order. An omitted element's own
/// descendants are not listed: step 4 removes it with them, and removing a
/// node from a subtree already taken out of the fragment changes nothing
/// anything can observe (no observer, no wrapper, nothing connected).
fn collectOmitted(allocator: std.mem.Allocator, parent: *dom.NodeBase, out: *std.ArrayListUnmanaged(*dom.NodeBase)) !void {
    var child = parent.first_child;
    while (child) |node| : (child = node.next_sibling) {
        if (isOmitted(node)) {
            try out.append(allocator, node);
            continue;
        }
        // Shadow-including tree order: a host's shadow tree before its children.
        if (dom.tree_helpers.shadowRootForHost(node)) |shadow| try collectOmitted(allocator, shadow, out);
        try collectOmitted(allocator, node, out);
    }
}

/// HTML "clone an option into a selectedcontent", steps 1-5, and "clear a
/// selectedcontent", step 1 (`option` null).
/// Internal clone/replace algorithms keep the caller's CEReactions scope:
/// custom-element upgrades and reactions run after this native operation.
/// Blink HTMLSelectedContentElement::CloneContentsFromOptionElement also
/// clones every child before replacing the contents in one mutation batch.
fn cloneContents(content: *runtime.Instance, option: ?*runtime.Instance) !void {
    const parent = try nodeBase(content);
    const selected = option orelse return dom.mutation.replaceAll(@as(?*dom.NodeBase, null), parent);
    // 1. Let documentFragment be the result of creating a document fragment
    // given option's node document.
    const document = (try interfaces.Node.get_ownerDocument(selected)) orelse return error.InvalidStateError;
    const fragment = try interfaces.Document.call_createDocumentFragment(document);
    const generation = runtime.SlabAllocator.generationOf(fragment);
    defer dom.node_creation.releaseIfUnwrapped(fragment, generation);
    // 2. For each child of option's children: clone it with subtree set to
    // true, and append the clone to documentFragment.
    var child = try interfaces.Node.get_firstChild(selected);
    while (child) |node| : (child = try interfaces.Node.get_nextSibling(node)) {
        _ = try dom.node_creation.clone(node, document, true, fragment);
    }
    // 3. Let removedElements be all elements that are shadow-including
    // descendants of documentFragment and are script, SVG script, frame,
    // iframe, embed, or object elements, in shadow-including tree order.
    // (whatwg/html#13201: a clone never runs a script or makes a frame.)
    const fragment_base = try nodeBase(fragment);
    var removed: std.ArrayListUnmanaged(*dom.NodeBase) = .empty;
    defer removed.deinit(content.ctx.allocator);
    try collectOmitted(content.ctx.allocator, fragment_base, &removed);
    // 4. For each element of removedElements: remove element.
    for (removed.items) |element| try dom.mutation.remove(element, false);
    // 5. Replace all with documentFragment within selectedcontent.
    try dom.mutation.replaceAll(@as(?*dom.NodeBase, fragment_base), parent);
}

/// HTML "update a select's descendant selectedcontent elements", steps 1-4,
/// with "update a selectedcontent" (steps 1-4) for each one.
/// Updating contents cannot change this traversal: those subtrees, option
/// subtrees and nested selects contain only disabled selectedcontent. The
/// internal DOM operations enqueue custom reactions instead of running them.
pub fn updateAll(select: *runtime.Instance) !void {
    // 1. Set select's pending selectedcontent update to false.
    dom.form_controls.setSelectedcontentPending(select, false) catch {};
    // Fast path: no descendant selectedcontent, nothing to update.
    if (!dom.form_controls.selectedcontentInterest(select)) return;
    // 2. If select has the multiple attribute, then return.
    if (associated.hasAttribute(select, "multiple")) return;
    // 3-4. Each descendant selectedcontent whose disabled is false, in tree
    // order: update a selectedcontent - clone the first selected option into
    // it, or clear it when there is none. Cloning changes no selectedness,
    // so the first selected option is found once.
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

/// The queued microtask of "queue an update of a select's descendant
/// selectedcontent elements", step 3. A stable TaskHold keeps the select
/// until it runs or the engine's dropped-reaction callback ends it.
const Update = struct {
    allocator: std.mem.Allocator,
    select: dom.node_holds.TaskHold = .{},

    const steps: engine.PromiseReactionSteps = .{ .fulfilled = fulfilled, .dropped = dropped };

    fn destroy(self: *Update) void {
        self.select.release();
        self.allocator.destroy(self);
    }

    fn fulfilled(data: ?*anyopaque, _: runtime.JSValue) void {
        const self: *Update = @ptrCast(@alignCast(data.?));
        defer self.destroy();
        const select = self.select.get() orelse return;
        // 3.1. If select's pending selectedcontent update is false, then
        // return: an update ran in the meantime (the option or selectedcontent
        // post-connection steps, a reset, a selectedness change).
        if (!dom.form_controls.selectedcontentPending(select)) return;
        // 3.2. Update a select's descendant selectedcontent elements.
        updateAll(select) catch {};
    }

    fn dropped(data: ?*anyopaque) void {
        const self: *Update = @ptrCast(@alignCast(data.?));
        self.destroy();
    }
};

/// HTML "queue an update of a select's descendant selectedcontent elements"
/// given select, steps 1-3. Explicit allocation domain lets all-OOM tests
/// cover the continuation. The engine runs exactly one fulfilled/dropped
/// callback after a successful handoff; on error this function still owns
/// and releases the record, and the flag goes back to false so a later
/// request queues again.
pub fn queueUpdate(allocator: std.mem.Allocator, select: *runtime.Instance) !void {
    // 1. If select's pending selectedcontent update is true or select has no
    // descendant selectedcontent elements, then return.
    if (dom.form_controls.selectedcontentPending(select)) return;
    if (!dom.form_controls.selectedcontentInterest(select)) return;
    // 2. Set select's pending selectedcontent update to true.
    try dom.form_controls.setSelectedcontentPending(select, true);
    // A realm without an engine runs no microtask: the flag stays set, and
    // the post-connection steps that read it still perform the update.
    if (!select.ctx.hasEngine()) return;
    errdefer dom.form_controls.setSelectedcontentPending(select, false) catch {};
    // 3. Queue a microtask (Update.fulfilled).
    const update = try allocator.create(Update);
    update.* = .{ .allocator = allocator };
    update.select.take(select);
    errdefer update.destroy();
    try engine.queueRealmMicrotask(select.ctx, &Update.steps, update);
}
