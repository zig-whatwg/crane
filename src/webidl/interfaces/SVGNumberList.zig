//! Generated from: SVG.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGNumberListImpl = @import("impls").SVGNumberList;
const SVGNumber = @import("interfaces").SVGNumber;

pub const SVGNumberList = struct {
    pub const Meta = struct {
        pub const name = "SVGNumberList";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            length: u32 = undefined,
            numberOfItems: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SVGNumberList, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,
        .get_numberOfItems = &get_numberOfItems,

        .call_appendItem = &call_appendItem,
        .call_clear = &call_clear,
        .call_getItem = &call_getItem,
        .call_initialize = &call_initialize,
        .call_insertItemBefore = &call_insertItemBefore,
        .call_removeItem = &call_removeItem,
        .call_replaceItem = &call_replaceItem,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SVGNumberListImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGNumberListImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try SVGNumberListImpl.get_length(instance);
    }

    pub fn get_numberOfItems(instance: *runtime.Instance) anyerror!u32 {
        return try SVGNumberListImpl.get_numberOfItems(instance);
    }

    pub fn call_removeItem(instance: *runtime.Instance, index: u32) anyerror!SVGNumber {
        
        return try SVGNumberListImpl.call_removeItem(instance, index);
    }

    pub fn call_insertItemBefore(instance: *runtime.Instance, newItem: SVGNumber, index: u32) anyerror!SVGNumber {
        
        return try SVGNumberListImpl.call_insertItemBefore(instance, newItem, index);
    }

    pub fn call_getItem(instance: *runtime.Instance, index: u32) anyerror!SVGNumber {
        
        return try SVGNumberListImpl.call_getItem(instance, index);
    }

    pub fn call_replaceItem(instance: *runtime.Instance, newItem: SVGNumber, index: u32) anyerror!SVGNumber {
        
        return try SVGNumberListImpl.call_replaceItem(instance, newItem, index);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try SVGNumberListImpl.call_clear(instance);
    }

    pub fn call_initialize(instance: *runtime.Instance, newItem: SVGNumber) anyerror!SVGNumber {
        
        return try SVGNumberListImpl.call_initialize(instance, newItem);
    }

    pub fn call_appendItem(instance: *runtime.Instance, newItem: SVGNumber) anyerror!SVGNumber {
        
        return try SVGNumberListImpl.call_appendItem(instance, newItem);
    }

};
