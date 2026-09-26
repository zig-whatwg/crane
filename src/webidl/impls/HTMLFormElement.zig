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

// Form submission (below call_submit).
const encoding_mod = @import("encoding");
const basic_parser = @import("basic_parser");
const url_serializer = @import("url_serializer");
const encode_sets = @import("encode_sets");
const v8 = @import("v8");
const log = std.log.scoped(.forms);

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

    /// HTML § 4.10.22.3 "planned navigation": the token of the queued task
    /// that will navigate, or 0 for null.
    planned_navigation: u64 = 0,

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
///
/// HTML § 4.10.22.3: submit the form from the form itself, "submitted from
/// submit() method" true - so no submit event and no constraint validation.
pub fn call_submit(instance: *runtime.Instance) anyerror!void {
    try submitForm(instance);
}

// ============================================================================
// Form submission (HTML § 4.10.22.3 - § 4.10.22.5)
//
// Everything below reaches other elements through their interfaces. Two
// stated deviations:
//
//   * No `formdata` event (§ 4.10.22.4 steps 6-7): firing one needs a FormData
//     over this entry list, which FormData's impl cannot yet be handed. So the
//     "constructing entry list" re-entrancy guard has nothing to guard.
//   * POST ("submit as entity body") does not navigate: Crane's navigations
//     fetch with GET and cannot carry a request body. TODO(forms).
// ============================================================================

/// An entry (§ 4.10.22.4): a name and a value, both scalar value strings in
/// UTF-8. A File value is represented by its name, which is all the
/// application/x-www-form-urlencoded serializer reads of it.
const Entry = struct {
    name: []u8,
    value: []u8,
};

const EntryList = std.ArrayListUnmanaged(Entry);

fn freeEntries(allocator: std.mem.Allocator, entries: *EntryList) void {
    for (entries.items) |entry| {
        allocator.free(entry.name);
        allocator.free(entry.value);
    }
    entries.deinit(allocator);
}

/// Copy a string a getter handed over, and free the getter's copy with the
/// allocator it was made in (the element's context allocator).
fn takeString(allocator: std.mem.Allocator, owner: *runtime.Instance, s: runtime.DOMString) ![]u8 {
    var owned = s;
    defer owned.deinit(owner.ctx.allocator);
    return allocator.dupe(u8, owned.asSlice());
}

/// The attribute's value, or null when the element has no such attribute.
fn attributeValue(allocator: std.mem.Allocator, element: *runtime.Instance, comptime name: []const u8) !?[]u8 {
    // Presence is asked separately: Element.getAttribute answers "" for a
    // missing attribute, which would make an absent accept-charset pick
    // UTF-8 over the document's encoding and a checkbox without a value
    // submit "" instead of "on".
    if (!hasAttribute(element, name)) return null;
    const value = (try interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned(name))) orelse return null;
    return try takeString(allocator, element, value);
}

fn hasAttribute(element: *runtime.Instance, comptime name: []const u8) bool {
    return interfaces.Element.call_hasAttribute(element, runtime.DOMString.initInterned(name)) catch false;
}

/// Whether `node` is an element with local name `name` (HTML elements are
/// lower-case, so this is an exact match on the lower-cased name).
fn isElementNamed(node: *runtime.Instance, comptime name: []const u8) bool {
    // Only an element may be handed to Element's members: the ancestor walks
    // reach the Document and the child walks reach Text, and Element's
    // accessors read whatever state they are given as an element's.
    const node_type = interfaces.Node.get_nodeType(node) catch return false;
    if (node_type != 1) return false; // ELEMENT_NODE
    var local = interfaces.Element.get_localName(node) catch return false;
    defer local.deinit(node.ctx.allocator);
    return std.ascii.eqlIgnoreCase(local.asSlice(), name);
}

fn parentOf(node: *runtime.Instance) ?*runtime.Instance {
    return interfaces.Node.get_parentNode(node) catch null;
}

/// Whether `node` is `ancestor` or one of its descendants.
fn isInclusiveDescendant(node: *runtime.Instance, ancestor: *runtime.Instance) bool {
    var current: ?*runtime.Instance = node;
    while (current) |n| : (current = parentOf(n)) {
        if (n == ancestor) return true;
    }
    return false;
}

/// The first `legend` element child of `fieldset`, if any.
fn firstLegendChild(fieldset: *runtime.Instance) ?*runtime.Instance {
    var child = interfaces.Node.get_firstChild(fieldset) catch null;
    while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) {
        if (isElementNamed(c, "legend")) return c;
    }
    return null;
}

