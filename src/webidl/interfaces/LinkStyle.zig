//! Generated from: cssom.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LinkStyleImpl = @import("impls").LinkStyle;
const StyleSheet = @import("interfaces").StyleSheet;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;

pub const LinkStyle = struct {
    pub const Meta = struct {
        pub const name = "LinkStyle";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            sheet: ?CSSStyleSheet = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(LinkStyle, .{
        .deinit_fn = &deinit_wrapper,

        .get_sheet = &get_sheet,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return LinkStyleImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LinkStyleImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_sheet(instance: *runtime.Instance) anyerror!CSSStyleSheet {
        return try LinkStyleImpl.get_sheet(instance);
    }

};
