//! Generated from: handwriting-recognition.idl
//! Generated at: 2025-11-28T22:33:19Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HandwritingDrawingImpl = @import("impls").HandwritingDrawing;
const mixins = @import("mixins");
const HandwritingStroke = @import("interfaces").HandwritingStroke;

pub const HandwritingDrawing = struct {
    pub const Meta = struct {
        pub const name = "HandwritingDrawing";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "addStroke", "call_addStroke", 1 },
            .{ "removeStroke", "call_removeStroke", 1 },
            .{ "clear", "call_clear", 0 },
            .{ "getStrokes", "call_getStrokes", 0 },
            .{ "getPrediction", "call_getPrediction", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "addStroke",
            "removeStroke",
            "clear",
            "getStrokes",
            "getPrediction",
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
            _internal: ?*HandwritingDrawingImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_addStroke = &call_addStroke,
        .call_clear = &call_clear,
        .call_getPrediction = &call_getPrediction,
        .call_getStrokes = &call_getStrokes,
        .call_removeStroke = &call_removeStroke,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HandwritingDrawingImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HandwritingDrawingImpl.deinit(instance);
    }

    pub fn call_addStroke(instance: *runtime.Instance, stroke: *runtime.Instance) anyerror!void {
        
        return try HandwritingDrawingImpl.call_addStroke(instance, stroke);
    }

    pub fn call_getStrokes(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try HandwritingDrawingImpl.call_getStrokes(instance);
    }

    pub fn call_getPrediction(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try HandwritingDrawingImpl.call_getPrediction(instance);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try HandwritingDrawingImpl.call_clear(instance);
    }

    pub fn call_removeStroke(instance: *runtime.Instance, stroke: *runtime.Instance) anyerror!void {
        
        return try HandwritingDrawingImpl.call_removeStroke(instance, stroke);
    }

};
