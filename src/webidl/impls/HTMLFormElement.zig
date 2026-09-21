//! Implementation for HTMLFormElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLFormElement = interfaces.HTMLFormElement;

// Import related impls for attribute access
const ElementImpl = @import("Element.zig");
const NodeImpl = @import("Node.zig");
const DOMTokenListImpl = @import("DOMTokenList.zig");

pub const State = HTMLFormElement.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;
const Registry = utils.InstanceRegistry(InternalState);

/// Internal state for HTMLFormElement implementation
pub const InternalState = struct {
    /// Cached relList DOMTokenList instance
    rel_list: ?*runtime.Instance = null,

    pub fn deinit(self: *InternalState) void {
        _ = self;
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

    // Initialize HTMLFormElement's own internal state in registry
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    // The registry owns this block, so `Registry.remove` returns it to the
    // arena. With `set` it was dropped from the map and held to process
    // exit - 904 bytes per discarded element, measured.
    const internal = try Registry.createIn(instance, ArenaAllocator.get());
    internal.* = .{};

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up from registry
    if (Registry.get(instance)) |internal| {
        internal.deinit();
    }
    Registry.remove(instance);

    // Chain to parent class (via interface per Golden Rule #13)
    interfaces.HTMLElement.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &HTMLFormElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

// ---------------------------------------------------------------------------
// Reflected content attributes
//
// https://html.spec.whatwg.org/multipage/forms.html#the-form-element
//
// These were all `return error.NotImplemented`, which V8 turns into a thrown
// exception - so `form.method` THREW rather than returning its default. Every
// form test died on the first property read.
//
// Three kinds of reflection appear here and they are not interchangeable:
//   * plain      - return the attribute, or "" when absent (name, target, rel)
//   * URL        - resolve against the document base URL (action)
//   * enumerated - "limited to only known values": an unrecognised value maps
//                  to the INVALID VALUE DEFAULT, and a missing attribute to the
//                  MISSING VALUE DEFAULT, which are not always the same thing
// ---------------------------------------------------------------------------

/// The attribute's literal value, or "" when it is absent.
fn reflectString(instance: *runtime.Instance, comptime attr: []const u8) anyerror!runtime.DOMString {
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;
    if (elem_internal.findAttribute(null, attr)) |entry| {
        return runtime.DOMString.initDupe(instance.ctx.allocator, entry.value) catch return error.OutOfMemory;
    }
    return runtime.DOMString.initEmpty();
}

/// Enumerated reflection. `known` is matched ASCII-case-insensitively; anything
/// unmatched yields `invalid_default`, and an absent attribute `missing_default`.
fn reflectEnumerated(
    instance: *runtime.Instance,
    comptime attr: []const u8,
    comptime known: []const []const u8,
    comptime missing_default: []const u8,
    comptime invalid_default: []const u8,
) anyerror!runtime.DOMString {
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;
    const entry = elem_internal.findAttribute(null, attr) orelse
        return runtime.DOMString.initInterned(missing_default);

    inline for (known) |candidate| {
        if (std.ascii.eqlIgnoreCase(entry.value, candidate)) {
            return runtime.DOMString.initInterned(candidate);
        }
    }
    return runtime.DOMString.initInterned(invalid_default);
}

/// Getter for acceptCharset
pub fn get_acceptCharset(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // Reflects "accept-charset", NOT "acceptcharset" - the content attribute
    // name differs from the IDL name.
    return reflectString(instance, "accept-charset");
}

/// Getter for action
pub fn get_action(instance: *runtime.Instance) anyerror!runtime.USVString {
    // Not plain reflection. Per spec the action IDL attribute reflects the
    // content attribute, EXCEPT that on getting, a missing attribute OR an
    // empty one returns the node document's URL instead. The empty-string case
    // is the one that surprises: action="" is not "", it is the document URL.
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;

    if (elem_internal.findAttribute(null, "action")) |entry| {
        if (entry.value.len != 0) {
            return try instance.ctx.allocator.dupe(u8, entry.value);
        }
    }

    // Fall back to the document URL.
    const node_internal = NodeImpl.getInternalState(instance) orelse return error.InvalidState;
    if (node_internal.owner_document) |doc| {
        return interfaces.Document.get_URL(doc) catch
            try instance.ctx.allocator.dupe(u8, "");
    }
    return try instance.ctx.allocator.dupe(u8, "");
}

/// Getter for autocomplete
pub fn get_autocomplete(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // Missing and invalid both default to "on".
    return reflectEnumerated(instance, "autocomplete", &.{ "on", "off" }, "on", "on");
}

/// Getter for enctype
pub fn get_enctype(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflectEnumerated(
        instance,
        "enctype",
        &.{ "application/x-www-form-urlencoded", "multipart/form-data", "text/plain" },
        "application/x-www-form-urlencoded",
        "application/x-www-form-urlencoded",
    );
}

/// Getter for encoding
pub fn get_encoding(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // `encoding` is a historical alias for `enctype` and reflects the SAME
    // content attribute.
    return get_enctype(instance);
}

/// Getter for method
pub fn get_method(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // Missing and invalid both default to "get".
    return reflectEnumerated(instance, "method", &.{ "get", "post", "dialog" }, "get", "get");
}

/// Getter for name
/// Spec: https://html.spec.whatwg.org/multipage/forms.html#dom-form-name
/// Reflects the name attribute.
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // Use Element's attribute access
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;

    // Look for the "name" attribute
    if (elem_internal.findAttribute(null, "name")) |entry| {
        return runtime.DOMString.initDupe(instance.ctx.allocator, entry.value) catch return error.OutOfMemory;
    }

    return runtime.DOMString.initEmpty();
}

/// Getter for noValidate
pub fn get_noValidate(instance: *runtime.Instance) anyerror!bool {
    // A boolean attribute: presence is true regardless of value, so even
    // novalidate="false" is true.
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;
    return elem_internal.findAttribute(null, "novalidate") != null;
}

/// Getter for target
pub fn get_target(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflectString(instance, "target");
}

/// Getter for rel
/// Spec: https://html.spec.whatwg.org/multipage/forms.html#dom-form-rel
/// Reflects the rel attribute.
pub fn get_rel(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // Use Element's attribute access
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;

    // Look for the "rel" attribute
    if (elem_internal.findAttribute(null, "rel")) |entry| {
        return runtime.DOMString.initDupe(instance.ctx.allocator, entry.value) catch return error.OutOfMemory;
    }

    return runtime.DOMString.initEmpty();
}

/// Getter for relList
/// Spec: https://html.spec.whatwg.org/multipage/forms.html#dom-form-rellist
/// Returns a DOMTokenList reflecting the rel attribute.
pub fn get_relList(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = Registry.get(instance) orelse return error.InvalidState;
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;

    // Return cached DOMTokenList if it exists
    if (internal.rel_list) |existing| {
        return existing;
    }

    // Create a new DOMTokenList
    const token_list = interfaces.DOMTokenList.init(elem_internal.allocator, instance.ctx) catch return error.OutOfMemory;
    errdefer interfaces.DOMTokenList.deinit(token_list);

    // Initialize with current rel attribute value
    if (elem_internal.findAttribute(null, "rel")) |entry| {
        interfaces.DOMTokenList.set_value(token_list, runtime.DOMString.initInterned(entry.value)) catch return error.OutOfMemory;
    }

    // Associate with this element and the "rel" attribute
    DOMTokenListImpl.setElement(token_list, instance, runtime.DOMString.initInterned("rel"));

    // Cache for future access
    internal.rel_list = token_list;

    return token_list;
}

/// The form's "listed elements", per
/// https://html.spec.whatwg.org/multipage/forms.html#dom-form-elements
///
/// input[type=image] is deliberately excluded: it is a listed element but the
/// spec removes it from this particular collection.
const LISTED_ELEMENTS = [_][]const u8{
    "button", "fieldset", "input", "object", "output", "select", "textarea",
};

fn collectListedElements(node: *runtime.Instance, collection: *runtime.Instance) anyerror!void {
    const HTMLCollectionImpl = @import("HTMLCollection.zig");

    var child = NodeImpl.getFirstChild(node);
    while (child) |c| {
        if (NodeImpl.getNodeType(c) orelse 0 == NodeImpl.NodeType.ELEMENT_NODE) {
            if (ElementImpl.getInternal(c)) |elem_internal| {
                const name = elem_internal.local_name.asSlice();
                for (LISTED_ELEMENTS) |listed| {
                    if (std.ascii.eqlIgnoreCase(name, listed)) {
                        // input[type=image] is a listed element but is excluded
                        // from form.elements specifically.
                        const excluded = std.ascii.eqlIgnoreCase(name, "input") and
                            if (elem_internal.findAttribute(null, "type")) |t|
                                std.ascii.eqlIgnoreCase(t.value, "image")
                            else
                                false;
                        if (!excluded) try HTMLCollectionImpl.addElement(collection, c);
                        break;
                    }
                }
            }
        }
        // Descend unconditionally: controls nest inside fieldsets, divs and
        // anything else, and a nested <form> is a parse error rather than
        // something to guard against here.
        try collectListedElements(c, collection);
        child = NodeImpl.getNextSibling(c);
    }
}

/// Getter for elements
/// Spec: https://html.spec.whatwg.org/multipage/forms.html#dom-form-elements
pub fn get_elements(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;

    const collection = try interfaces.HTMLCollection.init(elem_internal.allocator, instance.ctx);
    errdefer interfaces.HTMLCollection.deinit(collection);

    try collectListedElements(instance, collection);
    return collection;
}

/// Getter for length
/// Spec: the number of elements in the form's elements collection.
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const collection = try get_elements(instance);
    defer interfaces.HTMLCollection.deinit(collection);
    return interfaces.HTMLCollection.get_length(collection);
}

