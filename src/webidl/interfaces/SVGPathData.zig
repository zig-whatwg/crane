//! Generated from: svg-paths.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGPathDataImpl = @import("impls").SVGPathData;
const SVGPathDataSettings = @import("dictionaries").SVGPathDataSettings;
const SVGPathSegment = @import("interfaces").SVGPathSegment;

pub const SVGPathData = struct {
    pub const Meta = struct {
        pub const name = "SVGPathData";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SVGPathData, .{
        .deinit_fn = &deinit_wrapper,

        .call_getPathData = &call_getPathData,
        .call_setPathData = &call_setPathData,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return SVGPathDataImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGPathDataImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_setPathData(instance: *runtime.Instance, pathData: anyopaque) anyerror!void {
        
        return try SVGPathDataImpl.call_setPathData(instance, pathData);
    }

    pub fn call_getPathData(instance: *runtime.Instance, settings: SVGPathDataSettings) anyerror!anyopaque {
        
        return try SVGPathDataImpl.call_getPathData(instance, settings);
    }

};
