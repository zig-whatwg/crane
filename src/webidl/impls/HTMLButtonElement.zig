//! Implementation for HTMLButtonElement interface
//!
//! Spec: HTML § 4.10.6 The button element
//! https://html.spec.whatwg.org/multipage/form-elements.html#the-button-element
//!
//! The plain reflected attributes (disabled, formNoValidate, formTarget,
//! name, value, and the type and formAction setters) are the generated
//! interface's. What is here: the type getter, the form owner, the
//! form-submission attributes with the document URL and enumerated
//! fallbacks, labels, and the activation behaviour - a submit button submits
//! its form owner, a reset button resets it.
//!
//! Invoker commands keep their target only across synchronous dispatch;
//! commandForElement itself is the weak reference HTML 2.6.1 requires.
//! Dialog commands route through the dialog interface's lifecycle operations.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const forms = @import("html").forms;
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const reflection = @import("dom").reflection;
const form_associated = @import("html").form_associated;
const dom = @import("dom");
const engine = @import("engine");
const HTMLButtonElement = interfaces.HTMLButtonElement;
const log = std.log.scoped(.forms);

pub const State = HTMLButtonElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Custom validity is independent of the button's type and attributes.
///
/// A block of the Browser's arena, registered (dom.orphan_states): a button
/// removed from its tree while script held no wrapper of it is an orphan
/// nothing deinits, and a block of its own had no exit then (lane
/// orphanleak).
pub const InternalState = struct {
    /// The allocator the custom validity message came from: the context's.
    allocator: std.mem.Allocator,
    validation: forms.Validation = .{},
    labels: form_associated.LabelsCache = .{},
    // HTML's explicitly set attr-element is WEAK. Generation is the weak
    // reference's liveness test, not a substitute for a missing traced hold.
    command_target: ?dom.custom_elements.KeptInstance = null,

    /// What the state owns, without its element (dom.orphan_states): the
    /// custom validity message. The validity object is the element's to
    /// release (`deinit`).
    pub fn deinit(self: *InternalState) void {
        self.validation.custom_error.deinit(self.allocator);
    }
};

const States = dom.orphan_states.Swept(.html_button_element, InternalState);

/// Constraint state is allocated when it is first used - by script, or by
/// matching :valid and :invalid (form_associated.validationState).
fn validationState(instance: *runtime.Instance) !*forms.Validation {
    const state = instance.getState(State);
    if (state.own._internal) |internal| return &internal.validation;
    const internal = try States.create(instance, .{ .allocator = instance.ctx.allocator });
    state.own._internal = internal;
    return &internal.validation;
}

fn isValidationControl(instance: *runtime.Instance) bool {
    return instance.stateAs(State) != null;
}

fn constraintFlags(instance: *runtime.Instance) forms.ValidityFlags {
    const internal = instance.getState(State).own._internal orelse return .{};
    return .{ .customError = !internal.validation.custom_error.isEmpty() };
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    dom.form_controls.install(.{ .is = &isValidationControl, .validity_flags = &constraintFlags });
    // Installed before any button exists (idempotent).
    dom.activation.install(.{ .has = &hasActivationBehavior, .run = &runActivationBehavior });
    dom.attribute_change_steps.install("button", &attributeChangeSteps);
    // The states no deinit reached - orphaned buttons' - at their Browser's
    // end.
    States.installSweep();
}

fn attributeChangeSteps(element: *runtime.Instance, local_name: []const u8, _: ?[]const u8, _: ?[]const u8, namespace: ?[]const u8) void {
    // HTML 2.6.1: even setting the same attribute value clears the override.
    if (namespace != null or !std.mem.eql(u8, local_name, "commandfor")) return;
    if (element.getState(State).own._internal) |internal| internal.command_target = null;
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
        state.own._internal = null;
        States.destroy(instance);
    }
    interfaces.HTMLElement.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &HTMLButtonElement.vtable, ctx);
    errdefer deinit(instance);
    return instance;
}

// ============================================================================
// Activation behaviour
// ============================================================================

fn hasActivationBehavior(target: *runtime.Instance) bool {
    return form_associated.isButton(target);
}

