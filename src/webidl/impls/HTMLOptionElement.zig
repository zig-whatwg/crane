//! Implementation for HTMLOptionElement interface
//!
//! This file owns the SELECTION MODEL for `<select>`/`<option>`: the list of
//! options, selectedness, dirtiness, and the selectedness setting algorithm
//! ("ask for a reset"). `HTMLSelectElement.zig`
//! reaches its selection steps through dom.form_controls; the option owns
//! the state, while the shared forms helper owns option-list traversal.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLOptionElement = interfaces.HTMLOptionElement;
const log = std.log.scoped(.option);
const dom = @import("dom");
const selected_content = @import("html").forms.selected_content;
const option_list = @import("html").forms.options;
const controls = dom.form_controls;

// An element's local name, namespace and attributes, read in place
// (dom.element_data, which Element installs).
const element_data = @import("dom").element_data;
// A Text node's data lives in CharacterData's inline/heap storage, NOT in
// Node.InternalState.node_value - that field stays null for parsed and
// created text alike, so reading it yields "" for every option. It is read in
// place through dom.character_data, as Node.zig's collectTextContent reads it.

pub const State = HTMLOptionElement.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// Per-instance state, stored BY VALUE in a map of this module's own rather than
/// through `utils.InstanceRegistry`.
///
/// `InstanceRegistry.createIn` takes a block out of the process-wide
/// `ArenaAllocator` and hands it back on `remove`, so the block lands on a shared
/// size-class free list and is reissued to the next caller of that size. Adding
/// that alloc/free pair to an element the PARSER creates destabilised the DOM:
/// measured on the 5-file shard of html/semantics/forms/the-textarea-element/
/// containing textarea-minlength.html, 8 runs each, same tree, one file differing
///
///     textarea stubs (no state at all)          0 / 8 runs aborted
///     state via InstanceRegistry.createIn     1-7 / 8 runs aborted
///     state in this map (no arena block)        0 / 8 runs aborted
///
/// The abort was a SIGABRT from a SEGV in `Node.getFirstChild`, reading a
/// corrupted `node_base` under `Document.getElementsByTagName` in a LATER test
/// file - a block that had moved on being read or written through something's
/// stale view of it.
///
/// Storing the state inline in the map removes the arena from the picture
/// entirely: the map owns its own memory, so a stale entry can only ever give a
/// wrong answer, never corrupt a neighbour. The map is keyed on the instance
/// address and is its Browser's (a side table of its runtime.BrowserScope).
///
/// TODO: the same alloc/free pair is in HTMLInputElement.zig, HTMLFormElement.zig
/// and ~17 other impls. This is a local workaround, not the fix; the fix is in
/// whatever holds a block past `ArenaAllocator.destroy`.
const StateMap = struct {
    /// One Browser's table - a side table of its runtime.BrowserScope, so
    /// its entries are its own and end with it (instances B1) - with its
    /// tombstones kept in check: every option script writes to enters it at
    /// an address it has usually never seen and leaves it at its teardown
    /// (dom.InstanceStateMap; src/infra/tombstones.zig).
    const Table = dom.InstanceStateMap(InternalState);

    /// `instance`'s Browser's table, made on first use.
    fn ensure(instance: *runtime.Instance) !*Table {
        return runtime.BrowserScope.ofInstance(instance).table(.option_states, Table);
    }

    /// `instance`'s Browser's table, if it has one.
    fn existing(instance: *runtime.Instance) ?*Table {
        return runtime.BrowserScope.ofInstance(instance).existingTable(.option_states, Table);
    }

    fn put(instance: *runtime.Instance, value: InternalState) !void {
        try (try ensure(instance)).put(instance, value);
    }

    /// BORROWED until the next `put` or `getOrPut`, which may move every
    /// entry (a growth or a rehash).
    fn get(instance: *runtime.Instance) ?*InternalState {
        return (existing(instance) orelse return null).get(instance);
    }

    fn remove(instance: *runtime.Instance) ?InternalState {
        return (existing(instance) orelse return null).remove(instance);
    }

    /// Forget every one of `scope`'s entries (the states own nothing heap-allocated).
    fn sweep(scope: *runtime.BrowserScope) void {
        const table = scope.existingTable(.option_states, Table) orelse return;
        table.clear();
    }
};

