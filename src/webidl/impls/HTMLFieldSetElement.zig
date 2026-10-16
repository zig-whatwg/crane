//! Implementation for HTMLFieldSetElement interface

const std = @import("std");
const runtime = @import("runtime");
const forms = @import("html").forms;
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLFieldSetElement = interfaces.HTMLFieldSetElement;

pub const State = HTMLFieldSetElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// The fieldset's custom validity and its elements collection: a block of
/// the Browser's arena, registered (dom.orphan_states), made with the
/// element. A fieldset removed from its tree while script held no wrapper of
/// it - `innerHTML = ''` over a parsed form - is an orphan nothing deinits,
/// and a block of its own leaked once per orphaned fieldset (lane
/// orphanleak, crane/cl-orphan-form-controls.html).
pub const InternalState = struct {
    /// The allocator the custom validity message came from: the context's.
    allocator: std.mem.Allocator,
    validation: forms.Validation = .{},
    elements: ?*runtime.Instance = null,
    elements_generation: u64 = 0,
    elements_traced: bool = false,

    /// What the state owns, without its element (dom.orphan_states): the
    /// custom validity message. The elements collection and the validity
    /// object are the element's to release (`deinit`).
    pub fn deinit(self: *InternalState) void {
        self.validation.custom_error.deinit(self.allocator);
    }
};

const States = @import("dom").orphan_states.Swept(.html_field_set_element, InternalState);

fn validationState(instance: *runtime.Instance) !*forms.Validation {
    return &(instance.getState(State).own._internal orelse return error.InvalidStateError).validation;
}

fn isValidationControl(instance: *runtime.Instance) bool {
    return instance.stateAs(State) != null;
}

fn constraintFlags(instance: *runtime.Instance) forms.ValidityFlags {
    const internal = instance.getState(State).own._internal orelse return .{};
    return .{ .customError = !internal.validation.custom_error.isEmpty() };
}

pub fn installHooks() void {
    @import("dom").form_controls.install(.{ .is = &isValidationControl, .validity_flags = &constraintFlags });
    // The states no deinit reached - orphaned fieldsets' - at their
    // Browser's end.
    States.installSweep();
}

/// Initialize instance (creates the instance)
/// Chains to parent class: HTMLElement -> Element -> Node -> EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try interfaces.HTMLElement.initWithState(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    instance.getState(State).own._internal = try States.create(instance, .{ .allocator = ctx.allocator });
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.validation.validity_traced) @import("engine").forgetTracedChild(instance, .{ .name = "validity" });
        internal.validation.deinit(instance.ctx.allocator);
        if (internal.elements_traced) @import("engine").forgetTracedChild(instance, .{ .name = "elements" });
        if (!internal.elements_traced) if (liveChild(internal.elements, internal.elements_generation)) |collection| runtime.Instance.deinit(collection);
        state.own._internal = null;
        States.destroy(instance);
    }
    interfaces.HTMLElement.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &HTMLFieldSetElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for form: the element's form owner.
pub fn get_form(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return @import("html").form_associated.formOwner(instance);
}

/// Getter for type: "must return the string "fieldset"".
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initInterned("fieldset");
}

/// Getter for elements
pub fn get_elements(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    if (liveChild(internal.elements, internal.elements_generation)) |collection| return collection;
    const collection = try interfaces.HTMLCollection.init(instance.ctx.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(collection);
    try @import("dom").live_collections.formControls(collection, instance, true);
    if (instance.ctx.hasEngine()) {
        @import("engine").traceChild(instance, collection, .{ .name = "elements" });
        internal.elements_traced = true;
    }
    internal.elements = collection;
    internal.elements_generation = runtime.SlabAllocator.generationOf(collection);
    return collection;
}

/// A [SameObject] child kept beside the owner's traced edge to it: the
/// child while it is still the one made - its slot not freed or reissued,
/// not torn down. The edge is what keeps it; a child whose edge was lost
/// reads as gone and is made again, never a freed or reissued object
/// (PR-N1, the 2026-10-03 lesson).
fn liveChild(child: ?*runtime.Instance, generation: u64) ?*runtime.Instance {
    const value = child orelse return null;
    if (runtime.SlabAllocator.generationOf(value) != generation or runtime.instance_lifecycle.isCleanedUp(value)) return null;
    return value;
}

/// Getter for willValidate
pub fn get_willValidate(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    // HTML 4.10.18 and 4.10.21.1: this is not a submittable element.
    return false;
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

/// Operation: checkValidity
pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
    return forms.checkValidity(instance, try get_willValidate(instance), constraintFlags(instance));
}

/// Operation: reportValidity
pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
    // HTML reportValidity steps 1–2; a headless host has no validation UI.
    return forms.checkValidity(instance, try get_willValidate(instance), constraintFlags(instance));
}

/// Operation: setCustomValidity
pub fn call_setCustomValidity(instance: *runtime.Instance, @"error": runtime.DOMString) anyerror!void {
    // HTML setCustomValidity steps 1–2: normalize newlines, then replace.
    try (try validationState(instance)).setCustomError(instance.ctx.allocator, @"error".asSlice());
}
