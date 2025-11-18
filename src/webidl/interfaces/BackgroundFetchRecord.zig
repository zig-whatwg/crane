//! Generated from: background-fetch.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BackgroundFetchRecordImpl = @import("impls").BackgroundFetchRecord;
const Request = @import("interfaces").Request;
const Promise<Response> = @import("interfaces").Promise<Response>;

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
        
        // Initialize the instance (Impl receives full instance)
        BackgroundFetchRecordImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BackgroundFetchRecordImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_request(instance: *runtime.Instance) anyerror!Request {
        return try BackgroundFetchRecordImpl.get_request(instance);
    }

    pub fn get_responseReady(instance: *runtime.Instance) anyerror!anyopaque {
        return try BackgroundFetchRecordImpl.get_responseReady(instance);
    }

};