/// dom.teardown_sweeps: the options no teardown reached - nodes no exit
/// frees - leave the map with the browser, rather than as stale entries a new
/// option of the next browser could be born under.
fn cleanupAllRemainingInternal(scope: *runtime.BrowserScope) void {
    StateMap.sweep(scope);
}

/// HTML option selectedness and dirtiness are independent scalars. The
/// existing BrowserScope map stores only selectedness differing from the
/// attribute, dirtiness, or the single select's processed selection. An implicit selection is a real stored bit,
/// so an unread option retains it when removed (row61 Q14/Q21).
pub const InternalState = struct {
    selectedness: bool = false,
    dirtiness: bool = false,
    /// Selected and processed by a single select. Later, unprocessed members
    /// of one DOM insertion batch must retain their initial selectedness.
    settled: bool = false,
};

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // The select element's reset algorithm is this file's, as the rest of
    // the selection model is: installed before any option exists.
    controls.install(.{ .is = &isSelectElement, .reset = &resetSelect, .selected_index = &selectedIndex, .set_selected_index = &setSelectedIndex, .pick_option = &pickOption, .selection_invariant = &selectionInvariant });
    @import("dom").teardown_sweeps.install(.element_types, &cleanupAllRemainingInternal);
    dom.attribute_change_steps.install("option", &optionAttributeChanged);
    dom.attribute_change_steps.install("select", &selectAttributeChanged);
    dom.attribute_change_steps.install("optgroup", &optgroupAttributeChanged);
    dom.finish_parsing_children.install("option", .{ .finished = &finishedParsingChildren });
    dom.mutation.registerPostConnectionStepsCallback(&postConnectionSteps) catch {};
    dom.mutation.registerInsertionStepsCallback(&insertionSteps) catch {};
    dom.mutation.registerRemovingStepsCallback(&removingSteps) catch {};
    dom.mutation.registerMovingStepsCallback(&movingSteps) catch {};
}

fn finishedParsingChildren(option: *runtime.Instance) void {
    const select = ownerSelect(option) orelse return;
    if (!dom.form_controls.selectedcontentInterest(select)) return;
    if (!(get_selected(option) catch false)) return;
    selected_content.updateAll(select) catch {};
}

fn postConnectionSteps(node: *dom.NodeBase) void {
    if (node.node_type != interfaces.Node.get_ELEMENT_NODE()) return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return));
    if (instance.stateAs(State) == null) return;
    // HTML option post-connection steps and parser-pop steps run the same
    // update, only after the tree is consistent and only for a selected option.
    finishedParsingChildren(instance);
}

/// HTMLOptionElement's own construction steps: the generated chain runs HTMLElement's first.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = StateType;
    _ = args;
    // A new option at this address: an entry already under it is a dead
    // option's that a teardown missed. `StateMap` fills lazily, so left in
    // place it would be taken for this one's - a selectedness nobody set
    // (docs/lessons/architecture-an-address-keyed-entry-a-teardown-misses-is-inherited.md).
    if (StateMap.remove(instance) != null) {
        log.err("stale HTMLOptionElement state at a reissued address: a teardown missed it", .{});
    }

    // No state is recorded here on purpose: `StateMap` fills in lazily on the
    // first assignment, so an element the parser created and script never
    // touched allocates nothing and leaves nothing to clean up.
}

