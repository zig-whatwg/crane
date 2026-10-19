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
//! An event handler content attribute makes an "internal raw uncompiled
//! handler" (`setRaw`), which "getting the current value of the event
//! handler" compiles on first use (`compileRaw`). Element owns attributes and the
//! compiling, so it installs that step (`installRawCompiler`).
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes
//!
//! lint-impls: hook for EventTarget, Element
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const process_start = @import("process_start.zig");

pub const Implementation = struct {
    get: *const fn (*runtime.Instance, []const u8) ?usize,
    set: *const fn (*runtime.Instance, []const u8, ?usize) anyerror!void,
    /// Make the handler for the event type an internal raw uncompiled
    /// handler, and activate it.
    set_raw: ?*const fn (*runtime.Instance, []const u8, RawSource) anyerror!void = null,
    erase: *const fn (*runtime.Instance) void,
    /// Whether the target's event listener list holds a listener that is not
    /// removed - an activated event handler's included.
    has_listeners: *const fn (*runtime.Instance) bool,
};

// process-wide: hook table written once at process start by EventTarget.installHooks (B0); comptime in B9
var implementation: ?Implementation = null;

/// What compiling a raw uncompiled handler came to.
pub const RawCompile = enum {
    /// Scripting is disabled for the element's document (it still has no
    /// browsing context): the handler stays raw, and its value is null.
    scripting_disabled,
    /// Compiled: the value is now the function - or null, with the syntax
    /// error reported - and no longer raw.
    settled,
};

/// Element's "getting the current value of the event handler" step 3 for a
/// raw uncompiled handler of `target` for an event type: compile the body (the
/// content attribute) in the element's document and set the handler's value.
pub const RawCompiler = *const fn (target: *runtime.Instance, event_type: []const u8, source: RawSource) RawCompile;

/// HTML's internal raw uncompiled handler body and source location. Borrowed
/// at the hook boundary; EventTarget clones it into the handler map. The
/// stored body cannot be reconstructed from the current attribute: CSP may
/// reject a replacement, and a body/frameset's Window handler outlives that
/// element. Like WebKit's JSLazyEventListener, it keeps no origin-element ptr.
pub const RawSource = struct {
    body: []const u8,
    url: []const u8,
    lineno: u32 = 0,

    pub fn clone(self: RawSource, allocator: std.mem.Allocator) !RawSource {
        const body = try allocator.dupe(u8, self.body);
        errdefer allocator.free(body);
        return .{ .body = body, .url = try allocator.dupe(u8, self.url), .lineno = self.lineno };
    }

    /// Only a clone owns its slices.
    pub fn deinit(self: RawSource, allocator: std.mem.Allocator) void {
        allocator.free(self.body);
        allocator.free(self.url);
    }
};

// process-wide: a function pointer Element's installHooks writes once at process start, the same for every Browser
var raw_compiler: ?RawCompiler = null;

/// Install the owner's steps before any Browser exists.
pub fn install(steps: Implementation) void {
    process_start.assertInstalling();
    implementation = steps;
}

/// Install Element's raw-handler compiling step before any Browser exists.
pub fn installRawCompiler(compiler: RawCompiler) void {
    process_start.assertInstalling();
    raw_compiler = compiler;
}

/// The event handler content attribute change steps 5.2-5.6 for an element
/// given `target`: its handler for
/// `event_type` becomes an internal raw uncompiled handler, activated.
pub fn setRaw(target: *runtime.Instance, event_type: []const u8, source: RawSource) !void {
    const steps = implementation orelse return error.NotSupported;
    const set_raw = steps.set_raw orelse return error.NotSupported;
    return set_raw(target, event_type, source);
}

/// Compile `target`'s raw uncompiled handler for `event_type`
/// (EventTarget's "getting the current value"). With no compiler installed
/// the handler stays raw: nothing can compile it.
pub fn compileRaw(target: *runtime.Instance, event_type: []const u8, source: RawSource) RawCompile {
    const compiler = raw_compiler orelse return .scripting_disabled;
    return compiler(target, event_type, source);
}

