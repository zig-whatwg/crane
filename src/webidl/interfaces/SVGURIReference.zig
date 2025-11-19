//! Generated from: SVG.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGURIReferenceImpl = @import("impls").SVGURIReference;
const SVGAnimatedString = @import("interfaces").SVGAnimatedString;

pub const SVGURIReference = struct {
    pub const Meta = struct {
        pub const name = "SVGURIReference";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            href: SVGAnimatedString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SVGURIReference, .{
        .deinit_fn = &deinit_wrapper,

        .get_href = &get_href,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return SVGURIReferenceImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGURIReferenceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_href(instance: *runtime.Instance) anyerror!SVGAnimatedString {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_href) |cached| {
            return cached;
        }
        const value = try SVGURIReferenceImpl.get_href(instance);
        state.cached_href = value;
        return value;
    }

};