/// HTMLOptionElement's own teardown: the generated chain runs HTMLElement's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    // The state owns nothing heap-allocated, so dropping the entry is all of it.
    _ = StateMap.remove(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try HTMLOptionElement.init(ctx.allocator, ctx);
    errdefer HTMLOptionElement.deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

// ---------------------------------------------------------------------------
// Tree helpers
// ---------------------------------------------------------------------------

const HTML_NAMESPACE = "http://www.w3.org/1999/xhtml";
const SVG_NAMESPACE = "http://www.w3.org/2000/svg";

/// The element's local name, or null when `node` is not an element.
fn localName(node: *runtime.Instance) ?[]const u8 {
    const node_type = interfaces.Node.get_nodeType(node) catch return null;
    if (node_type != interfaces.Node.get_ELEMENT_NODE()) return null;
    const data = element_data.of(node) orelse return null;
    return data.local_name.asSlice();
}

fn isElementNamed(node: *runtime.Instance, name: []const u8) bool {
    const local = localName(node) orelse return false;
    return std.ascii.eqlIgnoreCase(local, name);
}

fn hasAttr(instance: *runtime.Instance, comptime attr: []const u8) bool {
    const data = element_data.of(instance) orelse return false;
    return element_data.hasAttribute(data, attr);
}

fn attrValue(instance: *runtime.Instance, comptime attr: []const u8) ?[]const u8 {
    const data = element_data.of(instance) orelse return null;
    const entry = element_data.getAttributeByNamespaceAndLocalName(data, null, attr) orelse return null;
    return entry.value;
}

/// https://html.spec.whatwg.org/multipage/form-elements.html#concept-select-option-list
///
/// A pre-order DESCENDANT walk of the select, not a scan of its children: an
/// option nested inside a `div` inside the select is still in the list, which
/// `select-value.html` ("option is child of div") asserts outright. The walk
/// skips the subtree of a nested `select`, an `hr`, a `datalist`, an `option`,
/// and a NESTED `optgroup`.
const collectOptions = @import("html").forms.options.collect;

/// The select whose list of options contains `option`, or null.
///
/// Walks ancestors rather than re-running `collectOptions`, stopping at the same
/// elements that stop the forward walk so the two agree.
const ownerSelect = @import("html").forms.select_picker.ownerSelect;

// ---------------------------------------------------------------------------
// Selectedness
// ---------------------------------------------------------------------------

/// What an option says about itself, before the select's reset algorithm.
fn isSelectElement(element: *runtime.Instance) bool {
    return element.stateAs(interfaces.HTMLSelectElement.State) != null;
}

/// dom.form_controls, for select elements: "The reset algorithm for a select
/// element selectElement is: 1. Set selectElement's user validity to false.
/// 2. For each optionElement of selectElement's list of options: if
/// optionElement has a selected attribute, then set optionElement's
/// selectedness to true; otherwise set it to false; and set optionElement's
/// dirtiness to false. 3. Run the selectedness setting algorithm given
/// selectElement." Removing sparse entries restores the attributes, then
/// the algorithm records its implicit selection before returning.
fn resetSelect(select: *runtime.Instance) void {
    // HTML select reset step 1: false never allocates owner state.
    controls.setUserValidity(select, false) catch return;
    // Reset steps 2–3 can share one borrowed traversal: no script runs
    // between clearing dirtiness and normalizing selectedness. Avoid a
    // temporary option list and re-reading every now-absent sparse entry.
    // These pointers live only on this stack, during the existing tree walk.
    const Reset = struct {
        multiple: bool,
        first: ?*runtime.Instance = null,
        last: ?*runtime.Instance = null,

        fn visit(self: *@This(), option: *runtime.Instance) !void {
            // Reset step 2: removing the override restores the selected
            // attribute and clears dirtiness and insertion settledness.
            _ = StateMap.remove(option);
            if (hasAttr(option, "selected")) {
                // Selectedness setting step 5.1: the last selected option
                // wins in a single select, including a disabled one.
                if (!self.multiple) if (self.last) |previous|
                    try writeSelection(previous, false, false, false);
                self.last = option;
            }
            // Step 5.2: only a single select needs a default candidate.
            if (!self.multiple and self.first == null and !optionIsDisabled(option)) self.first = option;
        }
    };
    var reset: Reset = .{ .multiple = hasAttr(select, "multiple") };
    @import("html").forms.options.forEach(select, &reset, Reset.visit) catch return;
    if (!reset.multiple) {
        // Step 6: select the first enabled option only when no selected
        // attribute won and this is a one-row select.
        if (reset.last == null and displaySize(select) == 1) reset.last = reset.first;
        if (reset.last) |selected| writeSelection(selected, true, false, true) catch return;
    }
    controls.setHasSelectedOption(select, reset.last != null) catch return;
    // HTML select reset algorithm, step 4.
    selected_content.updateAll(select) catch {};
}

// The select's non-IDL steps read this owner's selection model once.
fn selectedIndex(select: *runtime.Instance) !?usize {
    var options: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer options.deinit(select.ctx.allocator);
    try collectOptions(select, select.ctx.allocator, &options);
    return selectedIndexOf(options.items);
}

fn setSelectedIndex(select: *runtime.Instance, index: ?usize) !void {
    var options: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer options.deinit(select.ctx.allocator);
    try collectOptions(select, select.ctx.allocator, &options);
    const matching = if (index) |i| (if (i < options.items.len) index else null) else null;
    for (options.items, 0..) |option, i| {
        const selected = matching != null and matching.? == i;
        // The selected index/value setter dirties only the matching option.
        try writeSelection(option, selected, if (selected) true else null, selected and !hasAttr(select, "multiple"));
    }
    try controls.setHasSelectedOption(select, matching != null);
    // HTML set selected index and value setters, step 4.
    try selected_content.updateAll(select);
}

fn ownSelectedness(option: *runtime.Instance) bool {
    if (StateMap.get(option)) |state| return state.selectedness;
    return hasAttr(option, "selected");
}

fn isSettled(option: *runtime.Instance) bool {
    return if (StateMap.get(option)) |state| state.settled else false;
}

/// Null flags preserve them; false selectedness always clears settledness.
/// Copy before a possible map growth; no
/// borrowed value pointer survives writing another option's entry.
fn writeSelection(option: *runtime.Instance, selected: bool, dirtiness: ?bool, settled: ?bool) !void {
    if (StateMap.get(option)) |state| {
        const dirty = dirtiness orelse state.dirtiness;
        const processed = selected and (settled orelse state.settled);
        if (dirty or processed or selected != hasAttr(option, "selected")) {
            // No allocation or other option write while this value is
            // borrowed. The common dirty-setter path needs one map lookup.
            state.* = .{ .selectedness = selected, .dirtiness = dirty, .settled = processed };
            return;
        }
        _ = StateMap.remove(option);
        return;
    }
    const dirty = dirtiness orelse false;
    const processed = selected and (settled orelse false);
    if (!dirty and !processed and selected == hasAttr(option, "selected")) return;
    try StateMap.put(option, .{ .selectedness = selected, .dirtiness = dirty, .settled = processed });
}

fn deselectOthers(options: []const *runtime.Instance, chosen: *runtime.Instance) !void {
    return deselectOthersForInsertion(options, chosen, false);
}

fn deselectOthersForInsertion(options: []const *runtime.Instance, chosen: *runtime.Instance, inserting: bool) !void {
    var after_chosen = false;
    for (options) |option| if (option != chosen) {
        // DOM insert step 7 processes fragment children in order. Crane's
        // batch links them first; later unprocessed selected options have
        // not reached their own insertion steps yet (row61 Q25).
        if (inserting and after_chosen and ownSelectedness(option) and !isSettled(option)) continue;
        try writeSelection(option, false, null, false);
    } else {
        after_chosen = true;
    };
}

fn pickOption(select: *runtime.Instance, option: *runtime.Instance, toggle: bool) !void {
    var options: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer options.deinit(select.ctx.allocator);
    try collectOptions(select, select.ctx.allocator, &options);
    if (std.mem.indexOfScalar(*runtime.Instance, options.items, option) == null) return;
    const selected = if (toggle) !ownSelectedness(option) else true;
    try writeSelection(option, selected, true, selected and !hasAttr(select, "multiple"));
    if (selected and !hasAttr(select, "multiple")) try deselectOthers(options.items, option);
    try controls.setHasSelectedOption(select, selectedIndexOf(options.items) != null);
    // Pick/toggle does not ask for reset or update selectedcontent inline:
    // those notifications belong to the queued element task (row61 Q3(c)).
}

fn optionAttributeChanged(option: *runtime.Instance, name: []const u8, old: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    if (namespace != null or (old != null) == (value != null)) return;
    if (std.mem.eql(u8, name, "disabled")) {
        resetAfterDisabledChange(option);
        return;
    }
    if (!std.mem.eql(u8, name, "selected")) return;
    // The hook runs after the attribute write. A stored bit preserves the
    // old selection, otherwise the previous attribute gives it.
    const previous = if (StateMap.get(option)) |state| state.* else InternalState{ .selectedness = old != null };
    var changed = false;
    if (!previous.dirtiness) {
        changed = previous.selectedness != (value != null);
        _ = StateMap.remove(option);
    }
    const select = ownerSelect(option) orelse return;
    var options: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer options.deinit(select.ctx.allocator);
    collectOptions(select, select.ctx.allocator, &options) catch return;
    if (changed and value != null and !hasAttr(select, "multiple")) deselectOthers(options.items, option) catch return;
    changed = (setSelectednessForList(select, options.items) catch return) or changed;
    if (changed) selected_content.updateAll(select) catch {};
}

fn resetAfterDisabledChange(node: *runtime.Instance) void {
    const select = ownerSelect(node) orelse return;
    var options: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer options.deinit(select.ctx.allocator);
    collectOptions(select, select.ctx.allocator, &options) catch return;
    // Reset selectedness uses the stored bits, not a guess from the NEW
    // disabled attributes. Only an actual selection change clones content.
    if (setSelectednessForList(select, options.items) catch return) selected_content.updateAll(select) catch {};
}

fn optgroupAttributeChanged(group: *runtime.Instance, name: []const u8, old: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    if (namespace == null and std.mem.eql(u8, name, "disabled") and (old != null) != (value != null)) resetAfterDisabledChange(group);
}

fn parsedSize(value: ?[]const u8, multiple: bool) u32 {
    const fallback: u32 = if (multiple) 4 else 1;
    const raw = value orelse return fallback;
    const parsed = std.fmt.parseInt(u32, std.mem.trim(u8, raw, " \t\n\r\x0c"), 10) catch return fallback;
    return if (parsed == 0) fallback else parsed;
}

fn selectAttributeChanged(select: *runtime.Instance, name: []const u8, old: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    if (namespace != null) return;
    const multiple_change = std.mem.eql(u8, name, "multiple");
    if (!multiple_change and !std.mem.eql(u8, name, "size")) return;
    if (multiple_change and (old != null) == (value != null)) return;
    var options: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer options.deinit(select.ctx.allocator);
    collectOptions(select, select.ctx.allocator, &options) catch return;
    // A parser assigns attributes before adding options: preserve that
    // empty-list fast path, with nothing to reset or clone.
    if (options.items.len == 0) return;
    if (multiple_change and value == null) {
        var seen = false;
        for (options.items) |option| {
            if (ownSelectedness(option)) {
                if (seen) writeSelection(option, false, null, false) catch return;
                seen = true;
            }
        }
    }
    const changed = setSelectednessForList(select, options.items) catch return;
    if (changed or multiple_change) selected_content.updateAll(select) catch {};
}

/// Selectedness setting algorithm, steps 1–7. Dirtiness is unaffected.
fn setSelectednessForList(select: *runtime.Instance, options: []const *runtime.Instance) !bool {
    return setSelectednessForInsertion(select, options, null);
}

fn setSelectednessForInsertion(select: *runtime.Instance, options: []const *runtime.Instance, inserted: ?*runtime.Instance) !bool {
    if (hasAttr(select, "multiple")) {
        for (options) |option| if (isSettled(option)) try writeSelection(option, ownSelectedness(option), null, false);
        try controls.setHasSelectedOption(select, selectedIndexOf(options) != null);
        return false;
    }
    var last: ?*runtime.Instance = null;
    var first: ?*runtime.Instance = null;
    var changed = false;
    var after_inserted = false;
    for (options) |option| {
        if (option == inserted) {
            after_inserted = true;
        } else if (after_inserted and ownSelectedness(option) and !isSettled(option)) continue;
        if (ownSelectedness(option)) {
            if (last) |previous| {
                try writeSelection(previous, false, null, false);
                changed = true;
            }
            last = option;
        }
        if (first == null and !optionIsDisabled(option)) first = option;
    }
    if (last == null and first != null and displaySize(select) == 1) {
        try writeSelection(first.?, true, null, true);
        last = first;
        changed = true;
    }
    if (last) |selected| try writeSelection(selected, true, null, true);
    try controls.setHasSelectedOption(select, last != null);
    return changed;
}

/// https://html.spec.whatwg.org/multipage/form-elements.html#concept-option-disabled
///
/// The shared algorithm also serves focusability, keeping wrapper and
/// nearest-optgroup handling identical to default selection.
pub fn optionIsDisabled(option: *runtime.Instance) bool {
    return @import("html").forms.options.isDisabled(option);
}

/// https://html.spec.whatwg.org/multipage/form-elements.html#concept-select-size
///
/// Defaults to 1 for a single select and 4 for a multiple select. Preserve
/// the browser size="0" default used by the existing selection model.
pub fn displaySize(select: *runtime.Instance) u32 {
    return parsedSize(attrValue(select, "size"), hasAttr(select, "multiple"));
}

/// Reads never select or normalize: insertion and reset already did so.
fn selectedIndexOf(options: []const *runtime.Instance) ?usize {
    for (options, 0..) |option, i| {
        if (ownSelectedness(option)) return i;
    }
    return null;
}

fn optionInstance(node: *dom.NodeBase) ?*runtime.Instance {
    if (node.node_type != interfaces.Node.get_ELEMENT_NODE()) return null;
    const instance: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return null));
    return if (instance.stateAs(State) != null) instance else null;
}

