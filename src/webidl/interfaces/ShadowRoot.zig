//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ShadowRootImpl = @import("impls").ShadowRoot;
const mixins = @import("mixins");
const DocumentFragment = @import("interfaces").DocumentFragment;
const DocumentOrShadowRoot = @import("interfaces").DocumentOrShadowRoot;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const Document = @import("interfaces").Document;
const HTMLCollection = @import("interfaces").HTMLCollection;
const USVString = @import("interfaces").USVString;
const Element = @import("interfaces").Element;
const ShadowRootMode = @import("enums").ShadowRootMode;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const StyleSheetList = @import("interfaces").StyleSheetList;
const EventHandler = @import("typedefs").EventHandler;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const TrustedHTML = @import("interfaces").TrustedHTML;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const Animation = @import("interfaces").Animation;
const Node = @import("interfaces").Node;
const NodeList = @import("interfaces").NodeList;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const SlotAssignmentMode = @import("enums").SlotAssignmentMode;
const DOMString = @import("typedefs").DOMString;

pub const ShadowRoot = struct {
    pub const Meta = struct {
        pub const name = "ShadowRoot";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = DocumentFragment.State;
        pub const ParentInterface = DocumentFragment;
        pub const MixinTypes = &.{
            DocumentOrShadowRoot,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "mode", "get_mode", null },
            .{ "delegatesFocus", "get_delegatesFocus", null },
            .{ "slotAssignment", "get_slotAssignment", null },
            .{ "clonable", "get_clonable", null },
            .{ "serializable", "get_serializable", null },
            .{ "host", "get_host", null },
            .{ "onslotchange", "get_onslotchange", "set_onslotchange" },
            .{ "innerHTML", "get_innerHTML", "set_innerHTML" },
            .{ "customElementRegistry", "get_customElementRegistry", null },
            .{ "fullscreenElement", "get_fullscreenElement", null },
            .{ "pictureInPictureElement", "get_pictureInPictureElement", null },
            .{ "pointerLockElement", "get_pointerLockElement", null },
            .{ "styleSheets", "get_styleSheets", null },
            .{ "adoptedStyleSheets", "get_adoptedStyleSheets", "set_adoptedStyleSheets" },
            .{ "activeElement", "get_activeElement", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setHTMLUnsafe", "call_setHTMLUnsafe", 1 },
            .{ "getHTML", "call_getHTML", 0 },
            .{ "getAnimations", "call_getAnimations", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setHTMLUnsafe",
            "getHTML",
            "getAnimations",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "getRootNode",
            "hasChildNodes",
            "normalize",
            "cloneNode",
            "isEqualNode",
            "isSameNode",
            "compareDocumentPosition",
            "contains",
            "lookupPrefix",
            "lookupNamespaceURI",
            "isDefaultNamespace",
            "insertBefore",
            "appendChild",
            "replaceChild",
            "removeChild",
            "getElementById",
            "prepend",
            "append",
            "replaceChildren",
            "moveBefore",
            "querySelector",
            "querySelectorAll",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "mode", "get_mode", null },
            .{ "delegatesFocus", "get_delegatesFocus", null },
            .{ "slotAssignment", "get_slotAssignment", null },
            .{ "clonable", "get_clonable", null },
            .{ "serializable", "get_serializable", null },
            .{ "host", "get_host", null },
            .{ "onslotchange", "get_onslotchange", "set_onslotchange" },
            .{ "innerHTML", "get_innerHTML", "set_innerHTML" },
            .{ "customElementRegistry", "get_customElementRegistry", null },
            .{ "fullscreenElement", "get_fullscreenElement", null },
            .{ "pictureInPictureElement", "get_pictureInPictureElement", null },
            .{ "pointerLockElement", "get_pointerLockElement", null },
            .{ "styleSheets", "get_styleSheets", null },
            .{ "adoptedStyleSheets", "get_adoptedStyleSheets", "set_adoptedStyleSheets" },
            .{ "activeElement", "get_activeElement", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            mode: ShadowRootMode = undefined,
            delegatesFocus: bool = undefined,
            slotAssignment: SlotAssignmentMode = undefined,
            clonable: bool = undefined,
            serializable: bool = undefined,
            host: *runtime.Instance = undefined,
            onslotchange: EventHandler = undefined,
            innerHTML: union(enum) {
                TrustedHTML: TrustedHTML,
                DOMString: runtime.DOMString,
            } = undefined,
            customElementRegistry: ?*runtime.Instance = null,
            fullscreenElement: ?*runtime.Instance = null,
            pictureInPictureElement: ?*runtime.Instance = null,
            pointerLockElement: ?*runtime.Instance = null,
            styleSheets: *runtime.Instance = undefined,
            adoptedStyleSheets: runtime.ObservableArray(CSSStyleSheet) = undefined,
            activeElement: ?*runtime.Instance = null,
            cached_styleSheets: ?*runtime.Instance = null,
            _internal: ?*ShadowRootImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_activeElement = &get_activeElement,
        .get_adoptedStyleSheets = &get_adoptedStyleSheets,
        .get_clonable = &get_clonable,
        .get_customElementRegistry = &get_customElementRegistry,
        .get_delegatesFocus = &get_delegatesFocus,
        .get_fullscreenElement = &get_fullscreenElement,
        .get_host = &get_host,
        .get_innerHTML = &get_innerHTML,
        .get_mode = &get_mode,
        .get_onslotchange = &get_onslotchange,
        .get_pictureInPictureElement = &get_pictureInPictureElement,
        .get_pointerLockElement = &get_pointerLockElement,
        .get_serializable = &get_serializable,
        .get_slotAssignment = &get_slotAssignment,
        .get_styleSheets = &get_styleSheets,

        .set_adoptedStyleSheets = &set_adoptedStyleSheets,
        .set_innerHTML = &set_innerHTML,
        .set_onslotchange = &set_onslotchange,

        .call_getAnimations = &call_getAnimations,
        .call_getHTML = &call_getHTML,
        .call_setHTMLUnsafe = &call_setHTMLUnsafe,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ShadowRootImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ShadowRootImpl.deinit(instance);
    }

    pub fn get_mode(instance: *runtime.Instance) anyerror!ShadowRootMode {
        return try ShadowRootImpl.get_mode(instance);
    }

    pub fn get_delegatesFocus(instance: *runtime.Instance) anyerror!bool {
        return try ShadowRootImpl.get_delegatesFocus(instance);
    }

    pub fn get_slotAssignment(instance: *runtime.Instance) anyerror!SlotAssignmentMode {
        return try ShadowRootImpl.get_slotAssignment(instance);
    }

    pub fn get_clonable(instance: *runtime.Instance) anyerror!bool {
        return try ShadowRootImpl.get_clonable(instance);
    }

    pub fn get_serializable(instance: *runtime.Instance) anyerror!bool {
        return try ShadowRootImpl.get_serializable(instance);
    }

    pub fn get_host(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ShadowRootImpl.get_host(instance);
    }

    pub fn get_onslotchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try ShadowRootImpl.get_onslotchange(instance);
    }

    pub fn set_onslotchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ShadowRootImpl.set_onslotchange(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_innerHTML(instance: *runtime.Instance) anyerror!DOMString {
        return try ShadowRootImpl.get_innerHTML(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_innerHTML(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ShadowRootImpl.set_innerHTML(instance, value);
    }

    pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ShadowRootImpl.get_customElementRegistry(instance);
    }

    /// Extended attributes: [LegacyLenientSetter]
    pub fn get_fullscreenElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ShadowRootImpl.get_fullscreenElement(instance);
    }

    pub fn get_pictureInPictureElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ShadowRootImpl.get_pictureInPictureElement(instance);
    }

    pub fn get_pointerLockElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ShadowRootImpl.get_pointerLockElement(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_styleSheets(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_styleSheets) |cached| {
            return cached;
        }
        const value = try ShadowRootImpl.get_styleSheets(instance);
        state.own.cached_styleSheets = value;
        return value;
    }

    pub fn get_adoptedStyleSheets(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ShadowRootImpl.get_adoptedStyleSheets(instance);
    }

    pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try ShadowRootImpl.set_adoptedStyleSheets(instance, value);
    }

    pub fn get_activeElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ShadowRootImpl.get_activeElement(instance);
    }

    pub fn call_getHTML(instance: *runtime.Instance, options: webidl.Opt(GetHTMLOptions)) anyerror!DOMString {
        
        return try ShadowRootImpl.call_getHTML(instance, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setHTMLUnsafe(instance: *runtime.Instance, html: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ShadowRootImpl.call_setHTMLUnsafe(instance, html);
    }

    pub fn call_getAnimations(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ShadowRootImpl.call_getAnimations(instance);
    }

};
