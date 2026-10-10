//! Implementation for HTMLOptionElement interface
//!
//! This file owns the SELECTION MODEL for `<select>`/`<option>`: the list of
//! options, selectedness, dirtiness, and the lazily-evaluated form of the
//! selectedness setting algorithm ("ask for a reset"). `HTMLSelectElement.zig`
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

const ElementImpl = @import("Element.zig");
const NodeImpl = @import("Node.zig");
// A Text node's data lives in CharacterData's inline/heap storage, NOT in
// Node.InternalState.node_value - that field stays null for parsed and
// created text alike, so reading it yields "" for every option. Node.zig's own
// collectTextContent goes through here for the same reason.
const CharacterDataImpl = @import("CharacterData.zig");

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
/// address and is process-global, like the shared registry it replaces.
///
/// TODO: the same alloc/free pair is in HTMLInputElement.zig, HTMLFormElement.zig
/// and ~17 other impls. This is a local workaround, not the fix; the fix is in
/// whatever holds a block past `ArenaAllocator.destroy`.
const StateMap = struct {
    var map: ?std.AutoHashMap(usize, InternalState) = null;

    fn ensure() *std.AutoHashMap(usize, InternalState) {
        if (map == null) {
            map = std.AutoHashMap(usize, InternalState).init(std.heap.page_allocator);
        }
        return &map.?;
    }

    fn put(instance: *runtime.Instance, value: InternalState) !void {
        try ensure().put(@intFromPtr(instance), value);
    }

    fn get(instance: *runtime.Instance) ?*InternalState {
        return ensure().getPtr(@intFromPtr(instance));
    }

    /// The entry for `instance`, creating a default one if this is the first
    /// write. Nothing is stored until something assigns, so a parser-created
    /// element that script never touches costs nothing at all.
    fn getOrPut(instance: *runtime.Instance) !*InternalState {
        const entry = try ensure().getOrPut(@intFromPtr(instance));
        if (!entry.found_existing) entry.value_ptr.* = .{};
        return entry.value_ptr;
    }

    fn remove(instance: *runtime.Instance) ?InternalState {
        if (ensure().fetchRemove(@intFromPtr(instance))) |kv| return kv.value;
        return null;
    }

    /// Forget every entry. The states own nothing heap-allocated.
    fn sweep() void {
        if (map) |*m| m.clearRetainingCapacity();
    }
};

/// dom.teardown_sweeps: the options no teardown reached - nodes no exit
/// frees - leave the map with the browser, rather than as stale entries a new
/// option of the next browser could be born under.
fn cleanupAllRemainingInternal() void {
    StateMap.sweep();
}

/// https://html.spec.whatwg.org/multipage/form-elements.html#concept-option-selectedness
///
/// An option's selectedness is NOT a reflection of the `selected` content
/// attribute. It starts out tracking that attribute and detaches permanently
/// once anything assigns to `option.selected` - the DIRTINESS flag. On top of
/// that sits the select's reset algorithm, which can select an option that was
/// never marked selected at all.
///
/// Four states rather than a bool-plus-flag, because the two ways of clearing an
/// option differ in one observable respect:
///
///   * `option.selected = false` asks the owning select for a reset, so a
///     single-select immediately re-selects its first enabled option.
///   * `select.value = <no match>` and `select.selectedIndex = -1` do NOT ask for
///     a reset - the spec allows them to leave nothing selected at all, and
///     `selected-index.html` asserts exactly that (`selectedIndex == -1`,
///     `value == ""`).
///
/// Collapsing those two into one "false" makes one of the two tests fail
/// whichever way the reset is then applied.
pub const Selectedness = enum {
    /// Nothing has assigned: follows the `selected` content attribute, and the
    /// option is still eligible for the reset algorithm's auto-selection.
    clean,
    /// Explicitly selected, by `option.selected = true` or by
    /// `select.value`/`select.selectedIndex` picking this option.
    on,
    /// Explicitly deselected by `option.selected = false`. Ask-for-a-reset still
    /// applies afterwards.
    off,
    /// Deselected by `select.value`/`select.selectedIndex`, which do not ask for
    /// a reset. Nothing is auto-selected in their wake.
    off_no_reset,
};