/// "A button element element's activation behavior given event".
fn runActivationBehavior(element: *runtime.Instance, event: *runtime.Instance) void {
    // 1. If element is disabled, then return.
    if (form_associated.isDisabled(element)) return;
    // 2. (Its node document is not fully active: there is no navigable for a
    // submission to reach, which the submission itself checks.)
    // 3. If element has a form owner:
    if (form_associated.formOwner(element)) |owner| {
        // 3.1. A submit button submits the form owner from element, with
        // userInvolvement set to event's user navigation involvement.
        if (form_associated.isSubmitButton(element)) {
            dom.form_submission.submit(owner, element, userInvolvement(event)) catch |err| {
                log.warn("form not submitted: {}", .{err});
            };
            return;
        }
        switch (form_associated.buttonType(element)) {
            // 3.2. The Reset Button state resets the form owner.
            .reset => {
                dom.form_submission.reset(owner) catch |err| {
                    log.warn("form not reset: {}", .{err});
                };
                return;
            },
            // 3.3. The Auto state (with a command or commandfor): nothing.
            .auto => return,
            else => {},
        }
    }
    // 4-5. Resolve commandfor and run the command. Step 6's separate
    // popovertarget activation remains with that unimplemented owner API.
    runCommand(element) catch |err| log.warn("command not run: {}", .{err});
}

const DialogCommand = enum { show_modal, close, request_close };

fn runCommand(element: *runtime.Instance) !void {
    const document = (try interfaces.Node.get_ownerDocument(element)) orelse return;
    if (!dom.document_activity.fullyActive(document, runtime.SlabAllocator.generationOf(document))) return;
    const target = (try get_commandForElement(element)) orelse return;
    // Step 5.1 uses the CONTENT attribute, preserving its case in the event.
    const command = attribute(element, "command") orelse return;
    defer element.ctx.allocator.free(command);
    const custom = std.mem.startsWith(u8, command, "--");
    const show = std.ascii.eqlIgnoreCase(command, "show-popover");
    const hide = std.ascii.eqlIgnoreCase(command, "hide-popover");
    const toggle = std.ascii.eqlIgnoreCase(command, "toggle-popover");
    // "Determine if a command is valid", steps 1-6, and dialog's "is
    // valid command steps": validity depends on the element type, not
    // whether its current state permits the action (WebKit's
    // HTMLDialogElement::isValidCommandType makes the same distinction).
    var dialog_command: ?DialogCommand = null;
    if (!custom) {
        if (target.stateAs(interfaces.HTMLElement.State) == null) return;
        if (!(show or hide or toggle)) {
            if (target.stateAs(interfaces.HTMLDialogElement.State) == null) return;
            dialog_command = if (std.ascii.eqlIgnoreCase(command, "show-modal"))
                .show_modal
            else if (std.ascii.eqlIgnoreCase(command, "close"))
                .close
            else if (std.ascii.eqlIgnoreCase(command, "request-close"))
                .request_close
            else
                return;
        }
    }

    // A listener can remove target and collect wrappers. Hold it through
    // synchronous dispatch (WebKit HTMLButtonElement::handleCommand uses
    // a Ref too); KeptInstance separately guards realm teardown.
    const kept = dom.custom_elements.KeptInstance.of(target);
    var hold: ?engine.Owned = if (target.ctx.hasEngine()) try engine.retainValue(target.ctx, .{ .instance = target }) else null;
    defer if (hold) |*owned| owned.release();
    // HTML step 5.3 leaves composed false. This is the newer spec rule:
    // https://github.com/whatwg/html/pull/11255 (2025-08-15, supported by
    // all three engine teams), not a reason to adopt older WPT expectations
    // of true. WebKit's HTMLButtonElement::handleCommand likewise supplies
    // {false, true, false}; cmd-command-scoped-event.html pins this rule.
    const command_event = try interfaces.CommandEvent.call_constructor(element.ctx, runtime.DOMString.initInterned("command"), .passed(.{
        .base = .{ .cancelable = true },
        .command = runtime.DOMString.initInterned(command),
        .source = element,
    }));
    const generation = runtime.SlabAllocator.generationOf(command_event);
    defer command_event.releaseIfUnwrapped(generation);
    // Steps 5.3-6: dispatch, cancellation, connectedness, custom commands.
    if (!try dom.fire_event.dispatchTrusted(target, command_event)) return;
    const after = kept.get() orelse return;
    if (!(try interfaces.Node.get_isConnected(after)) or custom) return;
    const showing = dom.html_pseudo_classes.popoverShowing(after);
    if (dialog_command) |kind| {
        // Activation step 5.10, dialog command steps 1-4. Dispatch above
        // precedes these state checks; a listener can cancel, remove the
        // target, change its open state, or change the invoker's value.
        if (showing) return;
        const open = try interfaces.HTMLDialogElement.get_open(after);
        if (kind == .show_modal) {
            if (!open) dom.dialog.showModal(after, element) catch {};
        } else if (open) {
            const value = attribute(element, "value");
            defer if (value) |text| element.ctx.allocator.free(text);
            const return_value: webidl.Opt(runtime.DOMString) = if (value) |text|
                .passed(runtime.DOMString.initInterned(text))
            else
                .notPassed();
            switch (kind) {
                .close => dom.dialog.close(after, return_value, element) catch {},
                .request_close => dom.dialog.requestClose(after, return_value, element) catch {},
                .show_modal => unreachable,
            }
        }
        return;
    }
    // Steps 5.7-9. Owner interfaces perform popover validity checks. The
    // owner's show/hide algorithms still lack beforetoggle/toggle/source
    // propagation; this passes source for when the owner implements them.
    if (hide or (toggle and showing)) {
        if (showing) @import("html").popover.hidePopover(after, true, true, element) catch {};
    } else if (!showing) {
        interfaces.HTMLElement.call_showPopover(after, .passed(.{ .source = element })) catch {};
    }
}

