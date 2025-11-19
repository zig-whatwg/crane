//! Generated from: reporting.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ReportingObserverImpl = @import("impls").ReportingObserver;
const ReportList = @import("typedefs").ReportList;
const ReportingObserverOptions = @import("dictionaries").ReportingObserverOptions;
const ReportingObserverCallback = @import("callbacks").ReportingObserverCallback;

pub const ReportingObserver = struct {
    pub const Meta = struct {
        pub const name = "ReportingObserver";
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
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ReportingObserver, .{
        .deinit_fn = &deinit_wrapper,

        .call_disconnect = &call_disconnect,
        .call_observe = &call_observe,
        .call_takeRecords = &call_takeRecords,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return ReportingObserverImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ReportingObserverImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, callback: ReportingObserverCallback, options: ReportingObserverOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try ReportingObserverImpl.constructor(instance, callback, options);
        
        return instance;
    }

    pub fn call_observe(instance: *runtime.Instance) anyerror!void {
        return try ReportingObserverImpl.call_observe(instance);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
        return try ReportingObserverImpl.call_disconnect(instance);
    }

    pub fn call_takeRecords(instance: *runtime.Instance) anyerror!ReportList {
        return try ReportingObserverImpl.call_takeRecords(instance);
    }

};
