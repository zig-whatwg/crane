//! Generated from: streams.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WritableStreamDefaultControllerImpl = @import("impls").WritableStreamDefaultController;
const AbortSignal = @import("interfaces").AbortSignal;

pub const WritableStreamDefaultController = struct {
    pub const Meta = struct {
        pub const name = "WritableStreamDefaultController";
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

    pub const vtable = runtime.buildVTable(WritableStreamDefaultController, .{
        .deinit_fn = &deinit_wrapper,

        .get_signal = &get_signal,

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
        WritableStreamDefaultControllerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WritableStreamDefaultControllerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_signal(instance: *runtime.Instance) anyerror!AbortSignal {
        return try WritableStreamDefaultControllerImpl.get_signal(instance);
    }

    pub fn call_error(instance: *runtime.Instance, e: anyopaque) anyerror!void {
        
        return try WritableStreamDefaultControllerImpl.call_error(instance, e);
    }

};