/// HTML option insertion: update its owner, run selectedness setting, and
/// intentionally leave cloning to the selected option's post-connection step.
fn insertedInto(select: *runtime.Instance, option: *runtime.Instance) !bool {
    const selected = ownSelectedness(option);
    if (hasAttr(select, "multiple")) {
        if (selected) try controls.setHasSelectedOption(select, true);
        return false;
    }
    // Blink HTMLSelectElement::OptionInserted likewise avoids a reset for
    // an ordinary append when a selection already exists (row61 Q14).
    if (!selected and controls.hasSelectedOption(select)) return false;
    var options: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer options.deinit(select.ctx.allocator);
    try collectOptions(select, select.ctx.allocator, &options);
    // HTML 4.10.7: adding a selected option to a single select deselects
    // its other options, in DOM insertion order (row61 Q25).
    if (selected) try deselectOthersForInsertion(options.items, option, true);
    return try setSelectednessForInsertion(select, options.items, option);
}

fn insertionSteps(node: *dom.NodeBase) void {
    const option = optionInstance(node) orelse return;
    const select = ownerSelect(option) orelse return;
    // Updating the nearest ancestor select, step 4: insertion of a whole
    // select preserves its options' owner, including a cleared selection.
    if (controls.optionOwnerUnchanged(select)) return;
    _ = insertedInto(select, option) catch return;
}

