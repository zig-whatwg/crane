//! Implementation for HTMLSelectElement interface
//!
//! The selection model itself (list of options, selectedness, dirtiness, the
//! reset algorithm) lives in `HTMLOptionElement.zig`, because that is where the
//! state it reads and writes belongs. This file is the select-shaped view of it.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLSelectElement = interfaces.HTMLSelectElement;

const ElementImpl = @import("Element.zig");
const NodeImpl = @import("Node.zig");
const HTMLCollectionImpl = @import("HTMLCollection.zig");
// One-way, by design: the option impl owns selectedness and never imports this
// file back. See the header comment in HTMLOptionElement.zig.
const OptionImpl = @import("HTMLOptionElement.zig");

pub const State = HTMLSelectElement.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
    /// `add()` with an element that is an ancestor of the select.
    HierarchyRequestError,
    /// `add()` with a `before` element that is not inside the select.
    NotFoundError,
};

/// Internal state for implementation-specific data
///
/// Deliberately empty and deliberately unregistered: a select holds no selection
/// state of its own - every bit of it lives on the options, which is what lets
/// `option.selected` and `select.value` agree without either caching the other.
/// Nothing calls `Registry.createIn` here, so the zero-sized-InternalState abort
/// does not apply.
pub const InternalState = struct {};

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
    // HTMLSelectElement has no additional initialization
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // HTMLSelectElement has no additional cleanup
    // Chain to parent class
    const HTMLElementImpl = @import("HTMLElement.zig");
    HTMLElementImpl.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &HTMLSelectElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Indexed setter - sets option at index
/// Spec: https://html.spec.whatwg.org/multipage/form-elements.html#dom-select-setter
pub fn call_setter(instance: *runtime.Instance, index: u32, option: ?*runtime.Instance) anyerror!void {
    const existing = try call_item(instance, index);

    if (option) |new_option| {
        if (existing) |old_option| {
            const parent = NodeImpl.getParent(old_option) orelse instance;
            _ = try interfaces.Node.call_replaceChild(parent, new_option, old_option);
        } else {
            // Beyond the end: the spec pads with blank options first, then puts
            // the new one at `index`.
            try set_length(instance, index);
            _ = try interfaces.Node.call_appendChild(instance, new_option);
        }
        return;
    }

    // Setting null removes the option at that index.
    if (existing) |old_option| {
        const parent = NodeImpl.getParent(old_option) orelse return;
        _ = try interfaces.Node.call_removeChild(parent, old_option);
    }
}

// ---------------------------------------------------------------------------
// Reflection helpers
//
// Three kinds, not interchangeable:
//   * plain      - the attribute, or "" when absent (name)
//   * boolean    - true by PRESENCE, so disabled="false" is TRUE
//   * enumerated - a missing attribute maps to the MISSING VALUE DEFAULT and an
//                  unrecognised one to the INVALID VALUE DEFAULT
// ---------------------------------------------------------------------------

fn reflectBool(instance: *runtime.Instance, comptime attr: []const u8) anyerror!bool {
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;
    return elem_internal.findAttribute(null, attr) != null;
}

/// The list of options, owned by the caller.
fn optionList(instance: *runtime.Instance) anyerror!std.ArrayListUnmanaged(*runtime.Instance) {
    const allocator = instance.ctx.allocator;
    var options = std.ArrayListUnmanaged(*runtime.Instance).empty;
    errdefer options.deinit(allocator);
    try OptionImpl.collectOptions(instance, allocator, &options);
    return options;
}

// ---------------------------------------------------------------------------
// IDL attributes
// ---------------------------------------------------------------------------

