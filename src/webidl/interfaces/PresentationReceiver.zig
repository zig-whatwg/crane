//! Generated from: presentation-api.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PresentationReceiverImpl = @import("impls").PresentationReceiver;
const PresentationConnectionList = @import("interfaces").PresentationConnectionList;

pub const PresentationReceiver = struct {
    pub const Meta = struct {
        pub const name = "PresentationReceiver";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            connectionList: runtime.Promise(PresentationConnectionList) = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PresentationReceiver, .{
        .deinit_fn = &deinit_wrapper,

        .get_connectionList = &get_connectionList,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return PresentationReceiverImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PresentationReceiverImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_connectionList(instance: *runtime.Instance) anyerror!anyopaque {
        return try PresentationReceiverImpl.get_connectionList(instance);
    }

};
