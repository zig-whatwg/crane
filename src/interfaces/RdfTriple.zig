//! Generated from: json-ld-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RdfTripleImpl = @import("../impls/RdfTriple.zig");

pub const RdfTriple = struct {
    pub const Meta = struct {
        pub const name = "RdfTriple";
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
            subject: runtime.USVString = undefined,
            predicate: runtime.USVString = undefined,
            _object: (USVString or RdfLiteral) = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RdfTriple, .{
        .deinit_fn = &deinit_wrapper,

        .get__object = &get__object,
        .get_predicate = &get_predicate,
        .get_subject = &get_subject,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        RdfTripleImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RdfTripleImpl.deinit(state);
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
        try RdfTripleImpl.constructor(state);
        
        return instance;
    }

    pub fn get_subject(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return RdfTripleImpl.get_subject(state);
    }

    pub fn get_predicate(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return RdfTripleImpl.get_predicate(state);
    }

    pub fn get__object(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RdfTripleImpl.get__object(state);
    }

};