/// Getter for autocomplete
pub fn get_autocomplete(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // Enumerated, with "" for BOTH defaults - the same shape HTMLInputElement
    // uses, and unlike <form>, where both defaults are "on".
    //
    // TODO: the full autofill mantle also exposes field names ("email",
    // "street-address", ...). Only on/off are recognised here, matching
    // HTMLInputElement; anything else reads back "".
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

/// Getter for form
pub fn get_form(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    // TODO: form association is not implemented; HTMLInputElement returns null
    // here for the same reason.
    _ = instance;
    return null;
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // Not a reflection at all: derived from the presence of `multiple`.
    if (try reflectBool(instance, "multiple")) {
        return runtime.DOMString.initInterned("select-multiple");
    }
    return runtime.DOMString.initInterned("select-one");
}

/// Getter for options
/// Spec: https://html.spec.whatwg.org/multipage/form-elements.html#dom-select-options
pub fn get_options(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // KNOWN LIMITATION, shared with HTMLFormElement.get_elements: HTMLCollection
    // is a SNAPSHOT in this tree (nothing calls its `setRoot`, and `get_length`
    // reads a stored list), while `options` is [SameObject] - so the generated
    // interface caches whatever this returns and never asks again. An option
    // appended after the first `select.options` read will not appear in it.
    //
    // `select.length`, `select.item()`, `selectedIndex` and `value` all re-walk
    // the tree on every call, so the live answers are available; only the
    // collection object goes stale. Making it live needs a root+filter mode in
    // HTMLCollection.zig.
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;

    const collection = try interfaces.HTMLCollection.init(elem_internal.allocator, instance.ctx);
    errdefer interfaces.HTMLCollection.deinit(collection);

    var options = try optionList(instance);
    defer options.deinit(instance.ctx.allocator);
    for (options.items) |option| try HTMLCollectionImpl.addElement(collection, option);

    return collection;
}

/// Getter for length
/// Returns the number of options in the select element's list of options
/// Spec: https://html.spec.whatwg.org/multipage/form-elements.html#dom-select-length
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    var options = try optionList(instance);
    defer options.deinit(instance.ctx.allocator);
    return @intCast(options.items.len);
}

/// Getter for selectedOptions
pub fn get_selectedOptions(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // [SameObject], so the same snapshot caveat as `get_options` applies.
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;

    const collection = try interfaces.HTMLCollection.init(elem_internal.allocator, instance.ctx);
    errdefer interfaces.HTMLCollection.deinit(collection);

    var options = try optionList(instance);
    defer options.deinit(instance.ctx.allocator);

    if (try reflectBool(instance, "multiple")) {
        for (options.items) |option| {
            if (OptionImpl.explicitSelectedness(option) == .on) {
                try HTMLCollectionImpl.addElement(collection, option);
            }
        }
    } else if (OptionImpl.selectedIndexOf(instance, options.items)) |index| {
        try HTMLCollectionImpl.addElement(collection, options.items[index]);
    }

    return collection;
}

/// Getter for selectedIndex
pub fn get_selectedIndex(instance: *runtime.Instance) anyerror!i32 {
    var options = try optionList(instance);
    defer options.deinit(instance.ctx.allocator);

    const index = OptionImpl.selectedIndexOf(instance, options.items) orelse return -1;
    return @intCast(index);
}