/// § 4.10.19.5: a form control is disabled if it has a `disabled` attribute,
/// or is a descendant of a disabled fieldset and not of that fieldset's first
/// legend child.
fn isDisabledControl(field: *runtime.Instance) bool {
    if (hasAttribute(field, "disabled")) return true;
    var ancestor = parentOf(field);
    while (ancestor) |a| : (ancestor = parentOf(a)) {
        if (!isElementNamed(a, "fieldset") or !hasAttribute(a, "disabled")) continue;
        const legend = firstLegendChild(a) orelse return true;
        if (!isInclusiveDescendant(field, legend)) return true;
    }
    return false;
}

/// § 4.10.10: an option is disabled if it has a `disabled` attribute or is a
/// child of a disabled optgroup.
fn isDisabledOption(option: *runtime.Instance) bool {
    if (hasAttribute(option, "disabled")) return true;
    const parent = parentOf(option) orelse return false;
    return isElementNamed(parent, "optgroup") and hasAttribute(parent, "disabled");
}

fn hasAncestorNamed(node: *runtime.Instance, comptime name: []const u8) bool {
    var ancestor = parentOf(node);
    while (ancestor) |a| : (ancestor = parentOf(a)) {
        if (isElementNamed(a, name)) return true;
    }
    return false;
}

/// The node after `node` in tree order within `root`'s subtree, not
/// descending into `node` when `skip_children` is set.
fn nextInTree(node: *runtime.Instance, root: *runtime.Instance, skip_children: bool) ?*runtime.Instance {
    if (!skip_children) {
        if (interfaces.Node.get_firstChild(node) catch null) |child| return child;
    }
    var current = node;
    while (current != root) {
        if (interfaces.Node.get_nextSibling(current) catch null) |sibling| return sibling;
        current = parentOf(current) orelse return null;
    }
    return null;
}

/// § 4.10.7 "get the list of options" of a select: its option descendants in
/// tree order, not looking inside a select, hr, option or datalist, nor
/// inside an optgroup that is itself inside an optgroup.
fn forEachOption(select: *runtime.Instance, context: anytype, comptime visit: fn (@TypeOf(context), *runtime.Instance) anyerror!void) !void {
    // Steps 1-2: node is select's first child.
    var node = interfaces.Node.get_firstChild(select) catch null;
    // Step 3.
    while (node) |n| {
        // 3.1: an option is in the list.
        const is_option = isElementNamed(n, "option");
        if (is_option) try visit(context, n);
        // 3.2: the next descendant, skipping these subtrees.
        const skip = is_option or isElementNamed(n, "select") or isElementNamed(n, "hr") or
            isElementNamed(n, "datalist") or (isElementNamed(n, "optgroup") and hasOptgroupAncestorWithin(n, select));
        node = nextInTree(n, select, skip);
    }
}

/// Whether an optgroup ancestor lies between `node` and `select`.
fn hasOptgroupAncestorWithin(node: *runtime.Instance, select: *runtime.Instance) bool {
    var ancestor = parentOf(node);
    while (ancestor) |a| : (ancestor = parentOf(a)) {
        if (a == select) return false;
        if (isElementNamed(a, "optgroup")) return true;
    }
    return false;
}

/// § 4.10.22.5 "Picking an encoding for the form".
fn pickEncoding(allocator: std.mem.Allocator, form: *runtime.Instance, document: *runtime.Instance) !*const encoding_mod.Encoding {
    // Step 1: Let encoding be the document's character encoding.
    var chosen: *const encoding_mod.Encoding = encoding_mod.UTF_8;
    {
        var charset = try interfaces.Document.get_characterSet(document);
        defer charset.deinit(document.ctx.allocator);
        if (encoding_mod.getEncoding(charset.asSlice())) |e| chosen = e;
    }
    // Step 2: If the form element has an accept-charset attribute:
    if (try attributeValue(allocator, form, "accept-charset")) |input| {
        defer allocator.free(input);
        // 2.2-2.4: the labels, split on ASCII whitespace, that name an encoding.
        var labels = std.mem.tokenizeAny(u8, input, " \t\n\x0C\r");
        var candidate: ?*const encoding_mod.Encoding = null;
        while (labels.next()) |label| {
            if (encoding_mod.getEncoding(label)) |e| {
                candidate = e;
                break;
            }
        }
        // 2.5-2.6: the first of them, or UTF-8 if there are none.
        chosen = candidate orelse encoding_mod.UTF_8;
    }
    // Step 3: "get an output encoding".
    return encoding_mod.getOutputEncoding(chosen);
}

