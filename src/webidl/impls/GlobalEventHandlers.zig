//! GlobalEventHandlers: event handler IDL attributes (HTML §8.1.8.1).
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers
//!
//! Every interface that includes GlobalEventHandlers inherits these members
//! (src/webidl/codegen/inherited_mixins.zig), so this is their one
//! implementation, with `this` an instance of whichever includer the
//! attribute was read on. A handler lives in its target's event handler map,
//! on EventTarget - the ancestor every includer shares.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const GlobalEventHandlers = interfaces.GlobalEventHandlers;

pub const State = GlobalEventHandlers.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

// =============================================================================
// Event handler IDL attributes
// =============================================================================

const EventTargetImpl = @import("EventTarget.zig");
const event_handler_target = @import("event_handler_target.zig");

/// The event handler IDL attribute getter steps.
fn handlerValue(comptime Handler: type, this: *runtime.Instance, comptime name: []const u8) Handler {
    // Step 1: "Let eventTarget be the result of determining the target of an
    // event handler given this object and name."
    // Step 2: "If eventTarget is null, then return null."
    const target = event_handler_target.determine(this, name) orelse return null;
    // Step 3: "Return the result of getting the current value of the event
    // handler given eventTarget and name."
    return EventTargetImpl.eventHandler(Handler, target, name[2..]);
}

/// The event handler IDL attribute setter steps.
fn setHandlerValue(comptime Handler: type, this: *runtime.Instance, comptime name: []const u8, value: Handler) !void {
    // Steps 1 and 2: the target, or nothing to do.
    const target = event_handler_target.determine(this, name) orelse return;
    // Steps 3 and 4 on the target's event handler map.
    try EventTargetImpl.setEventHandler(Handler, target, name[2..], value);
}

/// Getter for onabort
pub fn get_onabort(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onabort");
}

/// Setter for onabort
pub fn set_onabort(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onabort", value);
}

/// Getter for onauxclick
pub fn get_onauxclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onauxclick");
}

/// Setter for onauxclick
pub fn set_onauxclick(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onauxclick", value);
}

/// Getter for onbeforeinput
pub fn get_onbeforeinput(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onbeforeinput");
}

/// Setter for onbeforeinput
pub fn set_onbeforeinput(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onbeforeinput", value);
}

/// Getter for onbeforematch
pub fn get_onbeforematch(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onbeforematch");
}

/// Setter for onbeforematch
pub fn set_onbeforematch(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onbeforematch", value);
}

/// Getter for onbeforetoggle
pub fn get_onbeforetoggle(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onbeforetoggle");
}

/// Setter for onbeforetoggle
pub fn set_onbeforetoggle(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onbeforetoggle", value);
}

/// Getter for onblur
pub fn get_onblur(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onblur");
}

/// Setter for onblur
pub fn set_onblur(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onblur", value);
}

/// Getter for oncancel
pub fn get_oncancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "oncancel");
}

/// Setter for oncancel
pub fn set_oncancel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "oncancel", value);
}

/// Getter for oncanplay
pub fn get_oncanplay(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "oncanplay");
}

/// Setter for oncanplay
pub fn set_oncanplay(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "oncanplay", value);
}

/// Getter for oncanplaythrough
pub fn get_oncanplaythrough(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "oncanplaythrough");
}

/// Setter for oncanplaythrough
pub fn set_oncanplaythrough(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "oncanplaythrough", value);
}

/// Getter for onchange
pub fn get_onchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onchange");
}

/// Setter for onchange
pub fn set_onchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onchange", value);
}

/// Getter for onclick
pub fn get_onclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onclick");
}

/// Setter for onclick
pub fn set_onclick(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onclick", value);
}

/// Getter for onclose
pub fn get_onclose(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onclose");
}

/// Setter for onclose
pub fn set_onclose(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onclose", value);
}

/// Getter for oncommand
pub fn get_oncommand(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "oncommand");
}

/// Setter for oncommand
pub fn set_oncommand(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "oncommand", value);
}

/// Getter for oncontextlost
pub fn get_oncontextlost(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "oncontextlost");
}

/// Setter for oncontextlost
pub fn set_oncontextlost(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "oncontextlost", value);
}