/// An event's "user navigation involvement": "activation" when it is
/// trusted, "none" otherwise.
fn userInvolvement(event: *runtime.Instance) dom.form_submission.UserInvolvement {
    const trusted = interfaces.Event.get_isTrusted(event) catch false;
    return if (trusted) .activation else .none;
}

// ============================================================================
// Attributes
// ============================================================================

/// The value of a content attribute in no namespace, owned by the element's
/// allocator; null when absent.
fn attribute(instance: *runtime.Instance, comptime name: []const u8) ?[]u8 {
    return form_associated.attributeValue(instance.ctx.allocator, instance, name) catch null;
}

/// Getter for type: "1. If this is a submit button, then return "submit".
/// 2. Let state be this's type attribute. 3. Assert: state is not in the
/// Submit Button state. 4. If state is in the Auto state, then return
/// "button". 5. Return the keyword value corresponding to state."
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    if (form_associated.isSubmitButton(instance)) return runtime.DOMString.initInterned("submit");
    return runtime.DOMString.initInterned(switch (form_associated.buttonType(instance)) {
        .reset => "reset",
        else => "button",
    });
}

/// Getter for command: "1. Let command be this's command attribute. 2. If
/// command is in the Custom state, then return command's value. 3. If
/// command is in the Unknown state, then return the empty string. 4. Return
/// the keyword corresponding to the value of command."
pub fn get_command(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const value = attribute(instance, "command") orelse return runtime.DOMString.initEmpty();
    // Custom: the value itself, handed over.
    if (std.mem.startsWith(u8, value, "--")) return runtime.DOMString.initOwned(value);
    defer instance.ctx.allocator.free(value);
    const keywords = [_][]const u8{ "toggle-popover", "show-popover", "hide-popover", "close", "request-close", "show-modal" };
    for (keywords) |keyword| {
        if (std.ascii.eqlIgnoreCase(value, keyword)) return runtime.DOMString.initInterned(keyword);
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for commandForElement
pub fn get_commandForElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    if (instance.getState(State).own._internal) |internal| {
        if (internal.command_target) |kept| {
            if (kept.get()) |target| {
                // HTML 2.6.1 step 3: target must be a descendant of one
                // of this element's shadow-including ancestors.
                var current: ?*runtime.Instance = instance;
                while (current) |node| {
                    if (node != instance and target != node and try interfaces.Node.call_contains(node, target)) return target;
                    current = form_associated.parentOf(node) orelse blk: {
                        if (node.stateAs(interfaces.ShadowRoot.State) == null) break :blk null;
                        break :blk try interfaces.ShadowRoot.get_host(node);
                    };
                }
                return null;
            }
            internal.command_target = null;
        }
    }
    // Steps 4-5: the content attribute resolves only within this tree.
    const id = attribute(instance, "commandfor") orelse return null;
    defer instance.ctx.allocator.free(id);
    return form_associated.firstElementWithId(form_associated.rootOf(instance), id);
}

/// Setter for commandForElement
pub fn set_commandForElement(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    // Temporary brand guard until interface argument conversion checks it.
    if (value) |target| if (target.stateAs(interfaces.Element.State) == null) return error.TypeError;
    if (value == null) {
        if (instance.getState(State).own._internal) |internal| internal.command_target = null;
        try interfaces.Element.call_removeAttribute(instance, runtime.DOMString.initInterned("commandfor"));
        return;
    }
    // Attribute change steps clear the old explicit value before step 3.
    _ = try validationState(instance);
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("commandfor"), .{ .domstring = runtime.DOMString.initEmpty() });
    instance.getState(State).own._internal.?.command_target = dom.custom_elements.KeptInstance.of(value.?);
}

