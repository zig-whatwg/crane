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
//! Stated: the command and commandfor attributes' behaviour (command
//! events, popover and dialog commands) and constraint validation are not
//! implemented.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const reflection = @import("reflection.zig");
const form_associated = @import("html").form_associated;
const dom = @import("dom");
const HTMLButtonElement = interfaces.HTMLButtonElement;
const log = std.log.scoped(.forms);

pub const State = HTMLButtonElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// HTMLButtonElement keeps nothing beyond its attributes.
pub const InternalState = struct {};

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // Installed before any button exists (idempotent).
    dom.activation.install(.{ .has = &hasActivationBehavior, .run = &runActivationBehavior });
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
    // 4-6. The commandfor-associated element's command, or the popover
    // target attribute activation behavior: not implemented.
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
    _ = instance;
    return null;
}

/// Setter for commandForElement
pub fn set_commandForElement(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
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
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("formenctype"), value);
}

/// Setter for formMethod
pub fn set_formMethod(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("formmethod"), value);
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
    return form_associated.labelsNodeList(instance);
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
    _ = instance;
    return error.NotImplemented;
}

/// Operation: reportValidity
pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setCustomValidity
pub fn call_setCustomValidity(instance: *runtime.Instance, @"error": runtime.DOMString) anyerror!void {
    _ = instance;
    _ = @"error";
    return error.NotImplemented;
}