/// Setter for acceptCharset
pub fn set_acceptCharset(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("accept-charset"), value);
}

/// Setter for action
pub fn set_action(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    // USVString is a plain []const u8. setAttribute copies into the attribute
    // store, so a borrowed view of the caller's bytes is safe here.
    try interfaces.Element.call_setAttribute(
        instance,
        runtime.DOMString.initInterned("action"),
        runtime.DOMString.initInterned(value),
    );
}

/// Setter for autocomplete
pub fn set_autocomplete(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("autocomplete"), value);
}

/// Setter for enctype
pub fn set_enctype(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("enctype"), value);
}

/// Setter for encoding
pub fn set_encoding(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // Alias for enctype - same content attribute, not a separate one.
    try set_enctype(instance, value);
}

/// Setter for method
pub fn set_method(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("method"), value);
}

/// Setter for name
/// Spec: https://html.spec.whatwg.org/multipage/forms.html#dom-form-name
/// Sets the name attribute.
pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // Use Element's setAttribute through the interface
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("name"), value);
}

/// Setter for noValidate
pub fn set_noValidate(instance: *runtime.Instance, value: bool) anyerror!void {
    // Boolean attribute: true adds it with the empty string, false removes it.
    // Setting it to "false" would still read back as true.
    const name = runtime.DOMString.initInterned("novalidate");
    if (value) {
        try interfaces.Element.call_setAttribute(instance, name, runtime.DOMString.initEmpty());
    } else {
        try interfaces.Element.call_removeAttribute(instance, name);
    }
}

/// Setter for target
pub fn set_target(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("target"), value);
}

/// Setter for rel
/// Spec: https://html.spec.whatwg.org/multipage/forms.html#dom-form-rel
/// Sets the rel attribute.
pub fn set_rel(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // Use Element's setAttribute through the interface
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("rel"), value);
}

/// Operation: requestSubmit
pub fn call_requestSubmit(instance: *runtime.Instance, submitter: webidl.Opt(?*runtime.Instance)) anyerror!void {
    _ = instance;
    _ = submitter;
    return error.NotImplemented;
}

/// Operation: reset
pub fn call_reset(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: checkValidity
pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: submit
pub fn call_submit(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: reportValidity
pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}
