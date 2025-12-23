//! Auto-generated mixin: GlobalEventHandlers
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const GlobalEventHandlersImpl = @import("impls").GlobalEventHandlers;

// Re-export types from impl
pub const impl = @import("impls").GlobalEventHandlers;

pub fn get_onabort(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onabort(instance);
}

pub fn set_onabort(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onabort(instance, value);
}

pub fn get_onauxclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onauxclick(instance);
}

pub fn set_onauxclick(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onauxclick(instance, value);
}

pub fn get_onbeforeinput(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onbeforeinput(instance);
}

pub fn set_onbeforeinput(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onbeforeinput(instance, value);
}

pub fn get_onbeforematch(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onbeforematch(instance);
}

pub fn set_onbeforematch(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onbeforematch(instance, value);
}

pub fn get_onbeforetoggle(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onbeforetoggle(instance);
}

pub fn set_onbeforetoggle(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onbeforetoggle(instance, value);
}

pub fn get_onblur(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onblur(instance);
}

pub fn set_onblur(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onblur(instance, value);
}

pub fn get_oncancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_oncancel(instance);
}

pub fn set_oncancel(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_oncancel(instance, value);
}

pub fn get_oncanplay(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_oncanplay(instance);
}

pub fn set_oncanplay(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_oncanplay(instance, value);
}

pub fn get_oncanplaythrough(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_oncanplaythrough(instance);
}

pub fn set_oncanplaythrough(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_oncanplaythrough(instance, value);
}

pub fn get_onchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onchange(instance);
}

pub fn set_onchange(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onchange(instance, value);
}

pub fn get_onclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onclick(instance);
}

pub fn set_onclick(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onclick(instance, value);
}

pub fn get_onclose(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onclose(instance);
}

pub fn set_onclose(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onclose(instance, value);
}

pub fn get_oncommand(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_oncommand(instance);
}

pub fn set_oncommand(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_oncommand(instance, value);
}

pub fn get_oncontextlost(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_oncontextlost(instance);
}

pub fn set_oncontextlost(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_oncontextlost(instance, value);
}

pub fn get_oncontextmenu(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_oncontextmenu(instance);
}

pub fn set_oncontextmenu(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_oncontextmenu(instance, value);
}

pub fn get_oncontextrestored(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_oncontextrestored(instance);
}

pub fn set_oncontextrestored(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_oncontextrestored(instance, value);
}

pub fn get_oncopy(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_oncopy(instance);
}

pub fn set_oncopy(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_oncopy(instance, value);
}

pub fn get_oncuechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_oncuechange(instance);
}

pub fn set_oncuechange(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_oncuechange(instance, value);
}

pub fn get_oncut(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_oncut(instance);
}

pub fn set_oncut(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_oncut(instance, value);
}

pub fn get_ondblclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_ondblclick(instance);
}

pub fn set_ondblclick(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_ondblclick(instance, value);
}

pub fn get_ondrag(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_ondrag(instance);
}

pub fn set_ondrag(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_ondrag(instance, value);
}

pub fn get_ondragend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_ondragend(instance);
}

pub fn set_ondragend(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_ondragend(instance, value);
}

pub fn get_ondragenter(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_ondragenter(instance);
}

pub fn set_ondragenter(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_ondragenter(instance, value);
}

pub fn get_ondragleave(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_ondragleave(instance);
}

pub fn set_ondragleave(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_ondragleave(instance, value);
}

pub fn get_ondragover(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_ondragover(instance);
}

pub fn set_ondragover(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_ondragover(instance, value);
}

pub fn get_ondragstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_ondragstart(instance);
}

pub fn set_ondragstart(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_ondragstart(instance, value);
}

pub fn get_ondrop(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_ondrop(instance);
}

pub fn set_ondrop(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_ondrop(instance, value);
}

pub fn get_ondurationchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_ondurationchange(instance);
}

pub fn set_ondurationchange(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_ondurationchange(instance, value);
}

pub fn get_onemptied(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onemptied(instance);
}

pub fn set_onemptied(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onemptied(instance, value);
}

pub fn get_onended(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onended(instance);
}

pub fn set_onended(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onended(instance, value);
}

pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.OnErrorEventHandler {
    return GlobalEventHandlersImpl.get_onerror(instance);
}

pub fn set_onerror(instance: *runtime.Instance, value: typedefs.OnErrorEventHandler) !void {
    return GlobalEventHandlersImpl.set_onerror(instance, value);
}

pub fn get_onfocus(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onfocus(instance);
}

pub fn set_onfocus(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onfocus(instance, value);
}

pub fn get_onformdata(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onformdata(instance);
}

pub fn set_onformdata(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onformdata(instance, value);
}

pub fn get_oninput(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_oninput(instance);
}

pub fn set_oninput(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_oninput(instance, value);
}

pub fn get_oninvalid(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_oninvalid(instance);
}

