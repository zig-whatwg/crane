//! Implementation for HTMLTextAreaElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLTextAreaElement = interfaces.HTMLTextAreaElement;

const ElementImpl = @import("Element.zig");
const NodeImpl = @import("Node.zig");
// A Text node's data lives in CharacterData's inline/heap storage, NOT in
// Node.InternalState.node_value - that field stays null for parsed and created
// text alike, so reading it yields "" for every textarea. Node.zig's own
// collectTextContent goes through here for the same reason.
const CharacterDataImpl = @import("CharacterData.zig");

pub const State = HTMLTextAreaElement.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
    /// An out-of-range assignment to cols/rows/maxLength/minLength. The name
    /// matters: it is the DOMException the binding maps it to.
    IndexSizeError,
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
};

/// https://html.spec.whatwg.org/multipage/form-elements.html#concept-textarea-raw-value
///
/// `value` is element state with a dirty value flag, exactly like
/// `input.value`: it starts out tracking the element's CHILD TEXT CONTENT and
/// detaches permanently once anything assigns to it.
///
///     <textarea>a</textarea>        .value -> "a"   (tracking the children)
///     el.textContent = "b";          .value -> "b"   (still tracking)
///     el.value = "c";                .value -> "c"   (now dirty)
///     el.textContent = "d";          .value -> "c"   (children no longer win)
///                                    .defaultValue -> "d"
///
/// Dirtiness is encoded as the optional being non-null, so a set flag with no
/// value behind it is unrepresentable.
///
/// The stored string is the RAW value. `value` returns the API value, which is
/// the raw value with CRLF and lone CR normalised to LF - so
/// `el.value = "a\r\nb"` reads back "a\nb", which
/// `value-defaultValue-textContent.html` asserts in two places.
pub const InternalState = struct {
    /// Owned. Non-null means the dirty value flag is set.
    raw_value: ?[]u8 = null,

    /// The text entry cursor, in UTF-16 code units of the API value. Not a
    /// reflection of anything; clamped on read because the value can shrink
    /// underneath it.
    selection_start: u32 = 0,
    selection_end: u32 = 0,
    selection_direction: SelectionDirection = .none,

    /// Releases what the state OWNS. Deliberately does not null the field
    /// afterwards: the block is handed back to the arena immediately, so the
    /// write would be pointless, and a write through a registry pointer is the
    /// one thing worth not doing on a teardown path.
    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        if (self.raw_value) |v| allocator.free(v);
    }
};

pub const SelectionDirection = enum {
    none,
    forward,
    backward,

    fn keyword(self: SelectionDirection) []const u8 {
        return switch (self) {
            .none => "none",
            .forward => "forward",
            .backward => "backward",
        };
    }

    fn parse(text: []const u8) SelectionDirection {
        if (std.ascii.eqlIgnoreCase(text, "forward")) return .forward;
        if (std.ascii.eqlIgnoreCase(text, "backward")) return .backward;
        return .none;
    }
};

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

    // No state is recorded here on purpose: `StateMap` fills in lazily on the
    // first assignment, so an element the parser created and script never
    // touched allocates nothing and leaves nothing to clean up.
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Take the entry out first, then free what it owned: the freeing happens
    // against a copy, so nothing is written back through a map slot that has
    // already been reused.
    if (StateMap.remove(instance)) |taken| {
        var state = taken;
        state.deinit(instance.ctx.allocator);
    }

    const HTMLElementImpl = @import("HTMLElement.zig");
    HTMLElementImpl.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &HTMLTextAreaElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

// ---------------------------------------------------------------------------
// Reflection helpers
// ---------------------------------------------------------------------------

/// Reflects an integer attribute, falling back to `default` when the attribute is
/// absent or does not parse. `positive_only` implements "limited to only positive
/// numbers", where a zero is as invalid as a letter.
fn reflectInt(
    instance: *runtime.Instance,
    comptime attr: []const u8,
    comptime T: type,
    default: T,
    comptime positive_only: bool,
) anyerror!T {
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;
    const entry = elem_internal.findAttribute(null, attr) orelse return default;
    const parsed = std.fmt.parseInt(T, std.mem.trim(u8, entry.value, " \t\n\r\x0C"), 10) catch return default;
    if (parsed < 0) return default;
    if (positive_only and parsed == 0) return default;
    return parsed;
}

