//! Implementation for HTMLInputElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLInputElement = interfaces.HTMLInputElement;
const ElementImpl = @import("Element.zig");
const autofill = @import("html").autofill;

pub const State = HTMLInputElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
// Shared registry utility, the same mechanism HTMLFormElement uses.
const utils = @import("webidl").utils;
const Registry = utils.InstanceRegistry(InternalState);

/// https://html.spec.whatwg.org/multipage/input.html#concept-fe-value
///
/// `value` and `checked` are NOT reflections. Each is element state that starts
/// out tracking a content attribute and permanently detaches the moment anything
/// assigns to it - the "dirty value flag" and "dirty checkedness flag". So:
///
///     <input value="a">           .value -> "a"   (tracking the attribute)
///     el.setAttribute("value","b"); .value -> "b"   (still tracking)
///     el.value = "c";               .value -> "c"   (now dirty)
///     el.setAttribute("value","d"); .value -> "c"   (attribute no longer wins)
///
/// That last line is the one that matters for React: it sets .value directly,
/// and a later attribute write must not clobber what it set.
///
/// Dirtiness is encoded as the optional being non-null, so there is no way to
/// have a dirty flag set with no value behind it.
pub const InternalState = struct {
    /// Owned. Non-null means the dirty value flag is set.
    value: ?[]u8 = null,
    /// Non-null means the dirty checkedness flag is set.
    checkedness: ?bool = null,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        if (self.value) |v| allocator.free(v);
        self.value = null;
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

// ---------------------------------------------------------------------------
// Reflected content attributes
//
// https://html.spec.whatwg.org/multipage/input.html
//
// These were `return error.NotImplemented`, which V8 turns into a thrown
// exception - so `input.type` THREW rather than returning "text". React's
// controlled inputs read value/checked/type/name/disabled on every commit, so
// none of them could work.
//
// NOTE the difference between the two `value`-ish pairs:
//   defaultValue   reflects the "value" CONTENT ATTRIBUTE
//   value          is the element's VALUE, which starts from that attribute
//                  and detaches from it once anything assigns to it
//   defaultChecked reflects the "checked" CONTENT ATTRIBUTE
//   checked        is the element's CHECKEDNESS, likewise detaching
// The reflecting halves are plain [Reflect] attributes, which the generated
// interface implements (src/webidl/impls/reflection.zig); the stateful halves
// here keep the dirty-value and dirty-checkedness flags.
// ---------------------------------------------------------------------------

fn reflectString(instance: *runtime.Instance, comptime attr: []const u8) anyerror!runtime.DOMString {
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;
    if (elem_internal.findAttribute(null, attr)) |entry| {
        return runtime.DOMString.initDupe(instance.ctx.allocator, entry.value) catch return error.OutOfMemory;
    }
    return runtime.DOMString.initEmpty();
}

fn reflectBool(instance: *runtime.Instance, comptime attr: []const u8) anyerror!bool {
    // A boolean content attribute is true by PRESENCE; disabled="false" is true.
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;
    return elem_internal.findAttribute(null, attr) != null;
}

fn setStringAttr(instance: *runtime.Instance, comptime attr: []const u8, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned(attr), value);
}

