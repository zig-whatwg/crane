//! Implementation for ElementInternals interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const ce = @import("dom").custom_elements;
const form_associated = @import("html").form_associated;
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const ElementInternals = interfaces.ElementInternals;

pub const State = ElementInternals.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    target: ?*runtime.Instance = null,
    target_generation: u64 = 0,
    target_traced: bool = false,
    states: ?*runtime.Instance = null,
    states_traced: bool = false,
    validity_flags: ce.ValidityFlags = .{},
    validity: ?*runtime.Instance = null,
    validity_traced: bool = false,
    validation_message: []const u8 = "",
    validation_anchor_traced: bool = false,
    submission: ControlValue = .none,
    form_state: ControlValue = .none,
    submission_traced: bool = false,
    form_state_traced: bool = false,
    form_owner: ?*runtime.Instance = null,
    form_owner_generation: u64 = 0,
    disabled: bool = false,
    labels: ?*runtime.Instance = null,
    labels_traced: bool = false,
};

const ControlValue = union(enum) {
    none,
    string: []const u8,
    /// Kept by the internals' traced edge; checked on every read (CE2-M2).
    file: ce.KeptInstance,
    form_data: struct { instance: *runtime.Instance, native_owned: bool, generation: u64 },

    fn deinit(value: *ControlValue, allocator: std.mem.Allocator) void {
        switch (value.*) {
            .string => |text| allocator.free(text),
            .form_data => |data| if (data.native_owned) runtime.Instance.deinit(data.instance) else data.instance.releaseIfUnwrapped(data.generation),
            else => {},
        }
        value.* = .none;
    }
    /// The object this value keeps while it is live: a File whose edge was
    /// lost, or a FormData freed under it, reads as none.
    fn object(value: ControlValue) ?*runtime.Instance {
        return switch (value) {
            .file => |file| file.get(),
            .form_data => |data| if (runtime.SlabAllocator.generationOf(data.instance) == data.generation) data.instance else null,
            else => null,
        };
    }
};

fn getInternal(instance: *runtime.Instance) !*InternalState {
    return instance.getState(State).own._internal orelse error.InvalidStateError;
}

fn targetElement(instance: *runtime.Instance) !*runtime.Instance {
    const internal = try getInternal(instance);
    const target = internal.target orelse return error.InvalidStateError;
    if (runtime.SlabAllocator.generationOf(target) != internal.target_generation or runtime.instance_lifecycle.isCleanedUp(target)) return error.InvalidStateError;
    return target;
}

fn formAssociatedTarget(instance: *runtime.Instance) !*runtime.Instance {
    const target = try targetElement(instance);
    const data = ce.get(target) orelse return error.NotSupportedError;
    const definition = data.definition orelse return error.NotSupportedError;
    if (!definition.form_associated) return error.NotSupportedError;
    return target;
}

pub fn installHooks() void {
    ce.installInternals(.{ .set_target = &setTarget, .states = &statesIfCreated, .validity_flags = &validityFlags, .refresh_form = &refreshForm, .append_form_entries = &appendFormEntries, .validation_state = &form_associated.validationState, .disabled_state = &form_associated.customDisabledState });
    @import("dom").form_controls.install(.{ .is = &ce.isFormAssociated, .reset = &resetControl });
}

fn resetControl(element: *runtime.Instance) void {
    // HTML 4.13.3 reset algorithm: one callback, no automatic value clearing.
    ce.enqueueCallback(element, .form_reset, .none);
}

fn refreshForm(instance: *runtime.Instance) void {
    const target = formAssociatedTarget(instance) catch return;
    const internal = getInternal(instance) catch return;
    const form = form_associated.formOwner(target);
    const generation = if (form) |owner| runtime.SlabAllocator.generationOf(owner) else 0;
    const data = ce.get(target) orelse return;
    const definition = data.definition orelse return;
    if (form != internal.form_owner or generation != internal.form_owner_generation) {
        internal.form_owner = form;
        internal.form_owner_generation = generation;
        @import("html").custom_elements.enqueueCallback(target, definition, .form_associated, .{ .form_associated = form }) catch {};
    }
    const disabled = form_associated.isDisabled(target);
    if (disabled != internal.disabled) {
        internal.disabled = disabled;
        @import("html").custom_elements.enqueueCallback(target, definition, .form_disabled, .{ .form_disabled = disabled }) catch {};
    }
}

