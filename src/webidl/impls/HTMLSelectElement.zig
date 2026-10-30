//! Implementation for HTMLSelectElement interface
//!
//! The selection model itself (list of options, selectedness, dirtiness, the
//! reset algorithm) lives in `HTMLOptionElement.zig`, because that is where the
//! state it reads and writes belongs. This file is the select-shaped view of it.

const std = @import("std");
const runtime = @import("runtime");
const forms = @import("html").forms;
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const dom = @import("dom");
const HTMLSelectElement = interfaces.HTMLSelectElement;

// The element's attributes, read in place (dom.element_data, which Element
// installs).
const element_data = @import("dom").element_data;
const collections = @import("dom").live_collections;
const controls = @import("dom").form_controls;
const form_associated = @import("html").form_associated;

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

/// Selection state belongs to the options. The select's custom validity
/// state is made lazily when its constraint API is first used.
///
/// A block of the Browser's arena, registered (dom.orphan_states): a select
/// removed from its tree while script held no wrapper of it is an orphan
/// nothing deinits, and a block of its own had no exit then (lane
/// orphanleak).
pub const InternalState = struct {
    /// The allocator the custom validity message came from: the context's.
    allocator: std.mem.Allocator,
    validation: forms.Validation = .{},
    user_validity: bool = false,
    labels: form_associated.LabelsCache = .{},
    options: ?*runtime.Instance = null,
    options_generation: u64 = 0,
    options_traced: bool = false,
    selected_options: ?*runtime.Instance = null,
    selected_options_generation: u64 = 0,
    selected_options_traced: bool = false,
    picker_open: bool = false,
    has_selected_option: bool = false,
    inserted_stamp: ?InsertionStamp = null,
    typeahead: std.ArrayListUnmanaged(u8) = .empty,
    last_typeahead_time: f64 = -std.math.inf(f64),
    selectedcontent_interest: bool = false,

    /// What the state owns, without its element (dom.orphan_states): the
    /// custom validity message. The collections and the validity object are
    /// the element's to release (`deinit`).
    pub fn deinit(self: *InternalState) void {
        self.validation.custom_error.deinit(self.allocator);
        self.typeahead.deinit(self.allocator);
    }
};

/// Identity token only, never a node pointer. Adoption can otherwise make
/// two documents' equal version counters look like the same insertion.
const InsertionStamp = struct { version: u64, document_key: u64 };

const States = @import("dom").orphan_states.Swept(.html_select_element, InternalState);

/// Constraint state is allocated when it is first used - by script, or by
/// matching :valid and :invalid (form_associated.validationState).
fn internalState(instance: *runtime.Instance) !*InternalState {
    const state = instance.getState(State);
    if (state.own._internal) |internal| return internal;
    const internal = try States.create(instance, .{ .allocator = instance.ctx.allocator });
    state.own._internal = internal;
    return internal;
}

fn validationState(instance: *runtime.Instance) !*forms.Validation {
    return &(try internalState(instance)).validation;
}

fn isValidationControl(instance: *runtime.Instance) bool {
    return instance.stateAs(State) != null;
}

fn userValidity(instance: *runtime.Instance) bool {
    return if (instance.getState(State).own._internal) |internal| internal.user_validity else false;
}

fn setUserValidity(instance: *runtime.Instance, value: bool) !void {
    const internal = if (value) try internalState(instance) else instance.getState(State).own._internal orelse return;
    internal.user_validity = value;
}

fn constraintFlags(instance: *runtime.Instance) forms.ValidityFlags {
    const internal = instance.getState(State).own._internal;
    var flags = forms.ValidityFlags{ .customError = if (internal) |state| !state.validation.custom_error.isEmpty() else false };
    if (!form_associated.hasAttribute(instance, "required")) return flags;
    var options = optionList(instance) catch return flags;
    defer options.deinit(instance.ctx.allocator);
    // Unlike cached HTML 4.10.7's paragraph, multiple never has a placeholder,
    // even at size=1. Blink HTMLSelectElement::HasPlaceholderLabelOption,
    // WebKit HTMLSelectElement::hasPlaceholderLabelOption and Gecko
    // HTMLSelectElement::IsValueMissing agree. wpt.fyi aligned stable
    // cc74d2669f (2026-10-06), the-select-element/select-validity.html:
    // Chrome 6/6, Firefox 6/6, Safari 6/6, all harness OK.
    const multiple = form_associated.hasAttribute(instance, "multiple");
    const single = !multiple and
        (interfaces.HTMLSelectElement.get_size(instance) catch 0) <= 1;
    const selected_index = if (!multiple) controls.selectedIndex(instance) catch null else null;
    flags.valueMissing = true;
    for (options.items, 0..) |option, index| {
        // Single-select selectedness walks the list: resolve it once.
        if (multiple) {
            if (!(interfaces.HTMLOptionElement.get_selected(option) catch false)) continue;
        } else if (selected_index == null or selected_index.? != index) continue;
        // HTML 4.10.7: wrappers are permitted; an intervening optgroup
        // prevents the first empty option from being the placeholder.
        if (single and index == 0 and !forms.options.hasOptgroupAncestor(option, instance)) {
            var value = interfaces.HTMLOptionElement.get_value(option) catch continue;
            defer value.deinit(instance.ctx.allocator);
            if (value.isEmpty()) continue;
        }
        flags.valueMissing = false;
        break;
    }
    return flags;
}