/// Reconstruct only the old ancestor walk, replacing the edge the DOM just
/// changed. No owner pointer is cached. Removal passes the original parent
/// to each descendant; moveBefore passes it only for the moved subtree root.
fn ownerBeforeChange(option: *runtime.Instance, moved_root: ?*dom.NodeBase, old_parent: ?*dom.NodeBase) ?*runtime.Instance {
    var current = dom.instance_bridge.getNodeBase(option) orelse return null;
    var crossed = false;
    var optgroup = false;
    while (true) {
        // A shadow root ends the option-list ancestor walk.
        if (current.node_type == interfaces.Node.get_DOCUMENT_FRAGMENT_NODE() or current.node_type == interfaces.Node.get_DOCUMENT_NODE()) return null;
        const next = if (!crossed and (current == moved_root or (moved_root == null and current.parent_node == null))) blk: {
            crossed = true;
            break :blk old_parent;
        } else current.parent_node;
        current = next orelse return null;
        const ancestor: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(current) orelse return null));
        if (ancestor.stateAs(interfaces.HTMLDataListElement.State) != null or
            ancestor.stateAs(interfaces.HTMLHRElement.State) != null or
            ancestor.stateAs(State) != null) return null;
        if (ancestor.stateAs(interfaces.HTMLOptGroupElement.State) != null) {
            if (optgroup) return null;
            optgroup = true;
        }
        if (isSelectElement(ancestor)) return ancestor;
    }
}

