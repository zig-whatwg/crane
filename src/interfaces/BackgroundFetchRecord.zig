//! Generated from: background-fetch.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BackgroundFetchRecordImpl = @import("../impls/BackgroundFetchRecord.zig");

pub const BackgroundFetchRecord = struct {
    pub const Meta = struct {
        pub const name = "BackgroundFetchRecord";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            request: Request = undefined,
            responseReady: Promise<Response> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BackgroundFetchRecord, .{
        .deinit_fn = &deinit_wrapper,

        .get_request = &get_request,
        .get_responseReady = &get_responseReady,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        BackgroundFetchRecordImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        BackgroundFetchRecordImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_request(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BackgroundFetchRecordImpl.get_request(state);
    }

    pub fn get_responseReady(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BackgroundFetchRecordImpl.get_responseReady(state);
    }

};