pub fn set_oninvalid(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_oninvalid(instance, value);
}

pub fn get_onkeydown(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onkeydown(instance);
}

pub fn set_onkeydown(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onkeydown(instance, value);
}

pub fn get_onkeypress(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onkeypress(instance);
}

pub fn set_onkeypress(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onkeypress(instance, value);
}

pub fn get_onkeyup(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onkeyup(instance);
}

pub fn set_onkeyup(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onkeyup(instance, value);
}

pub fn get_onload(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onload(instance);
}

pub fn set_onload(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onload(instance, value);
}

pub fn get_onloadeddata(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onloadeddata(instance);
}

pub fn set_onloadeddata(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onloadeddata(instance, value);
}

pub fn get_onloadedmetadata(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onloadedmetadata(instance);
}

pub fn set_onloadedmetadata(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onloadedmetadata(instance, value);
}

pub fn get_onloadstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onloadstart(instance);
}

pub fn set_onloadstart(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onloadstart(instance, value);
}

pub fn get_onmousedown(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onmousedown(instance);
}

pub fn set_onmousedown(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onmousedown(instance, value);
}

pub fn get_onmouseenter(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onmouseenter(instance);
}

pub fn set_onmouseenter(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onmouseenter(instance, value);
}

pub fn get_onmouseleave(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onmouseleave(instance);
}

pub fn set_onmouseleave(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onmouseleave(instance, value);
}

pub fn get_onmousemove(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onmousemove(instance);
}

pub fn set_onmousemove(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onmousemove(instance, value);
}

pub fn get_onmouseout(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onmouseout(instance);
}

pub fn set_onmouseout(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onmouseout(instance, value);
}

pub fn get_onmouseover(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onmouseover(instance);
}

pub fn set_onmouseover(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onmouseover(instance, value);
}

pub fn get_onmouseup(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onmouseup(instance);
}

pub fn set_onmouseup(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onmouseup(instance, value);
}

pub fn get_onpaste(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onpaste(instance);
}

pub fn set_onpaste(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onpaste(instance, value);
}

pub fn get_onpause(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onpause(instance);
}

pub fn set_onpause(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onpause(instance, value);
}

pub fn get_onplay(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onplay(instance);
}

pub fn set_onplay(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onplay(instance, value);
}

pub fn get_onplaying(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onplaying(instance);
}

pub fn set_onplaying(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onplaying(instance, value);
}

pub fn get_onprogress(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onprogress(instance);
}

pub fn set_onprogress(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onprogress(instance, value);
}

pub fn get_onratechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onratechange(instance);
}

pub fn set_onratechange(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onratechange(instance, value);
}

pub fn get_onreset(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onreset(instance);
}

pub fn set_onreset(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onreset(instance, value);
}

pub fn get_onresize(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onresize(instance);
}

pub fn set_onresize(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onresize(instance, value);
}

pub fn get_onscroll(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onscroll(instance);
}

pub fn set_onscroll(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onscroll(instance, value);
}

pub fn get_onscrollend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onscrollend(instance);
}

pub fn set_onscrollend(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onscrollend(instance, value);
}

pub fn get_onsecuritypolicyviolation(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onsecuritypolicyviolation(instance);
}

pub fn set_onsecuritypolicyviolation(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onsecuritypolicyviolation(instance, value);
}

pub fn get_onseeked(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onseeked(instance);
}

pub fn set_onseeked(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onseeked(instance, value);
}

pub fn get_onseeking(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onseeking(instance);
}

pub fn set_onseeking(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onseeking(instance, value);
}

pub fn get_onselect(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onselect(instance);
}

pub fn set_onselect(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onselect(instance, value);
}

pub fn get_onslotchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onslotchange(instance);
}

pub fn set_onslotchange(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onslotchange(instance, value);
}

pub fn get_onstalled(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onstalled(instance);
}

pub fn set_onstalled(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onstalled(instance, value);
}

pub fn get_onsubmit(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onsubmit(instance);
}

pub fn set_onsubmit(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onsubmit(instance, value);
}

pub fn get_onsuspend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onsuspend(instance);
}

pub fn set_onsuspend(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onsuspend(instance, value);
}

pub fn get_ontimeupdate(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_ontimeupdate(instance);
}

pub fn set_ontimeupdate(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_ontimeupdate(instance, value);
}

pub fn get_ontoggle(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_ontoggle(instance);
}

pub fn set_ontoggle(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_ontoggle(instance, value);
}

pub fn get_onvolumechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onvolumechange(instance);
}

pub fn set_onvolumechange(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onvolumechange(instance, value);
}

pub fn get_onwaiting(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onwaiting(instance);
}

pub fn set_onwaiting(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onwaiting(instance, value);
}

pub fn get_onwebkitanimationend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onwebkitanimationend(instance);
}

pub fn set_onwebkitanimationend(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onwebkitanimationend(instance, value);
}

pub fn get_onwebkitanimationiteration(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onwebkitanimationiteration(instance);
}

