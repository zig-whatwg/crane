//! Generated from: streams.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ReadableStreamDefaultControllerImpl = @import("impls").ReadableStreamDefaultController;
const unrestricted double = @import("interfaces").unrestricted double;

pub const ReadableStreamDefaultController = struct {
    pub const Meta = struct {
        pub const name = "ReadableStreamDefaultController";
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
            desiredSize: ?f64 = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ReadableStreamDefaultController, .{
        .deinit_fn = &deinit_wrapper,

        .get_desiredSize = &get_desiredSize,

        .call_close = &call_close,
        .call_enqueue = &call_enqueue,
        .call_error = &call_error,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ReadableStreamDefaultControllerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ReadableStreamDefaultControllerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_desiredSize(instance: *runtime.Instance) anyerror!anyopaque {
        return try ReadableStreamDefaultControllerImpl.get_desiredSize(instance);
    }

    pub fn call_error(instance: *runtime.Instance, e: anyopaque) anyerror!void {
        
        return try ReadableStreamDefaultControllerImpl.call_error(instance, e);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try ReadableStreamDefaultControllerImpl.call_close(instance);
    }

    pub fn call_enqueue(instance: *runtime.Instance, chunk: anyopaque) anyerror!void {
        
        return try ReadableStreamDefaultControllerImpl.call_enqueue(instance, chunk);
    }

};
