//! Implementation for HTMLLabelElement interface
//!
//! Spec: HTML § 4.10.4 The label element
//! https://html.spec.whatwg.org/multipage/forms.html#the-label-element
//!
//! htmlFor reflects `for` (the generated interface's). Here: the labeled
//! control, the label's form, and its activation behaviour. The spec leaves
//! that behaviour to the platform, except that "the activation behavior of a
//! label element for events targeted at interactive content descendants of a
//! label element, and any descendants of those interactive content
//! descendants, must be to do nothing". Every browser's platform behaviour
//! is to click the labeled control (Blink's HTMLLabelElement::
//! DefaultEventHandler dispatches a simulated click at it), and so does this
//! one.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const form_associated = @import("html").form_associated;
const dom = @import("dom");
const HTMLLabelElement = interfaces.HTMLLabelElement;
const log = std.log.scoped(.forms);

pub const State = HTMLLabelElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// HTMLLabelElement keeps nothing beyond its attributes.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
/// Chains to parent class: HTMLElement -> Element -> Node -> EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Installed before any label exists (idempotent).
    dom.activation.install(.{ .has = &hasActivationBehavior, .run = &runActivationBehavior });
    return interfaces.HTMLElement.initWithState(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    interfaces.HTMLElement.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &HTMLLabelElement.vtable, ctx);
    errdefer deinit(instance);
    return instance;
}

/// Getter for form: "1. If the label element has no labeled control, then
/// return null. 2. If the label element's labeled control is not a
/// form-associated element, then return null. 3. Return the label element's
/// labeled control's form owner (which can still be null)."
pub fn get_form(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const control = form_associated.labeledControl(instance) orelse return null;
    // Every labelable element but a form-associated custom element (not
    // implemented) is a form-associated element.
    return form_associated.formOwner(control);
}

/// Getter for control: "the label element's labeled control, if any, or
/// null if there isn't one."
pub fn get_control(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return form_associated.labeledControl(instance);
}

// ============================================================================
// Activation behaviour
// ============================================================================

fn hasActivationBehavior(target: *runtime.Instance) bool {
    return target.stateAs(State) != null;
}

/// Whether `node` is interactive content: a (with href), audio and video
/// (with controls), button, details, embed, iframe, img (with usemap),
/// input (not hidden), label, select and textarea.
fn isInteractiveContent(node: *runtime.Instance) bool {
    if (!form_associated.isElement(node)) return false;
    if (form_associated.isElementNamed(node, "a")) return form_associated.hasAttribute(node, "href");
    if (form_associated.isElementNamed(node, "audio") or form_associated.isElementNamed(node, "video")) return form_associated.hasAttribute(node, "controls");
    if (form_associated.isElementNamed(node, "img")) return form_associated.hasAttribute(node, "usemap");
    if (form_associated.isInput(node)) {
        var buffer: [16]u8 = undefined;
        return !std.mem.eql(u8, form_associated.inputType(node, &buffer), "hidden");
    }
    const names = [_][]const u8{ "button", "details", "embed", "iframe", "label", "select", "textarea" };
    var local = interfaces.Element.get_localName(node) catch return false;
    defer local.deinit(node.ctx.allocator);
    for (names) |name| {
        if (std.ascii.eqlIgnoreCase(local.asSlice(), name)) return true;
    }
    return false;
}

/// The label's activation behaviour, given the click event: nothing for an
/// event targeted at an interactive content descendant or anything inside
/// one; otherwise a click at the labeled control.
fn runActivationBehavior(label: *runtime.Instance, event: *runtime.Instance) void {
    const target = (interfaces.Event.get_target(event) catch null) orelse label;
    // Between the target and the label, inclusive of the target: interactive
    // content means the click was that content's, not the label's.
    var node: ?*runtime.Instance = target;
    while (node) |n| : (node = form_associated.parentOf(n)) {
        if (n == label) break;
        if (isInteractiveContent(n)) return;
    }
    const control = form_associated.labeledControl(label) orelse return;
    // A click the control's own subtree received is the control's.
    var inside: ?*runtime.Instance = target;
    while (inside) |n| : (inside = form_associated.parentOf(n)) {
        if (n == control) return;
    }
    interfaces.HTMLElement.call_click(control) catch |err| {
        log.warn("label click not forwarded: {}", .{err});
    };
}
