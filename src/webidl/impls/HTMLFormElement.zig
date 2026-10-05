//! Implementation for HTMLFormElement interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const fetch_body = @import("fetch_body.zig");
const same_object = @import("same_object.zig");
const HTMLFormElement = interfaces.HTMLFormElement;

// Form submission (below call_submit).
const encoding_mod = @import("encoding");
const basic_parser = @import("basic_parser");
const url_serializer = @import("url_serializer");
const encode_sets = @import("encode_sets");
const log = std.log.scoped(.forms);

// Import related impls for attribute access
const ElementImpl = @import("Element.zig");
const NodeImpl = @import("Node.zig");
const form_associated = @import("html").form_associated;
const attributeValue = form_associated.attributeValue;
const hasAttribute = form_associated.hasAttribute;
const isElementNamed = form_associated.isElementNamed;
const parentOf = form_associated.parentOf;
const nextInTree = form_associated.nextInTree;

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
    /// HTML § 4.10.22.3 "planned navigation": the token of the queued task
    /// that will navigate, or 0 for null.
    planned_navigation: u64 = 0,
    /// § 4.10.22.3 "constructing entry list", initially false.
    constructing_entry_list: bool = false,
    /// § 4.10.22.3 "firing submission events", initially false.
    firing_submission_events: bool = false,
    /// § 4.10.22 "locked for reset", initially false.
    locked_for_reset: bool = false,

    pub fn deinit(self: *InternalState) void {
        _ = self;
    }
};

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // The form's algorithms other element types run (a submit button's
    // activation, FormData's constructor): installed before anyone can hold
    // a form.
    @import("dom").form_submission.install(submission_algorithms);
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
// Plain [Reflect] attributes (acceptCharset, name, noValidate, target, rel)
// and the [ReflectSetter] action setter are the generated interface's own
// (src/webidl/impls/reflection.zig). What is left here is not plain:
//   * action     - a URL getter with the document URL as its fallback
//   * enumerated - "limited to only known values": an unrecognised value maps
//                  to the INVALID VALUE DEFAULT, and a missing attribute to the
//                  MISSING VALUE DEFAULT, which are not always the same thing
// ---------------------------------------------------------------------------

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

/// Setter for autocomplete
pub fn set_autocomplete(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("autocomplete"), .{ .domstring = value });
}

/// Setter for enctype
pub fn set_enctype(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("enctype"), .{ .domstring = value });
}

/// Setter for encoding
pub fn set_encoding(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // Alias for enctype - same content attribute, not a separate one.
    try set_enctype(instance, value);
}

/// Setter for method
pub fn set_method(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("method"), .{ .domstring = value });
}

/// Operation: requestSubmit
/// Spec: https://html.spec.whatwg.org/multipage/forms.html#dom-form-requestsubmit
///
/// 1. If submitter is not null, then:
///    1. If submitter is not a submit button, then throw a TypeError.
///    2. If submitter's form owner is not this form element, then throw a
///       "NotFoundError" DOMException.
/// 2. Otherwise, set submitter to this form element.
/// 3. Submit this form element, from submitter.
pub fn call_requestSubmit(instance: *runtime.Instance, submitter: webidl.Opt(?*runtime.Instance)) anyerror!void {
    const given: ?*runtime.Instance = if (submitter.was_passed) submitter.value else null;
    if (given) |element| {
        if (!form_associated.isSubmitButton(element)) return error.TypeError;
        if (form_associated.formOwner(element) != instance) return error.NotFoundError;
        return submit(instance, element, .{});
    }
    try submit(instance, instance, .{});
}

/// Operation: reset
/// Spec: https://html.spec.whatwg.org/multipage/forms.html#dom-form-reset
///
/// 1. If this's locked for reset is true, then return.
/// 2. Set this's locked for reset to true.
/// 3. Reset this.
/// 4. Set this's locked for reset to false.
pub fn call_reset(instance: *runtime.Instance) anyerror!void {
    const internal = Registry.get(instance) orelse return;
    if (internal.locked_for_reset) return;
    internal.locked_for_reset = true;
    // Looked up again: the reset event's listeners can run anything.
    defer if (Registry.get(instance)) |after| {
        after.locked_for_reset = false;
    };
    try resetForm(instance);
}

/// Operation: checkValidity
pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: submit
///
/// HTML § 4.10.22.3: "submit this from this, with submitted from submit()
/// method set to true" - so no submit event and no constraint validation.
pub fn call_submit(instance: *runtime.Instance) anyerror!void {
    try submit(instance, instance, .{ .from_submit_method = true });
}

