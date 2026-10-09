//! Implementation for HTMLOutputElement interface

const std = @import("std");
const runtime = @import("runtime");
const forms = @import("html").forms;
const form_associated = @import("html").form_associated;
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLOutputElement = interfaces.HTMLOutputElement;

pub const State = HTMLOutputElement.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {
    validation: forms.Validation = .{},
    // HTML 4.10.12: null means the default is computed from descendant text.
    default_value_override: ?runtime.DOMString = null,
};

fn internalState(instance: *runtime.Instance) !*InternalState {
    const state = instance.getState(State);
    if (state.own._internal) |internal| return internal;
    const internal = try instance.ctx.allocator.create(InternalState);
    internal.* = .{};
    state.own._internal = internal;
    return internal;
}

fn validationState(instance: *runtime.Instance) !*forms.Validation {
    return &(try internalState(instance)).validation;
}

fn resetAlgorithm(instance: *runtime.Instance) void {
    // HTML 4.10.12 reset steps 1–2: even the computed default replaces all text.
    var value = get_defaultValue(instance) catch return;
    defer value.deinit(instance.ctx.allocator);
    forms.replaceText(instance, value) catch return;
    if (instance.getState(State).own._internal) |internal| {
        if (internal.default_value_override) |*saved| saved.deinit(instance.ctx.allocator);
        internal.default_value_override = null;
    }
}

fn isValidationControl(instance: *runtime.Instance) bool {
    return instance.stateAs(State) != null;
}

fn constraintFlags(instance: *runtime.Instance) forms.ValidityFlags {
    const internal = instance.getState(State).own._internal orelse return .{};
    return .{ .customError = !internal.validation.custom_error.isEmpty() };
}

pub fn installHooks() void {
    @import("dom").form_controls.install(.{ .is = &isValidationControl, .reset = &resetAlgorithm, .validity_flags = &constraintFlags });
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
        if (internal.validation.validity_traced) @import("engine").forgetTracedChild(instance, .{ .name = "validity" });
        internal.validation.deinit(instance.ctx.allocator);
        if (internal.default_value_override) |*value| value.deinit(instance.ctx.allocator);
        instance.ctx.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.HTMLElement.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &HTMLOutputElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for form
pub fn get_form(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return form_associated.formOwner(instance);
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initInterned("output");
}

/// Getter for defaultValue
pub fn get_defaultValue(instance: *runtime.Instance) anyerror!runtime.DOMString {
    if (instance.getState(State).own._internal) |internal| {
        if (internal.default_value_override) |value| return value.clone(instance.ctx.allocator);
    }
    return get_value(instance);
}

/// Getter for value
pub fn get_value(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return (try interfaces.Node.get_textContent(instance)) orelse .empty;
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

/// Getter for labels
pub fn get_labels(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return form_associated.labelsNodeList(instance);
}

/// Setter for defaultValue
pub fn set_defaultValue(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // HTML 4.10.12 defaultValue setter: replace text while in default mode.
    if (instance.getState(State).own._internal) |internal| {
        if (internal.default_value_override) |previous| {
            internal.default_value_override = try value.clone(instance.ctx.allocator);
            var owned = previous;
            owned.deinit(instance.ctx.allocator);
            return;
        }
    }
    try forms.replaceText(instance, value);
}

/// Setter for value
pub fn set_value(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // HTML 4.10.12 value setter steps 1–2: preserve the default exactly once.
    const internal = try internalState(instance);
    if (internal.default_value_override == null) internal.default_value_override = try get_value(instance);
    try forms.replaceText(instance, value);
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