fn changedOwner(option: *runtime.Instance, old_select: ?*runtime.Instance) void {
    const new_select = ownerSelect(option);
    if (old_select == new_select) return;
    if (isSettled(option)) writeSelection(option, ownSelectedness(option), null, false) catch return;
    if (old_select) |select| {
        var changed = false;
        if (ownSelectedness(option) or !controls.hasSelectedOption(select)) {
            var options: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
            defer options.deinit(select.ctx.allocator);
            collectOptions(select, select.ctx.allocator, &options) catch return;
            changed = setSelectednessForList(select, options.items) catch return;
        }
        if (ownSelectedness(option) or changed) selected_content.queueUpdate(select.ctx.allocator, select, null) catch {};
    }
    if (new_select) |select| {
        const changed = insertedInto(select, option) catch return;
        if (ownSelectedness(option) or changed) selected_content.queueUpdate(select.ctx.allocator, select, null) catch {};
    }
}

fn removingSteps(node: *dom.NodeBase, old_parent: ?*dom.NodeBase) void {
    const option = optionInstance(node) orelse return;
    changedOwner(option, ownerBeforeChange(option, null, old_parent));
}

fn movedOptions(node: *dom.NodeBase, root: *dom.NodeBase, old_parent: *dom.NodeBase) void {
    if (optionInstance(node)) |option| changedOwner(option, ownerBeforeChange(option, root, old_parent));
    for (node.child_nodes.items()) |child| movedOptions(child, root, old_parent);
}

