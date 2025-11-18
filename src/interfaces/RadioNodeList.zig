//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RadioNodeListImpl = @import("../impls/RadioNodeList.zig");
const NodeList = @import("NodeList.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        RadioNodeListImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RadioNodeListImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return RadioNodeListImpl.get_length(state);
    }

    pub fn get_value(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return RadioNodeListImpl.get_value(state);
    }

    pub fn set_value(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        RadioNodeListImpl.set_value(state, value);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyopaque {
        const state = instance.getState(State);
        
        return RadioNodeListImpl.call_item(state, index);
    }

};