fn setStringAttr(instance: *runtime.Instance, comptime attr: []const u8, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned(attr), value);
}

fn setIntAttr(instance: *runtime.Instance, comptime attr: []const u8, value: anytype) anyerror!void {
    var buf: [24]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, "{d}", .{value}) catch return error.OutOfMemory;
    try setStringAttr(instance, attr, runtime.DOMString.initInterned(text));
}

// ---------------------------------------------------------------------------
// Raw value / API value
// ---------------------------------------------------------------------------

/// The element's child text content: the data of the Text node CHILDREN only.
///
/// Not `textContent`, which descends: `<textarea>foo<span>baz</span></textarea>`
/// has textContent "foobaz" and a child text content of "foo", and
/// `value-defaultValue-textContent.html` asserts that difference directly.
fn childTextContent(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]u8 {
    var out = std.ArrayListUnmanaged(u8).empty;
    errdefer out.deinit(allocator);

    var child = NodeImpl.getFirstChild(instance);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.TEXT_NODE or
            node_type == NodeImpl.NodeType.CDATA_SECTION_NODE)
        {
            if (CharacterDataImpl.getData(c)) |data| {
                try out.appendSlice(allocator, data);
            }
        }
        child = NodeImpl.getNextSibling(c);
    }
    return out.toOwnedSlice(allocator);
}

/// https://html.spec.whatwg.org/multipage/form-elements.html#concept-textarea-api-value
///
/// The raw value with every CRLF pair and every lone CR turned into a single LF.
/// Runs over bytes, which is safe: CR and LF are ASCII and cannot appear inside a
/// multi-byte UTF-8 sequence.
fn apiValue(allocator: std.mem.Allocator, raw: []const u8) ![]u8 {
    var out = std.ArrayListUnmanaged(u8).empty;
    errdefer out.deinit(allocator);
    try out.ensureTotalCapacity(allocator, raw.len);

    var i: usize = 0;
    while (i < raw.len) : (i += 1) {
        if (raw[i] == '\r') {
            out.appendAssumeCapacity('\n');
            // Swallow the LF of a CRLF pair so it does not become a second break.
            if (i + 1 < raw.len and raw[i + 1] == '\n') i += 1;
            continue;
        }
        out.appendAssumeCapacity(raw[i]);
    }
    return out.toOwnedSlice(allocator);
}

/// The API value, owned by the caller.
fn currentApiValue(instance: *runtime.Instance) ![]u8 {
    const allocator = instance.ctx.allocator;

    if (StateMap.get(instance)) |internal| {
        if (internal.raw_value) |raw| {
            // Dirty: the element's own value wins over the children.
            return apiValue(allocator, raw);
        }
    }
    // Clean: track the child text content.
    const raw = try childTextContent(instance, allocator);
    defer allocator.free(raw);
    return apiValue(allocator, raw);
}

// ---------------------------------------------------------------------------
// IDL attributes
// ---------------------------------------------------------------------------