/// Getter for value
/// Spec: https://html.spec.whatwg.org/multipage/form-elements.html#dom-select-value
pub fn get_value(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // State, not reflection: the value of the first selected option, and "" when
    // nothing is selected. There is no `value` content attribute on a select.
    var options = try optionList(instance);
    defer options.deinit(instance.ctx.allocator);

    const index = OptionImpl.selectedIndexOf(instance, options.items) orelse
        return runtime.DOMString.initEmpty();
    return interfaces.HTMLOptionElement.get_value(options.items[index]);
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

/// Setter for length
/// Spec: https://html.spec.whatwg.org/multipage/form-elements.html#dom-htmloptionscollection-length
pub fn set_length(instance: *runtime.Instance, value: u32) anyerror!void {
    var options = try optionList(instance);
    defer options.deinit(instance.ctx.allocator);

    const current: u32 = @intCast(options.items.len);
    if (value == current) return;

    if (value < current) {
        // Shrinking removes options from the END, in reverse order so the
        // surviving prefix keeps its indices.
        var i: u32 = current;
        while (i > value) : (i -= 1) {
            const option = options.items[i - 1];
            const parent = NodeImpl.getParent(option) orelse continue;
            _ = try interfaces.Node.call_removeChild(parent, option);
        }
        return;
    }

    // Growing appends blank option elements. Needs the node document, because
    // creating an element is the document's job.
    const node_internal = NodeImpl.getInternalState(instance) orelse return error.InvalidState;
    const document = node_internal.owner_document orelse return error.InvalidState;

    var i: u32 = current;
    while (i < value) : (i += 1) {
        const option = try interfaces.Document.call_createElement(
            document,
            runtime.DOMString.initInterned("option"),
            webidl.Opt(runtime.JSValue).notPassed(),
        );
        _ = try interfaces.Node.call_appendChild(instance, option);
    }
}

/// Setter for selectedIndex
/// Spec: https://html.spec.whatwg.org/multipage/form-elements.html#dom-select-selectedindex
pub fn set_selectedIndex(instance: *runtime.Instance, value: i32) anyerror!void {
    var options = try optionList(instance);
    defer options.deinit(instance.ctx.allocator);

    // "Set the selected index": clear every option, then select the one at the
    // given index if there is one. An out-of-range index (including -1) is not an
    // error - it legitimately leaves NOTHING selected, and unlike
    // `option.selected = false` it does not ask for a reset, so the first enabled
    // option must not quietly take over. That is what `.off_no_reset` encodes.
    const in_range = value >= 0 and @as(usize, @intCast(@max(value, 0))) < options.items.len;
    const target: usize = if (in_range) @intCast(value) else 0;

    for (options.items, 0..) |option, i| {
        if (in_range and i == target) {
            try OptionImpl.setSelectedness(option, .on);
        } else {
            try OptionImpl.setSelectedness(option, if (in_range) .off else .off_no_reset);
        }
    }
}

/// Setter for value
/// Spec: https://html.spec.whatwg.org/multipage/form-elements.html#dom-select-value
pub fn set_value(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // The half React depends on: `select.value = x` selects the first option
    // whose VALUE is x, and its dirtiness then keeps a later `selected` attribute
    // write from overriding it.
    const allocator = instance.ctx.allocator;
    var options = try optionList(instance);
    defer options.deinit(allocator);

    const wanted = value.asSlice();

    var match: ?usize = null;
    for (options.items, 0..) |option, i| {
        var option_value = try interfaces.HTMLOptionElement.get_value(option);
        defer option_value.deinit(allocator);
        if (std.mem.eql(u8, option_value.asSlice(), wanted)) {
            match = i;
            break;
        }
    }

    for (options.items, 0..) |option, i| {
        if (match != null and i == match.?) {
            try OptionImpl.setSelectedness(option, .on);
        } else {
            // No match at all means nothing is selected and nothing asks for a
            // reset, so `select.value = "nonexistent"` reads back "" rather than
            // the first option's value.
            try OptionImpl.setSelectedness(option, if (match == null) .off_no_reset else .off);
        }
    }
}

// ---------------------------------------------------------------------------
// Operations
// ---------------------------------------------------------------------------

/// Operation: item
/// Returns the option element at the specified index
/// Spec: https://html.spec.whatwg.org/multipage/form-elements.html#dom-select-item
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
    var options = try optionList(instance);
    defer options.deinit(instance.ctx.allocator);
    if (index >= options.items.len) return null;
    return options.items[index];
}

/// Operation: namedItem
/// Spec: https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#dom-htmloptionscollection-nameditem
pub fn call_namedItem(instance: *runtime.Instance, name: runtime.DOMString) anyerror!?*runtime.Instance {
    const wanted = name.asSlice();
    if (wanted.len == 0) return null;

    var options = try optionList(instance);
    defer options.deinit(instance.ctx.allocator);

    // id first, then name, per the collection's supported property names.
    for (options.items) |option| {
        const elem_internal = ElementImpl.getInternal(option) orelse continue;
        if (elem_internal.findAttribute(null, "id")) |entry| {
            if (std.mem.eql(u8, entry.value, wanted)) return option;
        }
    }
    for (options.items) |option| {
        const elem_internal = ElementImpl.getInternal(option) orelse continue;
        if (elem_internal.findAttribute(null, "name")) |entry| {
            if (std.mem.eql(u8, entry.value, wanted)) return option;
        }
    }
    return null;
}