/// Getter for oncontextmenu
pub fn get_oncontextmenu(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "oncontextmenu");
}

/// Setter for oncontextmenu
pub fn set_oncontextmenu(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "oncontextmenu", value);
}

/// Getter for oncontextrestored
pub fn get_oncontextrestored(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "oncontextrestored");
}

/// Setter for oncontextrestored
pub fn set_oncontextrestored(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "oncontextrestored", value);
}

/// Getter for oncopy
pub fn get_oncopy(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "oncopy");
}

/// Setter for oncopy
pub fn set_oncopy(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "oncopy", value);
}

/// Getter for oncuechange
pub fn get_oncuechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "oncuechange");
}

/// Setter for oncuechange
pub fn set_oncuechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "oncuechange", value);
}

/// Getter for oncut
pub fn get_oncut(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "oncut");
}

/// Setter for oncut
pub fn set_oncut(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "oncut", value);
}

/// Getter for ondblclick
pub fn get_ondblclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ondblclick");
}

/// Setter for ondblclick
pub fn set_ondblclick(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ondblclick", value);
}

/// Getter for ondrag
pub fn get_ondrag(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ondrag");
}

/// Setter for ondrag
pub fn set_ondrag(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ondrag", value);
}

/// Getter for ondragend
pub fn get_ondragend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ondragend");
}

/// Setter for ondragend
pub fn set_ondragend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ondragend", value);
}

/// Getter for ondragenter
pub fn get_ondragenter(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ondragenter");
}

/// Setter for ondragenter
pub fn set_ondragenter(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ondragenter", value);
}

/// Getter for ondragleave
pub fn get_ondragleave(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ondragleave");
}

/// Setter for ondragleave
pub fn set_ondragleave(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ondragleave", value);
}

/// Getter for ondragover
pub fn get_ondragover(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ondragover");
}

/// Setter for ondragover
pub fn set_ondragover(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ondragover", value);
}

/// Getter for ondragstart
pub fn get_ondragstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ondragstart");
}

/// Setter for ondragstart
pub fn set_ondragstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ondragstart", value);
}

/// Getter for ondrop
pub fn get_ondrop(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ondrop");
}

/// Setter for ondrop
pub fn set_ondrop(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ondrop", value);
}

/// Getter for ondurationchange
pub fn get_ondurationchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ondurationchange");
}

/// Setter for ondurationchange
pub fn set_ondurationchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ondurationchange", value);
}

/// Getter for onemptied
pub fn get_onemptied(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onemptied");
}

/// Setter for onemptied
pub fn set_onemptied(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onemptied", value);
}

/// Getter for onended
pub fn get_onended(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onended");
}

/// Setter for onended
pub fn set_onended(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onended", value);
}

/// Getter for onerror
pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.OnErrorEventHandler {
    return handlerValue(typedefs.OnErrorEventHandler, instance, "onerror");
}

/// Setter for onerror
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.OnErrorEventHandler) anyerror!void {
    try setHandlerValue(typedefs.OnErrorEventHandler, instance, "onerror", value);
}

/// Getter for onfocus
pub fn get_onfocus(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onfocus");
}

/// Setter for onfocus
pub fn set_onfocus(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onfocus", value);
}

/// Getter for onformdata
pub fn get_onformdata(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onformdata");
}

/// Setter for onformdata
pub fn set_onformdata(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onformdata", value);
}

/// Getter for oninput
pub fn get_oninput(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "oninput");
}

/// Setter for oninput
pub fn set_oninput(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "oninput", value);
}

/// Getter for oninvalid
pub fn get_oninvalid(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "oninvalid");
}

/// Setter for oninvalid
pub fn set_oninvalid(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "oninvalid", value);
}

/// Getter for onkeydown
pub fn get_onkeydown(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onkeydown");
}

/// Setter for onkeydown
pub fn set_onkeydown(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onkeydown", value);
}

/// Getter for onkeypress
pub fn get_onkeypress(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onkeypress");
}

/// Setter for onkeypress
pub fn set_onkeypress(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onkeypress", value);
}

/// Getter for onkeyup
pub fn get_onkeyup(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onkeyup");
}

