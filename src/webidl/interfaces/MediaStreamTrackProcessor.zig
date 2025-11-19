//! Generated from: mediacapture-transform.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaStreamTrackProcessorImpl = @import("impls").MediaStreamTrackProcessor;
const MediaStreamTrackProcessorInit = @import("dictionaries").MediaStreamTrackProcessorInit;
const ReadableStream = @import("interfaces").ReadableStream;

pub const MediaStreamTrackProcessor = struct {
    pub const Meta = struct {
        pub const name = "MediaStreamTrackProcessor";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "DedicatedWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .DedicatedWorker = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            readable: ReadableStream = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MediaStreamTrackProcessor, .{
        .deinit_fn = &deinit_wrapper,

        .get_readable = &get_readable,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return MediaStreamTrackProcessorImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaStreamTrackProcessorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init_data: MediaStreamTrackProcessorInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try MediaStreamTrackProcessorImpl.constructor(instance, init_data);
        
        return instance;
    }

    pub fn get_readable(instance: *runtime.Instance) anyerror!ReadableStream {
        return try MediaStreamTrackProcessorImpl.get_readable(instance);
    }

};