/// Installed into dom.form_submission when a form is made.
const submission_algorithms: @import("dom").form_submission.Implementation = .{
    .submit = &submitFromHook,
    .reset = &resetForm,
    .construct_entry_list = &constructEntryListInto,
};

fn submitFromHook(form: *runtime.Instance, submitter: *runtime.Instance, user_involvement: @import("dom").form_submission.UserInvolvement) anyerror!void {
    try submit(form, submitter, .{ .user_involvement = user_involvement });
}

// ============================================================================
// Resetting a form (HTML § 4.10.23)
// ============================================================================

/// "When a form element form is reset, run these steps:
/// 1. Let reset be the result of firing an event named reset at form, with
///    the bubbles and cancelable attributes initialized to true.
/// 2. If reset is true, then invoke the reset algorithm of each resettable
///    element whose form owner is form."
fn resetForm(form: *runtime.Instance) anyerror!void {
    const event = try interfaces.Event.call_constructor(
        form.ctx,
        runtime.DOMString.initInterned("reset"),
        webidl.Opt(dictionaries.EventInit).passed(.{ .bubbles = true, .cancelable = true }),
    );
    // A listener can keep the event; only one nothing wrapped is freed here.
    const generation = runtime.SlabAllocator.generationOf(event);
    const reset = blk: {
        defer event.releaseIfUnwrapped(generation);
        break :blk try @import("dom").fire_event.dispatchTrusted(form, event);
    };
    if (!reset) return;

    // The resettable elements - input, output, select and textarea - whose
    // form owner is form, in tree order. Collected first: a reset algorithm
    // changes state, never the tree, but nothing here depends on that.
    const allocator = form.ctx.allocator;
    var controls: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer controls.deinit(allocator);
    const root = form_associated.rootOf(form);
    var node: ?*runtime.Instance = root;
    while (node) |n| : (node = nextInTree(n, root, false)) {
        if (!form_associated.isElement(n)) continue;
        const resettable = form_associated.isInput(n) or form_associated.isSelect(n) or
            form_associated.isTextArea(n) or n.stateAs(interfaces.HTMLOutputElement.State) != null;
        if (!resettable) continue;
        if (form_associated.formOwner(n) != form) continue;
        try controls.append(allocator, n);
    }
    const form_controls = @import("dom").form_controls;
    for (controls.items) |control| form_controls.reset(control);
}

// ============================================================================
// Form submission (HTML § 4.10.22.3 - § 4.10.22.5)
//
// Everything below reaches other elements through their interfaces and the
// shared form-associated algorithms (form_associated.zig). Stated
// deviations:
//
//   * Constraint validation (submit step 5.4) is not implemented, so every
//     form validates: an invalid control does not stop a submission.
//   * "Submit as entity body" encodes multipart/form-data through Fetch's
//     FormData extraction: UTF-8 whatever the form's encoding, and a file
//     control's empty File as an empty string field (FormData cannot yet be
//     handed a Blob).
//   * An Image Button's selected coordinate is always (0, 0): nothing is
//     rendered, so no activation selects one.
// ============================================================================