/// Setter for onkeyup
pub fn set_onkeyup(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onkeyup", value);
}

/// Getter for onload
pub fn get_onload(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onload");
}

/// Setter for onload
pub fn set_onload(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onload", value);
}

/// Getter for onloadeddata
pub fn get_onloadeddata(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onloadeddata");
}

/// Setter for onloadeddata
pub fn set_onloadeddata(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onloadeddata", value);
}

/// Getter for onloadedmetadata
pub fn get_onloadedmetadata(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onloadedmetadata");
}

/// Setter for onloadedmetadata
pub fn set_onloadedmetadata(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onloadedmetadata", value);
}

/// Getter for onloadstart
pub fn get_onloadstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onloadstart");
}

/// Setter for onloadstart
pub fn set_onloadstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onloadstart", value);
}

/// Getter for onmousedown
pub fn get_onmousedown(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onmousedown");
}

/// Setter for onmousedown
pub fn set_onmousedown(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onmousedown", value);
}

/// Getter for onmouseenter
pub fn get_onmouseenter(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onmouseenter");
}

/// Setter for onmouseenter
pub fn set_onmouseenter(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onmouseenter", value);
}

/// Getter for onmouseleave
pub fn get_onmouseleave(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onmouseleave");
}

/// Setter for onmouseleave
pub fn set_onmouseleave(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onmouseleave", value);
}

/// Getter for onmousemove
pub fn get_onmousemove(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onmousemove");
}

/// Setter for onmousemove
pub fn set_onmousemove(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onmousemove", value);
}

/// Getter for onmouseout
pub fn get_onmouseout(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onmouseout");
}

/// Setter for onmouseout
pub fn set_onmouseout(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onmouseout", value);
}

/// Getter for onmouseover
pub fn get_onmouseover(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onmouseover");
}

/// Setter for onmouseover
pub fn set_onmouseover(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onmouseover", value);
}

/// Getter for onmouseup
pub fn get_onmouseup(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onmouseup");
}

/// Setter for onmouseup
pub fn set_onmouseup(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onmouseup", value);
}

/// Getter for onpaste
pub fn get_onpaste(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onpaste");
}

/// Setter for onpaste
pub fn set_onpaste(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onpaste", value);
}

/// Getter for onpause
pub fn get_onpause(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onpause");
}

/// Setter for onpause
pub fn set_onpause(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onpause", value);
}

/// Getter for onplay
pub fn get_onplay(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onplay");
}

/// Setter for onplay
pub fn set_onplay(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onplay", value);
}

/// Getter for onplaying
pub fn get_onplaying(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onplaying");
}

/// Setter for onplaying
pub fn set_onplaying(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onplaying", value);
}

/// Getter for onprogress
pub fn get_onprogress(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onprogress");
}

/// Setter for onprogress
pub fn set_onprogress(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onprogress", value);
}

/// Getter for onratechange
pub fn get_onratechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onratechange");
}

/// Setter for onratechange
pub fn set_onratechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onratechange", value);
}

/// Getter for onreset
pub fn get_onreset(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onreset");
}

/// Setter for onreset
pub fn set_onreset(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onreset", value);
}

/// Getter for onresize
pub fn get_onresize(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onresize");
}

/// Setter for onresize
pub fn set_onresize(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onresize", value);
}

/// Getter for onscroll
pub fn get_onscroll(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onscroll");
}

/// Setter for onscroll
pub fn set_onscroll(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onscroll", value);
}

/// Getter for onscrollend
pub fn get_onscrollend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onscrollend");
}

/// Setter for onscrollend
pub fn set_onscrollend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onscrollend", value);
}

/// Getter for onsecuritypolicyviolation
pub fn get_onsecuritypolicyviolation(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onsecuritypolicyviolation");
}

/// Setter for onsecuritypolicyviolation
pub fn set_onsecuritypolicyviolation(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onsecuritypolicyviolation", value);
}

/// Getter for onseeked
pub fn get_onseeked(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onseeked");
}

/// Setter for onseeked
pub fn set_onseeked(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onseeked", value);
}

/// Getter for onseeking
pub fn get_onseeking(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onseeking");
}

/// Setter for onseeking
pub fn set_onseeking(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onseeking", value);
}

