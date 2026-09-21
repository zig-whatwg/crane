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
    /// Setting an attribute "limited to only positive numbers" to zero, or a
    /// non-negative one to a negative number. The name matters: it is the
    /// DOMException the binding layer maps it to (see the table in
    /// engines/v8/conversions.zig).
    IndexSizeError,
};

const utils = @import("webidl").utils;
const Registry = utils.InstanceRegistry(InternalState);

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

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        if (self.raw_value) |v| allocator.free(v);
        self.raw_value = null;
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

    // createIn, not set: the registry then owns the block and returns it to the
    // arena on remove, rather than dropping it from the map and holding it to
    // process exit.
    const ArenaAllocator = runtime.ArenaAllocator;
    const internal = try Registry.createIn(instance, ArenaAllocator.get());
    internal.* = .{};

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    if (Registry.get(instance)) |internal| {
        internal.deinit(instance.ctx.allocator);
    }
    Registry.remove(instance);

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

fn reflectString(instance: *runtime.Instance, comptime attr: []const u8) anyerror!runtime.DOMString {
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;
    if (elem_internal.findAttribute(null, attr)) |entry| {
        return runtime.DOMString.initDupe(instance.ctx.allocator, entry.value) catch return error.OutOfMemory;
    }
    return runtime.DOMString.initEmpty();
}

fn reflectBool(instance: *runtime.Instance, comptime attr: []const u8) anyerror!bool {
    // A boolean content attribute is true by PRESENCE; readonly="false" is true.
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;
    return elem_internal.findAttribute(null, attr) != null;
}

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

fn setBoolAttr(instance: *runtime.Instance, comptime attr: []const u8, value: bool) anyerror!void {
    const name = runtime.DOMString.initInterned(attr);
    if (value) {
        try interfaces.Element.call_setAttribute(instance, name, runtime.DOMString.initEmpty());
    } else {
        try interfaces.Element.call_removeAttribute(instance, name);
    }
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

    if (Registry.get(instance)) |internal| {
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

/// Getter for dirName
pub fn get_dirName(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflectString(instance, "dirname");
}

/// Getter for disabled
pub fn get_disabled(instance: *runtime.Instance) anyerror!bool {
    return reflectBool(instance, "disabled");
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

/// Getter for name
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflectString(instance, "name");
}

/// Getter for placeholder
pub fn get_placeholder(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflectString(instance, "placeholder");
}

/// Getter for readOnly
pub fn get_readOnly(instance: *runtime.Instance) anyerror!bool {
    return reflectBool(instance, "readonly");
}

/// Getter for required
pub fn get_required(instance: *runtime.Instance) anyerror!bool {
    return reflectBool(instance, "required");
}

/// Getter for rows
pub fn get_rows(instance: *runtime.Instance) anyerror!u32 {
    // Limited to only positive numbers, default 2.
    return reflectInt(instance, "rows", u32, 2, true);
}

/// Getter for wrap
pub fn get_wrap(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // Plain reflection. `wrap` is an enumerated CONTENT attribute (soft/hard),
    // but the IDL attribute is [Reflect] rather than limited to known values, so
    // an unrecognised value is handed back verbatim.
    return reflectString(instance, "wrap");
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
    const internal = Registry.get(instance) orelse return 0;
    return @min(internal.selection_start, apiValueLength(instance));
}

/// Getter for selectionEnd
pub fn get_selectionEnd(instance: *runtime.Instance) anyerror!u32 {
    const internal = Registry.get(instance) orelse return 0;
    return @min(internal.selection_end, apiValueLength(instance));
}

/// Getter for selectionDirection
pub fn get_selectionDirection(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = Registry.get(instance) orelse return runtime.DOMString.initInterned("none");
    return runtime.DOMString.initInterned(internal.selection_direction.keyword());
}

/// Setter for autocomplete
pub fn set_autocomplete(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // Written VERBATIM; only the getter canonicalises.
    try setStringAttr(instance, "autocomplete", value);
}

/// Setter for cols
pub fn set_cols(instance: *runtime.Instance, value: u32) anyerror!void {
    // "Limited to only positive numbers": setting zero throws rather than
    // writing cols="0".
    if (value == 0) return error.IndexSizeError;
    try setIntAttr(instance, "cols", value);
}

/// Setter for dirName
pub fn set_dirName(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setStringAttr(instance, "dirname", value);
}

/// Setter for disabled
pub fn set_disabled(instance: *runtime.Instance, value: bool) anyerror!void {
    try setBoolAttr(instance, "disabled", value);
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

/// Setter for name
pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setStringAttr(instance, "name", value);
}

/// Setter for placeholder
pub fn set_placeholder(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setStringAttr(instance, "placeholder", value);
}

/// Setter for readOnly
pub fn set_readOnly(instance: *runtime.Instance, value: bool) anyerror!void {
    try setBoolAttr(instance, "readonly", value);
}

/// Setter for required
pub fn set_required(instance: *runtime.Instance, value: bool) anyerror!void {
    try setBoolAttr(instance, "required", value);
}

/// Setter for rows
pub fn set_rows(instance: *runtime.Instance, value: u32) anyerror!void {
    if (value == 0) return error.IndexSizeError;
    try setIntAttr(instance, "rows", value);
}

/// Setter for wrap
pub fn set_wrap(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setStringAttr(instance, "wrap", value);
}

/// Setter for defaultValue
pub fn set_defaultValue(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // "String replace all", i.e. what textContent does: every child goes,
    // elements included.
    try interfaces.Node.set_textContent(instance, value);
}

/// Setter for value
pub fn set_value(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = Registry.get(instance) orelse return error.InvalidState;
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
    const internal = Registry.get(instance) orelse return error.InvalidState;
    const length = apiValueLength(instance);
    internal.selection_start = @min(value, length);
    // "If the end is less than the new start, set the end to the new start."
    if (internal.selection_end < internal.selection_start) {
        internal.selection_end = internal.selection_start;
    }
}

/// Setter for selectionEnd
pub fn set_selectionEnd(instance: *runtime.Instance, value: u32) anyerror!void {
    const internal = Registry.get(instance) orelse return error.InvalidState;
    const length = apiValueLength(instance);
    internal.selection_end = @min(value, length);
    // "If the start is greater than the new end, set the start to the new end."
    if (internal.selection_start > internal.selection_end) {
        internal.selection_start = internal.selection_end;
    }
}

/// Setter for selectionDirection
pub fn set_selectionDirection(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = Registry.get(instance) orelse return error.InvalidState;
    internal.selection_direction = SelectionDirection.parse(value.asSlice());
}

/// Operation: select
pub fn call_select(instance: *runtime.Instance) anyerror!void {
    const internal = Registry.get(instance) orelse return error.InvalidState;
    internal.selection_start = 0;
    internal.selection_end = apiValueLength(instance);
    internal.selection_direction = .none;
}

/// Operation: setSelectionRange
pub fn call_setSelectionRange(instance: *runtime.Instance, start: u32, end: u32, direction: webidl.Opt(runtime.DOMString)) anyerror!void {
    const internal = Registry.get(instance) orelse return error.InvalidState;
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
