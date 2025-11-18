//! Generated from: dom.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DocumentOrShadowRootImpl = @import("impls").DocumentOrShadowRoot;
const Element = @import("interfaces").Element;
const StyleSheetList = @import("interfaces").StyleSheetList;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const ObservableArray<CSSStyleSheet> = @import("interfaces").ObservableArray<CSSStyleSheet>;

pub const DocumentOrShadowRoot = struct {
    pub const Meta = struct {
        pub const name = "DocumentOrShadowRoot";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            customElementRegistry: ?CustomElementRegistry = null,
            fullscreenElement: ?Element = null,
            pictureInPictureElement: ?Element = null,
            pointerLockElement: ?Element = null,
            styleSheets: StyleSheetList = undefined,
            adoptedStyleSheets: ObservableArray<CSSStyleSheet> = undefined,
            activeElement: ?Element = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DocumentOrShadowRoot, .{
        .deinit_fn = &deinit_wrapper,

        .get_activeElement = &get_activeElement,
        .get_adoptedStyleSheets = &get_adoptedStyleSheets,
        .get_customElementRegistry = &get_customElementRegistry,
        .get_fullscreenElement = &get_fullscreenElement,
        .get_pictureInPictureElement = &get_pictureInPictureElement,
        .get_pointerLockElement = &get_pointerLockElement,
        .get_styleSheets = &get_styleSheets,

        .set_adoptedStyleSheets = &set_adoptedStyleSheets,

        .call_getAnimations = &call_getAnimations,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        DocumentOrShadowRootImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DocumentOrShadowRootImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentOrShadowRootImpl.get_customElementRegistry(instance);
    }

    /// Extended attributes: [LegacyLenientSetter]
    pub fn get_fullscreenElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentOrShadowRootImpl.get_fullscreenElement(instance);
    }

    pub fn get_pictureInPictureElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentOrShadowRootImpl.get_pictureInPictureElement(instance);
    }

    pub fn get_pointerLockElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentOrShadowRootImpl.get_pointerLockElement(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_styleSheets(instance: *runtime.Instance) anyerror!StyleSheetList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_styleSheets) |cached| {
            return cached;
        }
        const value = try DocumentOrShadowRootImpl.get_styleSheets(instance);
        state.cached_styleSheets = value;
        return value;
    }

    pub fn get_adoptedStyleSheets(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentOrShadowRootImpl.get_adoptedStyleSheets(instance);
    }

    pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try DocumentOrShadowRootImpl.set_adoptedStyleSheets(instance, value);
    }

    pub fn get_activeElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentOrShadowRootImpl.get_activeElement(instance);
    }

    pub fn call_getAnimations(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentOrShadowRootImpl.call_getAnimations(instance);
    }

};
