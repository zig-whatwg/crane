//! Generated from: streams.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ReadableStreamBYOBRequestImpl = @import("../impls/ReadableStreamBYOBRequest.zig");

pub const ReadableStreamBYOBRequest = struct {
    pub const Meta = struct {
        pub const name = "ReadableStreamBYOBRequest";
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
            view: ?ArrayBufferView = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ReadableStreamBYOBRequest, .{
        .deinit_fn = &deinit_wrapper,

        .get_view = &get_view,

        .call_respond = &call_respond,
        .call_respondWithNewView = &call_respondWithNewView,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ReadableStreamBYOBRequestImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ReadableStreamBYOBRequestImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_view(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ReadableStreamBYOBRequestImpl.get_view(state);
    }

    pub fn call_respond(instance: *runtime.Instance, bytesWritten: u64) anyopaque {
        const state = instance.getState(State);
        // [EnforceRange] on bytesWritten
        if (bytesWritten > std.math.maxInt(u53)) return error.TypeError;
        
        return ReadableStreamBYOBRequestImpl.call_respond(state, bytesWritten);
    }

    pub fn call_respondWithNewView(instance: *runtime.Instance, view: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ReadableStreamBYOBRequestImpl.call_respondWithNewView(state, view);
    }

};
