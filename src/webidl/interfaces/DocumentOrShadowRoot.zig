//! Generated from: dom.idl
//! Generated at: 2025-12-07T20:02:44Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const DocumentOrShadowRootImpl = @import("impls").DocumentOrShadowRoot;
const mixins = @import("mixins");
const Element = @import("interfaces").Element;
const StyleSheetList = @import("interfaces").StyleSheetList;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const Animation = @import("interfaces").Animation;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;

pub const DocumentOrShadowRoot = struct {
    pub const Meta = struct {
        pub const name = "DocumentOrShadowRoot";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
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
            .{ "getAnimations", "call_getAnimations", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getAnimations",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
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
            customElementRegistry: ?*runtime.Instance = null,
            fullscreenElement: ?*runtime.Instance = null,
            pictureInPictureElement: ?*runtime.Instance = null,
            pointerLockElement: ?*runtime.Instance = null,
            styleSheets: *runtime.Instance = undefined,
            adoptedStyleSheets: runtime.ObservableArray(CSSStyleSheet) = undefined,
            activeElement: ?*runtime.Instance = null,
            cached_styleSheets: ?*runtime.Instance = null,
            _internal: ?*DocumentOrShadowRootImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_activeElement = &get_activeElement,
        .get_adoptedStyleSheets = &get_adoptedStyleSheets,
        .get_customElementRegistry = &get_customElementRegistry,
        .get_fullscreenElement = &get_fullscreenElement,
        .get_pictureInPictureElement = &get_pictureInPictureElement,
        .get_pointerLockElement = &get_pointerLockElement,
        .get_styleSheets = &get_styleSheets,

        .set_adoptedStyleSheets = &set_adoptedStyleSheets,

        .call_getAnimations = &call_getAnimations,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DocumentOrShadowRootImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DocumentOrShadowRootImpl.deinit(instance);
    }

    pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DocumentOrShadowRootImpl.get_customElementRegistry(instance);
    }

    /// Extended attributes: [LegacyLenientSetter]
    pub fn get_fullscreenElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DocumentOrShadowRootImpl.get_fullscreenElement(instance);
    }

    pub fn get_pictureInPictureElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DocumentOrShadowRootImpl.get_pictureInPictureElement(instance);
    }

    pub fn get_pointerLockElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DocumentOrShadowRootImpl.get_pointerLockElement(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_styleSheets(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_styleSheets) |cached| {
            return cached;
        }
        const value = try DocumentOrShadowRootImpl.get_styleSheets(instance);
        state.own.cached_styleSheets = value;
        return value;
    }

    pub fn get_adoptedStyleSheets(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try DocumentOrShadowRootImpl.get_adoptedStyleSheets(instance);
    }

    pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try DocumentOrShadowRootImpl.set_adoptedStyleSheets(instance, value);
    }

    pub fn get_activeElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DocumentOrShadowRootImpl.get_activeElement(instance);
    }

    pub fn call_getAnimations(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try DocumentOrShadowRootImpl.call_getAnimations(instance);
    }

};