pub fn set_onwebkitanimationiteration(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onwebkitanimationiteration(instance, value);
}

pub fn get_onwebkitanimationstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onwebkitanimationstart(instance);
}

pub fn set_onwebkitanimationstart(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onwebkitanimationstart(instance, value);
}

pub fn get_onwebkittransitionend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onwebkittransitionend(instance);
}

pub fn set_onwebkittransitionend(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onwebkittransitionend(instance, value);
}

pub fn get_onwheel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onwheel(instance);
}

pub fn set_onwheel(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onwheel(instance, value);
}

pub fn get_onselectstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onselectstart(instance);
}

pub fn set_onselectstart(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onselectstart(instance, value);
}

pub fn get_onselectionchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onselectionchange(instance);
}

pub fn set_onselectionchange(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onselectionchange(instance, value);
}

pub fn get_onanimationstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onanimationstart(instance);
}

pub fn set_onanimationstart(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onanimationstart(instance, value);
}

pub fn get_onanimationiteration(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onanimationiteration(instance);
}

pub fn set_onanimationiteration(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onanimationiteration(instance, value);
}

pub fn get_onanimationend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onanimationend(instance);
}

pub fn set_onanimationend(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onanimationend(instance, value);
}

pub fn get_onanimationcancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onanimationcancel(instance);
}

pub fn set_onanimationcancel(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onanimationcancel(instance, value);
}

pub fn get_ontransitionrun(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_ontransitionrun(instance);
}

pub fn set_ontransitionrun(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_ontransitionrun(instance, value);
}

pub fn get_ontransitionstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_ontransitionstart(instance);
}

pub fn set_ontransitionstart(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_ontransitionstart(instance, value);
}

pub fn get_ontransitionend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_ontransitionend(instance);
}

pub fn set_ontransitionend(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_ontransitionend(instance, value);
}

pub fn get_ontransitioncancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_ontransitioncancel(instance);
}

pub fn set_ontransitioncancel(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_ontransitioncancel(instance, value);
}

pub fn get_onbeforexrselect(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onbeforexrselect(instance);
}

pub fn set_onbeforexrselect(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onbeforexrselect(instance, value);
}

pub fn get_onpointerover(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onpointerover(instance);
}

pub fn set_onpointerover(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onpointerover(instance, value);
}

pub fn get_onpointerenter(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onpointerenter(instance);
}

pub fn set_onpointerenter(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onpointerenter(instance, value);
}

pub fn get_onpointerdown(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onpointerdown(instance);
}

pub fn set_onpointerdown(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onpointerdown(instance, value);
}

pub fn get_onpointermove(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onpointermove(instance);
}

pub fn set_onpointermove(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onpointermove(instance, value);
}

pub fn get_onpointerrawupdate(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onpointerrawupdate(instance);
}

pub fn set_onpointerrawupdate(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onpointerrawupdate(instance, value);
}

pub fn get_onpointerup(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onpointerup(instance);
}

pub fn set_onpointerup(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onpointerup(instance, value);
}

pub fn get_onpointercancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onpointercancel(instance);
}

pub fn set_onpointercancel(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onpointercancel(instance, value);
}

pub fn get_onpointerout(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onpointerout(instance);
}

pub fn set_onpointerout(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onpointerout(instance, value);
}

pub fn get_onpointerleave(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onpointerleave(instance);
}

pub fn set_onpointerleave(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onpointerleave(instance, value);
}

pub fn get_ongotpointercapture(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_ongotpointercapture(instance);
}

pub fn set_ongotpointercapture(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_ongotpointercapture(instance, value);
}

pub fn get_onlostpointercapture(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onlostpointercapture(instance);
}

pub fn set_onlostpointercapture(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onlostpointercapture(instance, value);
}

pub fn get_ontouchstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_ontouchstart(instance);
}

pub fn set_ontouchstart(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_ontouchstart(instance, value);
}

pub fn get_ontouchend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_ontouchend(instance);
}

pub fn set_ontouchend(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_ontouchend(instance, value);
}

pub fn get_ontouchmove(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_ontouchmove(instance);
}

pub fn set_ontouchmove(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_ontouchmove(instance, value);
}

pub fn get_ontouchcancel(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_ontouchcancel(instance);
}

pub fn set_ontouchcancel(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_ontouchcancel(instance, value);
}

pub fn get_onfencedtreeclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onfencedtreeclick(instance);
}

pub fn set_onfencedtreeclick(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onfencedtreeclick(instance, value);
}

pub fn get_onsnapchanged(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onsnapchanged(instance);
}

pub fn set_onsnapchanged(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onsnapchanged(instance, value);
}

pub fn get_onsnapchanging(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return GlobalEventHandlersImpl.get_onsnapchanging(instance);
}

pub fn set_onsnapchanging(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return GlobalEventHandlersImpl.set_onsnapchanging(instance, value);
}

