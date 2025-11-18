//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PopoverTargetAttributesImpl = @import("impls").PopoverTargetAttributes;
const Element = @import("interfaces").Element;

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
        
        // Initialize the instance (Impl receives full instance)
        PopoverTargetAttributesImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PopoverTargetAttributesImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_popoverTargetElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try PopoverTargetAttributesImpl.get_popoverTargetElement(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_popoverTargetElement(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try PopoverTargetAttributesImpl.set_popoverTargetElement(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_popoverTargetAction(instance: *runtime.Instance) anyerror!DOMString {
        return try PopoverTargetAttributesImpl.get_popoverTargetAction(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_popoverTargetAction(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try PopoverTargetAttributesImpl.set_popoverTargetAction(instance, value);
    }

};