/// Getter for form: the element's form owner.
pub fn get_form(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return form_associated.formOwner(instance);
}

/// Getter for formAction: reflects formaction as a URL, "except that on
/// getting, when the content attribute is missing or its value is the empty
/// string, the element's node document's URL must be returned instead."
pub fn get_formAction(instance: *runtime.Instance) anyerror!runtime.USVString {
    if (attribute(instance, "formaction")) |value| {
        defer instance.ctx.allocator.free(value);
        if (value.len > 0) return reflection.get(runtime.USVString, instance, .{ .name = "formaction", .url = true });
    }
    const document = (try interfaces.Node.get_ownerDocument(instance)) orelse return try instance.ctx.allocator.dupe(u8, "");
    return interfaces.Document.get_URL(document);
}

/// An enumerated attribute limited to only known values with no missing
/// value default: its keyword, `invalid` for an unknown value, "" when
/// absent.
fn enumeratedNoMissingDefault(instance: *runtime.Instance, comptime name: []const u8, comptime known: []const []const u8, comptime invalid: []const u8) runtime.DOMString {
    const value = attribute(instance, name) orelse return runtime.DOMString.initEmpty();
    defer instance.ctx.allocator.free(value);
    inline for (known) |candidate| {
        if (std.ascii.eqlIgnoreCase(value, candidate)) return runtime.DOMString.initInterned(candidate);
    }
    return runtime.DOMString.initInterned(invalid);
}

/// Getter for formEnctype: formenctype, limited to only known values; its
/// invalid value default is application/x-www-form-urlencoded, and it has no
/// missing value default.
pub fn get_formEnctype(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return enumeratedNoMissingDefault(instance, "formenctype", &.{ "application/x-www-form-urlencoded", "multipart/form-data", "text/plain" }, "application/x-www-form-urlencoded");
}

/// Getter for formMethod: formmethod, limited to only known values; its
/// invalid value default is GET, and it has no missing value default.
pub fn get_formMethod(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return enumeratedNoMissingDefault(instance, "formmethod", &.{ "get", "post", "dialog" }, "get");
}

/// Setter for formEnctype
pub fn set_formEnctype(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("formenctype"), .{ .domstring = value });
}

/// Setter for formMethod
pub fn set_formMethod(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("formmethod"), .{ .domstring = value });
}

/// Getter for willValidate: a candidate for constraint validation - a submit
/// button that is not disabled and has no datalist ancestor.
pub fn get_willValidate(instance: *runtime.Instance) anyerror!bool {
    if (!form_associated.isSubmitButton(instance)) return false;
    if (form_associated.isDisabled(instance)) return false;
    var ancestor = form_associated.parentOf(instance);
    while (ancestor) |a| : (ancestor = form_associated.parentOf(a)) {
        if (form_associated.isElementNamed(a, "datalist")) return false;
    }
    return true;
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
    // Reuse the existing lazy state; parsing an untouched button adds no work.
    _ = try validationState(instance);
    return instance.getState(State).own._internal.?.labels.get(instance);
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
