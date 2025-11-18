//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HTMLOrSVGElementImpl = @import("../impls/HTMLOrSVGElement.zig");

pub const HTMLOrSVGElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLOrSVGElement";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            dataset: DOMStringMap = undefined,
            nonce: runtime.DOMString = undefined,
            autofocus: bool = undefined,
            tabIndex: i32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(HTMLOrSVGElement, .{
        .deinit_fn = &deinit_wrapper,

        .get_autofocus = &get_autofocus,
        .get_dataset = &get_dataset,
        .get_nonce = &get_nonce,
        .get_tabIndex = &get_tabIndex,

        .set_autofocus = &set_autofocus,
        .set_nonce = &set_nonce,
        .set_tabIndex = &set_tabIndex,

        .call_blur = &call_blur,
        .call_focus = &call_focus,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        HTMLOrSVGElementImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        HTMLOrSVGElementImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_dataset(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_dataset) |cached| {
            return cached;
        }
        const value = HTMLOrSVGElementImpl.get_dataset(state);
        state.cached_dataset = value;
        return value;
    }

    pub fn get_nonce(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLOrSVGElementImpl.get_nonce(state);
    }

    pub fn set_nonce(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        HTMLOrSVGElementImpl.set_nonce(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_autofocus(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLOrSVGElementImpl.get_autofocus(state);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_autofocus(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLOrSVGElementImpl.set_autofocus(state, value);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_tabIndex(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return HTMLOrSVGElementImpl.get_tabIndex(state);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_tabIndex(instance: *runtime.Instance, value: i32) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLOrSVGElementImpl.set_tabIndex(state, value);
    }

    pub fn call_blur(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLOrSVGElementImpl.call_blur(state);
    }

    pub fn call_focus(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLOrSVGElementImpl.call_focus(state, options);
    }

};
