//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CounterImpl = @import("impls").Counter;

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
        
        // Initialize the instance (Impl receives full instance)
        CounterImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CounterImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_identifier(instance: *runtime.Instance) anyerror!DOMString {
        return try CounterImpl.get_identifier(instance);
    }

    pub fn get_listStyle(instance: *runtime.Instance) anyerror!DOMString {
        return try CounterImpl.get_listStyle(instance);
    }

    pub fn get_separator(instance: *runtime.Instance) anyerror!DOMString {
        return try CounterImpl.get_separator(instance);
    }

};
