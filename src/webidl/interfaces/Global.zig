//! Generated from: wasm-js-api.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GlobalImpl = @import("impls").Global;
const GlobalDescriptor = @import("dictionaries").GlobalDescriptor;

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
        return GlobalImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GlobalImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, descriptor: GlobalDescriptor, v: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try GlobalImpl.constructor(instance, descriptor, v);
        
        return instance;
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!anyopaque {
        return try GlobalImpl.get_value(instance);
    }

    pub fn set_value(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try GlobalImpl.set_value(instance, value);
    }

    pub fn call_valueOf(instance: *runtime.Instance) anyerror!anyopaque {
        return try GlobalImpl.call_valueOf(instance);
    }

};
