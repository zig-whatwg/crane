//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CounterImpl = @import("../impls/Counter.zig");

pub const Counter = struct {
    pub const Meta = struct {
        pub const name = "Counter";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            identifier: runtime.DOMString = undefined,
            listStyle: runtime.DOMString = undefined,
            separator: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Counter, .{
        .deinit_fn = &deinit_wrapper,

        .get_identifier = &get_identifier,
        .get_listStyle = &get_listStyle,
        .get_separator = &get_separator,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CounterImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CounterImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_identifier(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CounterImpl.get_identifier(state);
    }

    pub fn get_listStyle(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CounterImpl.get_listStyle(state);
    }

    pub fn get_separator(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CounterImpl.get_separator(state);
    }

};