/// An entry (§ 4.10.22.4): a name and a value, both scalar value strings in
/// UTF-8. A File value is represented by its name, which is all the
/// application/x-www-form-urlencoded serializer reads of it.
const Entry = struct {
    name: []u8,
    value: []u8,
    /// A file control's entry: its value is a File, represented by its name.
    is_file: bool = false,
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

/// Whether `element` is a submittable element: button, input, select or
/// textarea (form-associated custom elements are not implemented).
fn isSubmittable(element: *runtime.Instance) bool {
    return form_associated.isButton(element) or form_associated.isInput(element) or
        form_associated.isSelect(element) or form_associated.isTextArea(element);
}

/// § 4.10.22.4 "construct the entry list" given form, submitter (null when
/// the form is its own submitter) and encoding. Null when the form is
/// already constructing one.
fn constructEntryList(allocator: std.mem.Allocator, form: *runtime.Instance, submitter: ?*runtime.Instance, encoding: *const encoding_mod.Encoding) !?EntryList {
    // 1. If form's constructing entry list is true, then return null.
    const internal = Registry.get(form) orelse return null;
    if (internal.constructing_entry_list) return null;
    // 2. Set form's constructing entry list to true.
    internal.constructing_entry_list = true;
    // 8, however this leaves (the formdata event's listeners can run
    // anything, so the state is looked up again).
    defer if (Registry.get(form)) |after| {
        after.constructing_entry_list = false;
    };

    // 4. Let entry list be a new empty entry list.
    var entries: EntryList = .empty;
    errdefer freeEntries(allocator, &entries);

    // 3, 5. The submittable elements whose form owner is form, in tree order.
    // A control can be associated from anywhere in the form's tree through
    // its form attribute, so the whole tree is walked.
    const root = form_associated.rootOf(form);
    var next: ?*runtime.Instance = root;
    while (next) |field| : (next = nextInTree(field, root, false)) {
        if (!form_associated.isElement(field) or !isSubmittable(field)) continue;
        if (form_associated.formOwner(field) != form) continue;
        try appendFieldEntries(allocator, &entries, field, submitter, encoding);
    }

    // 6. Let form data be a new FormData object associated with entry list.
    const form_data = try entryListFormData(form, entries.items);
    const form_data_generation = runtime.SlabAllocator.generationOf(form_data);
    defer form_data.releaseIfUnwrapped(form_data_generation);

    // 7. Fire an event named formdata at form using FormDataEvent, with the
    //    formData attribute initialized to form data and the bubbles
    //    attribute initialized to true.
    {
        const event = try interfaces.FormDataEvent.call_constructor(
            form.ctx,
            runtime.DOMString.initInterned("formdata"),
            .{ .base = .{ .bubbles = true }, .formData = form_data },
        );
        const generation = runtime.SlabAllocator.generationOf(event);
        defer event.releaseIfUnwrapped(generation);
        _ = try @import("dom").fire_event.dispatchTrusted(form, event);
    }

    // 9. Return a clone of entry list - as the formdata event's listeners
    //    left it, through form data.
    freeEntries(allocator, &entries);
    entries = .empty;
    const after = interfaces.FormData.getEntriesForIterable(form_data) orelse &.{};
    for (after) |entry| {
        switch (entry.value) {
            .usvstring => |value| try appendEntry(allocator, &entries, entry.name, try allocator.dupe(u8, value)),
            .file => |file| {
                // A File is represented by its name; a Blob that is not a
                // File became one named "blob" (XHR "create an entry").
                const name: []u8 = if (file.stateAs(interfaces.File.State) != null)
                    try takeString(allocator, file, try interfaces.File.get_name(file))
                else
                    try allocator.dupe(u8, "blob");
                try appendEntry(allocator, &entries, entry.name, name);
                entries.items[entries.items.len - 1].is_file = true;
            },
        }
    }
    return entries;
}

/// Step 5's substeps for one field: append its entries, if any.
fn appendFieldEntries(allocator: std.mem.Allocator, entries: *EntryList, field: *runtime.Instance, submitter: ?*runtime.Instance, encoding: *const encoding_mod.Encoding) !void {
    var type_buffer: [16]u8 = undefined;
    const input_type: []const u8 = if (form_associated.isInput(field)) form_associated.inputType(field, &type_buffer) else "";
    const is_input = form_associated.isInput(field);

    // 5.1: a datalist ancestor; disabled; a button that is not submitter; an
    // unchecked checkbox or radio button.
    if (hasAncestorNamed(field, "datalist") or form_associated.isDisabled(field)) return;
    if (form_associated.isButtonControl(field) and field != submitter) return;
    if (is_input and (eql(input_type, "checkbox") or eql(input_type, "radio")) and
        !(try interfaces.HTMLInputElement.get_checked(field))) return;

    // 5.2: an Image Button (the submitter, per 5.1): name.x and name.y, the
    // selected coordinate.
    if (is_input and eql(input_type, "image")) {
        const given = (try attributeValue(allocator, field, "name")) orelse try allocator.dupe(u8, "");
        defer allocator.free(given);
        const prefix: []const u8 = if (given.len > 0) try std.fmt.allocPrint(allocator, "{s}.", .{given}) else "";
        defer if (prefix.len > 0) allocator.free(prefix);
        const name_x = try std.fmt.allocPrint(allocator, "{s}x", .{prefix});
        defer allocator.free(name_x);
        const name_y = try std.fmt.allocPrint(allocator, "{s}y", .{prefix});
        defer allocator.free(name_y);
        try appendEntry(allocator, entries, name_x, try allocator.dupe(u8, "0"));
        try appendEntry(allocator, entries, name_y, try allocator.dupe(u8, "0"));
        return;
    }

    // 5.4-5.5: no name attribute, or an empty one.
    const name = (try attributeValue(allocator, field, "name")) orelse return;
    defer allocator.free(name);
    if (name.len == 0) return;

    if (form_associated.isSelect(field)) {
        // 5.6: each option in the list of options whose selectedness is true
        // and that is not disabled. (Not `selectedOptions`: it is
        // [SameObject] and cached.)
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
        try forEachOption(field, Visit{ .allocator = allocator, .entries = entries, .name = name }, Visit.option);
    } else if (is_input and (eql(input_type, "checkbox") or eql(input_type, "radio"))) {
        // 5.7: the value attribute, or "on".
        const value = (try attributeValue(allocator, field, "value")) orelse try allocator.dupe(u8, "on");
        try appendEntry(allocator, entries, name, value);
    } else if (is_input and eql(input_type, "file")) {
        // 5.8.1: no files are ever selected here, so a File with an empty
        // name - represented by that name.
        try appendEntry(allocator, entries, name, try allocator.dupe(u8, ""));
        entries.items[entries.items.len - 1].is_file = true;
    } else if (is_input and eql(input_type, "hidden") and std.ascii.eqlIgnoreCase(name, "_charset_")) {
        // 5.9: the encoding's name.
        try appendEntry(allocator, entries, name, try allocator.dupe(u8, encoding.name));
    } else {
        // 5.10: the value of the field element.
        const value = if (form_associated.isTextArea(field))
            try takeString(allocator, field, try interfaces.HTMLTextAreaElement.get_value(field))
        else if (form_associated.isButton(field))
            try takeString(allocator, field, try interfaces.HTMLButtonElement.get_value(field))
        else
            try takeString(allocator, field, try interfaces.HTMLInputElement.get_value(field));
        try appendEntry(allocator, entries, name, value);
    }

    // 5.11: a dirname attribute that is not empty, on an auto-directionality
    // form-associated element: its directionality, under the dirname.
    if (form_associated.isAutoDirectionalityFormAssociated(field)) {
        if (try attributeValue(allocator, field, "dirname")) |dirname| {
            defer allocator.free(dirname);
            if (dirname.len > 0) {
                const dir: []const u8 = switch (form_associated.directionality(field)) {
                    .ltr => "ltr",
                    .rtl => "rtl",
                };
                try appendEntry(allocator, entries, dirname, try allocator.dupe(u8, dir));
            }
        }
    }
}

/// dom.form_submission's "construct the entry list": FormData(form,
/// submitter)'s steps 1.1-1.4, appending the clone to `form_data`.
fn constructEntryListInto(form: *runtime.Instance, submitter: ?*runtime.Instance, form_data: *runtime.Instance) anyerror!void {
    // 1.1: a submitter must be a submit button whose form owner is form.
    if (submitter) |element| {
        if (!form_associated.isSubmitButton(element)) return error.TypeError;
        if (form_associated.formOwner(element) != form) return error.NotFoundError;
    }
    // 1.2-1.3: the entry list with the default encoding, UTF-8; null (a
    // form already constructing one) throws.
    const allocator = form.ctx.allocator;
    var entries = (try constructEntryList(allocator, form, submitter, encoding_mod.UTF_8)) orelse return error.InvalidStateError;
    defer freeEntries(allocator, &entries);
    // 1.4: set this's entry list to it.
    for (entries.items) |entry| try interfaces.FormData.call_append(form_data, entry.name, entry.value);
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

/// The optional arguments of § 4.10.22.3 "submit".
const SubmitOptions = struct {
    /// "submitted from submit() method".
    from_submit_method: bool = false,
    /// "userInvolvement" - "none" by default.
    user_involvement: @import("dom").form_submission.UserInvolvement = .none,
};

/// A form "cannot navigate" if it is not connected, or its node document is
/// not fully active. (Only the first is checked: a document that is not
/// fully active has no navigable for the planned navigation to reach.)
fn cannotNavigate(form: *runtime.Instance) bool {
    return !(interfaces.Node.get_isConnected(form) catch false);
}

/// The value of a submit button's form-submission attribute (`formaction`,
/// `formmethod`, ...) when `submitter` is a submit button that has it, owned;
/// null otherwise - the form's own attribute then applies.
fn submitterAttribute(allocator: std.mem.Allocator, submitter: *runtime.Instance, form: *runtime.Instance, comptime name: []const u8) !?[]u8 {
    if (submitter == form or !form_associated.isSubmitButton(submitter)) return null;
    return attributeValue(allocator, submitter, name);
}

/// A method or formmethod keyword's state; invalid values are GET.
fn methodState(value: []const u8) []const u8 {
    if (std.ascii.eqlIgnoreCase(value, "post")) return "post";
    if (std.ascii.eqlIgnoreCase(value, "dialog")) return "dialog";
    return "get";
}

/// An enctype or formenctype keyword's state; invalid values are
/// application/x-www-form-urlencoded.
fn enctypeState(value: []const u8) []const u8 {
    if (std.ascii.eqlIgnoreCase(value, "multipart/form-data")) return "multipart/form-data";
    if (std.ascii.eqlIgnoreCase(value, "text/plain")) return "text/plain";
    return "application/x-www-form-urlencoded";
}

/// § 4.10.22.3 "submit" `form` from `submitter` - a submit button, or the
/// form itself.
fn submit(form: *runtime.Instance, submitter: *runtime.Instance, options: SubmitOptions) !void {
    const allocator = form.ctx.allocator;

    // 1. If form cannot navigate, then return.
    if (cannotNavigate(form)) return;
    // 2. If form's constructing entry list is true, then return.
    if (Registry.get(form)) |internal| {
        if (internal.constructing_entry_list) return;
    }
    // 3. Let form document be form's node document.
    const document = (try interfaces.Node.get_ownerDocument(form)) orelse return;

    // 5. If submitted from submit() method is false:
    if (!options.from_submit_method) {
        const internal = Registry.get(form) orelse return;
        // 5.1-5.2: firing submission events.
        if (internal.firing_submission_events) return;
        internal.firing_submission_events = true;
        // 5.3-5.4: user validity and interactive validation - not
        // implemented (stated above); every form validates.

        // 5.5: submitterButton is null if submitter is form.
        const submitter_button: ?*runtime.Instance = if (submitter == form) null else submitter;
        // 5.6: fire submit, a SubmitEvent with submitter, bubbling and
        // cancelable.
        const should_continue = blk: {
            // 5.7, however the dispatch ends.
            defer if (Registry.get(form)) |after| {
                after.firing_submission_events = false;
            };
            const event = try interfaces.SubmitEvent.call_constructor(
                form.ctx,
                runtime.DOMString.initInterned("submit"),
                webidl.Opt(dictionaries.SubmitEventInit).passed(.{
                    .base = .{ .bubbles = true, .cancelable = true },
                    .submitter = submitter_button,
                }),
            );
            const generation = runtime.SlabAllocator.generationOf(event);
            defer event.releaseIfUnwrapped(generation);
            break :blk try @import("dom").fire_event.dispatchTrusted(form, event);
        };
        // 5.8: If shouldContinue is false, then return.
        if (!should_continue) return;
        // 5.9: dispatching submit could have changed this.
        if (cannotNavigate(form)) return;
    }

    // 6. Let encoding be the result of picking an encoding for the form.
    const encoding = try pickEncoding(allocator, form, document);
    // 7. Let entry list be the result of constructing the entry list with
    //    form, submitter and encoding. (8: it is not null - nothing between
    //    step 2 and here constructs one.)
    var entries = (try constructEntryList(allocator, form, if (submitter == form) null else submitter, encoding)) orelse return;
    defer freeEntries(allocator, &entries);
    // 9. The formdata event could have changed this.
    if (cannotNavigate(form)) return;

    // 10. Let method be the submitter element's method: its formmethod
    //     attribute's state if it is a submit button that has one, else the
    //     form's method attribute's state.
    const method: []const u8 = blk: {
        if (try submitterAttribute(allocator, submitter, form, "formmethod")) |value| {
            defer allocator.free(value);
            break :blk methodState(value);
        }
        const value = (try attributeValue(allocator, form, "method")) orelse break :blk "get";
        defer allocator.free(value);
        break :blk methodState(value);
    };
    // 11. dialog closes the nearest dialog ancestor; nothing navigates.
    // TODO(forms): close the dialog.
    if (eql(method, "dialog")) return;

    // 12-13: action - the submitter's formaction or the form's action - or
    // the form document's URL when it is empty.
    const document_url = try interfaces.Document.get_URL(document);
    defer document.ctx.allocator.free(document_url);
    const action_attribute = (try submitterAttribute(allocator, submitter, form, "formaction")) orelse
        try attributeValue(allocator, form, "action");
    defer if (action_attribute) |a| allocator.free(a);
    const action: []const u8 = if (action_attribute) |a| (if (a.len > 0) a else document_url) else document_url;

    // 14-15: "encoding-parsing a URL given action, relative to submitter's
    // node document" - its document base URL, which for an about:blank
    // document is its creator's (an initial about:blank frame's form has no
    // other). (The document's encoding does not reach the URL parser; see
    // encoding-parse.)
    const base_url = interfaces.Node.get_baseURI(document) catch null;
    defer if (base_url) |b| document.ctx.allocator.free(b);
    var base = basic_parser.parse(allocator, base_url orelse document_url, null) catch null;
    defer if (base) |*b| b.deinit();
    // Deviation, stated (encoding-parse-utf8): the query is encoded as UTF-8, not with the document's encoding - queued.
    var parsed_action = basic_parser.parse(allocator, action, if (base) |*b| b else null) catch return;
    defer parsed_action.deinit();

    // 17. Let enctype be the submitter element's enctype.
    const enctype: []const u8 = blk: {
        if (try submitterAttribute(allocator, submitter, form, "formenctype")) |value| {
            defer allocator.free(value);
            break :blk enctypeState(value);
        }
        const value = (try attributeValue(allocator, form, "enctype")) orelse break :blk "application/x-www-form-urlencoded";
        defer allocator.free(value);
        break :blk enctypeState(value);
    };

    // 18-20: formTarget - a submit button's formtarget attribute - then the
    // target, "getting an element's target" given the submitter's form owner
    // (form) and formTarget. The navigable for it is chosen when the planned
    // navigation runs (dom.navigables), which opens a new one for "_blank"
    // or a name nothing has.
    const form_target = try submitterAttribute(allocator, submitter, form, "formtarget");
    defer if (form_target) |t| allocator.free(t);
    const target = try elementTarget(allocator, form, form_target, document);
    errdefer allocator.free(target);

    // 26. The scheme and method pick the behaviour.
    const scheme = parsed_action.scheme();
    const is_get = eql(method, "get");
    const mutate = is_get and (eql(scheme, "http") or eql(scheme, "https") or eql(scheme, "data") or eql(scheme, "file"));
    if (!is_get and (eql(scheme, "http") or eql(scheme, "https"))) {
        // "Submit as entity body": a POST resource of the entry list encoded
        // by enctype, planned to the parsed action as it is. The entry list
        // goes with it, as a FormData, for the navigate event (navigate's
        // formDataEntryList).
        // The target goes with the errdefer above on every error return:
        // freed here as well, a failed step freed it twice.
        const form_data = try entryListFormData(form, entries.items);
        const form_data_generation = runtime.SlabAllocator.generationOf(form_data);
        var post = entityBody(allocator, enctype, form_data, entries.items, encoding) catch |err| {
            form_data.releaseIfUnwrapped(form_data_generation);
            return err;
        };
        errdefer post.deinit(allocator);
        errdefer form_data.releaseIfUnwrapped(form_data_generation);
        const url = try url_serializer.serialize(allocator, &parsed_action, false);
        planNavigationWith(form, url, target, post, form_data);
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

/// HTML "get an element's target" given the form and a target override
/// (the submitter's formtarget): the override if given, else the form's
/// target attribute, else the target of the document's first base element
/// that has one, else ""; one with an ASCII tab or newline and a "<" in it is
/// "_blank" (dangling markup). Owned.
fn elementTarget(allocator: std.mem.Allocator, form: *runtime.Instance, override: ?[]const u8, document: *runtime.Instance) ![]u8 {
    const given = if (override) |t| try allocator.dupe(u8, t) else (try attributeValue(allocator, form, "target")) orelse blk: {
        const base = (interfaces.Document.call_querySelector(document, runtime.DOMString.initInterned("base[target]")) catch null) orelse
            break :blk try allocator.dupe(u8, "");
        break :blk (try attributeValue(allocator, base, "target")) orelse try allocator.dupe(u8, "");
    };
    if (std.mem.indexOfAny(u8, given, "\t\n\r") != null and std.mem.indexOfScalar(u8, given, '<') != null) {
        allocator.free(given);
        return allocator.dupe(u8, "_blank");
    }
    return given;
}

/// A POST resource (HTML "POST resource"): its request body and request
/// content-type. Owned.
const PostResource = struct {
    body: []u8,
    content_type: []u8,

    fn deinit(self: *PostResource, allocator: std.mem.Allocator) void {
        allocator.free(self.body);
        allocator.free(self.content_type);
    }
};

/// "Submit as entity body": "Switch on enctype" - the body and mimeType for
/// the entry list, given the submitter's enctype.
fn entityBody(allocator: std.mem.Allocator, enctype: []const u8, form_data: *runtime.Instance, entries: []const Entry, encoding: *const encoding_mod.Encoding) !PostResource {
    if (eql(enctype, "multipart/form-data")) return multipartBody(allocator, form_data);
    if (eql(enctype, "text/plain")) {
        // "Let body be the result of running the text/plain encoding
        // algorithm with pairs. Set body to the result of encoding body using
        // encoding. Let mimeType be `text/plain`."
        const body = try textPlainBody(allocator, entries, encoding);
        errdefer allocator.free(body);
        return .{ .body = body, .content_type = try allocator.dupe(u8, "text/plain") };
    }
    // application/x-www-form-urlencoded: "Let body be the result of running
    // the application/x-www-form-urlencoded serializer with pairs and
    // encoding. Set body to the result of encoding body. Let mimeType be
    // `application/x-www-form-urlencoded`."
    const body = try serializeEntries(allocator, entries, encoding);
    errdefer allocator.free(body);
    return .{ .body = body, .content_type = try allocator.dupe(u8, "application/x-www-form-urlencoded") };
}

/// "The multipart/form-data encoding algorithm with entry list and
/// encoding", through Fetch's own - "extract a body" of a FormData over the
/// entry list - whose boundary makes the mimeType "multipart/form-data;
/// boundary=...". Stated: that encoding is UTF-8 whatever the form's, and a
/// file control's empty File is an empty string field, since FormData cannot
/// yet be handed a Blob (its append(name, blob) is not implemented).
fn multipartBody(allocator: std.mem.Allocator, form_data: *runtime.Instance) !PostResource {
    var extracted = fetch_body.extract(allocator, .{ .xmlhttp_request_body_init = .{ .form_data = form_data } }, false) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.TypeError => error.TypeError,
    };
    defer extracted.deinit();
    const body_object = extracted.body orelse return error.TypeError;
    const body = try allocator.dupe(u8, body_object.getBytes());
    errdefer allocator.free(body);
    const content_type = extracted.content_type orelse return error.TypeError;
    extracted.content_type = null;
    return .{ .body = body, .content_type = content_type };
}

/// A FormData over the entry list - a new one in the form's realm, with the
/// entries appended (a file control's empty File as an empty string: see
/// multipartBody). Nothing holds it yet.
fn entryListFormData(form: *runtime.Instance, entries: []const Entry) !*runtime.Instance {
    const form_data = try interfaces.FormData.call_constructor(form.ctx, webidl.Opt(*runtime.Instance).notPassed(), webidl.Opt(?*runtime.Instance).notPassed());
    errdefer form_data.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(form_data));
    for (entries) |entry| try interfaces.FormData.call_append(form_data, entry.name, entry.value);
    return form_data;
}

/// "The text/plain encoding algorithm" over the entry list's pairs ("convert
/// to a list of name-value pairs": a file's name for a File, newlines as
/// CRLF), then encoded with `encoding`: "1. Let result be the empty string.
/// 2. For each pair in pairs: append pair's name, "=", pair's value, then a
/// U+000D CR U+000A LF pair to result. 3. Return result."
fn textPlainBody(allocator: std.mem.Allocator, entries: []const Entry, encoding: *const encoding_mod.Encoding) ![]u8 {
    var text: std.ArrayListUnmanaged(u8) = .empty;
    defer text.deinit(allocator);
    for (entries) |entry| {
        const name = try normalizeNewlines(allocator, entry.name);
        defer allocator.free(name);
        const value = try normalizeNewlines(allocator, entry.value);
        defer allocator.free(value);
        try text.appendSlice(allocator, name);
        try text.append(allocator, '=');
        try text.appendSlice(allocator, value);
        try text.appendSlice(allocator, "\r\n");
    }
    if (eql(encoding.name, "UTF-8")) return allocator.dupe(u8, text.items);
    const units = try std.unicode.utf8ToUtf16LeAlloc(allocator, text.items);
    defer allocator.free(units);
    const encoded = encoding_mod.hooks.encode(allocator, units, encoding) catch return error.OutOfMemory;
    defer allocator.free(encoded);
    return allocator.dupe(u8, encoded);
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
    /// Submit step 22's condition, taken when the form was submitted: the
    /// form document had not completely loaded.
    source_not_completely_loaded: bool,
    /// The form document at submission, and its slab generation: "the rules
    /// for choosing a navigable" (submit step 22) start from its node
    /// navigable. The form may be in another document by the time the task
    /// runs - the navigation still goes to the navigable chosen at
    /// submission.
    form_document: ?*runtime.Instance = null,
    form_document_generation: u64 = 0,
    /// The POST resource of a submission "as entity body"; null for GET.
    post: ?PostResource = null,
    /// With it, the entry list as a FormData, kept alive until the planned
    /// navigation runs.
    form_data: ?*runtime.Instance = null,
    form_data_pin: same_object.Pin = .{},
    allocator: std.mem.Allocator,

    fn destroy(self: *PlannedNavigation) void {
        self.allocator.free(self.url);
        self.allocator.free(self.target);
        if (self.post) |*post| post.deinit(self.allocator);
        self.form_data_pin.release();
        self.allocator.destroy(self);
    }
};

/// Source of planned-navigation tokens: never reused, never zero.
threadlocal var next_navigation_token: u64 = 1;

/// "Plan to navigate" to `url`. Takes ownership of `url` and `target`.
fn planNavigation(form: *runtime.Instance, url: []const u8, target: []const u8) void {
    planNavigationWith(form, url, target, null, null);
}

/// "Plan to navigate" to `url`, given a POST resource and the entry list's
/// FormData, or neither. Takes ownership of `url`, `target` and `post`; a
/// `form_data` nothing else holds goes with the task.
fn planNavigationWith(form: *runtime.Instance, url: []const u8, target: []const u8, post: ?PostResource, form_data: ?*runtime.Instance) void {
    const allocator = form.ctx.allocator;
    const task = allocator.create(PlannedNavigation) catch {
        allocator.free(url);
        allocator.free(target);
        if (post) |resource| {
            var owned = resource;
            owned.deinit(allocator);
        }
        if (form_data) |fd| fd.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(fd));
        return;
    };
    // Submit step 22: "If form document equals targetNavigable's active
    // document, and form document has not yet completely loaded, then set
    // historyHandling to "replace"" - the load state now, at submission.
    const document = interfaces.Node.get_ownerDocument(form) catch null;
    const not_loaded = if (document) |d| !@import("dom").document_lifecycle.isCompletelyLoaded(d) else false;
    task.* = .{
        .form = form,
        .form_generation = runtime.SlabAllocator.generationOf(form),
        .token = next_navigation_token,
        .url = url,
        .target = target,
        .source_not_completely_loaded = not_loaded,
        .form_document = document,
        .form_document_generation = if (document) |d| runtime.SlabAllocator.generationOf(d) else 0,
        .post = post,
        .form_data = form_data,
        .allocator = allocator,
    };
    if (form_data) |fd| task.form_data_pin.hold(fd);
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

    // A task is entered from the event loop, not from script: it runs as a
    // task of the form's realm, which enters it. A realm with no engine
    // behind it any more (its page has gone) runs nothing, and the task has
    // no one to report to: it is dropped, as a task of a document that is
    // not fully active is.
    engine.runTaskInRealm(task.form.ctx, navigateSteps, task) catch {};
}

/// Step 4.2 of the planned navigation's task, inside the form's realm.
fn navigateSteps(data: ?*anyopaque) void {
    const task: *PlannedNavigation = @ptrCast(@alignCast(data orelse return));

    // Step 4.2: "Navigate targetNavigable to url using the form element's
    // node document, with historyHandling set to historyHandling" - which
    // submit step 22 made "replace" when the form document is the target's
    // active document and has not completely loaded. The rules for choosing
    // a navigable and the navigation are the navigables' (dom.navigables).
    //
    // Submit step 22 chooses targetNavigable at submission, from the form
    // document's node navigable; Crane chooses when the task runs, but from
    // that same document, so a form moved to another document before its
    // task still navigates the navigable it was submitted in
    // (form-submission-0/reparent-form-during-planned-navigation-task; Chrome
    // and Safari pass it). The navigation uses the form's node document now.
    const document = (interfaces.Node.get_ownerDocument(task.form) catch null) orelse return;
    const form_document: ?*runtime.Instance = if (task.form_document) |d|
        (if (runtime.SlabAllocator.generationOf(d) == task.form_document_generation) d else null)
    else
        null;
    const navigables = @import("dom").navigables;
    navigables.navigateByTarget(document, .{
        .target = task.target,
        .current_document = if (form_document != document) form_document else null,
        .url = task.url,
        .source_not_completely_loaded = task.source_not_completely_loaded,
        .source_element = task.form,
        .post_resource = if (task.post) |post| .{ .body = post.body, .content_type = post.content_type } else null,
        .form_data = task.form_data,
        // "Navigate" with cspNavigationType "form-submission".
        .csp_navigation_type = .form_submission,
    });
}

/// Operation: reportValidity
pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}