/// Internal state for HTMLOptionElement.
///
/// One byte, deliberately: `InternalState = struct {}` is zero-sized and used to
/// abort the process on `createIn` before 75dac607a.
pub const InternalState = struct {
    selectedness: Selectedness = .clean,
};

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // The select element's reset algorithm is this file's, as the rest of
    // the selection model is: installed before any option exists.
    @import("dom").form_controls.install(.{ .is = &isSelectElement, .reset = &resetSelect, .selected_index = &selectedIndex, .set_selected_index = &setSelectedIndex });
    @import("dom").teardown_sweeps.install(&cleanupAllRemainingInternal);
}

/// Initialize instance (creates the instance)
/// Chains to parent class: HTMLElement -> Element -> Node -> EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {

    // Chain to parent class (HTMLElement)
    const HTMLElementImpl = @import("HTMLElement.zig");
    const instance = try HTMLElementImpl.init(allocator, StateType, vtable, ctx);
    errdefer interfaces.HTMLElement.deinit(instance);

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
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // The state owns nothing heap-allocated, so dropping the entry is all of it.
    _ = StateMap.remove(instance);

    const HTMLElementImpl = @import("HTMLElement.zig");
    HTMLElementImpl.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &HTMLOptionElement.vtable, ctx);
    errdefer deinit(instance);

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
    const node_type = NodeImpl.getNodeType(node) orelse return null;
    if (node_type != NodeImpl.NodeType.ELEMENT_NODE) return null;
    const elem_internal = ElementImpl.getInternal(node) orelse return null;
    return elem_internal.local_name.asSlice();
}

fn isElementNamed(node: *runtime.Instance, name: []const u8) bool {
    const local = localName(node) orelse return false;
    return std.ascii.eqlIgnoreCase(local, name);
}

fn hasAttr(instance: *runtime.Instance, comptime attr: []const u8) bool {
    const elem_internal = ElementImpl.getInternal(instance) orelse return false;
    return elem_internal.findAttribute(null, attr) != null;
}