fn statesIfCreated(instance: *runtime.Instance) ?*runtime.Instance {
    return (getInternal(instance) catch return null).states;
}

fn validityFlags(instance: *runtime.Instance) ce.ValidityFlags {
    return (getInternal(instance) catch return .{}).validity_flags;
}

fn flagsAreValid(flags: ce.ValidityFlags) bool {
    inline for (std.meta.fields(ce.ValidityFlags)) |field| {
        if (@field(flags, field.name) orelse false) return false;
    }
    return true;
}

fn setTarget(instance: *runtime.Instance, target: *runtime.Instance) !void {
    const internal = try getInternal(instance);
    internal.target = target;
    internal.target_generation = runtime.SlabAllocator.generationOf(target);
    if (instance.ctx.hasEngine()) {
        engine.traceChild(instance, target, .{ .name = "targetElement" });
        internal.target_traced = true;
    }
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    if (internal.target_traced) engine.forgetTracedChild(instance, .{ .name = "targetElement" });
    if (internal.states_traced) engine.forgetTracedChild(instance, .{ .name = "states" });
    if (internal.validity_traced) engine.forgetTracedChild(instance, .{ .name = "validity" });
    if (internal.labels_traced) engine.forgetTracedChild(instance, .{ .name = "labels" });
    // In engine-free tests the owner is responsible for lazily created
    // children. With an engine, the traced wrapper graph owns their lifetime.
    if (!internal.states_traced) if (internal.states) |child| runtime.Instance.deinit(child);
    if (!internal.validity_traced) if (internal.validity) |child| runtime.Instance.deinit(child);
    if (!internal.labels_traced) if (internal.labels) |child| runtime.Instance.deinit(child);
    if (internal.validation_anchor_traced) engine.forgetTracedChild(instance, .{ .name = "validationAnchor" });
    internal.allocator.free(internal.validation_message);
    if (internal.submission_traced) engine.forgetTracedChild(instance, .{ .name = "submissionValue" });
    if (internal.form_state_traced) engine.forgetTracedChild(instance, .{ .name = "formState" });
    internal.submission.deinit(internal.allocator);
    internal.form_state.deinit(internal.allocator);
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

/// Getter for shadowRoot
pub fn get_shadowRoot(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    // HTML 4.13.7.2 steps 1–5 include closed roots that were made available.
    const shadow = ce.shadowRootOf(try targetElement(instance)) orelse return null;
    return if (ce.shadowAvailableToInternals(shadow)) shadow else null;
}

/// Getter for form
pub fn get_form(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = try formAssociatedTarget(instance);
    const internal = try getInternal(instance);
    const owner = internal.form_owner orelse return null;
    if (runtime.SlabAllocator.generationOf(owner) != internal.form_owner_generation or runtime.instance_lifecycle.isCleanedUp(owner)) return null;
    return owner;
}

/// Getter for willValidate
pub fn get_willValidate(instance: *runtime.Instance) anyerror!bool {
    const target = try formAssociatedTarget(instance);
    // HTML 4.10.21.1 and 4.13.3: disabled, readonly and datalist bar FACE.
    if (form_associated.isDisabled(target) or form_associated.hasAttribute(target, "readonly")) return false;
    var ancestor = form_associated.parentOf(target);
    while (ancestor) |node| : (ancestor = form_associated.parentOf(node)) {
        if (form_associated.isElementNamed(node, "datalist")) return false;
    }
    return true;
}

/// Getter for validity
pub fn get_validity(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = try formAssociatedTarget(instance);
    const internal = try getInternal(instance);
    if (internal.validity) |validity| return validity;
    const validity = try interfaces.ValidityState.init(internal.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(validity);
    try ce.setValidityInternals(validity, instance);
    if (instance.ctx.hasEngine()) {
        engine.traceChild(instance, validity, .{ .name = "validity" });
        internal.validity_traced = true;
    }
    internal.validity = validity;
    return validity;
}

/// Getter for validationMessage
pub fn get_validationMessage(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = try formAssociatedTarget(instance);
    return runtime.DOMString.initDupe(instance.ctx.allocator, (try getInternal(instance)).validation_message);
}

/// Getter for labels
pub fn get_labels(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const target = try formAssociatedTarget(instance);
    const internal = try getInternal(instance);
    if (internal.labels) |labels| return labels;
    const list = try interfaces.NodeList.init(internal.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(list);
    try @import("dom").node_lists.labels(list, target);
    if (instance.ctx.hasEngine()) {
        engine.traceChild(instance, list, .{ .name = "labels" });
        internal.labels_traced = true;
    }
    internal.labels = list;
    return list;
}

/// Getter for states
pub fn get_states(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = try getInternal(instance);
    if (internal.states) |states| return states;
    // HTML 4.13.7.5: the target's initially empty set, with stable identity.
    const states = try interfaces.CustomStateSet.init(internal.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(states);
    try ce.setCustomStatesTarget(states, try targetElement(instance));
    if (instance.ctx.hasEngine()) {
        engine.traceChild(instance, states, .{ .name = "states" });
        internal.states_traced = true;
    }
    internal.states = states;
    return states;
}

/// Getter for role
pub fn get_role(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaActiveDescendantElement
pub fn get_ariaActiveDescendantElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for ariaAtomic
pub fn get_ariaAtomic(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaAutoComplete
pub fn get_ariaAutoComplete(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaBrailleLabel
pub fn get_ariaBrailleLabel(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaBrailleRoleDescription
pub fn get_ariaBrailleRoleDescription(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaBusy
pub fn get_ariaBusy(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaChecked
pub fn get_ariaChecked(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaColCount
pub fn get_ariaColCount(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaColIndex
pub fn get_ariaColIndex(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaColIndexText
pub fn get_ariaColIndexText(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaColSpan
pub fn get_ariaColSpan(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaControlsElements
pub fn get_ariaControlsElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    return null;
}

/// Getter for ariaCurrent
pub fn get_ariaCurrent(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaDescribedByElements
pub fn get_ariaDescribedByElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    return null;
}

/// Getter for ariaDescription
pub fn get_ariaDescription(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaDetailsElements
pub fn get_ariaDetailsElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    return null;
}

/// Getter for ariaDisabled
pub fn get_ariaDisabled(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaErrorMessageElements
pub fn get_ariaErrorMessageElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    return null;
}

/// Getter for ariaExpanded
pub fn get_ariaExpanded(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaFlowToElements
pub fn get_ariaFlowToElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    return null;
}

/// Getter for ariaHasPopup
pub fn get_ariaHasPopup(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaHidden
pub fn get_ariaHidden(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaInvalid
pub fn get_ariaInvalid(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaKeyShortcuts
pub fn get_ariaKeyShortcuts(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaLabel
pub fn get_ariaLabel(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaLabelledByElements
pub fn get_ariaLabelledByElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    return null;
}

/// Getter for ariaLevel
pub fn get_ariaLevel(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaLive
pub fn get_ariaLive(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaModal
pub fn get_ariaModal(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaMultiLine
pub fn get_ariaMultiLine(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaMultiSelectable
pub fn get_ariaMultiSelectable(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaOrientation
pub fn get_ariaOrientation(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaOwnsElements
pub fn get_ariaOwnsElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    return null;
}

/// Getter for ariaPlaceholder
pub fn get_ariaPlaceholder(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaPosInSet
pub fn get_ariaPosInSet(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaPressed
pub fn get_ariaPressed(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaReadOnly
pub fn get_ariaReadOnly(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaRelevant
pub fn get_ariaRelevant(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaRequired
pub fn get_ariaRequired(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaRoleDescription
pub fn get_ariaRoleDescription(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaRowCount
pub fn get_ariaRowCount(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaRowIndex
pub fn get_ariaRowIndex(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaRowIndexText
pub fn get_ariaRowIndexText(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaRowSpan
pub fn get_ariaRowSpan(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaSelected
pub fn get_ariaSelected(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaSetSize
pub fn get_ariaSetSize(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaSort
pub fn get_ariaSort(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaValueMax
pub fn get_ariaValueMax(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaValueMin
pub fn get_ariaValueMin(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaValueNow
pub fn get_ariaValueNow(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for ariaValueText
pub fn get_ariaValueText(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Setter for role
pub fn set_role(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaActiveDescendantElement
pub fn set_ariaActiveDescendantElement(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaAtomic
pub fn set_ariaAtomic(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaAutoComplete
pub fn set_ariaAutoComplete(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaBrailleLabel
pub fn set_ariaBrailleLabel(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaBrailleRoleDescription
pub fn set_ariaBrailleRoleDescription(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaBusy
pub fn set_ariaBusy(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaChecked
pub fn set_ariaChecked(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaColCount
pub fn set_ariaColCount(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaColIndex
pub fn set_ariaColIndex(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaColIndexText
pub fn set_ariaColIndexText(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaColSpan
pub fn set_ariaColSpan(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaControlsElements
pub fn set_ariaControlsElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaCurrent
pub fn set_ariaCurrent(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaDescribedByElements
pub fn set_ariaDescribedByElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaDescription
pub fn set_ariaDescription(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaDetailsElements
pub fn set_ariaDetailsElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaDisabled
pub fn set_ariaDisabled(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaErrorMessageElements
pub fn set_ariaErrorMessageElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaExpanded
pub fn set_ariaExpanded(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaFlowToElements
pub fn set_ariaFlowToElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaHasPopup
pub fn set_ariaHasPopup(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaHidden
pub fn set_ariaHidden(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaInvalid
pub fn set_ariaInvalid(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaKeyShortcuts
pub fn set_ariaKeyShortcuts(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaLabel
pub fn set_ariaLabel(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaLabelledByElements
pub fn set_ariaLabelledByElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaLevel
pub fn set_ariaLevel(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaLive
pub fn set_ariaLive(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaModal
pub fn set_ariaModal(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaMultiLine
pub fn set_ariaMultiLine(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaMultiSelectable
pub fn set_ariaMultiSelectable(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaOrientation
pub fn set_ariaOrientation(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaOwnsElements
pub fn set_ariaOwnsElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaPlaceholder
pub fn set_ariaPlaceholder(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaPosInSet
pub fn set_ariaPosInSet(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaPressed
pub fn set_ariaPressed(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaReadOnly
pub fn set_ariaReadOnly(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaRelevant
pub fn set_ariaRelevant(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaRequired
pub fn set_ariaRequired(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaRoleDescription
pub fn set_ariaRoleDescription(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaRowCount
pub fn set_ariaRowCount(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaRowIndex
pub fn set_ariaRowIndex(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaRowIndexText
pub fn set_ariaRowIndexText(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaRowSpan
pub fn set_ariaRowSpan(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaSelected
pub fn set_ariaSelected(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaSetSize
pub fn set_ariaSetSize(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaSort
pub fn set_ariaSort(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaValueMax
pub fn set_ariaValueMax(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaValueMin
pub fn set_ariaValueMin(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaValueNow
pub fn set_ariaValueNow(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ariaValueText
pub fn set_ariaValueText(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: setValidity
pub fn call_setValidity(instance: *runtime.Instance, flags: webidl.Opt(dictionaries.ValidityStateFlags), message: webidl.Opt(runtime.DOMString), anchor: webidl.Opt(*runtime.Instance)) anyerror!void {
    // The generated pointer signature erases the IDL HTMLElement brand.
    if (anchor.was_passed and anchor.value.stateAs(interfaces.HTMLElement.State) == null) return error.TypeError;
    // HTML 4.13.7.3 steps 1–4: validate before changing the validity flags.
    const target = try formAssociatedTarget(instance);
    const internal = try getInternal(instance);
    const new_flags = flags.getOrDefault(.{});
    const valid = flagsAreValid(new_flags);
    const text = message.getOrDefault(runtime.DOMString.initEmpty()).asSlice();
    if (!valid and text.len == 0) return error.TypeError;
    // Steps 5–8: normalize CRLF/CR to LF and replace every flag and message.
    var normalized: std.ArrayList(u8) = .empty;
    defer normalized.deinit(internal.allocator);
    if (!valid) {
        var index: usize = 0;
        while (index < text.len) : (index += 1) {
            if (text[index] == '\r') {
                try normalized.append(internal.allocator, '\n');
                if (index + 1 < text.len and text[index + 1] == '\n') index += 1;
            } else try normalized.append(internal.allocator, text[index]);
        }
    }
    const owned_message = try normalized.toOwnedSlice(internal.allocator);
    internal.allocator.free(internal.validation_message);
    internal.validation_message = owned_message;
    internal.validity_flags = new_flags;
    // Steps 9–11: the anchor must be a shadow-including inclusive descendant.
    const selected_anchor = anchor.getOrDefault(target);
    var ancestor: ?*runtime.Instance = selected_anchor;
    while (ancestor) |node| {
        if (node == target) break;
        ancestor = form_associated.parentOf(node);
        if (ancestor == null and node.stateAs(interfaces.ShadowRoot.State) != null) ancestor = try interfaces.ShadowRoot.get_host(node);
    } else return error.NotFoundError;
    if (instance.ctx.hasEngine()) {
        engine.traceChild(instance, selected_anchor, .{ .name = "validationAnchor" });
        internal.validation_anchor_traced = true;
    }
}

/// Operation: checkValidity
pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
    const target = try formAssociatedTarget(instance);
    // HTML 4.10.21.3 check-validity steps 1–2.
    if (!(try get_willValidate(instance)) or flagsAreValid((try getInternal(instance)).validity_flags)) return true;
    const event = try interfaces.Event.call_constructor(instance.ctx, runtime.DOMString.initInterned("invalid"), .passed(.{ .cancelable = true }));
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);
    _ = try @import("dom").fire_event.dispatchTrusted(target, event);
    return false;
}

/// Operation: reportValidity
pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
    // Same observable result/event; the host supplies any validation UI.
    return call_checkValidity(instance);
}

/// Operation: setFormValue
pub fn call_setFormValue(instance: *runtime.Instance, value: ?typedefs.FileOrUSVStringOrFormData, state: webidl.Opt(?runtime.JSValue)) anyerror!void {
    const realm = instance.ctx;
    const allocator = realm.allocator;
    const had_engine = realm.hasEngine();
    // WebIDL operation steps 2.1.5–2.1.8: convert every argument before
    // running HTML's method steps. This conversion can run author script.
    const converted_state = if (state.was_passed) try convertStateValue(realm, state.value) else null;
    defer if (converted_state) |converted| {
        if (converted == .usvstring) allocator.free(converted.usvstring);
    };
    if (had_engine and !realm.hasEngine()) return error.InvalidStateError;
    _ = try formAssociatedTarget(instance);
    const internal = try getInternal(instance);
    var submission = try copyControlValue(instance, value);
    defer submission.releaseRoot();
    errdefer submission.value.deinit(allocator);
    // HTML 4.13.7.3 steps 3–6: FormData's entry list is cloned, and an
    // omitted state uses the same value while an explicit null stays null.
    var saved_state = try copyControlValue(instance, if (state.was_passed) converted_state else value);
    defer saved_state.releaseRoot();
    errdefer saved_state.value.deinit(allocator);
    setValueEdge(instance, submission.value, "submissionValue", &internal.submission_traced);
    setValueEdge(instance, saved_state.value, "formState", &internal.form_state_traced);
    internal.submission.deinit(internal.allocator);
    internal.form_state.deinit(internal.allocator);
    internal.submission = submission.value;
    internal.form_state = saved_state.value;
}

fn setValueEdge(instance: *runtime.Instance, value: ControlValue, comptime slot: []const u8, traced: *bool) void {
    if (instance.ctx.hasEngine()) {
        if (value.object()) |object| {
            engine.traceChild(instance, object, .{ .name = slot });
            traced.* = true;
            return;
        }
    }
    if (traced.*) engine.forgetTracedChild(instance, .{ .name = slot });
    traced.* = false;
}

/// A cloned list must survive allocations while its entries (and a second
/// state list) are copied, before the internals' traced edges are installed.
const PreparedValue = struct {
    value: ControlValue,
    root: ?engine.Owned = null,

    fn releaseRoot(self: PreparedValue) void {
        if (self.root) |root| root.release();
    }
};

fn copyControlValue(instance: *runtime.Instance, value: ?typedefs.FileOrUSVStringOrFormData) !PreparedValue {
    const supplied = value orelse return .{ .value = .none };
    var prepared: PreparedValue = .{ .value = switch (supplied) {
        .usvstring => |text| .{ .string = try instance.ctx.allocator.dupe(u8, text) },
        .file => |file| .{ .file = ce.KeptInstance.of(file) },
        .form_data => blk: {
            const clone = try interfaces.FormData.call_constructor(instance.ctx, .notPassed(), .notPassed());
            break :blk .{ .form_data = .{ .instance = clone, .native_owned = !instance.ctx.hasEngine(), .generation = runtime.SlabAllocator.generationOf(clone) } };
        },
    } };
    errdefer prepared.value.deinit(instance.ctx.allocator);
    if (instance.ctx.hasEngine()) {
        if (prepared.value.object()) |object| prepared.root = try engine.retainValue(object.ctx, .{ .instance = object });
    }
    errdefer prepared.releaseRoot();
    if (supplied == .form_data) try appendDataEntries(prepared.value.form_data.instance, supplied.form_data);
    return prepared;
}

fn convertStateValue(realm: runtime.Context, value: ?runtime.JSValue) !?typedefs.FileOrUSVStringOrFormData {
    const given = value orelse return null;
    switch (engine.typeOf(realm, given)) {
        .null, .undefined => return null,
        else => {},
    }
    if (engine.convertToPlatformObject(realm, given)) |object| {
        if (object.stateAs(interfaces.File.State) != null) return .{ .file = object };
        if (object.stateAs(interfaces.FormData.State) != null) return .{ .form_data = object };
    }
    return .{ .usvstring = try engine.convertToUSVString(realm, given, realm.allocator) };
}

fn appendDataEntries(destination: *runtime.Instance, source: *runtime.Instance) !void {
    const entries = interfaces.FormData.getEntriesForIterable(source) orelse return;
    for (entries) |entry| switch (entry.value) {
        .usvstring => |text| try interfaces.FormData.call_append(destination, entry.name, text),
        .file => |file| try interfaces.FormData.call_append__1(destination, entry.name, file, .notPassed()),
    };
}

fn appendFormEntries(instance: *runtime.Instance, form_data: *runtime.Instance) !void {
    const target = try formAssociatedTarget(instance);
    const internal = try getInternal(instance);
    // HTML 4.13.7.3 entry-construction step 1 precedes the name check.
    if (internal.submission == .form_data) return appendDataEntries(form_data, internal.submission.object() orelse return);
    const name = (try form_associated.attributeValue(internal.allocator, target, "name")) orelse return;
    defer internal.allocator.free(name);
    if (name.len == 0) return;
    switch (internal.submission) {
        .none => {},
        .string => |text| try interfaces.FormData.call_append(form_data, name, text),
        // A File that is gone is submitted as nothing, never as whatever
        // reissued its slot.
        .file => |file| if (file.get()) |live| try interfaces.FormData.call_append__1(form_data, name, live, .notPassed()),
        .form_data => unreachable,
    }
}
