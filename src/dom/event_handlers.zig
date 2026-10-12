//! HTML event handlers (8.1.8.1): the event handler IDL attributes' getter
//! and setter steps, and the event handler map they act on, which is
//! EventTarget's.
//!
//! Every attribute of type EventHandler, OnErrorEventHandler or
//! OnBeforeUnloadEventHandler has the same getter and setter steps, so its
//! generated accessor runs them here (`value`, `setValue`) unless the impl
//! implements it (src/webidl/codegen/writer.zig, `isEventHandlerAttribute`).
//! WebKit's generator does the same: CodeGeneratorJS.pm's IsEventHandlerType
//! branch emits `eventHandlerAttribute(...)`, and its implementation classes
//! declare nothing per attribute.
//!
//! The map itself is EventTarget's state, reached through the steps it
//! installs once, at process start (its installHooks).
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes
//!
//! lint-impls: hook for EventTarget
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const process_start = @import("process_start.zig");

pub const Implementation = struct {
    get: *const fn (*runtime.Instance, []const u8) ?usize,
    set: *const fn (*runtime.Instance, []const u8, ?usize) anyerror!void,
    erase: *const fn (*runtime.Instance) void,
};

// process-wide: hook table written once at process start by EventTarget.installHooks (B0); comptime in B9
var implementation: ?Implementation = null;

/// Install the owner's steps before any Browser exists.
pub fn install(steps: Implementation) void {
    process_start.assertInstalling();
    implementation = steps;
}

/// The event handler IDL attribute getter steps, for the attribute `name`
/// ("onload") read on `this`: the handler's value in the binding's
/// representation (BORROWED from the map), or null.
pub inline fn value(comptime Handler: type, this: *runtime.Instance, comptime name: []const u8) Handler {
    // 1. Let eventTarget be the result of determining the target of an event
    //    handler given this object and name.
    // 2. If eventTarget is null, then return null.
    const target = targetOf(this, name) orelse return null;
    // 3. Return the result of getting the current value of the event handler
    //    given eventTarget and name. The map is keyed by the event handler
    //    event type: the name without its "on".
    return get(Handler, target, eventType(name));
}

/// The event handler IDL attribute setter steps, for the attribute `name` set
/// on `this` to `handler` (the binding's representation, handed over).
pub inline fn setValue(comptime Handler: type, this: *runtime.Instance, comptime name: []const u8, handler: Handler) !void {
    // 1. Let eventTarget be the result of determining the target of an event
    //    handler given this object and name.
    // 2. If eventTarget is null, then return.
    const target = targetOf(this, name) orelse return;
    // 3. If the given value is null, then deactivate an event handler given
    //    eventTarget and name.
    // 4. Otherwise: set eventHandler's value to the given value, then
    //    activate an event handler given eventTarget and name.
    try set(Handler, target, eventType(name), handler);
}

/// An event handler's event type: its IDL attribute's name without "on"
/// (HTML 8.1.8.1: an event handler's name "always starts with 'on'").
fn eventType(comptime name: []const u8) []const u8 {
    comptime std.debug.assert(name.len > 2 and std.mem.startsWith(u8, name, "on"));
    return name[2..];
}

/// "Determining the target of an event handler" for a `name` known at
/// compile time. Step 2 first - it, like step 1, returns eventTarget, so the
/// order is not observable - and it is decided at compile time: a handler
/// that is neither a WindowEventHandlers member nor in the Window-reflecting
/// set is always its own object's, for any receiver.
inline fn targetOf(this: *runtime.Instance, comptime name: []const u8) ?*runtime.Instance {
    if (comptime !isWindowReflecting(name)) return this;
    return determineTarget(this, name);
}

/// The "Window-reflecting body element event handler set", and the attribute
/// members of WindowEventHandlers: the handlers a body or frameset element
/// exposes but whose target is its Window.
const window_reflecting = [_][]const u8{
    // Window-reflecting body element event handler set
    "onblur",         "onerror",              "onfocus",
    "onload",         "onresize",             "onscroll",
    // WindowEventHandlers
    "onafterprint",   "onbeforeprint",        "onbeforeunload",
    "onhashchange",   "onlanguagechange",     "onmessage",
    "onmessageerror", "onoffline",            "ononline",
    "onpagehide",     "onpagereveal",         "onpageshow",
    "onpageswap",     "onpopstate",           "onrejectionhandled",
    "onstorage",      "onunhandledrejection", "onunload",
};