fn attrValue(instance: *runtime.Instance, comptime attr: []const u8) ?[]const u8 {
    const elem_internal = ElementImpl.getInternal(instance) orelse return null;
    const entry = elem_internal.findAttribute(null, attr) orelse return null;
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
pub fn ownerSelect(option: *runtime.Instance) ?*runtime.Instance {
    var optgroups: u32 = 0;
    var parent = NodeImpl.getParent(option);
    while (parent) |node| {
        if (localName(node)) |name| {
            if (std.ascii.eqlIgnoreCase(name, "select")) {
                return if (optgroups <= 1) node else null;
            }
            if (std.ascii.eqlIgnoreCase(name, "datalist") or
                std.ascii.eqlIgnoreCase(name, "option") or
                std.ascii.eqlIgnoreCase(name, "hr"))
            {
                return null;
            }
            if (std.ascii.eqlIgnoreCase(name, "optgroup")) optgroups += 1;
        }
        parent = NodeImpl.getParent(node);
    }
    return null;
}

// ---------------------------------------------------------------------------
// Selectedness
// ---------------------------------------------------------------------------

/// What an option says about itself, before the select's reset algorithm.
pub const Explicit = enum { on, off, off_no_reset, absent };

fn isSelectElement(element: *runtime.Instance) bool {
    return element.stateAs(interfaces.HTMLSelectElement.State) != null;
}

/// dom.form_controls, for select elements: "The reset algorithm for a select
/// element selectElement is: 1. Set selectElement's user validity to false.
/// 2. For each optionElement of selectElement's list of options: if
/// optionElement has a selected attribute, then set optionElement's
/// selectedness to true; otherwise set it to false; and set optionElement's
/// dirtiness to false. 3. Run the selectedness setting algorithm given
/// selectElement." A clean option IS its selected attribute, and the
/// selectedness setting algorithm runs whenever selectedness is read.
fn resetSelect(select: *runtime.Instance) void {
    const allocator = select.ctx.allocator;
    var options = std.ArrayListUnmanaged(*runtime.Instance).empty;
    defer options.deinit(allocator);
    collectOptions(select, allocator, &options) catch return;
    for (options.items) |option| _ = StateMap.remove(option);
}

// The select's non-IDL steps keep this owner’s lazy selectedness model.
fn selectedIndex(select: *runtime.Instance) !?usize {
    var options: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer options.deinit(select.ctx.allocator);
    try collectOptions(select, select.ctx.allocator, &options);
    return selectedIndexOf(select, options.items);
}

fn setSelectedIndex(select: *runtime.Instance, index: ?usize) !void {
    var options: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer options.deinit(select.ctx.allocator);
    try collectOptions(select, select.ctx.allocator, &options);
    for (options.items, 0..) |option, i| {
        try setSelectedness(option, if (index) |selected| (if (selected == i) .on else .off) else .off_no_reset);
    }
}

/// The option's own selectedness, which never consults the owning select - that
/// is what keeps `get_selected` from recursing through its siblings.
fn explicitSelectedness(option: *runtime.Instance) Explicit {
    if (StateMap.get(option)) |internal| {
        switch (internal.selectedness) {
            .on => return .on,
            .off => return .off,
            .off_no_reset => return .off_no_reset,
            .clean => {},
        }
    }
    // Clean: track the `selected` content attribute. A boolean attribute is true
    // by PRESENCE, so selected="false" is still true.
    if (hasAttr(option, "selected")) return .on;
    return .absent;
}

/// Record an explicit selectedness. Used by `option.selected` and, through this
/// module, by `select.value` / `select.selectedIndex`.
fn setSelectedness(option: *runtime.Instance, state: Selectedness) !void {
    const internal = try StateMap.getOrPut(option);
    internal.selectedness = state;
}

/// https://html.spec.whatwg.org/multipage/form-elements.html#concept-option-disabled
///
/// The `disabled` attribute on the option, or on an ancestor optgroup. The spec
/// walks ancestors in reverse tree order and stops at select/hr/datalist/option;
/// within a select that is the parent optgroup, so the loop below stops there
/// too.
pub fn optionIsDisabled(option: *runtime.Instance) bool {
    if (hasAttr(option, "disabled")) return true;
    var parent = NodeImpl.getParent(option);
    while (parent) |node| {
        if (localName(node)) |name| {
            if (std.ascii.eqlIgnoreCase(name, "optgroup")) {
                if (hasAttr(node, "disabled")) return true;
            } else {
                return false;
            }
        }
        parent = NodeImpl.getParent(node);
    }
    return false;
}

/// https://html.spec.whatwg.org/multipage/form-elements.html#concept-select-size
///
/// 1 unless `size` parses as a positive integer. size="0" behaves as 1, which is
/// what browsers do and what keeps `<select size=0><option>` selecting its
/// option.
pub fn displaySize(select: *runtime.Instance) u32 {
    const raw = attrValue(select, "size") orelse return 1;
    const parsed = std.fmt.parseInt(u32, std.mem.trim(u8, raw, " \t\n\r\x0C"), 10) catch return 1;
    return if (parsed == 0) 1 else parsed;
}

/// https://html.spec.whatwg.org/multipage/form-elements.html#selectedness-setting-algorithm
///
/// The reset algorithm, evaluated LAZILY at read time instead of on every DOM
/// mutation. The spec model runs it whenever an option is inserted, removed or
/// toggled; nothing in this tree notifies an impl of those, so instead the same
/// predicate is applied to the current list of options on each read. The
/// observable result is the same, and `<select><option>a</option></select>`
/// reports `value == "a"` rather than "" - which is the case React hits first.
///
/// Returns the index into `options` of the selected option, or null when nothing
/// is selected.
fn selectedIndexOf(select: *runtime.Instance, options: []const *runtime.Instance) ?usize {
    var first_on: ?usize = null;
    var last_on: ?usize = null;
    var any_no_reset = false;
    for (options, 0..) |option, i| {
        switch (explicitSelectedness(option)) {
            .on => {
                if (first_on == null) first_on = i;
                last_on = i;
            },
            .off_no_reset => any_no_reset = true,
            .off, .absent => {},
        }
    }

    // A multiple select gets no reset algorithm at all: any number of options
    // may be selected, and `value`/`selectedIndex` report the FIRST of them.
    if (hasAttr(select, "multiple")) return first_on;

    // Single select. The spec's step "if two or more options have selectedness
    // true, set all but the LAST to false" is what makes the last assignment
    // win, so resolve to the last rather than the first.
    if (last_on) |i| return i;

    // Nothing selected. Two ways to get here, and only one of them auto-selects.
    if (any_no_reset) return null;
    if (displaySize(select) != 1) return null;
    for (options, 0..) |option, i| {
        if (!optionIsDisabled(option)) return i;
    }
    return null;
}

// ---------------------------------------------------------------------------
// Text content
// ---------------------------------------------------------------------------

fn isAsciiWhitespace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == 0x0C;
}