/// Turn an argument that WebIDL typed as a union of interfaces into an instance.
///
/// The conversion layer hands a union-typed argument over as `runtime.JSValue`,
/// and an object arrives as a `.handle`, never a `.instance` - see the
/// `T == runtime.JSValue` branch in engines/v8/conversions.zig, which builds
/// `.{ .handle = .{ .ptr = value, .handle_scope = .local } }`. So the instance
/// has to come out of the wrapper's internal field.
///
/// Nothing is acquired here and nothing may be disposed: the handle belongs to
/// the argument-cleanup path, and reading an aligned internal field allocates no
/// `Global<T>` - unlike every `v8_*` call that RETURNS a handle pointer.
///
/// `EngineInterface` has no unwrap hook (only `wrapInstance`), so this goes
/// through the v8 module directly, the way FormData.zig and WebSocket.zig reach
/// for the isolate.
fn instanceFromJSValue(value: runtime.JSValue) ?*runtime.Instance {
    if (value.toInstance()) |unwrapped| return unwrapped;

    const v8 = @import("v8");
    const handle = value.asEngineHandle() orelse return null;

    const untagged = v8.untagPointer(handle);
    const js_value: *v8.ffi.Value = @ptrCast(untagged.ptr);
    if (!v8.ffi.v8_Value_IsObject(js_value)) return null;

    const object: *v8.ffi.Object = @ptrCast(js_value);
    return v8.wrapper_type_info_mod.unwrapAnyInstance(object);
}

fn isInclusiveAncestorOf(ancestor: *runtime.Instance, node: *runtime.Instance) bool {
    var current: ?*runtime.Instance = node;
    while (current) |c| {
        if (c == ancestor) return true;
        current = NodeImpl.getParent(c);
    }
    return false;
}

/// Operation: add
/// Spec: https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#dom-htmloptionscollection-add
pub fn call_add(instance: *runtime.Instance, element: runtime.JSValue, before: webidl.Opt(?runtime.JSValue)) anyerror!void {
    const new_option = instanceFromJSValue(element) orelse return error.TypeError;

    // 1. Adding an ancestor of the select would make a cycle.
    if (isInclusiveAncestorOf(new_option, instance)) return error.HierarchyRequestError;

    // 2-4. Resolve `before` to a reference node. It is either an element (which
    // must be inside the select) or an index into the list of options; anything
    // else, including omitted, null and undefined, means "append".
    var reference: ?*runtime.Instance = null;
    if (before.wasPassed()) {
        if (before.getValue()) |before_value| {
            switch (before_value) {
                .number => |n| {
                    // A non-integral or out-of-range index is not an error - it
                    // just leaves reference null.
                    if (n >= 0 and n == @floor(n)) {
                        reference = try call_item(instance, @intFromFloat(n));
                    }
                },
                .undefined, .null => {},
                else => {
                    const before_node = instanceFromJSValue(before_value) orelse
                        return error.TypeError;
                    if (!isInclusiveAncestorOf(instance, before_node)) return error.NotFoundError;
                    reference = before_node;
                },
            }
        }
    }

    // 3. Inserting an element before itself is a no-op rather than an error.
    if (reference) |ref| {
        if (ref == new_option) return;
    }

    // 5-6. Pre-insert into the reference's parent, which is not necessarily the
    // select - `before` may be an option inside an optgroup.
    const parent = if (reference) |ref| NodeImpl.getParent(ref) orelse instance else instance;
    _ = try interfaces.Node.call_insertBefore(parent, new_option, reference);
}

/// Operation: remove
/// Spec: https://html.spec.whatwg.org/multipage/form-elements.html#dom-select-remove
pub fn call_remove(instance: *runtime.Instance) anyerror!void {
    // This is the NO-ARGUMENT overload, which acts like ChildNode.remove() and
    // removes the select itself.
    //
    // TODO: the IDL also declares `remove(long index)`, which removes that
    // option, but codegen emits a single arity-0 binding (see the `methods`
    // table in interfaces/HTMLSelectElement.zig) so the index never reaches
    // here. Overload dispatch for this pair has to be fixed in
    // src/webidl/codegen/, not worked around here.
    try interfaces.Element.call_remove(instance);
}

/// Operation: setCustomValidity
pub fn call_setCustomValidity(instance: *runtime.Instance, @"error": runtime.DOMString) anyerror!void {
    _ = instance;
    _ = @"error";
    return error.NotImplemented;
}

/// Operation: checkValidity
pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: showPicker
pub fn call_showPicker(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: reportValidity
pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}