/// Whether a body or frameset element's handler `name` is its Window's.
pub fn isWindowReflecting(name: []const u8) bool {
    for (window_reflecting) |reflecting| {
        if (std.mem.eql(u8, reflecting, name)) return true;
    }
    return false;
}

/// HTML "determining the target of an event handler": the target of the
/// event handler `name` exposed on `this`, or null when there is none.
/// https://html.spec.whatwg.org/multipage/webappapis.html#determining-the-target-of-an-event-handler
pub fn determineTarget(this: *runtime.Instance, name: []const u8) ?*runtime.Instance {
    // Step 1: "If eventTarget is not a body element or a frameset element,
    // then return eventTarget."
    const body_or_frameset = this.stateAs(interfaces.HTMLBodyElement.State) != null or
        this.stateAs(interfaces.HTMLFrameSetElement.State) != null;
    if (!body_or_frameset) return this;

    // Step 2: "If name is not the name of an attribute member of the
    // WindowEventHandlers interface mixin and the Window-reflecting body
    // element event handler set does not contain name, then return
    // eventTarget."
    if (!isWindowReflecting(name)) return this;

    // Step 3: "If eventTarget's node document is not an active document, then
    // return null." A document is active when it is its window's document.
    const document = (interfaces.Node.get_ownerDocument(this) catch null) orelse return null;
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return null;
    const shown = interfaces.Window.get_document(window) catch return null;
    if (shown != document) return null;

    // Step 4: "Return eventTarget's node document's relevant global object."
    return window;
}

/// Borrow the handler in the binding's representation.
pub inline fn get(comptime Handler: type, target: *runtime.Instance, event_type: []const u8) Handler {
    const address = (implementation orelse return null).get(target, event_type) orelse return null;
    return fromAddress(Handler, address);
}

/// Hand the binding's handler value to EventTarget, or deactivate it.
pub inline fn set(comptime Handler: type, target: *runtime.Instance, event_type: []const u8, handler: Handler) !void {
    const steps = implementation orelse return error.NotSupported;
    return steps.set(target, event_type, toAddress(Handler, handler));
}

/// HTML "erase all event listeners and handlers", including activated IDL
/// event handlers. document.open applies this to its shadow-including tree.
pub fn eraseAll(target: *runtime.Instance) void {
    const steps = implementation orelse return;
    steps.erase(target);
}

fn fromAddress(comptime Handler: type, address: usize) Handler {
    const Callable = @typeInfo(Handler).optional.child;
    comptime std.debug.assert(@sizeOf(Callable) == @sizeOf(usize));
    var handler: Callable = undefined;
    @memcpy(std.mem.asBytes(&handler), std.mem.asBytes(&address));
    return handler;
}

fn toAddress(comptime Handler: type, maybe: Handler) ?usize {
    const Callable = @typeInfo(Handler).optional.child;
    comptime std.debug.assert(@sizeOf(Callable) == @sizeOf(usize));
    const handler = maybe orelse return null;
    var address: usize = undefined;
    @memcpy(std.mem.asBytes(&address), std.mem.asBytes(&handler));
    return address;
}

test "the window-reflecting set is WindowEventHandlers plus six" {
    try std.testing.expect(isWindowReflecting("onload"));
    try std.testing.expect(isWindowReflecting("onhashchange"));
    try std.testing.expect(isWindowReflecting("onbeforeunload"));
    try std.testing.expect(!isWindowReflecting("onclick"));
    try std.testing.expect(!isWindowReflecting("load"));
    // Decided at compile time for a generated accessor's name.
    try std.testing.expect(comptime !isWindowReflecting("onreadystatechange"));
}

test "an event handler's event type is its name without on" {
    try std.testing.expectEqualStrings("load", eventType("onload"));
    try std.testing.expectEqualStrings("beforeunload", eventType("onbeforeunload"));
}

test "event handler representation - null and callable round trip" {
    const Handler = ?*const fn () void;
    const function = struct {
        fn callback() void {}
    }.callback;
    const handler: Handler = &function;
    try std.testing.expect(toAddress(Handler, null) == null);
    try std.testing.expect(fromAddress(Handler, toAddress(Handler, handler).?) == handler);
}