/// § 4.10.22.4 "Constructing the entry list", for a submission whose
/// submitter is the form itself: every button is skipped (5.1), and so is
/// every image button (5.2.1).
fn constructEntryList(allocator: std.mem.Allocator, form: *runtime.Instance, encoding: *const encoding_mod.Encoding) !EntryList {
    var entries: EntryList = .empty;
    errdefer freeEntries(allocator, &entries);

    // Step 3: the submittable elements whose form owner is form, in tree
    // order. Walked here rather than read from `form.elements`: that
    // collection is [SameObject], cached on the form by the interface, and
    // a snapshot of the controls at its first read. A nested form owns its
    // own descendants. (A control associated by its `form` attribute is not
    // found; TODO(forms).)
    var next = nextInTree(form, form, false);
    while (next) |field| {
        const nested_form = isElementNamed(field, "form");
        next = nextInTree(field, form, nested_form);
        if (nested_form) continue;
        const kind: enum { input, select, textarea } = if (isElementNamed(field, "input"))
            .input
        else if (isElementNamed(field, "select"))
            .select
        else if (isElementNamed(field, "textarea"))
            .textarea
        else
            // button is always skipped here (5.1); fieldset, object and
            // output are listed but not submittable.
            continue;

        // 5.1: a datalist ancestor, or disabled.
        if (hasAncestorNamed(field, "datalist") or isDisabledControl(field)) continue;

        var input_type: []u8 = &.{};
        defer allocator.free(input_type);
        if (kind == .input) {
            input_type = try takeString(allocator, field, try interfaces.HTMLInputElement.get_type(field));
            // 5.1: a button that is not the submitter; 5.2.1: an image button
            // that is not the submitter.
            if (eql(input_type, "submit") or eql(input_type, "reset") or eql(input_type, "button") or eql(input_type, "image")) continue;
            // 5.1: an unchecked checkbox or radio button.
            if ((eql(input_type, "checkbox") or eql(input_type, "radio")) and !(try interfaces.HTMLInputElement.get_checked(field))) continue;
        }

        // 5.4: no name attribute, or an empty one.
        const name = (try attributeValue(allocator, field, "name")) orelse continue;
        if (name.len == 0) {
            allocator.free(name);
            continue;
        }
        defer allocator.free(name);

        switch (kind) {
            .select => {
                // 5.6: each option in the list of options whose selectedness
                // is true and that is not disabled. (Not `selectedOptions`:
                // it is [SameObject] and cached, like `form.elements`.)
                const Visit = struct {
                    allocator: std.mem.Allocator,
                    entries: *EntryList,
                    name: []const u8,
                    fn option(self: @This(), element: *runtime.Instance) anyerror!void {
                        if (!(try interfaces.HTMLOptionElement.get_selected(element))) return;
                        if (isDisabledOption(element)) return;
                        const value = try takeString(self.allocator, element, try interfaces.HTMLOptionElement.get_value(element));
                        try appendEntry(self.allocator, self.entries, self.name, value);
                    }
                };
                try forEachOption(field, Visit{ .allocator = allocator, .entries = &entries, .name = name }, Visit.option);
            },
            .textarea => {
                // 5.10: the value.
                const value = try takeString(allocator, field, try interfaces.HTMLTextAreaElement.get_value(field));
                try appendEntry(allocator, &entries, name, value);
            },
            .input => {
                const value: []u8 = if (eql(input_type, "checkbox") or eql(input_type, "radio"))
                    // 5.7: the value attribute, or "on".
                    (try attributeValue(allocator, field, "value")) orelse try allocator.dupe(u8, "on")
                else if (eql(input_type, "file"))
                    // 5.8.1: no files are ever selected here, so a File with an
                    // empty name - represented by that name.
                    try allocator.dupe(u8, "")
                else if (eql(input_type, "hidden") and std.ascii.eqlIgnoreCase(name, "_charset_"))
                    // 5.9: the encoding's name.
                    try allocator.dupe(u8, encoding.name)
                else
                    // 5.10: the value.
                    try takeString(allocator, field, try interfaces.HTMLInputElement.get_value(field));
                try appendEntry(allocator, &entries, name, value);
            },
        }
    }
    return entries;
}

