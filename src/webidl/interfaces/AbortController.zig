//! Generated from: dom.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AbortControllerImpl = @import("impls").AbortController;
const AbortSignal = @import("interfaces").AbortSignal;

pub const AbortController = struct {
    pub const Meta = struct {
        pub const name = "AbortController";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
    };

    pub const State = runtime.FlattenedState(
        struct {
            signal: AbortSignal = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AbortController, .{
        .deinit_fn = &deinit_wrapper,

        .get_signal = &get_signal,

        .call_abort = &call_abort,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        AbortControllerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AbortControllerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try AbortControllerImpl.constructor(instance);
        
        return instance;
    }

    /// Extended attributes: [SameObject]
    pub fn get_signal(instance: *runtime.Instance) anyerror!AbortSignal {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_signal) |cached| {
            return cached;
        }
        const value = try AbortControllerImpl.get_signal(instance);
        state.cached_signal = value;
        return value;
    }

    pub fn call_abort(instance: *runtime.Instance, reason: anyopaque) anyerror!void {
        
        return try AbortControllerImpl.call_abort(instance, reason);
    }

};
