//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RadioNodeListImpl = @import("impls").RadioNodeList;
const NodeList = @import("interfaces").NodeList;

pub const RadioNodeList = struct {
    pub const Meta = struct {
        pub const name = "RadioNodeList";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *NodeList;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            value: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RadioNodeList, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,
        .get_value = &get_value,

        .set_value = &set_value,

        .call_item = &call_item,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        RadioNodeListImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RadioNodeListImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try RadioNodeListImpl.get_length(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!DOMString {
        return try RadioNodeListImpl.get_value(instance);
    }

    pub fn set_value(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try RadioNodeListImpl.set_value(instance, value);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!anyopaque {
        
        return try RadioNodeListImpl.call_item(instance, index);
    }

};
