//! HTML "determining the target of an event handler" (§8.1.8.1).
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#determining-the-target-of-an-event-handler
//!
//! An event handler IDL attribute acts on its target's event handler map, and
//! the target is the object the attribute was read on - except that a body or
//! frameset element's WindowEventHandlers members, and the handlers in the
//! "Window-reflecting body element event handler set", are its Window's.
//! Used by the GlobalEventHandlers and WindowEventHandlers impls, whose members
//! every includer inherits, and by Element's event handler content attribute
//! steps.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

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

/// The target of the event handler `name` exposed on `this`, or null when
/// there is none.
pub fn determine(this: *runtime.Instance, name: []const u8) ?*runtime.Instance {
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

test "the window-reflecting set is WindowEventHandlers plus six" {
    try std.testing.expect(isWindowReflecting("onload"));
    try std.testing.expect(isWindowReflecting("onhashchange"));
    try std.testing.expect(isWindowReflecting("onbeforeunload"));
    try std.testing.expect(!isWindowReflecting("onclick"));
    try std.testing.expect(!isWindowReflecting("load"));
}
