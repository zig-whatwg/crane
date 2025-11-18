//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PopoverTargetAttributesImpl = @import("../impls/PopoverTargetAttributes.zig");

pub const PopoverTargetAttributes = struct {
    pub const Meta = struct {
        pub const name = "PopoverTargetAttributes";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            popoverTargetElement: ?Element = null,
            popoverTargetAction: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PopoverTargetAttributes, .{
        .deinit_fn = &deinit_wrapper,

        .get_popoverTargetAction = &get_popoverTargetAction,
        .get_popoverTargetElement = &get_popoverTargetElement,

        .set_popoverTargetAction = &set_popoverTargetAction,
        .set_popoverTargetElement = &set_popoverTargetElement,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        PopoverTargetAttributesImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PopoverTargetAttributesImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_popoverTargetElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PopoverTargetAttributesImpl.get_popoverTargetElement(state);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_popoverTargetElement(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        PopoverTargetAttributesImpl.set_popoverTargetElement(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_popoverTargetAction(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PopoverTargetAttributesImpl.get_popoverTargetAction(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_popoverTargetAction(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        PopoverTargetAttributesImpl.set_popoverTargetAction(state, value);
    }

};
