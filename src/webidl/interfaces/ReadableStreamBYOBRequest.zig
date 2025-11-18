//! Generated from: streams.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ReadableStreamBYOBRequestImpl = @import("impls").ReadableStreamBYOBRequest;
const ArrayBufferView = @import("typedefs").ArrayBufferView;

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
        
        // Initialize the instance (Impl receives full instance)
        ReadableStreamBYOBRequestImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ReadableStreamBYOBRequestImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_view(instance: *runtime.Instance) anyerror!anyopaque {
        return try ReadableStreamBYOBRequestImpl.get_view(instance);
    }

    pub fn call_respond(instance: *runtime.Instance, bytesWritten: u64) anyerror!void {
        // [EnforceRange] on bytesWritten
        if (!runtime.isInRange(bytesWritten)) return error.TypeError;
        
        return try ReadableStreamBYOBRequestImpl.call_respond(instance, bytesWritten);
    }

    pub fn call_respondWithNewView(instance: *runtime.Instance, view: ArrayBufferView) anyerror!void {
        
        return try ReadableStreamBYOBRequestImpl.call_respondWithNewView(instance, view);
    }

};