fn eql(a: []const u8, comptime b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

/// "Create an entry" and append it. Takes ownership of `value`.
fn appendEntry(allocator: std.mem.Allocator, entries: *EntryList, name: []const u8, value: []u8) !void {
    errdefer allocator.free(value);
    const name_copy = try allocator.dupe(u8, name);
    errdefer allocator.free(name_copy);
    try entries.append(allocator, .{ .name = name_copy, .value = value });
}

/// § 4.10.22.6 "convert to a list of name-value pairs", steps 2.1 and 2.3:
/// every CR not followed by LF and every LF not preceded by CR becomes CRLF.
fn normalizeNewlines(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    var i: usize = 0;
    while (i < s.len) : (i += 1) {
        switch (s[i]) {
            '\r' => {
                try out.appendSlice(allocator, "\r\n");
                if (i + 1 < s.len and s[i + 1] == '\n') i += 1;
            },
            '\n' => try out.appendSlice(allocator, "\r\n"),
            else => |c| try out.append(allocator, c),
        }
    }
    return out.toOwnedSlice(allocator);
}

/// URL's application/x-www-form-urlencoded percent-encode set.
fn inFormUrlencodedSet(byte: u8) bool {
    return encode_sets.shouldEncode(byte, .form_urlencoded);
}

/// URL § 5.2 "application/x-www-form-urlencoded serializer", given the pairs
/// of `entries` (converted as above) and `encoding`.
fn serializeEntries(allocator: std.mem.Allocator, entries: []const Entry, encoding: *const encoding_mod.Encoding) ![]u8 {
    var output: std.ArrayListUnmanaged(u8) = .empty;
    errdefer output.deinit(allocator);
    for (entries) |entry| {
        const name = try normalizeNewlines(allocator, entry.name);
        defer allocator.free(name);
        const value = try normalizeNewlines(allocator, entry.value);
        defer allocator.free(value);
        // Step 3.4: "&" between tuples.
        if (output.items.len > 0) try output.append(allocator, '&');
        // Steps 3.2-3.3 and 3.5.
        try encoding_mod.percentEncodeAfterEncoding(allocator, &output, encoding, name, inFormUrlencodedSet, true);
        try output.append(allocator, '=');
        try encoding_mod.percentEncodeAfterEncoding(allocator, &output, encoding, value, inFormUrlencodedSet, true);
    }
    return output.toOwnedSlice(allocator);
}

/// § 4.10.22.3 "submit", from the form itself with "submitted from submit()
/// method" true (steps 5.1-5.9 are skipped).
fn submitForm(form: *runtime.Instance) !void {
    const allocator = form.ctx.allocator;

    // Step 1: If form cannot navigate, then return. (Not connected; a
    // document that is not fully active has no navigable to reach below.)
    if (!(try interfaces.Node.get_isConnected(form))) return;
    // Step 3: form document.
    const document = (try interfaces.Node.get_ownerDocument(form)) orelse return;

    // Step 6: Let encoding be the result of picking an encoding for the form.
    const encoding = try pickEncoding(allocator, form, document);
    // Step 7: Let entry list be the result of constructing the entry list.
    var entries = try constructEntryList(allocator, form, encoding);
    defer freeEntries(allocator, &entries);

    // Step 10: method - the form's, as the form is the submitter.
    var method_string = try interfaces.HTMLFormElement.get_method(form);
    defer method_string.deinit(form.ctx.allocator);
    const method = method_string.asSlice();
    // Step 11: dialog closes the nearest dialog ancestor; nothing navigates.
    // TODO(forms): close the dialog.
    if (eql(method, "dialog")) return;

    // Steps 12-13: action, or the form document's URL when it is empty.
    const document_url = try interfaces.Document.get_URL(document);
    defer document.ctx.allocator.free(document_url);
    const action_attribute = try attributeValue(allocator, form, "action");
    defer if (action_attribute) |a| allocator.free(a);
    const action: []const u8 = if (action_attribute) |a| (if (a.len > 0) a else document_url) else document_url;

    // Steps 14-15: parse it relative to the document. (The document's
    // encoding does not reach the URL parser; see encoding-parse.)
    var base = basic_parser.parse(allocator, document_url, null) catch null;
    defer if (base) |*b| b.deinit();
    var parsed_action = basic_parser.parse(allocator, action, if (base) |*b| b else null) catch return;
    defer parsed_action.deinit();

    // Steps 18-23: the target. The navigable for it is chosen when the
    // planned navigation runs (dom.navigables), which opens a new one for
    // "_blank" or a name nothing has.
    const target = (try attributeValue(allocator, form, "target")) orelse try allocator.dupe(u8, "");
    errdefer allocator.free(target);

    // Step 26: the scheme and method pick the behaviour.
    const scheme = parsed_action.scheme();
    const is_get = eql(method, "get");
    const mutate = is_get and (eql(scheme, "http") or eql(scheme, "https") or eql(scheme, "data") or eql(scheme, "file"));
    if (!is_get and (eql(scheme, "http") or eql(scheme, "https"))) {
        // "Submit as entity body". TODO(forms): needs a navigation that
        // carries a POST resource.
        allocator.free(target);
        return;
    }
    if (eql(scheme, "mailto")) {
        // "Mail with headers" / "Mail as body": no mail client to hand to.
        allocator.free(target);
        return;
    }
    if (mutate) {
        // "Mutate action URL": pairs, serialized with encoding, become the query.
        const query = try serializeEntries(allocator, entries.items, encoding);
        defer allocator.free(query);
        try parsed_action.setQuery(query);
    }
    // Otherwise "get action URL": parsed action as it is.

    const url = try url_serializer.serialize(allocator, &parsed_action, false);
    planNavigation(form, url, target);
}

/// A planned navigation (§ 4.10.22.3 "plan to navigate"): the queued task's
/// data. The form is held by address, so it is identified by its slab
/// generation and its planned-navigation token before anything touches it.
const PlannedNavigation = struct {
    form: *runtime.Instance,
    form_generation: u64,
    token: u64,
    url: []const u8,
    target: []const u8,
    allocator: std.mem.Allocator,

    fn destroy(self: *PlannedNavigation) void {
        self.allocator.free(self.url);
        self.allocator.free(self.target);
        self.allocator.destroy(self);
    }
};

/// Source of planned-navigation tokens: never reused, never zero.
threadlocal var next_navigation_token: u64 = 1;

/// "Plan to navigate" to `url`. Takes ownership of `url` and `target`.
fn planNavigation(form: *runtime.Instance, url: []const u8, target: []const u8) void {
    const allocator = form.ctx.allocator;
    const task = allocator.create(PlannedNavigation) catch {
        allocator.free(url);
        allocator.free(target);
        return;
    };
    task.* = .{
        .form = form,
        .form_generation = runtime.SlabAllocator.generationOf(form),
        .token = next_navigation_token,
        .url = url,
        .target = target,
        .allocator = allocator,
    };
    next_navigation_token += 1;

    const internal = Registry.get(form) orelse return task.destroy();
    const event_loop = form.ctx.getOptionalEventLoop() orelse return task.destroy();
    // Steps 3 and 5: this plan replaces any earlier one, whose task then
    // finds a different token and does nothing.
    internal.planned_navigation = task.token;
    // Step 4: queue a task that navigates.
    event_loop.queueTask(.{ .callback = &runPlannedNavigation, .context = task });
}

fn runPlannedNavigation(data: ?*anyopaque) void {
    const task: *PlannedNavigation = @ptrCast(@alignCast(data orelse return));
    defer task.destroy();

    // The form may have been collected and its slot reissued since.
    if (runtime.SlabAllocator.generationOf(task.form) != task.form_generation) return;
    const internal = Registry.get(task.form) orelse return;
    if (internal.planned_navigation != task.token) return;
    // Step 4.1: Set the form's planned navigation to null.
    internal.planned_navigation = 0;

    // A task is entered from the event loop, not from script: it has no
    // HandleScope or entered context of its own.
    const scope = v8.JsScope.init(task.form.ctx) orelse return;
    defer scope.deinit();

    // Step 4.2: "Navigate targetNavigable to url using the form element's
    // node document, with historyHandling set to historyHandling" - which
    // submit step 22 made "replace" when the form document is the target's
    // active document and has not completely loaded. The rules for choosing
    // a navigable and the navigation are the navigables' (dom.navigables).
    const document = (interfaces.Node.get_ownerDocument(task.form) catch null) orelse return;
    const navigables = @import("dom").navigables;
    if (!navigables.isInstalled()) {
        const installer = interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("iframe"), webidl.Opt(runtime.JSValue).notPassed()) catch return;
        installer.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(installer));
    }
    navigables.navigateByTarget(document, .{
        .target = task.target,
        .url = task.url,
        .replace_if_source_not_loaded = true,
    });
}

/// Operation: reportValidity
pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}
