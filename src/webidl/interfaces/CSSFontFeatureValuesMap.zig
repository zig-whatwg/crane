//! Generated from: css-fonts.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSFontFeatureValuesMapImpl = @import("impls").CSSFontFeatureValuesMap;
const sequence = @import("interfaces").sequence;
const CSSOMString = @import("interfaces").CSSOMString;

pub const CSSFontFeatureValuesMap = struct {
    pub const Meta = struct {
        pub const name = "CSSFontFeatureValuesMap";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const void _skipped = null;
    pub fn get__skipped() void {
        return null;
    }

    pub const vtable = runtime.buildVTable(CSSFontFeatureValuesMap, .{
        .deinit_fn = &deinit_wrapper,

        .get__skipped = &get__skipped,

        .call_set = &call_set,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return CSSFontFeatureValuesMapImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSFontFeatureValuesMapImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_set(instance: *runtime.Instance, featureValueName: anyopaque, values: anyopaque) anyerror!void {
        
        return try CSSFontFeatureValuesMapImpl.call_set(instance, featureValueName, values);
    }

};