/// Getter for autocomplete
pub fn get_autocomplete(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // Enumerated with "" for BOTH defaults, matching HTMLInputElement. Unlike
    // <form>, where both defaults are "on".
    //
    // TODO: the autofill mantle also exposes field names; only on/off are
    // recognised here, so anything else reads back "".
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;
    const entry = elem_internal.findAttribute(null, "autocomplete") orelse
        return runtime.DOMString.initEmpty();
    inline for ([_][]const u8{ "on", "off" }) |candidate| {
        if (std.ascii.eqlIgnoreCase(entry.value, candidate)) {
            return runtime.DOMString.initInterned(candidate);
        }
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for cols
pub fn get_cols(instance: *runtime.Instance) anyerror!u32 {
    // Limited to only POSITIVE numbers, default 20 - so cols="0" reads back 20.
    return reflectInt(instance, "cols", u32, 20, true);
}

/// Getter for form
pub fn get_form(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    // TODO: form association is not implemented; HTMLInputElement returns null
    // here for the same reason.
    _ = instance;
    return null;
}

/// Getter for maxLength
pub fn get_maxLength(instance: *runtime.Instance) anyerror!i32 {
    // Limited to only non-negative numbers, default -1, so maxlength="0" is 0.
    return reflectInt(instance, "maxlength", i32, -1, false);
}

/// Getter for minLength
pub fn get_minLength(instance: *runtime.Instance) anyerror!i32 {
    return reflectInt(instance, "minlength", i32, -1, false);
}

/// Getter for rows
pub fn get_rows(instance: *runtime.Instance) anyerror!u32 {
    // Limited to only positive numbers, default 2.
    return reflectInt(instance, "rows", u32, 2, true);
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // A constant, not a reflection.
    _ = instance;
    return runtime.DOMString.initInterned("textarea");
}

/// Getter for defaultValue
pub fn get_defaultValue(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // The child text content, RAW - defaultValue keeps the CRs that `value`
    // normalises away.
    const allocator = instance.ctx.allocator;
    const text = try childTextContent(instance, allocator);
    if (text.len == 0) {
        allocator.free(text);
        return runtime.DOMString.initEmpty();
    }
    return runtime.DOMString.initOwned(text);
}

/// Getter for value
pub fn get_value(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const allocator = instance.ctx.allocator;
    const text = try currentApiValue(instance);
    if (text.len == 0) {
        allocator.free(text);
        return runtime.DOMString.initEmpty();
    }
    return runtime.DOMString.initOwned(text);
}

/// Getter for textLength
pub fn get_textLength(instance: *runtime.Instance) anyerror!u32 {
    // The LENGTH of the API value, which WebIDL measures in UTF-16 code units -
    // not bytes and not codepoints. `textarea-textLength.html` pins this with
    // "你好，世界!", 18 UTF-8 bytes and 6 code units.
    const allocator = instance.ctx.allocator;
    const text = try currentApiValue(instance);
    defer allocator.free(text);
    const units = std.unicode.calcUtf16LeLen(text) catch return @intCast(text.len);
    return @intCast(units);
}

/// Getter for willValidate
pub fn get_willValidate(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for validity
pub fn get_validity(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for validationMessage
pub fn get_validationMessage(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for labels
pub fn get_labels(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// The API value's length in UTF-16 code units, for clamping the cursor.
fn apiValueLength(instance: *runtime.Instance) u32 {
    const allocator = instance.ctx.allocator;
    const text = currentApiValue(instance) catch return 0;
    defer allocator.free(text);
    const units = std.unicode.calcUtf16LeLen(text) catch return @intCast(text.len);
    return @intCast(units);
}

/// Getter for selectionStart
pub fn get_selectionStart(instance: *runtime.Instance) anyerror!u32 {
    // There is no rendered text entry cursor here - no layout, no focus - so this
    // is the API-visible cursor only: what was last assigned, clamped to the
    // current value. React reads selectionStart/selectionEnd to restore the
    // caret after a controlled re-render, which is why this reports a position
    // rather than throwing.
    const internal = StateMap.get(instance) orelse return 0;
    return @min(internal.selection_start, apiValueLength(instance));
}

/// Getter for selectionEnd
pub fn get_selectionEnd(instance: *runtime.Instance) anyerror!u32 {
    const internal = StateMap.get(instance) orelse return 0;
    return @min(internal.selection_end, apiValueLength(instance));
}

/// Getter for selectionDirection
pub fn get_selectionDirection(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = StateMap.get(instance) orelse return runtime.DOMString.initInterned("none");
    return runtime.DOMString.initInterned(internal.selection_direction.keyword());
}

// ---------------------------------------------------------------------------
// Out-of-range integer assignments
//
// "Limited to only positive numbers" and "limited to only non-negative numbers"
// both throw "IndexSizeError" on an out-of-range assignment rather than writing
// the attribute, which textarea-minlength.html and textarea-maxlength.html each
// assert.
// ---------------------------------------------------------------------------

/// Setter for cols
pub fn set_cols(instance: *runtime.Instance, value: u32) anyerror!void {
    // "Limited to only positive numbers": zero is invalid.
    if (value == 0) return error.IndexSizeError;
    try setIntAttr(instance, "cols", value);
}

/// Setter for maxLength
pub fn set_maxLength(instance: *runtime.Instance, value: i32) anyerror!void {
    if (value < 0) return error.IndexSizeError;
    try setIntAttr(instance, "maxlength", value);
}

/// Setter for minLength
pub fn set_minLength(instance: *runtime.Instance, value: i32) anyerror!void {
    if (value < 0) return error.IndexSizeError;
    try setIntAttr(instance, "minlength", value);
}

/// Setter for rows
pub fn set_rows(instance: *runtime.Instance, value: u32) anyerror!void {
    if (value == 0) return error.IndexSizeError;
    try setIntAttr(instance, "rows", value);
}

/// Setter for defaultValue
pub fn set_defaultValue(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // "String replace all", i.e. what textContent does: every child goes,
    // elements included.
    try interfaces.Node.set_textContent(instance, value);
}

/// Setter for value
pub fn set_value(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = try StateMap.getOrPut(instance);
    const allocator = instance.ctx.allocator;

    const copy = allocator.dupe(u8, value.asSlice()) catch return error.OutOfMemory;
    // Free AFTER the new copy succeeds, so a failed allocation leaves the old
    // value intact rather than clearing it.
    if (internal.raw_value) |old| allocator.free(old);
    internal.raw_value = copy;

    // The spec moves the text entry cursor to the end of the new value when the
    // API value actually changed. Collapsing it unconditionally is the same
    // observable result for a value that did not change, since the cursor was
    // already clamped to that length.
    const length = apiValueLength(instance);
    internal.selection_start = length;
    internal.selection_end = length;
    internal.selection_direction = .none;
}

/// Setter for selectionStart
pub fn set_selectionStart(instance: *runtime.Instance, value: u32) anyerror!void {
    const internal = try StateMap.getOrPut(instance);
    const length = apiValueLength(instance);
    internal.selection_start = @min(value, length);
    // "If the end is less than the new start, set the end to the new start."
    if (internal.selection_end < internal.selection_start) {
        internal.selection_end = internal.selection_start;
    }
}

/// Setter for selectionEnd
pub fn set_selectionEnd(instance: *runtime.Instance, value: u32) anyerror!void {
    const internal = try StateMap.getOrPut(instance);
    const length = apiValueLength(instance);
    internal.selection_end = @min(value, length);
    // "If the start is greater than the new end, set the start to the new end."
    if (internal.selection_start > internal.selection_end) {
        internal.selection_start = internal.selection_end;
    }
}

/// Setter for selectionDirection
pub fn set_selectionDirection(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = try StateMap.getOrPut(instance);
    internal.selection_direction = SelectionDirection.parse(value.asSlice());
}

/// Operation: select
pub fn call_select(instance: *runtime.Instance) anyerror!void {
    const internal = try StateMap.getOrPut(instance);
    internal.selection_start = 0;
    internal.selection_end = apiValueLength(instance);
    internal.selection_direction = .none;
}

/// Operation: setSelectionRange
pub fn call_setSelectionRange(instance: *runtime.Instance, start: u32, end: u32, direction: webidl.Opt(runtime.DOMString)) anyerror!void {
    const internal = try StateMap.getOrPut(instance);
    const length = apiValueLength(instance);

    const clamped_end = @min(end, length);
    const clamped_start = @min(@min(start, length), clamped_end);

    internal.selection_start = clamped_start;
    internal.selection_end = clamped_end;
    internal.selection_direction = if (direction.wasPassed())
        SelectionDirection.parse(direction.getValue().asSlice())
    else
        .none;
}

/// Operation: setRangeText
pub fn call_setRangeText(instance: *runtime.Instance, replacement: runtime.DOMString) anyerror!void {
    // TODO: the full algorithm also takes (start, end, selectMode); codegen emits
    // only the 1-argument overload, and replacing "the selection" needs the text
    // entry cursor semantics this element does not have yet.
    _ = instance;
    _ = replacement;
    return error.NotImplemented;
}

/// Operation: checkValidity
pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: reportValidity
pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setCustomValidity
pub fn call_setCustomValidity(instance: *runtime.Instance, @"error": runtime.DOMString) anyerror!void {
    _ = instance;
    _ = @"error";
    return error.NotImplemented;
}