/// Is this element one whose text `option.text` must not descend into?
///
/// HTML `script` and SVG `script`, but not MathML `script`. Note that an element
/// created by `createElementNS(null, "script")` is indistinguishable from an
/// HTML one here: `Element.InternalState.namespace_uri` is null for HTML
/// elements (see `Element.get_tagName`, which treats null as HTML), so the null
/// namespace cannot be told apart. The common case wins; the one WPT subtest
/// asserting the null-namespace script DOES recurse stays red until Element
/// stores the namespace explicitly.
fn isOpaqueScript(element: *runtime.Instance) bool {
    const local = localName(element) orelse return false;
    if (!std.ascii.eqlIgnoreCase(local, "script")) return false;
    const elem_internal = ElementImpl.getInternal(element) orelse return false;
    const ns = elem_internal.namespace_uri orelse return true; // implicit HTML
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
    var child = NodeImpl.getFirstChild(node);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.TEXT_NODE or
            node_type == NodeImpl.NodeType.CDATA_SECTION_NODE)
        {
            if (CharacterDataImpl.getData(c)) |data| {
                try out.appendSlice(allocator, data);
            }
        } else if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            if (!isOpaqueScript(c)) try collectHtmlAwareText(c, allocator, out);
        }
        child = NodeImpl.getNextSibling(c);
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

/// Getter for form: "If the option element has a select element as its
/// parent, or has an optgroup element as its parent and that optgroup element
/// has a select element as its parent, then the form IDL attribute must
/// return the same value as the form IDL attribute on that select element.
/// Otherwise, it must return null."
pub fn get_form(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    var parent = (interfaces.Node.get_parentNode(instance) catch null) orelse return null;
    if (isElementNamed(parent, "optgroup")) parent = (interfaces.Node.get_parentNode(parent) catch null) orelse return null;
    if (parent.stateAs(interfaces.HTMLSelectElement.State) == null) return null;
    return interfaces.HTMLSelectElement.get_form(parent);
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
    const explicit = explicitSelectedness(instance);

    const select = ownerSelect(instance) orelse return explicit == .on;

    // A multiple select never reduces the set, so the option's own answer stands.
    if (hasAttr(select, "multiple")) return explicit == .on;

    // Single select: exactly one option can be selected, and which one is the
    // reset algorithm's business rather than any single option's.
    const allocator = instance.ctx.allocator;
    var options = std.ArrayListUnmanaged(*runtime.Instance).empty;
    defer options.deinit(allocator);
    collectOptions(select, allocator, &options) catch return explicit == .on;

    const selected = selectedIndexOf(select, options.items) orelse return false;
    return options.items[selected] == instance;
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
    // Sets selectedness AND dirtiness, then asks for a reset - which is why
    // `false` maps to `.off` rather than `.off_no_reset`: a single select
    // re-selects its first enabled option immediately afterwards.
    try setSelectedness(instance, if (value) .on else .off);
}

/// Setter for text
pub fn set_text(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // "String replace all", i.e. exactly what textContent does: every child goes,
    // including the existing text node - `option-text-setter.html` asserts the
    // old text node is detached rather than updated in place.
    try interfaces.Node.set_textContent(instance, value);
}
