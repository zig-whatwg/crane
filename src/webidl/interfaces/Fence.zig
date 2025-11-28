//! Generated from: fenced-frame.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FenceImpl = @import("impls").Fence;
const mixins = @import("mixins");
const FenceEvent = @import("dictionaries").FenceEvent;
const FencedFrameConfig = @import("interfaces").FencedFrameConfig;
const ReportEventType = @import("typedefs").ReportEventType;
const Event = @import("interfaces").Event;

pub const Fence = struct {
    pub const Meta = struct {
        pub const name = "Fence";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "reportEvent", "call_reportEvent", 0 },
            .{ "setReportEventDataForAutomaticBeacons", "call_setReportEventDataForAutomaticBeacons", 0 },
            .{ "getNestedConfigs", "call_getNestedConfigs", 0 },
            .{ "disableUntrustedNetwork", "call_disableUntrustedNetwork", 0 },
            .{ "notifyEvent", "call_notifyEvent", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "reportEvent",
            "setReportEventDataForAutomaticBeacons",
            "getNestedConfigs",
            "disableUntrustedNetwork",
            "notifyEvent",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*FenceImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_disableUntrustedNetwork = &call_disableUntrustedNetwork,
        .call_getNestedConfigs = &call_getNestedConfigs,
        .call_notifyEvent = &call_notifyEvent,
        .call_reportEvent = &call_reportEvent,
        .call_setReportEventDataForAutomaticBeacons = &call_setReportEventDataForAutomaticBeacons,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FenceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FenceImpl.deinit(instance);
    }

    pub fn call_reportEvent(instance: *runtime.Instance, event: webidl.Opt(ReportEventType)) anyerror!void {
        
        return try FenceImpl.call_reportEvent(instance, event.value);
    }

    pub fn call_getNestedConfigs(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try FenceImpl.call_getNestedConfigs(instance);
    }

    pub fn call_setReportEventDataForAutomaticBeacons(instance: *runtime.Instance, event: webidl.Opt(FenceEvent)) anyerror!void {
        
        return try FenceImpl.call_setReportEventDataForAutomaticBeacons(instance, event.value);
    }

    pub fn call_disableUntrustedNetwork(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try FenceImpl.call_disableUntrustedNetwork(instance);
    }

    pub fn call_notifyEvent(instance: *runtime.Instance, event: *runtime.Instance) anyerror!void {
        
        return try FenceImpl.call_notifyEvent(instance, event);
    }

};
