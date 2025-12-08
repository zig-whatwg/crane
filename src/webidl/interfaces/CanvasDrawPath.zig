//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasDrawPathImpl = @import("impls").CanvasDrawPath;
const mixins = @import("mixins");
const CanvasFillRule = @import("enums").CanvasFillRule;
const Path2D = @import("interfaces").Path2D;

pub const CanvasDrawPath = struct {
    pub const Meta = struct {
        pub const name = "CanvasDrawPath";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "beginPath", "call_beginPath", 0 },
            .{ "fill", "call_fill", 0 },
            .{ "fill", "call_fill", 1 },
            .{ "stroke", "call_stroke", 0 },
            .{ "stroke", "call_stroke", 1 },
            .{ "clip", "call_clip", 0 },
            .{ "clip", "call_clip", 1 },
            .{ "isPointInPath", "call_isPointInPath", 2 },
            .{ "isPointInPath", "call_isPointInPath", 3 },
            .{ "isPointInStroke", "call_isPointInStroke", 2 },
            .{ "isPointInStroke", "call_isPointInStroke", 3 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "beginPath",
            "fill",
            "fill",
            "stroke",
            "stroke",
            "clip",
            "clip",
            "isPointInPath",
            "isPointInPath",
            "isPointInStroke",
            "isPointInStroke",
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
            _internal: ?*CanvasDrawPathImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_beginPath = &call_beginPath,
        .call_clip = &call_clip,
        .call_fill = &call_fill,
        .call_isPointInPath = &call_isPointInPath,
        .call_isPointInStroke = &call_isPointInStroke,
        .call_stroke = &call_stroke,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CanvasDrawPathImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasDrawPathImpl.deinit(instance);
    }

    pub fn call_clip(instance: *runtime.Instance, fillRule: webidl.Opt(CanvasFillRule)) anyerror!void {
        
        return try CanvasDrawPathImpl.call_clip(instance, fillRule);
    }

    pub fn call_isPointInStroke(instance: *runtime.Instance, x: f64, y: f64) anyerror!bool {
        
        return try CanvasDrawPathImpl.call_isPointInStroke(instance, x, y);
    }

    pub fn call_beginPath(instance: *runtime.Instance) anyerror!void {
        return try CanvasDrawPathImpl.call_beginPath(instance);
    }

    pub fn call_isPointInPath(instance: *runtime.Instance, x: f64, y: f64, fillRule: webidl.Opt(CanvasFillRule)) anyerror!bool {
        
        return try CanvasDrawPathImpl.call_isPointInPath(instance, x, y, fillRule);
    }

    pub fn call_fill(instance: *runtime.Instance, fillRule: webidl.Opt(CanvasFillRule)) anyerror!void {
        
        return try CanvasDrawPathImpl.call_fill(instance, fillRule);
    }

    pub fn call_stroke(instance: *runtime.Instance) anyerror!void {
        return try CanvasDrawPathImpl.call_stroke(instance);
    }

};
