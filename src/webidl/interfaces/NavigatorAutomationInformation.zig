//! Generated from: webdriver.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorAutomationInformationImpl = @import("impls").NavigatorAutomationInformation;

pub const NavigatorAutomationInformation = struct {
    pub const Meta = struct {
        pub const name = "NavigatorAutomationInformation";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            webdriver: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NavigatorAutomationInformation, .{
        .deinit_fn = &deinit_wrapper,

        .get_webdriver = &get_webdriver,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return NavigatorAutomationInformationImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorAutomationInformationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_webdriver(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorAutomationInformationImpl.get_webdriver(instance);
    }

};
