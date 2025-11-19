//! Generated from: epub-rs.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EpubReadingSystemImpl = @import("impls").EpubReadingSystem;
const DOMString = @import("typedefs").DOMString;

pub const EpubReadingSystem = struct {
    pub const Meta = struct {
        pub const name = "EpubReadingSystem";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(EpubReadingSystem, .{
        .deinit_fn = &deinit_wrapper,

        .call_hasFeature = &call_hasFeature,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return EpubReadingSystemImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EpubReadingSystemImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_hasFeature(instance: *runtime.Instance, feature: DOMString, version: DOMString) anyerror!bool {
        
        return try EpubReadingSystemImpl.call_hasFeature(instance, feature, version);
    }

};