/// The input type keywords, in spec order. Missing OR unrecognised both map to
/// "text", so this needs no separate invalid-value default.
const INPUT_TYPES = [_][]const u8{
    "hidden", "text",     "search", "tel",  "url",            "email",  "password",
    "date",   "month",    "week",   "time", "datetime-local", "number", "range",
    "color",  "checkbox", "radio",  "file", "submit",         "image",  "reset",
    "button",
};

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
    const instance = try init(ctx.allocator, State, &HTMLInputElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for autocomplete
pub fn get_autocomplete(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#autofill
    //
    // Not a two-value enumeration. "on"/"off" are one branch; the other is an
    // ordered autofill token list, returned verbatim (lowercased) when it forms
    // a valid expansion and "" when it does not:
    //
    //     <input>                                -> ""
    //     <input autocomplete="on">              -> "on"
    //     <input autocomplete="shipping country">-> "shipping country"
    //     <input autocomplete="foobar">          -> ""
    //     <input autocomplete="home country">    -> ""  (country is not a
    //                                                    contact field)
    //
    // An earlier version handled only on/off and reflected anything else
    // verbatim, which got both `foobar` and `shipping country` wrong in
    // opposite directions.
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;
    const entry = elem_internal.findAttribute(null, "autocomplete") orelse
        return runtime.DOMString.initEmpty();

    inline for ([_][]const u8{ "on", "off" }) |candidate| {
        if (std.ascii.eqlIgnoreCase(entry.value, candidate)) {
            return runtime.DOMString.initInterned(candidate);
        }
    }

    const expansion = autofill.parse(entry.value) orelse
        return runtime.DOMString.initEmpty();

    var buf: [256]u8 = undefined;
    const serialized = autofill.serialize(expansion, &buf) orelse
        return runtime.DOMString.initEmpty();
    return runtime.DOMString.initDupe(instance.ctx.allocator, serialized) catch
        return error.OutOfMemory;
}

/// Getter for checked
pub fn get_checked(instance: *runtime.Instance) anyerror!bool {
    if (Registry.get(instance)) |internal| {
        if (internal.checkedness) |c| return c;
    }
    return reflectBool(instance, "checked");
}

/// Getter for colorSpace
pub fn get_colorSpace(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for form
pub fn get_form(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for files
pub fn get_files(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for formAction
pub fn get_formAction(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for formEnctype
pub fn get_formEnctype(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for formMethod
pub fn get_formMethod(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for height
pub fn get_height(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for indeterminate
pub fn get_indeterminate(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for list
pub fn get_list(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for maxLength
pub fn get_maxLength(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for minLength
pub fn get_minLength(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for size
pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;
    const entry = elem_internal.findAttribute(null, "type") orelse
        return runtime.DOMString.initInterned("text");
    inline for (INPUT_TYPES) |candidate| {
        if (std.ascii.eqlIgnoreCase(entry.value, candidate)) {
            return runtime.DOMString.initInterned(candidate);
        }
    }
    return runtime.DOMString.initInterned("text");
}

/// Getter for value
pub fn get_value(instance: *runtime.Instance) anyerror!runtime.DOMString {
    if (Registry.get(instance)) |internal| {
        if (internal.value) |v| {
            // Dirty: the element's own value wins over the attribute.
            return runtime.DOMString.initDupe(instance.ctx.allocator, v) catch return error.OutOfMemory;
        }
    }
    // Clean: track the content attribute.
    return reflectString(instance, "value");
}

/// Getter for valueAsDate
pub fn get_valueAsDate(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    return null;
}

/// Getter for valueAsNumber
pub fn get_valueAsNumber(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for width
pub fn get_width(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return error.NotImplemented;
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
pub fn get_labels(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for selectionStart
pub fn get_selectionStart(instance: *runtime.Instance) anyerror!?u32 {
    _ = instance;
    return null;
}

/// Getter for selectionEnd
pub fn get_selectionEnd(instance: *runtime.Instance) anyerror!?u32 {
    _ = instance;
    return null;
}

/// Getter for selectionDirection
pub fn get_selectionDirection(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for capture
pub fn get_capture(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for webkitdirectory
pub fn get_webkitdirectory(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for webkitEntries
pub fn get_webkitEntries(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for popoverTargetElement
pub fn get_popoverTargetElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for popoverTargetAction
pub fn get_popoverTargetAction(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for checked
pub fn set_checked(instance: *runtime.Instance, value: bool) anyerror!void {
    const internal = Registry.get(instance) orelse return error.InvalidState;
    internal.checkedness = value;
}

/// Setter for colorSpace
pub fn set_colorSpace(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for files
pub fn set_files(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for formEnctype
pub fn set_formEnctype(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for formMethod
pub fn set_formMethod(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for height
pub fn set_height(instance: *runtime.Instance, value: u32) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for indeterminate
pub fn set_indeterminate(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for maxLength
pub fn set_maxLength(instance: *runtime.Instance, value: i32) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for minLength
pub fn set_minLength(instance: *runtime.Instance, value: i32) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for size
pub fn set_size(instance: *runtime.Instance, value: u32) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for type
pub fn set_type(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // Setting writes the attribute VERBATIM; only the getter canonicalises.
    // `el.type = "NONSENSE"` leaves type="NONSENSE" in the markup while
    // `el.type` reads back "text".
    try setStringAttr(instance, "type", value);
}

/// Setter for value
pub fn set_value(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = Registry.get(instance) orelse return error.InvalidState;
    const allocator = instance.ctx.allocator;

    const copy = allocator.dupe(u8, value.asSlice()) catch return error.OutOfMemory;
    // Free AFTER the new copy succeeds, so a failed allocation leaves the old
    // value intact rather than clearing it.
    if (internal.value) |old| allocator.free(old);
    internal.value = copy;
}

/// Setter for valueAsDate
pub fn set_valueAsDate(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for valueAsNumber
pub fn set_valueAsNumber(instance: *runtime.Instance, value: f64) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for width
pub fn set_width(instance: *runtime.Instance, value: u32) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for selectionStart
pub fn set_selectionStart(instance: *runtime.Instance, value: ?u32) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for selectionEnd
pub fn set_selectionEnd(instance: *runtime.Instance, value: ?u32) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for selectionDirection
pub fn set_selectionDirection(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for capture
pub fn set_capture(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for webkitdirectory
pub fn set_webkitdirectory(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for popoverTargetElement
pub fn set_popoverTargetElement(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for popoverTargetAction
pub fn set_popoverTargetAction(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: showPicker
pub fn call_showPicker(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setCustomValidity
pub fn call_setCustomValidity(instance: *runtime.Instance, @"error": runtime.DOMString) anyerror!void {
    _ = instance;
    _ = @"error";
    return error.NotImplemented;
}

/// Operation: setRangeText
pub fn call_setRangeText(instance: *runtime.Instance, replacement: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = replacement;
    return error.NotImplemented;
}

/// Operation: select
pub fn call_select(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: stepUp
pub fn call_stepUp(instance: *runtime.Instance, n: webidl.Opt(i32)) anyerror!void {
    _ = instance;
    _ = n;
    return error.NotImplemented;
}

/// Operation: checkValidity
pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setSelectionRange
pub fn call_setSelectionRange(instance: *runtime.Instance, start: u32, end: u32, direction: webidl.Opt(runtime.DOMString)) anyerror!void {
    _ = instance;
    _ = start;
    _ = end;
    _ = direction;
    return error.NotImplemented;
}

/// Operation: reportValidity
pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: stepDown
pub fn call_stepDown(instance: *runtime.Instance, n: webidl.Opt(i32)) anyerror!void {
    _ = instance;
    _ = n;
    return error.NotImplemented;
}