/// The event handler event type for the event handler content attribute
/// `name` ("onclick" -> "click"): HTML 8.1.8.2's table, whose four legacy
/// WebKit-prefixed attributes have mixed-case event types. BORROWED from
/// `name`, or static.
pub fn eventTypeOf(name: []const u8) []const u8 {
    std.debug.assert(name.len > 2);
    inline for (.{ "onwebkitanimationend", "onwebkitanimationiteration", "onwebkitanimationstart", "onwebkittransitionend" }) |legacy| {
        if (std.mem.eql(u8, name, legacy)) return comptime eventType(legacy);
    }
    return name[2..];
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
    //    event type (including the legacy mixed-case event types).
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

/// The event type from HTML 8.1.8.2's event handler table. The four legacy
/// WebKit-prefixed attributes use lowercase names but mixed-case event types.
fn eventType(comptime name: []const u8) []const u8 {
    comptime std.debug.assert(name.len > 2 and std.mem.startsWith(u8, name, "on"));
    if (comptime std.mem.eql(u8, name, "onwebkitanimationend")) return "webkitAnimationEnd";
    if (comptime std.mem.eql(u8, name, "onwebkitanimationiteration")) return "webkitAnimationIteration";
    if (comptime std.mem.eql(u8, name, "onwebkitanimationstart")) return "webkitAnimationStart";
    if (comptime std.mem.eql(u8, name, "onwebkittransitionend")) return "webkitTransitionEnd";
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
    "onblur",              "onerror",              "onfocus",
    "onload",              "onresize",             "onscroll",
    // WindowEventHandlers
    "onafterprint",        "onbeforeprint",        "onbeforeunload",
    "onhashchange",        "onlanguagechange",     "onmessage",
    "onmessageerror",      "onoffline",            "ononline",
    "onpagehide",          "onpagereveal",         "onpageshow",
    "onpageswap",          "onpopstate",           "onrejectionhandled",
    "onstorage",           "onunhandledrejection", "onunload",
    // Compat partial HTMLBodyElement. Browser deviation from the Compat
    // text, which leaves it on the body: Blink (html_body_element.h) and
    // Gecko (EventNameList.h, WINDOW_EVENT) forward it to the Window.
    "onorientationchange",
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

/// Whether `target` has an event listener registered: one in its event
/// listener list whose removed is false, an activated event handler's
/// included (XHR send() step 5, "one or more event listeners are registered
/// on this's upload object").
pub fn hasListeners(target: *runtime.Instance) bool {
    const steps = implementation orelse return false;
    return steps.has_listeners(target);
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

test "the window-reflecting set is WindowEventHandlers plus six, and orientationchange" {
    try std.testing.expect(isWindowReflecting("onload"));
    try std.testing.expect(isWindowReflecting("onhashchange"));
    try std.testing.expect(isWindowReflecting("onbeforeunload"));
    // Blink html_body_element.h and Gecko EventNameList.h (WINDOW_EVENT)
    // forward body.onorientationchange to the Window.
    try std.testing.expect(isWindowReflecting("onorientationchange"));
    try std.testing.expect(!isWindowReflecting("onclick"));
    try std.testing.expect(!isWindowReflecting("load"));
    // Decided at compile time for a generated accessor's name.
    try std.testing.expect(comptime !isWindowReflecting("onreadystatechange"));
}

test "a content attribute's event type matches its IDL attribute's" {
    try std.testing.expectEqualStrings("click", eventTypeOf("onclick"));
    try std.testing.expectEqualStrings("beforeunload", eventTypeOf("onbeforeunload"));
    try std.testing.expectEqualStrings("webkitAnimationEnd", eventTypeOf("onwebkitanimationend"));
    try std.testing.expectEqualStrings("webkitTransitionEnd", eventTypeOf("onwebkittransitionend"));
}

test "without a compiler a raw handler stays raw" {
    const saved = raw_compiler;
    defer raw_compiler = saved;
    raw_compiler = null;
    // Never dereferenced: nothing is installed to read it.
    var target: runtime.Instance = undefined;
    try std.testing.expectEqual(RawCompile.scripting_disabled, compileRaw(&target, "click", .{ .body = "", .url = "" }));
}

test "an event handler's event type is its name without on" {
    try std.testing.expectEqualStrings("load", eventType("onload"));
    try std.testing.expectEqualStrings("beforeunload", eventType("onbeforeunload"));
}

test "legacy WebKit handler attributes use mixed-case event types" {
    try std.testing.expectEqualStrings("webkitAnimationEnd", eventType("onwebkitanimationend"));
    try std.testing.expectEqualStrings("webkitAnimationIteration", eventType("onwebkitanimationiteration"));
    try std.testing.expectEqualStrings("webkitAnimationStart", eventType("onwebkitanimationstart"));
    try std.testing.expectEqualStrings("webkitTransitionEnd", eventType("onwebkittransitionend"));
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
