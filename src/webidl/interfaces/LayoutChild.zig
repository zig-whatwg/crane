//! Generated from: css-layout-api.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LayoutChildImpl = @import("impls").LayoutChild;
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const LayoutFragment = @import("interfaces").LayoutFragment;
const IntrinsicSizes = @import("interfaces").IntrinsicSizes;
const ChildBreakToken = @import("interfaces").ChildBreakToken;
const LayoutConstraintsOptions = @import("dictionaries").LayoutConstraintsOptions;

pub const LayoutChild = struct {
    pub const Meta = struct {
        pub const name = "LayoutChild";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "LayoutWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .LayoutWorklet = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            styleMap: StylePropertyMapReadOnly = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(LayoutChild, .{
        .deinit_fn = &deinit_wrapper,

        .get_styleMap = &get_styleMap,

        .call_intrinsicSizes = &call_intrinsicSizes,
        .call_layoutNextFragment = &call_layoutNextFragment,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return LayoutChildImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LayoutChildImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_styleMap(instance: *runtime.Instance) anyerror!StylePropertyMapReadOnly {
        return try LayoutChildImpl.get_styleMap(instance);
    }

    pub fn call_intrinsicSizes(instance: *runtime.Instance) anyerror!anyopaque {
        return try LayoutChildImpl.call_intrinsicSizes(instance);
    }

    pub fn call_layoutNextFragment(instance: *runtime.Instance, constraints: LayoutConstraintsOptions, breakToken: ChildBreakToken) anyerror!anyopaque {
        
        return try LayoutChildImpl.call_layoutNextFragment(instance, constraints, breakToken);
    }

};