fn movingSteps(node: *dom.NodeBase, old_parent: ?*dom.NodeBase) void {
    // Only the root receives the old parent. Walk its own subtree once;
    // descendant callbacks carry null and must not reset the same select again.
    movedOptions(node, node, old_parent orelse return);
}

/// Read-only diagnostic for native tests, never a production write-path
/// assertion. The option owner alone can inspect its private sparse map.
fn selectionInvariant(select: *runtime.Instance) bool {
    const Check = struct {
        any_selected: bool = false,
        settled_count: usize = 0,
        valid: bool = true,
        fn visit(self: *@This(), option: *runtime.Instance) anyerror!void {
            const selected = ownSelectedness(option);
            self.any_selected = self.any_selected or selected;
            if (isSettled(option)) {
                self.settled_count += 1;
                self.valid = self.valid and selected;
            }
        }
    };
    var check: Check = .{};
    option_list.forEach(select, &check, Check.visit) catch return false;
    return check.valid and check.any_selected == controls.hasSelectedOption(select) and
        check.settled_count <= @as(usize, if (hasAttr(select, "multiple")) 0 else 1);
}

// ---------------------------------------------------------------------------
// Text content
// ---------------------------------------------------------------------------

fn isAsciiWhitespace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == 0x0C;
}

/// Is this element one whose text `option.text` must not descend into?
///
/// HTML `script` and SVG `script`, but not MathML or null-namespace `script`.
/// HTML-aware text step 2.1 tests the namespace and case-sensitive local name,
/// as Blink's IsScriptElement does. Element stores HTML's namespace explicitly.
fn isOpaqueScript(element: *runtime.Instance) bool {
    const local = localName(element) orelse return false;
    if (!std.mem.eql(u8, local, "script")) return false;
    const data = element_data.of(element) orelse return false;
    const ns = data.namespace_uri orelse return false;
    const slice = ns.asSlice();
    return std.mem.eql(u8, slice, HTML_NAMESPACE) or std.mem.eql(u8, slice, SVG_NAMESPACE);
}

/// https://html.spec.whatwg.org/multipage/form-elements.html#get-html-aware-text-content
///
/// The descendant text content, skipping opaque script subtrees. Comments and
/// processing instructions contribute nothing, which falls out of only
/// collecting Text and CDATA nodes.
fn collectHtmlAwareText(
    node: *runtime.Instance,
    allocator: std.mem.Allocator,
    out: *std.ArrayListUnmanaged(u8),
) !void {
    var child = interfaces.Node.get_firstChild(node) catch null;
    while (child) |c| {
        const node_type = interfaces.Node.get_nodeType(c) catch 0;
        if (node_type == interfaces.Node.get_TEXT_NODE() or
            node_type == interfaces.Node.get_CDATA_SECTION_NODE())
        {
            if (@import("dom").character_data.dataOf(c)) |data| {
                try out.appendSlice(allocator, data);
            }
        } else if (node_type == interfaces.Node.get_ELEMENT_NODE()) {
            if (!isOpaqueScript(c)) try collectHtmlAwareText(c, allocator, out);
        }
        child = interfaces.Node.get_nextSibling(c) catch null;
    }
}