pub fn installHooks() void {
    @import("dom").form_controls.install(.{
        .is = &isValidationControl,
        .validity_flags = &constraintFlags,
        .user_validity = &userValidity,
        .set_user_validity = &setUserValidity,
        .has_selected_option = &hasSelectedOption,
        .set_has_selected_option = &setHasSelectedOption,
        .option_owner_unchanged = &optionOwnerUnchanged,
        .selection_invariant = &selectionInvariant,
        .select_typeahead = &typeaheadInput,
        .picker_open = &pickerOpen,
        .set_picker_open = &setPickerOpen,
        .selectedcontent_interest = &selectedcontentInterest,
        .set_selectedcontent_interest = &setSelectedcontentInterest,
    });
    // The states no deinit reached - orphaned selects' - at their Browser's
    // end.
    States.installSweep();
    dom.mutation.registerInsertionStepsCallback(&insertionSteps) catch {};
    dom.mutation.registerRemovingStepsCallback(&removingSteps) catch {};
}

fn currentInsertionStamp(select: *runtime.Instance) ?InsertionStamp {
    const document = (interfaces.Node.get_ownerDocument(select) catch return null) orelse return null;
    return .{
        .version = collections.treeVersion(document) orelse return null,
        .document_key = @intFromPtr(document) ^ runtime.SlabAllocator.generationOf(document),
    };
}

fn selectInstance(node: *dom.NodeBase) ?*runtime.Instance {
    if (node.node_type != interfaces.Node.get_ELEMENT_NODE()) return null;
    const instance: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return null));
    return if (isValidationControl(instance)) instance else null;
}

fn insertionSteps(node: *dom.NodeBase) void {
    const select = selectInstance(node) orelse return;
    const stamp = currentInsertionStamp(select) orelse return;
    // DOM insert step 7 runs a select before its descendant options. No
    // mutation occurs between those callbacks, even for a linked batch.
    // This implements update-nearest-select step 4 without cached owners.
    (internalState(select) catch return).inserted_stamp = stamp;
}

fn removingSteps(node: *dom.NodeBase, _: ?*dom.NodeBase) void {
    const select = selectInstance(node) orelse return;
    if (select.getState(State).own._internal) |internal| internal.inserted_stamp = null;
}

fn optionOwnerUnchanged(select: *runtime.Instance) bool {
    const internal = select.getState(State).own._internal orelse return false;
    const inserted = internal.inserted_stamp orelse return false;
    const current = currentInsertionStamp(select) orelse return false;
    return std.meta.eql(inserted, current);
}

/// Native-only diagnostic alongside the option owner's bit checks. A
/// removal clears the stamp; a version or document change makes it inert.
fn selectionInvariant(select: *runtime.Instance) bool {
    const internal = select.getState(State).own._internal orelse return true;
    _ = internal.inserted_stamp orelse return true;
    return (interfaces.Node.get_parentNode(select) catch return false) != null;
}

fn hasSelectedOption(instance: *runtime.Instance) bool {
    const internal = instance.getState(State).own._internal orelse return false;
    return internal.has_selected_option;
}

fn setHasSelectedOption(instance: *runtime.Instance, value: bool) !void {
    if (!value and instance.getState(State).own._internal == null) return;
    (try internalState(instance)).has_selected_option = value;
}

fn typeaheadInput(instance: *runtime.Instance, text: []const u8) ![]const u8 {
    const internal = try internalState(instance);
    const now = @import("dom").user_activation_state.sharedCurrentTime();
    // Blink TypeAhead's one-second session. Repeated identical characters
    // cycle matches instead of extending the prefix (kCycleFirstChar).
    if (now - internal.last_typeahead_time > 1000 or now < internal.last_typeahead_time) internal.typeahead.clearRetainingCapacity();
    internal.last_typeahead_time = now;
    var repeated = text.len != 0 and internal.typeahead.items.len != 0 and internal.typeahead.items.len % text.len == 0;
    if (repeated) {
        var offset: usize = 0;
        while (offset < internal.typeahead.items.len) : (offset += text.len) {
            if (!std.ascii.eqlIgnoreCase(internal.typeahead.items[offset..][0..text.len], text)) {
                repeated = false;
                break;
            }
        }
    }
    try internal.typeahead.appendSlice(internal.allocator, text);
    // Cycling searches one character without discarding the session: after
    // "cc", a following "a" searches "cca", not "ca" (Blink TypeAhead).
    return if (repeated) internal.typeahead.items[0..text.len] else internal.typeahead.items;
}

