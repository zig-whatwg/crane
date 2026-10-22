//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GlobalEventHandlersImpl = @import("impls").GlobalEventHandlers;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const EventHandler = @import("typedefs").EventHandler;

pub const GlobalEventHandlers = struct {
    pub const Meta = struct {
        pub const name = "GlobalEventHandlers";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onabort", "get_onabort", "set_onabort" },
            .{ "onauxclick", "get_onauxclick", "set_onauxclick" },
            .{ "onbeforeinput", "get_onbeforeinput", "set_onbeforeinput" },
            .{ "onbeforematch", "get_onbeforematch", "set_onbeforematch" },
            .{ "onbeforetoggle", "get_onbeforetoggle", "set_onbeforetoggle" },
            .{ "onblur", "get_onblur", "set_onblur" },
            .{ "oncancel", "get_oncancel", "set_oncancel" },
            .{ "oncanplay", "get_oncanplay", "set_oncanplay" },
            .{ "oncanplaythrough", "get_oncanplaythrough", "set_oncanplaythrough" },
            .{ "onchange", "get_onchange", "set_onchange" },
            .{ "onclick", "get_onclick", "set_onclick" },
            .{ "onclose", "get_onclose", "set_onclose" },
            .{ "oncommand", "get_oncommand", "set_oncommand" },
            .{ "oncontextlost", "get_oncontextlost", "set_oncontextlost" },
            .{ "oncontextmenu", "get_oncontextmenu", "set_oncontextmenu" },
            .{ "oncontextrestored", "get_oncontextrestored", "set_oncontextrestored" },
            .{ "oncopy", "get_oncopy", "set_oncopy" },
            .{ "oncuechange", "get_oncuechange", "set_oncuechange" },
            .{ "oncut", "get_oncut", "set_oncut" },
            .{ "ondblclick", "get_ondblclick", "set_ondblclick" },
            .{ "ondrag", "get_ondrag", "set_ondrag" },
            .{ "ondragend", "get_ondragend", "set_ondragend" },
            .{ "ondragenter", "get_ondragenter", "set_ondragenter" },
            .{ "ondragleave", "get_ondragleave", "set_ondragleave" },
            .{ "ondragover", "get_ondragover", "set_ondragover" },
            .{ "ondragstart", "get_ondragstart", "set_ondragstart" },
            .{ "ondrop", "get_ondrop", "set_ondrop" },
            .{ "ondurationchange", "get_ondurationchange", "set_ondurationchange" },
            .{ "onemptied", "get_onemptied", "set_onemptied" },
            .{ "onended", "get_onended", "set_onended" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onfocus", "get_onfocus", "set_onfocus" },
            .{ "onformdata", "get_onformdata", "set_onformdata" },
            .{ "oninput", "get_oninput", "set_oninput" },
            .{ "oninvalid", "get_oninvalid", "set_oninvalid" },
            .{ "onkeydown", "get_onkeydown", "set_onkeydown" },
            .{ "onkeypress", "get_onkeypress", "set_onkeypress" },
            .{ "onkeyup", "get_onkeyup", "set_onkeyup" },
            .{ "onload", "get_onload", "set_onload" },
            .{ "onloadeddata", "get_onloadeddata", "set_onloadeddata" },
            .{ "onloadedmetadata", "get_onloadedmetadata", "set_onloadedmetadata" },
            .{ "onloadstart", "get_onloadstart", "set_onloadstart" },
            .{ "onmousedown", "get_onmousedown", "set_onmousedown" },
            .{ "onmouseenter", "get_onmouseenter", "set_onmouseenter" },
            .{ "onmouseleave", "get_onmouseleave", "set_onmouseleave" },
            .{ "onmousemove", "get_onmousemove", "set_onmousemove" },
            .{ "onmouseout", "get_onmouseout", "set_onmouseout" },
            .{ "onmouseover", "get_onmouseover", "set_onmouseover" },
            .{ "onmouseup", "get_onmouseup", "set_onmouseup" },
            .{ "onpaste", "get_onpaste", "set_onpaste" },
            .{ "onpause", "get_onpause", "set_onpause" },
            .{ "onplay", "get_onplay", "set_onplay" },
            .{ "onplaying", "get_onplaying", "set_onplaying" },
            .{ "onprogress", "get_onprogress", "set_onprogress" },
            .{ "onratechange", "get_onratechange", "set_onratechange" },
            .{ "onreset", "get_onreset", "set_onreset" },
            .{ "onresize", "get_onresize", "set_onresize" },
            .{ "onscroll", "get_onscroll", "set_onscroll" },
            .{ "onscrollend", "get_onscrollend", "set_onscrollend" },
            .{ "onsecuritypolicyviolation", "get_onsecuritypolicyviolation", "set_onsecuritypolicyviolation" },
            .{ "onseeked", "get_onseeked", "set_onseeked" },
            .{ "onseeking", "get_onseeking", "set_onseeking" },
            .{ "onselect", "get_onselect", "set_onselect" },
            .{ "onslotchange", "get_onslotchange", "set_onslotchange" },
            .{ "onstalled", "get_onstalled", "set_onstalled" },
            .{ "onsubmit", "get_onsubmit", "set_onsubmit" },
            .{ "onsuspend", "get_onsuspend", "set_onsuspend" },
            .{ "ontimeupdate", "get_ontimeupdate", "set_ontimeupdate" },
            .{ "ontoggle", "get_ontoggle", "set_ontoggle" },
            .{ "onvolumechange", "get_onvolumechange", "set_onvolumechange" },
            .{ "onwaiting", "get_onwaiting", "set_onwaiting" },
            .{ "onwebkitanimationend", "get_onwebkitanimationend", "set_onwebkitanimationend" },
            .{ "onwebkitanimationiteration", "get_onwebkitanimationiteration", "set_onwebkitanimationiteration" },
            .{ "onwebkitanimationstart", "get_onwebkitanimationstart", "set_onwebkitanimationstart" },
            .{ "onwebkittransitionend", "get_onwebkittransitionend", "set_onwebkittransitionend" },
            .{ "onwheel", "get_onwheel", "set_onwheel" },
            .{ "onanimationstart", "get_onanimationstart", "set_onanimationstart" },
            .{ "onanimationiteration", "get_onanimationiteration", "set_onanimationiteration" },
            .{ "onanimationend", "get_onanimationend", "set_onanimationend" },
            .{ "onanimationcancel", "get_onanimationcancel", "set_onanimationcancel" },
            .{ "onsnapchanged", "get_onsnapchanged", "set_onsnapchanged" },
            .{ "onsnapchanging", "get_onsnapchanging", "set_onsnapchanging" },
            .{ "ontransitionrun", "get_ontransitionrun", "set_ontransitionrun" },
            .{ "ontransitionstart", "get_ontransitionstart", "set_ontransitionstart" },
            .{ "ontransitionend", "get_ontransitionend", "set_ontransitionend" },
            .{ "ontransitioncancel", "get_ontransitioncancel", "set_ontransitioncancel" },
            .{ "onfencedtreeclick", "get_onfencedtreeclick", "set_onfencedtreeclick" },
            .{ "onpointerover", "get_onpointerover", "set_onpointerover" },
            .{ "onpointerenter", "get_onpointerenter", "set_onpointerenter" },
            .{ "onpointerdown", "get_onpointerdown", "set_onpointerdown" },
            .{ "onpointermove", "get_onpointermove", "set_onpointermove" },
            .{ "onpointerrawupdate", "get_onpointerrawupdate", "set_onpointerrawupdate" },
            .{ "onpointerup", "get_onpointerup", "set_onpointerup" },
            .{ "onpointercancel", "get_onpointercancel", "set_onpointercancel" },
            .{ "onpointerout", "get_onpointerout", "set_onpointerout" },
            .{ "onpointerleave", "get_onpointerleave", "set_onpointerleave" },
            .{ "ongotpointercapture", "get_ongotpointercapture", "set_ongotpointercapture" },
            .{ "onlostpointercapture", "get_onlostpointercapture", "set_onlostpointercapture" },
            .{ "onselectstart", "get_onselectstart", "set_onselectstart" },
            .{ "onselectionchange", "get_onselectionchange", "set_onselectionchange" },
            .{ "ontouchstart", "get_ontouchstart", "set_ontouchstart" },
            .{ "ontouchend", "get_ontouchend", "set_ontouchend" },
            .{ "ontouchmove", "get_ontouchmove", "set_ontouchmove" },
            .{ "ontouchcancel", "get_ontouchcancel", "set_ontouchcancel" },
            .{ "onbeforexrselect", "get_onbeforexrselect", "set_onbeforexrselect" },
        };

        /// [LegacyLenientThis] attributes: do NOT throw TypeError on invalid this
        /// Getters return undefined, setters silently return
        pub const lenient_this_attributes = .{
            "onmouseenter",
            "onmouseleave",
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "onabort", "get_onabort", "set_onabort" },
            .{ "onauxclick", "get_onauxclick", "set_onauxclick" },
            .{ "onbeforeinput", "get_onbeforeinput", "set_onbeforeinput" },
            .{ "onbeforematch", "get_onbeforematch", "set_onbeforematch" },
            .{ "onbeforetoggle", "get_onbeforetoggle", "set_onbeforetoggle" },
            .{ "onblur", "get_onblur", "set_onblur" },
            .{ "oncancel", "get_oncancel", "set_oncancel" },
            .{ "oncanplay", "get_oncanplay", "set_oncanplay" },
            .{ "oncanplaythrough", "get_oncanplaythrough", "set_oncanplaythrough" },
            .{ "onchange", "get_onchange", "set_onchange" },
            .{ "onclick", "get_onclick", "set_onclick" },
            .{ "onclose", "get_onclose", "set_onclose" },
            .{ "oncommand", "get_oncommand", "set_oncommand" },
            .{ "oncontextlost", "get_oncontextlost", "set_oncontextlost" },
            .{ "oncontextmenu", "get_oncontextmenu", "set_oncontextmenu" },
            .{ "oncontextrestored", "get_oncontextrestored", "set_oncontextrestored" },
            .{ "oncopy", "get_oncopy", "set_oncopy" },
            .{ "oncuechange", "get_oncuechange", "set_oncuechange" },
            .{ "oncut", "get_oncut", "set_oncut" },
            .{ "ondblclick", "get_ondblclick", "set_ondblclick" },
            .{ "ondrag", "get_ondrag", "set_ondrag" },
            .{ "ondragend", "get_ondragend", "set_ondragend" },
            .{ "ondragenter", "get_ondragenter", "set_ondragenter" },
            .{ "ondragleave", "get_ondragleave", "set_ondragleave" },
            .{ "ondragover", "get_ondragover", "set_ondragover" },
            .{ "ondragstart", "get_ondragstart", "set_ondragstart" },
            .{ "ondrop", "get_ondrop", "set_ondrop" },
            .{ "ondurationchange", "get_ondurationchange", "set_ondurationchange" },
            .{ "onemptied", "get_onemptied", "set_onemptied" },
            .{ "onended", "get_onended", "set_onended" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onfocus", "get_onfocus", "set_onfocus" },
            .{ "onformdata", "get_onformdata", "set_onformdata" },
            .{ "oninput", "get_oninput", "set_oninput" },
            .{ "oninvalid", "get_oninvalid", "set_oninvalid" },
            .{ "onkeydown", "get_onkeydown", "set_onkeydown" },
            .{ "onkeypress", "get_onkeypress", "set_onkeypress" },
            .{ "onkeyup", "get_onkeyup", "set_onkeyup" },
            .{ "onload", "get_onload", "set_onload" },
            .{ "onloadeddata", "get_onloadeddata", "set_onloadeddata" },
            .{ "onloadedmetadata", "get_onloadedmetadata", "set_onloadedmetadata" },
            .{ "onloadstart", "get_onloadstart", "set_onloadstart" },
            .{ "onmousedown", "get_onmousedown", "set_onmousedown" },
            .{ "onmouseenter", "get_onmouseenter", "set_onmouseenter" },
            .{ "onmouseleave", "get_onmouseleave", "set_onmouseleave" },
            .{ "onmousemove", "get_onmousemove", "set_onmousemove" },
            .{ "onmouseout", "get_onmouseout", "set_onmouseout" },
            .{ "onmouseover", "get_onmouseover", "set_onmouseover" },
            .{ "onmouseup", "get_onmouseup", "set_onmouseup" },
            .{ "onpaste", "get_onpaste", "set_onpaste" },
            .{ "onpause", "get_onpause", "set_onpause" },
            .{ "onplay", "get_onplay", "set_onplay" },
            .{ "onplaying", "get_onplaying", "set_onplaying" },
            .{ "onprogress", "get_onprogress", "set_onprogress" },
            .{ "onratechange", "get_onratechange", "set_onratechange" },
            .{ "onreset", "get_onreset", "set_onreset" },
            .{ "onresize", "get_onresize", "set_onresize" },
            .{ "onscroll", "get_onscroll", "set_onscroll" },
            .{ "onscrollend", "get_onscrollend", "set_onscrollend" },
            .{ "onsecuritypolicyviolation", "get_onsecuritypolicyviolation", "set_onsecuritypolicyviolation" },
            .{ "onseeked", "get_onseeked", "set_onseeked" },
            .{ "onseeking", "get_onseeking", "set_onseeking" },
            .{ "onselect", "get_onselect", "set_onselect" },
            .{ "onslotchange", "get_onslotchange", "set_onslotchange" },
            .{ "onstalled", "get_onstalled", "set_onstalled" },
            .{ "onsubmit", "get_onsubmit", "set_onsubmit" },
            .{ "onsuspend", "get_onsuspend", "set_onsuspend" },
            .{ "ontimeupdate", "get_ontimeupdate", "set_ontimeupdate" },
            .{ "ontoggle", "get_ontoggle", "set_ontoggle" },
            .{ "onvolumechange", "get_onvolumechange", "set_onvolumechange" },
            .{ "onwaiting", "get_onwaiting", "set_onwaiting" },
            .{ "onwebkitanimationend", "get_onwebkitanimationend", "set_onwebkitanimationend" },
            .{ "onwebkitanimationiteration", "get_onwebkitanimationiteration", "set_onwebkitanimationiteration" },
            .{ "onwebkitanimationstart", "get_onwebkitanimationstart", "set_onwebkitanimationstart" },
            .{ "onwebkittransitionend", "get_onwebkittransitionend", "set_onwebkittransitionend" },
            .{ "onwheel", "get_onwheel", "set_onwheel" },
            .{ "onanimationstart", "get_onanimationstart", "set_onanimationstart" },
            .{ "onanimationiteration", "get_onanimationiteration", "set_onanimationiteration" },
            .{ "onanimationend", "get_onanimationend", "set_onanimationend" },
            .{ "onanimationcancel", "get_onanimationcancel", "set_onanimationcancel" },
            .{ "onsnapchanged", "get_onsnapchanged", "set_onsnapchanged" },
            .{ "onsnapchanging", "get_onsnapchanging", "set_onsnapchanging" },
            .{ "ontransitionrun", "get_ontransitionrun", "set_ontransitionrun" },
            .{ "ontransitionstart", "get_ontransitionstart", "set_ontransitionstart" },
            .{ "ontransitionend", "get_ontransitionend", "set_ontransitionend" },
            .{ "ontransitioncancel", "get_ontransitioncancel", "set_ontransitioncancel" },
            .{ "onfencedtreeclick", "get_onfencedtreeclick", "set_onfencedtreeclick" },
            .{ "onpointerover", "get_onpointerover", "set_onpointerover" },
            .{ "onpointerenter", "get_onpointerenter", "set_onpointerenter" },
            .{ "onpointerdown", "get_onpointerdown", "set_onpointerdown" },
            .{ "onpointermove", "get_onpointermove", "set_onpointermove" },
            .{ "onpointerrawupdate", "get_onpointerrawupdate", "set_onpointerrawupdate" },
            .{ "onpointerup", "get_onpointerup", "set_onpointerup" },
            .{ "onpointercancel", "get_onpointercancel", "set_onpointercancel" },
            .{ "onpointerout", "get_onpointerout", "set_onpointerout" },
            .{ "onpointerleave", "get_onpointerleave", "set_onpointerleave" },
            .{ "ongotpointercapture", "get_ongotpointercapture", "set_ongotpointercapture" },
            .{ "onlostpointercapture", "get_onlostpointercapture", "set_onlostpointercapture" },
            .{ "onselectstart", "get_onselectstart", "set_onselectstart" },
            .{ "onselectionchange", "get_onselectionchange", "set_onselectionchange" },
            .{ "ontouchstart", "get_ontouchstart", "set_ontouchstart" },
            .{ "ontouchend", "get_ontouchend", "set_ontouchend" },
            .{ "ontouchmove", "get_ontouchmove", "set_ontouchmove" },
            .{ "ontouchcancel", "get_ontouchcancel", "set_ontouchcancel" },
            .{ "onbeforexrselect", "get_onbeforexrselect", "set_onbeforexrselect" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// [SecureContext] members - their own, their partial interface's or
        /// their mixin's: hidden in a realm that is not a secure context
        /// (WebIDL 3.3.13).
        pub const secure_context_members = .{
            "onpointerrawupdate",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onabort: typedefs.EventHandler = undefined,
            onauxclick: typedefs.EventHandler = undefined,
            onbeforeinput: typedefs.EventHandler = undefined,
            onbeforematch: typedefs.EventHandler = undefined,
            onbeforetoggle: typedefs.EventHandler = undefined,
            onblur: typedefs.EventHandler = undefined,
            oncancel: typedefs.EventHandler = undefined,
            oncanplay: typedefs.EventHandler = undefined,
            oncanplaythrough: typedefs.EventHandler = undefined,
            onchange: typedefs.EventHandler = undefined,
            onclick: typedefs.EventHandler = undefined,
            onclose: typedefs.EventHandler = undefined,
            oncommand: typedefs.EventHandler = undefined,
            oncontextlost: typedefs.EventHandler = undefined,
            oncontextmenu: typedefs.EventHandler = undefined,
            oncontextrestored: typedefs.EventHandler = undefined,
            oncopy: typedefs.EventHandler = undefined,
            oncuechange: typedefs.EventHandler = undefined,
            oncut: typedefs.EventHandler = undefined,
            ondblclick: typedefs.EventHandler = undefined,
            ondrag: typedefs.EventHandler = undefined,
            ondragend: typedefs.EventHandler = undefined,
            ondragenter: typedefs.EventHandler = undefined,
            ondragleave: typedefs.EventHandler = undefined,
            ondragover: typedefs.EventHandler = undefined,
            ondragstart: typedefs.EventHandler = undefined,
            ondrop: typedefs.EventHandler = undefined,
            ondurationchange: typedefs.EventHandler = undefined,
            onemptied: typedefs.EventHandler = undefined,
            onended: typedefs.EventHandler = undefined,
            onerror: typedefs.OnErrorEventHandler = undefined,
            onfocus: typedefs.EventHandler = undefined,
            onformdata: typedefs.EventHandler = undefined,
            oninput: typedefs.EventHandler = undefined,
            oninvalid: typedefs.EventHandler = undefined,
            onkeydown: typedefs.EventHandler = undefined,
            onkeypress: typedefs.EventHandler = undefined,
            onkeyup: typedefs.EventHandler = undefined,
            onload: typedefs.EventHandler = undefined,
            onloadeddata: typedefs.EventHandler = undefined,
            onloadedmetadata: typedefs.EventHandler = undefined,
            onloadstart: typedefs.EventHandler = undefined,
            onmousedown: typedefs.EventHandler = undefined,
            onmouseenter: typedefs.EventHandler = undefined,
            onmouseleave: typedefs.EventHandler = undefined,
            onmousemove: typedefs.EventHandler = undefined,
            onmouseout: typedefs.EventHandler = undefined,
            onmouseover: typedefs.EventHandler = undefined,
            onmouseup: typedefs.EventHandler = undefined,
            onpaste: typedefs.EventHandler = undefined,
            onpause: typedefs.EventHandler = undefined,
            onplay: typedefs.EventHandler = undefined,
            onplaying: typedefs.EventHandler = undefined,
            onprogress: typedefs.EventHandler = undefined,
            onratechange: typedefs.EventHandler = undefined,
            onreset: typedefs.EventHandler = undefined,
            onresize: typedefs.EventHandler = undefined,
            onscroll: typedefs.EventHandler = undefined,
            onscrollend: typedefs.EventHandler = undefined,
            onsecuritypolicyviolation: typedefs.EventHandler = undefined,
            onseeked: typedefs.EventHandler = undefined,
            onseeking: typedefs.EventHandler = undefined,
            onselect: typedefs.EventHandler = undefined,
            onslotchange: typedefs.EventHandler = undefined,
            onstalled: typedefs.EventHandler = undefined,
            onsubmit: typedefs.EventHandler = undefined,
            onsuspend: typedefs.EventHandler = undefined,
            ontimeupdate: typedefs.EventHandler = undefined,
            ontoggle: typedefs.EventHandler = undefined,
            onvolumechange: typedefs.EventHandler = undefined,
            onwaiting: typedefs.EventHandler = undefined,
            onwebkitanimationend: typedefs.EventHandler = undefined,
            onwebkitanimationiteration: typedefs.EventHandler = undefined,
            onwebkitanimationstart: typedefs.EventHandler = undefined,
            onwebkittransitionend: typedefs.EventHandler = undefined,
            onwheel: typedefs.EventHandler = undefined,
            onanimationstart: typedefs.EventHandler = undefined,
            onanimationiteration: typedefs.EventHandler = undefined,
            onanimationend: typedefs.EventHandler = undefined,
            onanimationcancel: typedefs.EventHandler = undefined,
            onsnapchanged: typedefs.EventHandler = undefined,
            onsnapchanging: typedefs.EventHandler = undefined,
            ontransitionrun: typedefs.EventHandler = undefined,
            ontransitionstart: typedefs.EventHandler = undefined,
            ontransitionend: typedefs.EventHandler = undefined,
            ontransitioncancel: typedefs.EventHandler = undefined,
            onfencedtreeclick: typedefs.EventHandler = undefined,
            onpointerover: typedefs.EventHandler = undefined,
            onpointerenter: typedefs.EventHandler = undefined,
            onpointerdown: typedefs.EventHandler = undefined,
            onpointermove: typedefs.EventHandler = undefined,
            onpointerrawupdate: typedefs.EventHandler = undefined,
            onpointerup: typedefs.EventHandler = undefined,
            onpointercancel: typedefs.EventHandler = undefined,
            onpointerout: typedefs.EventHandler = undefined,
            onpointerleave: typedefs.EventHandler = undefined,
            ongotpointercapture: typedefs.EventHandler = undefined,
            onlostpointercapture: typedefs.EventHandler = undefined,
            onselectstart: typedefs.EventHandler = undefined,
            onselectionchange: typedefs.EventHandler = undefined,
            ontouchstart: typedefs.EventHandler = undefined,
            ontouchend: typedefs.EventHandler = undefined,
            ontouchmove: typedefs.EventHandler = undefined,
            ontouchcancel: typedefs.EventHandler = undefined,
            onbeforexrselect: typedefs.EventHandler = undefined,
            _internal: ?*GlobalEventHandlersImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "GlobalEventHandlers")) {
            if (comptime @hasDecl(impls.GlobalEventHandlers, "installHooks")) impls.GlobalEventHandlers.installHooks();
        }
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onabort(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onabort")) return try GlobalEventHandlersImpl.get_onabort(instance);
        return event_handlers.value(EventHandler, instance, "onabort");
    }

    pub fn set_onabort(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onabort")) return try GlobalEventHandlersImpl.set_onabort(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onabort", value);
    }

    pub fn get_onauxclick(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onauxclick")) return try GlobalEventHandlersImpl.get_onauxclick(instance);
        return event_handlers.value(EventHandler, instance, "onauxclick");
    }

    pub fn set_onauxclick(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onauxclick")) return try GlobalEventHandlersImpl.set_onauxclick(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onauxclick", value);
    }

    pub fn get_onbeforeinput(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onbeforeinput")) return try GlobalEventHandlersImpl.get_onbeforeinput(instance);
        return event_handlers.value(EventHandler, instance, "onbeforeinput");
    }

    pub fn set_onbeforeinput(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onbeforeinput")) return try GlobalEventHandlersImpl.set_onbeforeinput(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onbeforeinput", value);
    }

    pub fn get_onbeforematch(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onbeforematch")) return try GlobalEventHandlersImpl.get_onbeforematch(instance);
        return event_handlers.value(EventHandler, instance, "onbeforematch");
    }

    pub fn set_onbeforematch(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onbeforematch")) return try GlobalEventHandlersImpl.set_onbeforematch(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onbeforematch", value);
    }

    pub fn get_onbeforetoggle(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onbeforetoggle")) return try GlobalEventHandlersImpl.get_onbeforetoggle(instance);
        return event_handlers.value(EventHandler, instance, "onbeforetoggle");
    }

    pub fn set_onbeforetoggle(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onbeforetoggle")) return try GlobalEventHandlersImpl.set_onbeforetoggle(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onbeforetoggle", value);
    }

    pub fn get_onblur(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onblur")) return try GlobalEventHandlersImpl.get_onblur(instance);
        return event_handlers.value(EventHandler, instance, "onblur");
    }

    pub fn set_onblur(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onblur")) return try GlobalEventHandlersImpl.set_onblur(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onblur", value);
    }

    pub fn get_oncancel(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_oncancel")) return try GlobalEventHandlersImpl.get_oncancel(instance);
        return event_handlers.value(EventHandler, instance, "oncancel");
    }

    pub fn set_oncancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_oncancel")) return try GlobalEventHandlersImpl.set_oncancel(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncancel", value);
    }

    pub fn get_oncanplay(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_oncanplay")) return try GlobalEventHandlersImpl.get_oncanplay(instance);
        return event_handlers.value(EventHandler, instance, "oncanplay");
    }

    pub fn set_oncanplay(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_oncanplay")) return try GlobalEventHandlersImpl.set_oncanplay(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncanplay", value);
    }

    pub fn get_oncanplaythrough(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_oncanplaythrough")) return try GlobalEventHandlersImpl.get_oncanplaythrough(instance);
        return event_handlers.value(EventHandler, instance, "oncanplaythrough");
    }

    pub fn set_oncanplaythrough(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_oncanplaythrough")) return try GlobalEventHandlersImpl.set_oncanplaythrough(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncanplaythrough", value);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onchange")) return try GlobalEventHandlersImpl.get_onchange(instance);
        return event_handlers.value(EventHandler, instance, "onchange");
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onchange")) return try GlobalEventHandlersImpl.set_onchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onchange", value);
    }

    pub fn get_onclick(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onclick")) return try GlobalEventHandlersImpl.get_onclick(instance);
        return event_handlers.value(EventHandler, instance, "onclick");
    }

    pub fn set_onclick(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onclick")) return try GlobalEventHandlersImpl.set_onclick(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onclick", value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onclose")) return try GlobalEventHandlersImpl.get_onclose(instance);
        return event_handlers.value(EventHandler, instance, "onclose");
    }

    pub fn set_onclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onclose")) return try GlobalEventHandlersImpl.set_onclose(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onclose", value);
    }

    pub fn get_oncommand(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_oncommand")) return try GlobalEventHandlersImpl.get_oncommand(instance);
        return event_handlers.value(EventHandler, instance, "oncommand");
    }

    pub fn set_oncommand(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_oncommand")) return try GlobalEventHandlersImpl.set_oncommand(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncommand", value);
    }

    pub fn get_oncontextlost(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_oncontextlost")) return try GlobalEventHandlersImpl.get_oncontextlost(instance);
        return event_handlers.value(EventHandler, instance, "oncontextlost");
    }

    pub fn set_oncontextlost(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_oncontextlost")) return try GlobalEventHandlersImpl.set_oncontextlost(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncontextlost", value);
    }

    pub fn get_oncontextmenu(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_oncontextmenu")) return try GlobalEventHandlersImpl.get_oncontextmenu(instance);
        return event_handlers.value(EventHandler, instance, "oncontextmenu");
    }

    pub fn set_oncontextmenu(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_oncontextmenu")) return try GlobalEventHandlersImpl.set_oncontextmenu(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncontextmenu", value);
    }

    pub fn get_oncontextrestored(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_oncontextrestored")) return try GlobalEventHandlersImpl.get_oncontextrestored(instance);
        return event_handlers.value(EventHandler, instance, "oncontextrestored");
    }

    pub fn set_oncontextrestored(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_oncontextrestored")) return try GlobalEventHandlersImpl.set_oncontextrestored(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncontextrestored", value);
    }

    pub fn get_oncopy(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_oncopy")) return try GlobalEventHandlersImpl.get_oncopy(instance);
        return event_handlers.value(EventHandler, instance, "oncopy");
    }

    pub fn set_oncopy(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_oncopy")) return try GlobalEventHandlersImpl.set_oncopy(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncopy", value);
    }

    pub fn get_oncuechange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_oncuechange")) return try GlobalEventHandlersImpl.get_oncuechange(instance);
        return event_handlers.value(EventHandler, instance, "oncuechange");
    }

    pub fn set_oncuechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_oncuechange")) return try GlobalEventHandlersImpl.set_oncuechange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncuechange", value);
    }

    pub fn get_oncut(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_oncut")) return try GlobalEventHandlersImpl.get_oncut(instance);
        return event_handlers.value(EventHandler, instance, "oncut");
    }

    pub fn set_oncut(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_oncut")) return try GlobalEventHandlersImpl.set_oncut(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncut", value);
    }

    pub fn get_ondblclick(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_ondblclick")) return try GlobalEventHandlersImpl.get_ondblclick(instance);
        return event_handlers.value(EventHandler, instance, "ondblclick");
    }

    pub fn set_ondblclick(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_ondblclick")) return try GlobalEventHandlersImpl.set_ondblclick(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ondblclick", value);
    }

    pub fn get_ondrag(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_ondrag")) return try GlobalEventHandlersImpl.get_ondrag(instance);
        return event_handlers.value(EventHandler, instance, "ondrag");
    }

    pub fn set_ondrag(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_ondrag")) return try GlobalEventHandlersImpl.set_ondrag(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ondrag", value);
    }

    pub fn get_ondragend(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_ondragend")) return try GlobalEventHandlersImpl.get_ondragend(instance);
        return event_handlers.value(EventHandler, instance, "ondragend");
    }

    pub fn set_ondragend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_ondragend")) return try GlobalEventHandlersImpl.set_ondragend(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ondragend", value);
    }

    pub fn get_ondragenter(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_ondragenter")) return try GlobalEventHandlersImpl.get_ondragenter(instance);
        return event_handlers.value(EventHandler, instance, "ondragenter");
    }

    pub fn set_ondragenter(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_ondragenter")) return try GlobalEventHandlersImpl.set_ondragenter(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ondragenter", value);
    }

    pub fn get_ondragleave(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_ondragleave")) return try GlobalEventHandlersImpl.get_ondragleave(instance);
        return event_handlers.value(EventHandler, instance, "ondragleave");
    }

    pub fn set_ondragleave(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_ondragleave")) return try GlobalEventHandlersImpl.set_ondragleave(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ondragleave", value);
    }

    pub fn get_ondragover(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_ondragover")) return try GlobalEventHandlersImpl.get_ondragover(instance);
        return event_handlers.value(EventHandler, instance, "ondragover");
    }

    pub fn set_ondragover(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_ondragover")) return try GlobalEventHandlersImpl.set_ondragover(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ondragover", value);
    }

    pub fn get_ondragstart(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_ondragstart")) return try GlobalEventHandlersImpl.get_ondragstart(instance);
        return event_handlers.value(EventHandler, instance, "ondragstart");
    }

    pub fn set_ondragstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_ondragstart")) return try GlobalEventHandlersImpl.set_ondragstart(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ondragstart", value);
    }

    pub fn get_ondrop(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_ondrop")) return try GlobalEventHandlersImpl.get_ondrop(instance);
        return event_handlers.value(EventHandler, instance, "ondrop");
    }

    pub fn set_ondrop(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_ondrop")) return try GlobalEventHandlersImpl.set_ondrop(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ondrop", value);
    }

    pub fn get_ondurationchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_ondurationchange")) return try GlobalEventHandlersImpl.get_ondurationchange(instance);
        return event_handlers.value(EventHandler, instance, "ondurationchange");
    }

    pub fn set_ondurationchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_ondurationchange")) return try GlobalEventHandlersImpl.set_ondurationchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ondurationchange", value);
    }

    pub fn get_onemptied(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onemptied")) return try GlobalEventHandlersImpl.get_onemptied(instance);
        return event_handlers.value(EventHandler, instance, "onemptied");
    }

    pub fn set_onemptied(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onemptied")) return try GlobalEventHandlersImpl.set_onemptied(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onemptied", value);
    }

    pub fn get_onended(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onended")) return try GlobalEventHandlersImpl.get_onended(instance);
        return event_handlers.value(EventHandler, instance, "onended");
    }

    pub fn set_onended(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onended")) return try GlobalEventHandlersImpl.set_onended(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onended", value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!OnErrorEventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onerror")) return try GlobalEventHandlersImpl.get_onerror(instance);
        return event_handlers.value(OnErrorEventHandler, instance, "onerror");
    }

    pub fn set_onerror(instance: *runtime.Instance, value: OnErrorEventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onerror")) return try GlobalEventHandlersImpl.set_onerror(instance, value);
        try event_handlers.setValue(OnErrorEventHandler, instance, "onerror", value);
    }

    pub fn get_onfocus(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onfocus")) return try GlobalEventHandlersImpl.get_onfocus(instance);
        return event_handlers.value(EventHandler, instance, "onfocus");
    }

    pub fn set_onfocus(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onfocus")) return try GlobalEventHandlersImpl.set_onfocus(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onfocus", value);
    }

    pub fn get_onformdata(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onformdata")) return try GlobalEventHandlersImpl.get_onformdata(instance);
        return event_handlers.value(EventHandler, instance, "onformdata");
    }

    pub fn set_onformdata(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onformdata")) return try GlobalEventHandlersImpl.set_onformdata(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onformdata", value);
    }

    pub fn get_oninput(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_oninput")) return try GlobalEventHandlersImpl.get_oninput(instance);
        return event_handlers.value(EventHandler, instance, "oninput");
    }

    pub fn set_oninput(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_oninput")) return try GlobalEventHandlersImpl.set_oninput(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oninput", value);
    }

    pub fn get_oninvalid(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_oninvalid")) return try GlobalEventHandlersImpl.get_oninvalid(instance);
        return event_handlers.value(EventHandler, instance, "oninvalid");
    }

    pub fn set_oninvalid(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_oninvalid")) return try GlobalEventHandlersImpl.set_oninvalid(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oninvalid", value);
    }

    pub fn get_onkeydown(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onkeydown")) return try GlobalEventHandlersImpl.get_onkeydown(instance);
        return event_handlers.value(EventHandler, instance, "onkeydown");
    }

    pub fn set_onkeydown(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onkeydown")) return try GlobalEventHandlersImpl.set_onkeydown(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onkeydown", value);
    }

    pub fn get_onkeypress(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onkeypress")) return try GlobalEventHandlersImpl.get_onkeypress(instance);
        return event_handlers.value(EventHandler, instance, "onkeypress");
    }

    pub fn set_onkeypress(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onkeypress")) return try GlobalEventHandlersImpl.set_onkeypress(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onkeypress", value);
    }

    pub fn get_onkeyup(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onkeyup")) return try GlobalEventHandlersImpl.get_onkeyup(instance);
        return event_handlers.value(EventHandler, instance, "onkeyup");
    }

    pub fn set_onkeyup(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onkeyup")) return try GlobalEventHandlersImpl.set_onkeyup(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onkeyup", value);
    }

    pub fn get_onload(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onload")) return try GlobalEventHandlersImpl.get_onload(instance);
        return event_handlers.value(EventHandler, instance, "onload");
    }

    pub fn set_onload(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onload")) return try GlobalEventHandlersImpl.set_onload(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onload", value);
    }

    pub fn get_onloadeddata(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onloadeddata")) return try GlobalEventHandlersImpl.get_onloadeddata(instance);
        return event_handlers.value(EventHandler, instance, "onloadeddata");
    }

    pub fn set_onloadeddata(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onloadeddata")) return try GlobalEventHandlersImpl.set_onloadeddata(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onloadeddata", value);
    }

    pub fn get_onloadedmetadata(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onloadedmetadata")) return try GlobalEventHandlersImpl.get_onloadedmetadata(instance);
        return event_handlers.value(EventHandler, instance, "onloadedmetadata");
    }

    pub fn set_onloadedmetadata(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onloadedmetadata")) return try GlobalEventHandlersImpl.set_onloadedmetadata(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onloadedmetadata", value);
    }

    pub fn get_onloadstart(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onloadstart")) return try GlobalEventHandlersImpl.get_onloadstart(instance);
        return event_handlers.value(EventHandler, instance, "onloadstart");
    }

    pub fn set_onloadstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onloadstart")) return try GlobalEventHandlersImpl.set_onloadstart(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onloadstart", value);
    }

    pub fn get_onmousedown(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onmousedown")) return try GlobalEventHandlersImpl.get_onmousedown(instance);
        return event_handlers.value(EventHandler, instance, "onmousedown");
    }

    pub fn set_onmousedown(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onmousedown")) return try GlobalEventHandlersImpl.set_onmousedown(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onmousedown", value);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn get_onmouseenter(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onmouseenter")) return try GlobalEventHandlersImpl.get_onmouseenter(instance);
        return event_handlers.value(EventHandler, instance, "onmouseenter");
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn set_onmouseenter(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onmouseenter")) return try GlobalEventHandlersImpl.set_onmouseenter(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onmouseenter", value);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn get_onmouseleave(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onmouseleave")) return try GlobalEventHandlersImpl.get_onmouseleave(instance);
        return event_handlers.value(EventHandler, instance, "onmouseleave");
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn set_onmouseleave(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onmouseleave")) return try GlobalEventHandlersImpl.set_onmouseleave(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onmouseleave", value);
    }

    pub fn get_onmousemove(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onmousemove")) return try GlobalEventHandlersImpl.get_onmousemove(instance);
        return event_handlers.value(EventHandler, instance, "onmousemove");
    }

    pub fn set_onmousemove(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onmousemove")) return try GlobalEventHandlersImpl.set_onmousemove(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onmousemove", value);
    }

    pub fn get_onmouseout(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onmouseout")) return try GlobalEventHandlersImpl.get_onmouseout(instance);
        return event_handlers.value(EventHandler, instance, "onmouseout");
    }

    pub fn set_onmouseout(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onmouseout")) return try GlobalEventHandlersImpl.set_onmouseout(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onmouseout", value);
    }

    pub fn get_onmouseover(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onmouseover")) return try GlobalEventHandlersImpl.get_onmouseover(instance);
        return event_handlers.value(EventHandler, instance, "onmouseover");
    }

    pub fn set_onmouseover(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onmouseover")) return try GlobalEventHandlersImpl.set_onmouseover(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onmouseover", value);
    }

    pub fn get_onmouseup(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onmouseup")) return try GlobalEventHandlersImpl.get_onmouseup(instance);
        return event_handlers.value(EventHandler, instance, "onmouseup");
    }

    pub fn set_onmouseup(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onmouseup")) return try GlobalEventHandlersImpl.set_onmouseup(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onmouseup", value);
    }

    pub fn get_onpaste(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onpaste")) return try GlobalEventHandlersImpl.get_onpaste(instance);
        return event_handlers.value(EventHandler, instance, "onpaste");
    }

    pub fn set_onpaste(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onpaste")) return try GlobalEventHandlersImpl.set_onpaste(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onpaste", value);
    }

    pub fn get_onpause(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onpause")) return try GlobalEventHandlersImpl.get_onpause(instance);
        return event_handlers.value(EventHandler, instance, "onpause");
    }

    pub fn set_onpause(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onpause")) return try GlobalEventHandlersImpl.set_onpause(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onpause", value);
    }

    pub fn get_onplay(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onplay")) return try GlobalEventHandlersImpl.get_onplay(instance);
        return event_handlers.value(EventHandler, instance, "onplay");
    }

    pub fn set_onplay(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onplay")) return try GlobalEventHandlersImpl.set_onplay(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onplay", value);
    }

    pub fn get_onplaying(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onplaying")) return try GlobalEventHandlersImpl.get_onplaying(instance);
        return event_handlers.value(EventHandler, instance, "onplaying");
    }

    pub fn set_onplaying(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onplaying")) return try GlobalEventHandlersImpl.set_onplaying(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onplaying", value);
    }

    pub fn get_onprogress(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onprogress")) return try GlobalEventHandlersImpl.get_onprogress(instance);
        return event_handlers.value(EventHandler, instance, "onprogress");
    }

    pub fn set_onprogress(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onprogress")) return try GlobalEventHandlersImpl.set_onprogress(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onprogress", value);
    }

    pub fn get_onratechange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onratechange")) return try GlobalEventHandlersImpl.get_onratechange(instance);
        return event_handlers.value(EventHandler, instance, "onratechange");
    }

    pub fn set_onratechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onratechange")) return try GlobalEventHandlersImpl.set_onratechange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onratechange", value);
    }

    pub fn get_onreset(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onreset")) return try GlobalEventHandlersImpl.get_onreset(instance);
        return event_handlers.value(EventHandler, instance, "onreset");
    }

    pub fn set_onreset(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onreset")) return try GlobalEventHandlersImpl.set_onreset(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onreset", value);
    }

    pub fn get_onresize(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onresize")) return try GlobalEventHandlersImpl.get_onresize(instance);
        return event_handlers.value(EventHandler, instance, "onresize");
    }

    pub fn set_onresize(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onresize")) return try GlobalEventHandlersImpl.set_onresize(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onresize", value);
    }

    pub fn get_onscroll(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onscroll")) return try GlobalEventHandlersImpl.get_onscroll(instance);
        return event_handlers.value(EventHandler, instance, "onscroll");
    }

    pub fn set_onscroll(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onscroll")) return try GlobalEventHandlersImpl.set_onscroll(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onscroll", value);
    }

    pub fn get_onscrollend(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onscrollend")) return try GlobalEventHandlersImpl.get_onscrollend(instance);
        return event_handlers.value(EventHandler, instance, "onscrollend");
    }

    pub fn set_onscrollend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onscrollend")) return try GlobalEventHandlersImpl.set_onscrollend(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onscrollend", value);
    }

    pub fn get_onsecuritypolicyviolation(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onsecuritypolicyviolation")) return try GlobalEventHandlersImpl.get_onsecuritypolicyviolation(instance);
        return event_handlers.value(EventHandler, instance, "onsecuritypolicyviolation");
    }

    pub fn set_onsecuritypolicyviolation(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onsecuritypolicyviolation")) return try GlobalEventHandlersImpl.set_onsecuritypolicyviolation(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onsecuritypolicyviolation", value);
    }

    pub fn get_onseeked(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onseeked")) return try GlobalEventHandlersImpl.get_onseeked(instance);
        return event_handlers.value(EventHandler, instance, "onseeked");
    }

    pub fn set_onseeked(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onseeked")) return try GlobalEventHandlersImpl.set_onseeked(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onseeked", value);
    }

    pub fn get_onseeking(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onseeking")) return try GlobalEventHandlersImpl.get_onseeking(instance);
        return event_handlers.value(EventHandler, instance, "onseeking");
    }

    pub fn set_onseeking(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onseeking")) return try GlobalEventHandlersImpl.set_onseeking(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onseeking", value);
    }

    pub fn get_onselect(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onselect")) return try GlobalEventHandlersImpl.get_onselect(instance);
        return event_handlers.value(EventHandler, instance, "onselect");
    }

    pub fn set_onselect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onselect")) return try GlobalEventHandlersImpl.set_onselect(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onselect", value);
    }

    pub fn get_onslotchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onslotchange")) return try GlobalEventHandlersImpl.get_onslotchange(instance);
        return event_handlers.value(EventHandler, instance, "onslotchange");
    }

    pub fn set_onslotchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onslotchange")) return try GlobalEventHandlersImpl.set_onslotchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onslotchange", value);
    }

    pub fn get_onstalled(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onstalled")) return try GlobalEventHandlersImpl.get_onstalled(instance);
        return event_handlers.value(EventHandler, instance, "onstalled");
    }

    pub fn set_onstalled(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onstalled")) return try GlobalEventHandlersImpl.set_onstalled(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onstalled", value);
    }

    pub fn get_onsubmit(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onsubmit")) return try GlobalEventHandlersImpl.get_onsubmit(instance);
        return event_handlers.value(EventHandler, instance, "onsubmit");
    }

    pub fn set_onsubmit(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onsubmit")) return try GlobalEventHandlersImpl.set_onsubmit(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onsubmit", value);
    }

    pub fn get_onsuspend(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onsuspend")) return try GlobalEventHandlersImpl.get_onsuspend(instance);
        return event_handlers.value(EventHandler, instance, "onsuspend");
    }

    pub fn set_onsuspend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onsuspend")) return try GlobalEventHandlersImpl.set_onsuspend(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onsuspend", value);
    }

    pub fn get_ontimeupdate(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_ontimeupdate")) return try GlobalEventHandlersImpl.get_ontimeupdate(instance);
        return event_handlers.value(EventHandler, instance, "ontimeupdate");
    }

    pub fn set_ontimeupdate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_ontimeupdate")) return try GlobalEventHandlersImpl.set_ontimeupdate(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ontimeupdate", value);
    }

    pub fn get_ontoggle(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_ontoggle")) return try GlobalEventHandlersImpl.get_ontoggle(instance);
        return event_handlers.value(EventHandler, instance, "ontoggle");
    }

    pub fn set_ontoggle(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_ontoggle")) return try GlobalEventHandlersImpl.set_ontoggle(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ontoggle", value);
    }

    pub fn get_onvolumechange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onvolumechange")) return try GlobalEventHandlersImpl.get_onvolumechange(instance);
        return event_handlers.value(EventHandler, instance, "onvolumechange");
    }

    pub fn set_onvolumechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onvolumechange")) return try GlobalEventHandlersImpl.set_onvolumechange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onvolumechange", value);
    }

    pub fn get_onwaiting(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onwaiting")) return try GlobalEventHandlersImpl.get_onwaiting(instance);
        return event_handlers.value(EventHandler, instance, "onwaiting");
    }

    pub fn set_onwaiting(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onwaiting")) return try GlobalEventHandlersImpl.set_onwaiting(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onwaiting", value);
    }

    pub fn get_onwebkitanimationend(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onwebkitanimationend")) return try GlobalEventHandlersImpl.get_onwebkitanimationend(instance);
        return event_handlers.value(EventHandler, instance, "onwebkitanimationend");
    }

    pub fn set_onwebkitanimationend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onwebkitanimationend")) return try GlobalEventHandlersImpl.set_onwebkitanimationend(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onwebkitanimationend", value);
    }

    pub fn get_onwebkitanimationiteration(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onwebkitanimationiteration")) return try GlobalEventHandlersImpl.get_onwebkitanimationiteration(instance);
        return event_handlers.value(EventHandler, instance, "onwebkitanimationiteration");
    }

    pub fn set_onwebkitanimationiteration(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onwebkitanimationiteration")) return try GlobalEventHandlersImpl.set_onwebkitanimationiteration(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onwebkitanimationiteration", value);
    }

    pub fn get_onwebkitanimationstart(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onwebkitanimationstart")) return try GlobalEventHandlersImpl.get_onwebkitanimationstart(instance);
        return event_handlers.value(EventHandler, instance, "onwebkitanimationstart");
    }

    pub fn set_onwebkitanimationstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onwebkitanimationstart")) return try GlobalEventHandlersImpl.set_onwebkitanimationstart(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onwebkitanimationstart", value);
    }

    pub fn get_onwebkittransitionend(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onwebkittransitionend")) return try GlobalEventHandlersImpl.get_onwebkittransitionend(instance);
        return event_handlers.value(EventHandler, instance, "onwebkittransitionend");
    }

    pub fn set_onwebkittransitionend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onwebkittransitionend")) return try GlobalEventHandlersImpl.set_onwebkittransitionend(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onwebkittransitionend", value);
    }

    pub fn get_onwheel(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onwheel")) return try GlobalEventHandlersImpl.get_onwheel(instance);
        return event_handlers.value(EventHandler, instance, "onwheel");
    }

    pub fn set_onwheel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onwheel")) return try GlobalEventHandlersImpl.set_onwheel(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onwheel", value);
    }

    pub fn get_onanimationstart(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onanimationstart")) return try GlobalEventHandlersImpl.get_onanimationstart(instance);
        return event_handlers.value(EventHandler, instance, "onanimationstart");
    }

    pub fn set_onanimationstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onanimationstart")) return try GlobalEventHandlersImpl.set_onanimationstart(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onanimationstart", value);
    }

    pub fn get_onanimationiteration(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onanimationiteration")) return try GlobalEventHandlersImpl.get_onanimationiteration(instance);
        return event_handlers.value(EventHandler, instance, "onanimationiteration");
    }

    pub fn set_onanimationiteration(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onanimationiteration")) return try GlobalEventHandlersImpl.set_onanimationiteration(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onanimationiteration", value);
    }

    pub fn get_onanimationend(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onanimationend")) return try GlobalEventHandlersImpl.get_onanimationend(instance);
        return event_handlers.value(EventHandler, instance, "onanimationend");
    }

    pub fn set_onanimationend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onanimationend")) return try GlobalEventHandlersImpl.set_onanimationend(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onanimationend", value);
    }

    pub fn get_onanimationcancel(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onanimationcancel")) return try GlobalEventHandlersImpl.get_onanimationcancel(instance);
        return event_handlers.value(EventHandler, instance, "onanimationcancel");
    }

    pub fn set_onanimationcancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onanimationcancel")) return try GlobalEventHandlersImpl.set_onanimationcancel(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onanimationcancel", value);
    }

    pub fn get_onsnapchanged(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onsnapchanged")) return try GlobalEventHandlersImpl.get_onsnapchanged(instance);
        return event_handlers.value(EventHandler, instance, "onsnapchanged");
    }

    pub fn set_onsnapchanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onsnapchanged")) return try GlobalEventHandlersImpl.set_onsnapchanged(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onsnapchanged", value);
    }

    pub fn get_onsnapchanging(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onsnapchanging")) return try GlobalEventHandlersImpl.get_onsnapchanging(instance);
        return event_handlers.value(EventHandler, instance, "onsnapchanging");
    }

    pub fn set_onsnapchanging(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onsnapchanging")) return try GlobalEventHandlersImpl.set_onsnapchanging(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onsnapchanging", value);
    }

    pub fn get_ontransitionrun(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_ontransitionrun")) return try GlobalEventHandlersImpl.get_ontransitionrun(instance);
        return event_handlers.value(EventHandler, instance, "ontransitionrun");
    }

    pub fn set_ontransitionrun(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_ontransitionrun")) return try GlobalEventHandlersImpl.set_ontransitionrun(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ontransitionrun", value);
    }

    pub fn get_ontransitionstart(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_ontransitionstart")) return try GlobalEventHandlersImpl.get_ontransitionstart(instance);
        return event_handlers.value(EventHandler, instance, "ontransitionstart");
    }

    pub fn set_ontransitionstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_ontransitionstart")) return try GlobalEventHandlersImpl.set_ontransitionstart(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ontransitionstart", value);
    }

    pub fn get_ontransitionend(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_ontransitionend")) return try GlobalEventHandlersImpl.get_ontransitionend(instance);
        return event_handlers.value(EventHandler, instance, "ontransitionend");
    }

    pub fn set_ontransitionend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_ontransitionend")) return try GlobalEventHandlersImpl.set_ontransitionend(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ontransitionend", value);
    }

    pub fn get_ontransitioncancel(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_ontransitioncancel")) return try GlobalEventHandlersImpl.get_ontransitioncancel(instance);
        return event_handlers.value(EventHandler, instance, "ontransitioncancel");
    }

    pub fn set_ontransitioncancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_ontransitioncancel")) return try GlobalEventHandlersImpl.set_ontransitioncancel(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ontransitioncancel", value);
    }

    pub fn get_onfencedtreeclick(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onfencedtreeclick")) return try GlobalEventHandlersImpl.get_onfencedtreeclick(instance);
        return event_handlers.value(EventHandler, instance, "onfencedtreeclick");
    }

    pub fn set_onfencedtreeclick(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onfencedtreeclick")) return try GlobalEventHandlersImpl.set_onfencedtreeclick(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onfencedtreeclick", value);
    }

    pub fn get_onpointerover(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onpointerover")) return try GlobalEventHandlersImpl.get_onpointerover(instance);
        return event_handlers.value(EventHandler, instance, "onpointerover");
    }

    pub fn set_onpointerover(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onpointerover")) return try GlobalEventHandlersImpl.set_onpointerover(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onpointerover", value);
    }

    pub fn get_onpointerenter(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onpointerenter")) return try GlobalEventHandlersImpl.get_onpointerenter(instance);
        return event_handlers.value(EventHandler, instance, "onpointerenter");
    }

    pub fn set_onpointerenter(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onpointerenter")) return try GlobalEventHandlersImpl.set_onpointerenter(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onpointerenter", value);
    }

    pub fn get_onpointerdown(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onpointerdown")) return try GlobalEventHandlersImpl.get_onpointerdown(instance);
        return event_handlers.value(EventHandler, instance, "onpointerdown");
    }

    pub fn set_onpointerdown(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onpointerdown")) return try GlobalEventHandlersImpl.set_onpointerdown(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onpointerdown", value);
    }

    pub fn get_onpointermove(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onpointermove")) return try GlobalEventHandlersImpl.get_onpointermove(instance);
        return event_handlers.value(EventHandler, instance, "onpointermove");
    }

    pub fn set_onpointermove(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onpointermove")) return try GlobalEventHandlersImpl.set_onpointermove(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onpointermove", value);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_onpointerrawupdate(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onpointerrawupdate")) return try GlobalEventHandlersImpl.get_onpointerrawupdate(instance);
        return event_handlers.value(EventHandler, instance, "onpointerrawupdate");
    }

    /// Extended attributes: [SecureContext]
    pub fn set_onpointerrawupdate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onpointerrawupdate")) return try GlobalEventHandlersImpl.set_onpointerrawupdate(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onpointerrawupdate", value);
    }

    pub fn get_onpointerup(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onpointerup")) return try GlobalEventHandlersImpl.get_onpointerup(instance);
        return event_handlers.value(EventHandler, instance, "onpointerup");
    }

    pub fn set_onpointerup(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onpointerup")) return try GlobalEventHandlersImpl.set_onpointerup(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onpointerup", value);
    }

    pub fn get_onpointercancel(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onpointercancel")) return try GlobalEventHandlersImpl.get_onpointercancel(instance);
        return event_handlers.value(EventHandler, instance, "onpointercancel");
    }

    pub fn set_onpointercancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onpointercancel")) return try GlobalEventHandlersImpl.set_onpointercancel(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onpointercancel", value);
    }

    pub fn get_onpointerout(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onpointerout")) return try GlobalEventHandlersImpl.get_onpointerout(instance);
        return event_handlers.value(EventHandler, instance, "onpointerout");
    }

    pub fn set_onpointerout(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onpointerout")) return try GlobalEventHandlersImpl.set_onpointerout(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onpointerout", value);
    }

    pub fn get_onpointerleave(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onpointerleave")) return try GlobalEventHandlersImpl.get_onpointerleave(instance);
        return event_handlers.value(EventHandler, instance, "onpointerleave");
    }

    pub fn set_onpointerleave(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onpointerleave")) return try GlobalEventHandlersImpl.set_onpointerleave(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onpointerleave", value);
    }

    pub fn get_ongotpointercapture(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_ongotpointercapture")) return try GlobalEventHandlersImpl.get_ongotpointercapture(instance);
        return event_handlers.value(EventHandler, instance, "ongotpointercapture");
    }

    pub fn set_ongotpointercapture(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_ongotpointercapture")) return try GlobalEventHandlersImpl.set_ongotpointercapture(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ongotpointercapture", value);
    }

    pub fn get_onlostpointercapture(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onlostpointercapture")) return try GlobalEventHandlersImpl.get_onlostpointercapture(instance);
        return event_handlers.value(EventHandler, instance, "onlostpointercapture");
    }

    pub fn set_onlostpointercapture(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onlostpointercapture")) return try GlobalEventHandlersImpl.set_onlostpointercapture(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onlostpointercapture", value);
    }

    pub fn get_onselectstart(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onselectstart")) return try GlobalEventHandlersImpl.get_onselectstart(instance);
        return event_handlers.value(EventHandler, instance, "onselectstart");
    }

    pub fn set_onselectstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onselectstart")) return try GlobalEventHandlersImpl.set_onselectstart(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onselectstart", value);
    }

    pub fn get_onselectionchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onselectionchange")) return try GlobalEventHandlersImpl.get_onselectionchange(instance);
        return event_handlers.value(EventHandler, instance, "onselectionchange");
    }

    pub fn set_onselectionchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onselectionchange")) return try GlobalEventHandlersImpl.set_onselectionchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onselectionchange", value);
    }

    pub fn get_ontouchstart(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_ontouchstart")) return try GlobalEventHandlersImpl.get_ontouchstart(instance);
        return event_handlers.value(EventHandler, instance, "ontouchstart");
    }

    pub fn set_ontouchstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_ontouchstart")) return try GlobalEventHandlersImpl.set_ontouchstart(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ontouchstart", value);
    }

    pub fn get_ontouchend(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_ontouchend")) return try GlobalEventHandlersImpl.get_ontouchend(instance);
        return event_handlers.value(EventHandler, instance, "ontouchend");
    }

    pub fn set_ontouchend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_ontouchend")) return try GlobalEventHandlersImpl.set_ontouchend(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ontouchend", value);
    }

    pub fn get_ontouchmove(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_ontouchmove")) return try GlobalEventHandlersImpl.get_ontouchmove(instance);
        return event_handlers.value(EventHandler, instance, "ontouchmove");
    }

    pub fn set_ontouchmove(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_ontouchmove")) return try GlobalEventHandlersImpl.set_ontouchmove(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ontouchmove", value);
    }

    pub fn get_ontouchcancel(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_ontouchcancel")) return try GlobalEventHandlersImpl.get_ontouchcancel(instance);
        return event_handlers.value(EventHandler, instance, "ontouchcancel");
    }

    pub fn set_ontouchcancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_ontouchcancel")) return try GlobalEventHandlersImpl.set_ontouchcancel(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ontouchcancel", value);
    }

    pub fn get_onbeforexrselect(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "get_onbeforexrselect")) return try GlobalEventHandlersImpl.get_onbeforexrselect(instance);
        return event_handlers.value(EventHandler, instance, "onbeforexrselect");
    }

    pub fn set_onbeforexrselect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(GlobalEventHandlersImpl, "set_onbeforexrselect")) return try GlobalEventHandlersImpl.set_onbeforexrselect(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onbeforexrselect", value);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_onabort", "set_onauxclick", "set_onbeforeinput", "set_onbeforematch", "set_onbeforetoggle", "set_onblur", "set_oncancel", "set_oncanplay", "set_oncanplaythrough", "set_onchange", "set_onclick", "set_onclose", "set_oncommand", "set_oncontextlost", "set_oncontextmenu", "set_oncontextrestored", "set_oncopy", "set_oncuechange", "set_oncut", "set_ondblclick", "set_ondrag", "set_ondragend", "set_ondragenter", "set_ondragleave", "set_ondragover", "set_ondragstart", "set_ondrop", "set_ondurationchange", "set_onemptied", "set_onended", "set_onerror", "set_onfocus", "set_onformdata", "set_oninput", "set_oninvalid", "set_onkeydown", "set_onkeypress", "set_onkeyup", "set_onload", "set_onloadeddata", "set_onloadedmetadata", "set_onloadstart", "set_onmousedown", "set_onmouseenter", "set_onmouseleave", "set_onmousemove", "set_onmouseout", "set_onmouseover", "set_onmouseup", "set_onpaste", "set_onpause", "set_onplay", "set_onplaying", "set_onprogress", "set_onratechange", "set_onreset", "set_onresize", "set_onscroll", "set_onscrollend", "set_onsecuritypolicyviolation", "set_onseeked", "set_onseeking", "set_onselect", "set_onslotchange", "set_onstalled", "set_onsubmit", "set_onsuspend", "set_ontimeupdate", "set_ontoggle", "set_onvolumechange", "set_onwaiting", "set_onwebkitanimationend", "set_onwebkitanimationiteration", "set_onwebkitanimationstart", "set_onwebkittransitionend", "set_onwheel", "set_onanimationstart", "set_onanimationiteration", "set_onanimationend", "set_onanimationcancel", "set_onsnapchanged", "set_onsnapchanging", "set_ontransitionrun", "set_ontransitionstart", "set_ontransitionend", "set_ontransitioncancel", "set_onfencedtreeclick", "set_onpointerover", "set_onpointerenter", "set_onpointerdown", "set_onpointermove", "set_onpointerrawupdate", "set_onpointerup", "set_onpointercancel", "set_onpointerout", "set_onpointerleave", "set_ongotpointercapture", "set_onlostpointercapture", "set_onselectstart", "set_onselectionchange", "set_ontouchstart", "set_ontouchend", "set_ontouchmove", "set_ontouchcancel", "set_onbeforexrselect" };
};
