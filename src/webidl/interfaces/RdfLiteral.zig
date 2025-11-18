//! Generated from: json-ld-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RdfLiteralImpl = @import("impls").RdfLiteral;
const USVString = @import("interfaces").USVString;

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
        
        // Initialize the instance (Impl receives full instance)
        RdfLiteralImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RdfLiteralImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try RdfLiteralImpl.constructor(instance);
        
        return instance;
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RdfLiteralImpl.get_value(instance);
    }

    pub fn get_datatype(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RdfLiteralImpl.get_datatype(instance);
    }

    pub fn get_language(instance: *runtime.Instance) anyerror!anyopaque {
        return try RdfLiteralImpl.get_language(instance);
    }

};
