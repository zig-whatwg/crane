//! Generated from: json-ld-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RdfDatasetImpl = @import("../impls/RdfDataset.zig");

pub const RdfDataset = struct {
    pub const Meta = struct {
        pub const name = "RdfDataset";
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
            defaultGraph: RdfGraph = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RdfDataset, .{
        .deinit_fn = &deinit_wrapper,

        .get_defaultGraph = &get_defaultGraph,

        .call_add = &call_add,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        RdfDatasetImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RdfDatasetImpl.deinit(state);
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
        try RdfDatasetImpl.constructor(state);
        
        return instance;
    }

    pub fn get_defaultGraph(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RdfDatasetImpl.get_defaultGraph(state);
    }

    pub fn call_add(instance: *runtime.Instance, graphName: runtime.USVString, graph: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RdfDatasetImpl.call_add(state, graphName, graph);
    }

};
