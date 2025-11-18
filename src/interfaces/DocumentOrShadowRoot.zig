//! Generated from: dom.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DocumentOrShadowRootImpl = @import("../impls/DocumentOrShadowRoot.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        DocumentOrShadowRootImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        DocumentOrShadowRootImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_customElementRegistry(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DocumentOrShadowRootImpl.get_customElementRegistry(state);
    }

    /// Extended attributes: [LegacyLenientSetter]
    pub fn get_fullscreenElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DocumentOrShadowRootImpl.get_fullscreenElement(state);
    }

    pub fn get_pictureInPictureElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DocumentOrShadowRootImpl.get_pictureInPictureElement(state);
    }

    pub fn get_pointerLockElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DocumentOrShadowRootImpl.get_pointerLockElement(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_styleSheets(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_styleSheets) |cached| {
            return cached;
        }
        const value = DocumentOrShadowRootImpl.get_styleSheets(state);
        state.cached_styleSheets = value;
        return value;
    }

    pub fn get_adoptedStyleSheets(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DocumentOrShadowRootImpl.get_adoptedStyleSheets(state);
    }

    pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        DocumentOrShadowRootImpl.set_adoptedStyleSheets(state, value);
    }

    pub fn get_activeElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DocumentOrShadowRootImpl.get_activeElement(state);
    }

    pub fn call_getAnimations(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DocumentOrShadowRootImpl.call_getAnimations(state);
    }

};