/// Getter for onselect
pub fn get_onselect(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onselect");
}

/// Setter for onselect
pub fn set_onselect(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onselect", value);
}

/// Getter for onslotchange
pub fn get_onslotchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onslotchange");
}

/// Setter for onslotchange
pub fn set_onslotchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onslotchange", value);
}

/// Getter for onstalled
pub fn get_onstalled(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onstalled");
}

/// Setter for onstalled
pub fn set_onstalled(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onstalled", value);
}

/// Getter for onsubmit
pub fn get_onsubmit(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onsubmit");
}

/// Setter for onsubmit
pub fn set_onsubmit(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onsubmit", value);
}

/// Getter for onsuspend
pub fn get_onsuspend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onsuspend");
}

/// Setter for onsuspend
pub fn set_onsuspend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onsuspend", value);
}

/// Getter for ontimeupdate
pub fn get_ontimeupdate(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ontimeupdate");
}

/// Setter for ontimeupdate
pub fn set_ontimeupdate(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ontimeupdate", value);
}

/// Getter for ontoggle
pub fn get_ontoggle(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ontoggle");
}

/// Setter for ontoggle
pub fn set_ontoggle(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ontoggle", value);
}

/// Getter for onvolumechange
pub fn get_onvolumechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onvolumechange");
}

/// Setter for onvolumechange
pub fn set_onvolumechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onvolumechange", value);
}

/// Getter for onwaiting
pub fn get_onwaiting(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onwaiting");
}

/// Setter for onwaiting
pub fn set_onwaiting(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onwaiting", value);
}

/// Getter for onwebkitanimationend
pub fn get_onwebkitanimationend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onwebkitanimationend");
}

/// Setter for onwebkitanimationend
pub fn set_onwebkitanimationend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onwebkitanimationend", value);
}

/// Getter for onwebkitanimationiteration
pub fn get_onwebkitanimationiteration(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onwebkitanimationiteration");
}

/// Setter for onwebkitanimationiteration
pub fn set_onwebkitanimationiteration(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onwebkitanimationiteration", value);
}

/// Getter for onwebkitanimationstart
pub fn get_onwebkitanimationstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onwebkitanimationstart");
}

/// Setter for onwebkitanimationstart
pub fn set_onwebkitanimationstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onwebkitanimationstart", value);
}

/// Getter for onwebkittransitionend
pub fn get_onwebkittransitionend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onwebkittransitionend");
}

/// Setter for onwebkittransitionend
pub fn set_onwebkittransitionend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onwebkittransitionend", value);
}

/// Getter for onwheel
pub fn get_onwheel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onwheel");
}

/// Setter for onwheel
pub fn set_onwheel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onwheel", value);
}

/// Getter for onselectstart
pub fn get_onselectstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onselectstart");
}

/// Setter for onselectstart
pub fn set_onselectstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onselectstart", value);
}

/// Getter for onselectionchange
pub fn get_onselectionchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onselectionchange");
}

/// Setter for onselectionchange
pub fn set_onselectionchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onselectionchange", value);
}

/// Getter for onanimationstart
pub fn get_onanimationstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onanimationstart");
}

/// Setter for onanimationstart
pub fn set_onanimationstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onanimationstart", value);
}

/// Getter for onanimationiteration
pub fn get_onanimationiteration(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onanimationiteration");
}

/// Setter for onanimationiteration
pub fn set_onanimationiteration(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onanimationiteration", value);
}

/// Getter for onanimationend
pub fn get_onanimationend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onanimationend");
}

/// Setter for onanimationend
pub fn set_onanimationend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onanimationend", value);
}

/// Getter for onanimationcancel
pub fn get_onanimationcancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onanimationcancel");
}

/// Setter for onanimationcancel
pub fn set_onanimationcancel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onanimationcancel", value);
}

/// Getter for ontransitionrun
pub fn get_ontransitionrun(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ontransitionrun");
}

/// Setter for ontransitionrun
pub fn set_ontransitionrun(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ontransitionrun", value);
}

/// Getter for ontransitionstart
pub fn get_ontransitionstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ontransitionstart");
}

/// Setter for ontransitionstart
pub fn set_ontransitionstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ontransitionstart", value);
}