/// https://infra.spec.whatwg.org/#strip-and-collapse-ascii-whitespace
///
/// Byte-wise on purpose: U+00A0 is 0xC2 0xA0 in UTF-8 and neither byte is ASCII
/// whitespace, so a non-breaking space survives untouched - four subtests in
/// `option-text-spaces.html` check precisely that.
fn stripAndCollapse(allocator: std.mem.Allocator, src: []const u8) ![]u8 {
    var out = std.ArrayListUnmanaged(u8).empty;
    errdefer out.deinit(allocator);

    var i: usize = 0;
    var pending_space = false;
    while (i < src.len) : (i += 1) {
        const c = src[i];
        if (isAsciiWhitespace(c)) {
            // Only emit a separator once something follows it, which also strips
            // the trailing run without a second pass.
            if (out.items.len != 0) pending_space = true;
            continue;
        }
        if (pending_space) {
            try out.append(allocator, ' ');
            pending_space = false;
        }
        try out.append(allocator, c);
    }
    return out.toOwnedSlice(allocator);
}

/// `option.text`: the stripped and collapsed HTML-aware text content.
fn optionText(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const allocator = instance.ctx.allocator;

    var raw = std.ArrayListUnmanaged(u8).empty;
    defer raw.deinit(allocator);
    try collectHtmlAwareText(instance, allocator, &raw);

    const collapsed = try stripAndCollapse(allocator, raw.items);
    if (collapsed.len == 0) {
        allocator.free(collapsed);
        return runtime.DOMString.initEmpty();
    }
    return runtime.DOMString.initOwned(collapsed);
}

// ---------------------------------------------------------------------------
// Reflection helpers
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// IDL attributes
// ---------------------------------------------------------------------------

/// HTML option form getter, steps 1–3 (cached 2026-10-17): return the
/// nearest ancestor select's form owner, or null when there is no such select.
pub fn get_form(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const select = ownerSelect(instance) orelse return null;
    return interfaces.HTMLSelectElement.get_form(select);
}

/// Getter for label
pub fn get_label(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // Attribute if present, INCLUDING when it is the empty string, otherwise the
    // option's text. `option-label.html` asserts "" for label="" and "child" for
    // an absent label over " child ".
    if (attrValue(instance, "label")) |value| {
        return runtime.DOMString.initDupe(instance.ctx.allocator, value) catch return error.OutOfMemory;
    }
    return optionText(instance);
}

/// Getter for selected
pub fn get_selected(instance: *runtime.Instance) anyerror!bool {
    return ownSelectedness(instance);
}

/// Getter for value
pub fn get_value(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // NOT plain reflection: with no `value` attribute the option's value is its
    // TEXT. An empty value="" is still an empty value, not a fallback.
    if (attrValue(instance, "value")) |value| {
        return runtime.DOMString.initDupe(instance.ctx.allocator, value) catch return error.OutOfMemory;
    }
    return optionText(instance);
}

/// Getter for text
pub fn get_text(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return optionText(instance);
}

/// Getter for index
pub fn get_index(instance: *runtime.Instance) anyerror!i32 {
    // The position in the owning select's list of options, and 0 for an option
    // that is not in one at all - including options in a datalist, which
    // `option-index.html` checks explicitly.
    const select = ownerSelect(instance) orelse return 0;

    const allocator = instance.ctx.allocator;
    var options = std.ArrayListUnmanaged(*runtime.Instance).empty;
    defer options.deinit(allocator);
    try collectOptions(select, allocator, &options);

    for (options.items, 0..) |option, i| {
        if (option == instance) return @intCast(i);
    }
    return 0;
}

/// Setter for selected
pub fn set_selected(instance: *runtime.Instance, value: bool) anyerror!void {
    if (ownerSelect(instance)) |select| {
        var options: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
        defer options.deinit(instance.ctx.allocator);
        try collectOptions(select, instance.ctx.allocator, &options);
        try writeSelection(instance, value, true, value and !hasAttr(select, "multiple"));
        // Whenever selectedness becomes true in a single select, deselect
        // every other option before the selectedness-setting algorithm.
        if (value and !hasAttr(select, "multiple")) try deselectOthers(options.items, instance);
        _ = try setSelectednessForList(select, options.items);
        try selected_content.updateAll(select);
    } else try StateMap.put(instance, .{ .selectedness = value, .dirtiness = true });
}

/// Setter for text
pub fn set_text(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // "String replace all", i.e. exactly what textContent does: every child goes,
    // including the existing text node - `option-text-setter.html` asserts the
    // old text node is detached rather than updated in place.
    try interfaces.Node.set_textContent(instance, value);
}