fn pickerOpen(instance: *runtime.Instance) bool {
    return if (instance.getState(State).own._internal) |internal| internal.picker_open else false;
}

fn setPickerOpen(instance: *runtime.Instance, open: bool) !void {
    if (!open and instance.getState(State).own._internal == null) return;
    (try internalState(instance)).picker_open = open;
}

fn selectedcontentInterest(instance: *runtime.Instance) bool {
    return if (instance.getState(State).own._internal) |internal| internal.selectedcontent_interest else false;
}

fn setSelectedcontentInterest(instance: *runtime.Instance, present: bool) !void {
    if (!present and instance.getState(State).own._internal == null) return;
    (try internalState(instance)).selectedcontent_interest = present;
}

/// Initialize instance (creates the instance)
/// Chains to parent class: HTMLElement -> Element -> Node -> EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return interfaces.HTMLElement.initWithState(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.labels.deinit(instance);
        if (internal.validation.validity_traced) @import("engine").forgetTracedChild(instance, .{ .name = "validity" });
        internal.validation.deinit(instance.ctx.allocator);
        if (internal.options_traced) engine.forgetTracedChild(instance, .{ .name = "options" });
        if (internal.selected_options_traced) engine.forgetTracedChild(instance, .{ .name = "selectedOptions" });
        if (!internal.options_traced) if (forms.liveChild(internal.options, internal.options_generation)) |child| runtime.Instance.deinit(child);
        if (!internal.selected_options_traced) if (forms.liveChild(internal.selected_options, internal.selected_options_generation)) |child| runtime.Instance.deinit(child);
        state.own._internal = null;
        States.destroy(instance);
    }
    interfaces.HTMLElement.deinit(instance);
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
    try forms.options.setIndex(instance, index, option);
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
    const data = element_data.of(instance) orelse return error.InvalidState;
    return element_data.hasAttribute(data, attr);
}

/// The list of options, owned by the caller.
fn optionList(instance: *runtime.Instance) anyerror!std.ArrayListUnmanaged(*runtime.Instance) {
    const allocator = instance.ctx.allocator;
    var options = std.ArrayListUnmanaged(*runtime.Instance).empty;
    errdefer options.deinit(allocator);
    try forms.options.collect(instance, allocator, &options);
    return options;
}

// ---------------------------------------------------------------------------
// IDL attributes
// ---------------------------------------------------------------------------

/// Getter for autocomplete
pub fn get_autocomplete(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return @import("html").autofill.idlValue(instance, .expectation);
}

