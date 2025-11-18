//! Generated from: wasm-js-api.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GlobalImpl = @import("../impls/Global.zig");

pub const Global = struct {
    pub const Meta = struct {
        pub const name = "Global";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "LegacyNamespace", .value = .{ .identifier = "WebAssembly" } },
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
    };

    pub const State = runtime.FlattenedState(
        struct {
            value: anyopaque = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Global, .{
        .deinit_fn = &deinit_wrapper,

        .get_value = &get_value,

        .set_value = &set_value,

        .call_valueOf = &call_valueOf,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        GlobalImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GlobalImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, descriptor: anyopaque, v: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try GlobalImpl.constructor(state, descriptor, v);
        
        return instance;
    }

    pub fn get_value(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GlobalImpl.get_value(state);
    }

    pub fn set_value(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        GlobalImpl.set_value(state, value);
    }

    pub fn call_valueOf(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GlobalImpl.call_valueOf(state);
    }

};