/// Getter for ontransitionend
pub fn get_ontransitionend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ontransitionend");
}

/// Setter for ontransitionend
pub fn set_ontransitionend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ontransitionend", value);
}

/// Getter for ontransitioncancel
pub fn get_ontransitioncancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ontransitioncancel");
}

/// Setter for ontransitioncancel
pub fn set_ontransitioncancel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ontransitioncancel", value);
}

/// Getter for onbeforexrselect
pub fn get_onbeforexrselect(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onbeforexrselect");
}

/// Setter for onbeforexrselect
pub fn set_onbeforexrselect(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onbeforexrselect", value);
}

/// Getter for onpointerover
pub fn get_onpointerover(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onpointerover");
}

/// Setter for onpointerover
pub fn set_onpointerover(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onpointerover", value);
}

/// Getter for onpointerenter
pub fn get_onpointerenter(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onpointerenter");
}

/// Setter for onpointerenter
pub fn set_onpointerenter(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onpointerenter", value);
}

/// Getter for onpointerdown
pub fn get_onpointerdown(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onpointerdown");
}

/// Setter for onpointerdown
pub fn set_onpointerdown(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onpointerdown", value);
}

/// Getter for onpointermove
pub fn get_onpointermove(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onpointermove");
}

/// Setter for onpointermove
pub fn set_onpointermove(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onpointermove", value);
}

/// Getter for onpointerrawupdate
pub fn get_onpointerrawupdate(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onpointerrawupdate");
}

/// Setter for onpointerrawupdate
pub fn set_onpointerrawupdate(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onpointerrawupdate", value);
}

/// Getter for onpointerup
pub fn get_onpointerup(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onpointerup");
}

/// Setter for onpointerup
pub fn set_onpointerup(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onpointerup", value);
}

/// Getter for onpointercancel
pub fn get_onpointercancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onpointercancel");
}

/// Setter for onpointercancel
pub fn set_onpointercancel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onpointercancel", value);
}

/// Getter for onpointerout
pub fn get_onpointerout(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onpointerout");
}

/// Setter for onpointerout
pub fn set_onpointerout(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onpointerout", value);
}

/// Getter for onpointerleave
pub fn get_onpointerleave(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onpointerleave");
}

/// Setter for onpointerleave
pub fn set_onpointerleave(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onpointerleave", value);
}

/// Getter for ongotpointercapture
pub fn get_ongotpointercapture(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ongotpointercapture");
}

/// Setter for ongotpointercapture
pub fn set_ongotpointercapture(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ongotpointercapture", value);
}

/// Getter for onlostpointercapture
pub fn get_onlostpointercapture(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onlostpointercapture");
}

/// Setter for onlostpointercapture
pub fn set_onlostpointercapture(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onlostpointercapture", value);
}

/// Getter for ontouchstart
pub fn get_ontouchstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ontouchstart");
}

/// Setter for ontouchstart
pub fn set_ontouchstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ontouchstart", value);
}

/// Getter for ontouchend
pub fn get_ontouchend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ontouchend");
}

/// Setter for ontouchend
pub fn set_ontouchend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ontouchend", value);
}

/// Getter for ontouchmove
pub fn get_ontouchmove(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ontouchmove");
}

/// Setter for ontouchmove
pub fn set_ontouchmove(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ontouchmove", value);
}

/// Getter for ontouchcancel
pub fn get_ontouchcancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ontouchcancel");
}

/// Setter for ontouchcancel
pub fn set_ontouchcancel(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ontouchcancel", value);
}

/// Getter for onfencedtreeclick
pub fn get_onfencedtreeclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onfencedtreeclick");
}

/// Setter for onfencedtreeclick
pub fn set_onfencedtreeclick(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onfencedtreeclick", value);
}

/// Getter for onsnapchanged
pub fn get_onsnapchanged(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onsnapchanged");
}

/// Setter for onsnapchanged
pub fn set_onsnapchanged(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onsnapchanged", value);
}

/// Getter for onsnapchanging
pub fn get_onsnapchanging(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onsnapchanging");
}

/// Setter for onsnapchanging
pub fn set_onsnapchanging(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onsnapchanging", value);
}