/// Getter for form: the element's form owner.
pub fn get_form(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return form_associated.formOwner(instance);
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
    // HTML 4.10.7: a SameObject live HTMLOptionsCollection rooted here.
    const internal = try internalState(instance);
    if (forms.liveChild(internal.options, internal.options_generation)) |collection| return collection;
    const collection = try interfaces.HTMLOptionsCollection.init(instance.ctx.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(collection);
    try collections.selectOptions(collection, instance, false);
    if (instance.ctx.hasEngine()) {
        engine.traceChild(instance, collection, .{ .name = "options" });
        internal.options_traced = true;
    }
    internal.options = collection;
    internal.options_generation = runtime.SlabAllocator.generationOf(collection);
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
    const internal = try internalState(instance);
    if (forms.liveChild(internal.selected_options, internal.selected_options_generation)) |collection| return collection;
    const collection = try interfaces.HTMLCollection.init(instance.ctx.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(collection);
    try collections.selectOptions(collection, instance, true);
    if (instance.ctx.hasEngine()) {
        engine.traceChild(instance, collection, .{ .name = "selectedOptions" });
        internal.selected_options_traced = true;
    }
    internal.selected_options = collection;
    internal.selected_options_generation = runtime.SlabAllocator.generationOf(collection);
    return collection;
}

/// Getter for selectedIndex
pub fn get_selectedIndex(instance: *runtime.Instance) anyerror!i32 {
    return @intCast((try controls.selectedIndex(instance)) orelse return -1);
}

/// Getter for value
/// Spec: https://html.spec.whatwg.org/multipage/form-elements.html#dom-select-value
pub fn get_value(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // State, not reflection: the value of the first selected option, and "" when
    // nothing is selected. There is no `value` content attribute on a select.
    var options = try optionList(instance);
    defer options.deinit(instance.ctx.allocator);

    const index = (try controls.selectedIndex(instance)) orelse
        return runtime.DOMString.initEmpty();
    return interfaces.HTMLOptionElement.get_value(options.items[index]);
}

/// Getter for willValidate
pub fn get_willValidate(instance: *runtime.Instance) anyerror!bool {
    return !forms.isBarred(instance);
}

/// Getter for validity
pub fn get_validity(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // HTML 4.10.21.3: the same live ValidityState on every access.
    const internal = try validationState(instance);
    if (forms.liveChild(internal.validity, internal.validity_generation)) |validity| return validity;
    const validity = try interfaces.ValidityState.init(instance.ctx.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(validity);
    try @import("dom").custom_elements.setValidityControl(validity, instance);
    if (instance.ctx.hasEngine()) {
        @import("engine").traceChild(instance, validity, .{ .name = "validity" });
        internal.validity_traced = true;
    }
    internal.validity = validity;
    internal.validity_generation = runtime.SlabAllocator.generationOf(validity);
    return validity;
}

/// Getter for validationMessage
pub fn get_validationMessage(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return forms.validationMessage(instance.ctx.allocator, try get_willValidate(instance), constraintFlags(instance), (try validationState(instance)).custom_error);
}

/// Getter for labels
pub fn get_labels(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return (try internalState(instance)).labels.get(instance);
}

/// Setter for length
/// Spec: https://html.spec.whatwg.org/multipage/form-elements.html#dom-htmloptionscollection-length
pub fn set_length(instance: *runtime.Instance, value: u32) anyerror!void {
    try forms.options.setLength(instance, value);
}

/// Setter for selectedIndex
/// Spec: https://html.spec.whatwg.org/multipage/form-elements.html#dom-select-selectedindex
pub fn set_selectedIndex(instance: *runtime.Instance, value: i32) anyerror!void {
    // HTML set the selected index: an out-of-range value clears all options
    // without asking for a reset. The option owner checks the upper bound
    // during its one list walk; the interface needs no duplicate list.
    const index: ?usize = if (value >= 0) @intCast(value) else null;
    try controls.setSelectedIndex(instance, index);
}

/// Setter for value
/// Spec: https://html.spec.whatwg.org/multipage/form-elements.html#dom-select-value
pub fn set_value(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // HTML value setter: select the first matching value, marking dirtiness.
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

    try controls.setSelectedIndex(instance, match);
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
    // HTML: the same first match in tree order as the options collection.
    return interfaces.HTMLCollection.call_namedItem(try get_options(instance), name);
}

/// Operation: add
/// Spec: https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#dom-htmloptionscollection-add
pub fn call_add(instance: *runtime.Instance, element: typedefs.HTMLOptionElementOrHTMLOptGroupElement, before: webidl.Opt(?runtime.JSValue)) anyerror!void {
    const option = switch (element) {
        inline else => |object| object,
    };
    try forms.options.add(instance, option, before);
}

/// Operation: remove
/// Spec: https://html.spec.whatwg.org/multipage/form-elements.html#dom-select-remove
pub fn call_remove(instance: *runtime.Instance) anyerror!void {
    // HTML remove() without an argument removes the select itself.
    try interfaces.Element.call_remove(instance);
}

/// HTML remove(index) runs the options collection removal algorithm.
pub fn call_remove__1(instance: *runtime.Instance, index: i32) anyerror!void {
    try forms.options.remove(instance, index);
}

/// Operation: setCustomValidity
pub fn call_setCustomValidity(instance: *runtime.Instance, @"error": runtime.DOMString) anyerror!void {
    // HTML setCustomValidity steps 1–2: normalize newlines, then replace.
    try (try validationState(instance)).setCustomError(instance.ctx.allocator, @"error".asSlice());
}

/// Operation: checkValidity
pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
    return forms.checkValidity(instance, try get_willValidate(instance), constraintFlags(instance));
}

/// Operation: showPicker
pub fn call_showPicker(instance: *runtime.Instance) anyerror!void {
    // HTML select.showPicker steps 1–4, in order. A failed rendering check
    // does not consume activation. The shared rendering predicate includes
    // skipped contents of applicable content-visibility:hidden ancestors.
    if (form_associated.isDisabled(instance)) return error.InvalidStateError;
    try forms.picker.requireSameOriginWithTop(instance);
    const window = try forms.picker.requireActivation(instance);
    if (!try dom.style.isBeingRendered(instance)) return error.NotSupportedError;
    // Steps 5–6: consume activation, then show the base-select picker.
    @import("html").user_activation.consume(window);
    try forms.select_picker.show(instance);
}

/// Operation: reportValidity
pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
    // HTML reportValidity steps 1–2; a headless host has no validation UI.
    return forms.checkValidity(instance, try get_willValidate(instance), constraintFlags(instance));
}
