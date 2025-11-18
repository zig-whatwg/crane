//! Generated from: geometry.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMQuadImpl = @import("../impls/DOMQuad.zig");

pub const DOMQuad = struct {
    pub const Meta = struct {
        pub const name = "DOMQuad";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            p1: DOMPoint = undefined,
            p2: DOMPoint = undefined,
            p3: DOMPoint = undefined,
            p4: DOMPoint = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DOMQuad, .{
        .deinit_fn = &deinit_wrapper,

        .get_p1 = &get_p1,
        .get_p2 = &get_p2,
        .get_p3 = &get_p3,
        .get_p4 = &get_p4,

        .call_fromQuad = &call_fromQuad,
        .call_fromRect = &call_fromRect,
        .call_getBounds = &call_getBounds,
        .call_toJSON = &call_toJSON,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        DOMQuadImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        DOMQuadImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, p1: anyopaque, p2: anyopaque, p3: anyopaque, p4: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try DOMQuadImpl.constructor(state, p1, p2, p3, p4);
        
        return instance;
    }

    /// Extended attributes: [SameObject]
    pub fn get_p1(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_p1) |cached| {
            return cached;
        }
        const value = DOMQuadImpl.get_p1(state);
        state.cached_p1 = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_p2(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_p2) |cached| {
            return cached;
        }
        const value = DOMQuadImpl.get_p2(state);
        state.cached_p2 = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_p3(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_p3) |cached| {
            return cached;
        }
        const value = DOMQuadImpl.get_p3(state);
        state.cached_p3 = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_p4(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_p4) |cached| {
            return cached;
        }
        const value = DOMQuadImpl.get_p4(state);
        state.cached_p4 = value;
        return value;
    }

    /// Extended attributes: [NewObject]
    pub fn call_getBounds(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return DOMQuadImpl.call_getBounds(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fromQuad(instance: *runtime.Instance, other: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return DOMQuadImpl.call_fromQuad(state, other);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fromRect(instance: *runtime.Instance, other: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return DOMQuadImpl.call_fromRect(state, other);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DOMQuadImpl.call_toJSON(state);
    }

};
