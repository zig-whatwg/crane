//! Generated from: json-ld-api.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RdfLiteralImpl = @import("../impls/RdfLiteral.zig");

pub const RdfLiteral = struct {
    pub const Meta = struct {
        pub const name = "RdfLiteral";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "JsonLd" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .JsonLd = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            value: runtime.USVString = undefined,
            datatype: runtime.USVString = undefined,
            language: ?runtime.USVString = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RdfLiteral, .{
        .deinit_fn = &deinit_wrapper,

        .get_datatype = &get_datatype,
        .get_language = &get_language,
        .get_value = &get_value,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        RdfLiteralImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RdfLiteralImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try RdfLiteralImpl.constructor(state);
        
        return instance;
    }

    pub fn get_value(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return RdfLiteralImpl.get_value(state);
    }

    pub fn get_datatype(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return RdfLiteralImpl.get_datatype(state);
    }

    pub fn get_language(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RdfLiteralImpl.get_language(state);
    }

};
