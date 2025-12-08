//! Generated from: handwriting-recognition.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HandwritingStrokeImpl = @import("impls").HandwritingStroke;
const mixins = @import("mixins");
const HandwritingPoint = @import("dictionaries").HandwritingPoint;

pub const HandwritingStroke = struct {
    pub const Meta = struct {
        pub const name = "HandwritingStroke";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "addPoint", "call_addPoint", 1 },
            .{ "getPoints", "call_getPoints", 0 },
            .{ "clear", "call_clear", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "addPoint",
            "getPoints",
            "clear",
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
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*HandwritingStrokeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_addPoint = &call_addPoint,
        .call_clear = &call_clear,
        .call_getPoints = &call_getPoints,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HandwritingStrokeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HandwritingStrokeImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HandwritingStrokeImpl.call_constructor(allocator, ctx);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try HandwritingStrokeImpl.call_clear(instance);
    }

    pub fn call_getPoints(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try HandwritingStrokeImpl.call_getPoints(instance);
    }

    pub fn call_addPoint(instance: *runtime.Instance, point: HandwritingPoint) anyerror!void {
        
        return try HandwritingStrokeImpl.call_addPoint(instance, point);
    }

};
