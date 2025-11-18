//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HTMLOrSVGElementImpl = @import("impls").HTMLOrSVGElement;
const DOMStringMap = @import("interfaces").DOMStringMap;
const FocusOptions = @import("dictionaries").FocusOptions;

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
        
        // Initialize the instance (Impl receives full instance)
        HTMLOrSVGElementImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLOrSVGElementImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_dataset(instance: *runtime.Instance) anyerror!DOMStringMap {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_dataset) |cached| {
            return cached;
        }
        const value = try HTMLOrSVGElementImpl.get_dataset(instance);
        state.cached_dataset = value;
        return value;
    }

    pub fn get_nonce(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLOrSVGElementImpl.get_nonce(instance);
    }

    pub fn set_nonce(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try HTMLOrSVGElementImpl.set_nonce(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_autofocus(instance: *runtime.Instance) anyerror!bool {
        return try HTMLOrSVGElementImpl.get_autofocus(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_autofocus(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLOrSVGElementImpl.set_autofocus(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_tabIndex(instance: *runtime.Instance) anyerror!i32 {
        return try HTMLOrSVGElementImpl.get_tabIndex(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_tabIndex(instance: *runtime.Instance, value: i32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLOrSVGElementImpl.set_tabIndex(instance, value);
    }

    pub fn call_blur(instance: *runtime.Instance) anyerror!void {
        return try HTMLOrSVGElementImpl.call_blur(instance);
    }

    pub fn call_focus(instance: *runtime.Instance, options: FocusOptions) anyerror!void {
        
        return try HTMLOrSVGElementImpl.call_focus(instance, options);
    }

};
