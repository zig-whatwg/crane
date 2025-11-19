//! Generated from: SVG.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGAnimatedStringImpl = @import("impls").SVGAnimatedString;
const TrustedScriptURL = @import("interfaces").TrustedScriptURL;
const DOMString = @import("typedefs").DOMString;

pub const SVGAnimatedString = struct {
    pub const Meta = struct {
        pub const name = "SVGAnimatedString";
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
        struct {
            baseVal: union(enum) {
                DOMString: runtime.DOMString,
                TrustedScriptURL: TrustedScriptURL,
            } = undefined,
            animVal: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SVGAnimatedString, .{
        .deinit_fn = &deinit_wrapper,

        .get_animVal = &get_animVal,
        .get_baseVal = &get_baseVal,

        .set_baseVal = &set_baseVal,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return SVGAnimatedStringImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGAnimatedStringImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_baseVal(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGAnimatedStringImpl.get_baseVal(instance);
    }

    pub fn set_baseVal(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try SVGAnimatedStringImpl.set_baseVal(instance, value);
    }

    pub fn get_animVal(instance: *runtime.Instance) anyerror!DOMString {
        return try SVGAnimatedStringImpl.get_animVal(instance);
    }

};
