//! Generated from: WEBGL_multi_draw.idl
//! Generated at: 2025-11-23T20:06:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_multi_drawImpl = @import("impls").WEBGL_multi_draw;
const GLenum = @import("typedefs").GLenum;
const sequence = @import("interfaces").sequence;
const GLsizei = @import("typedefs").GLsizei;

pub const WEBGL_multi_draw = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_multi_draw";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "LegacyNoInterfaceObject" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "multiDrawArraysWEBGL", "call_multiDrawArraysWEBGL", 6 },
            .{ "multiDrawElementsWEBGL", "call_multiDrawElementsWEBGL", 7 },
            .{ "multiDrawArraysInstancedWEBGL", "call_multiDrawArraysInstancedWEBGL", 8 },
            .{ "multiDrawElementsInstancedWEBGL", "call_multiDrawElementsInstancedWEBGL", 9 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "multiDrawArraysWEBGL",
            "multiDrawElementsWEBGL",
            "multiDrawArraysInstancedWEBGL",
            "multiDrawElementsInstancedWEBGL",
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
        struct {},
    );

    const delegates = .{

        .call_multiDrawArraysInstancedWEBGL = &call_multiDrawArraysInstancedWEBGL,
        .call_multiDrawArraysWEBGL = &call_multiDrawArraysWEBGL,
        .call_multiDrawElementsInstancedWEBGL = &call_multiDrawElementsInstancedWEBGL,
        .call_multiDrawElementsWEBGL = &call_multiDrawElementsWEBGL,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WEBGL_multi_drawImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_multi_drawImpl.deinit(instance);
    }

    pub fn call_multiDrawArraysWEBGL(instance: *runtime.Instance, mode: GLenum, firstsList: *const anyopaque, firstsOffset: u64, countsList: *const anyopaque, countsOffset: u64, drawcount: GLsizei) anyerror!void {
        
        return try WEBGL_multi_drawImpl.call_multiDrawArraysWEBGL(instance, mode, firstsList, firstsOffset, countsList, countsOffset, drawcount);
    }

    pub fn call_multiDrawElementsWEBGL(instance: *runtime.Instance, mode: GLenum, countsList: *const anyopaque, countsOffset: u64, @"type": GLenum, offsetsList: *const anyopaque, offsetsOffset: u64, drawcount: GLsizei) anyerror!void {
        
        return try WEBGL_multi_drawImpl.call_multiDrawElementsWEBGL(instance, mode, countsList, countsOffset, @"type", offsetsList, offsetsOffset, drawcount);
    }

    pub fn call_multiDrawArraysInstancedWEBGL(instance: *runtime.Instance, mode: GLenum, firstsList: *const anyopaque, firstsOffset: u64, countsList: *const anyopaque, countsOffset: u64, instanceCountsList: *const anyopaque, instanceCountsOffset: u64, drawcount: GLsizei) anyerror!void {
        
        return try WEBGL_multi_drawImpl.call_multiDrawArraysInstancedWEBGL(instance, mode, firstsList, firstsOffset, countsList, countsOffset, instanceCountsList, instanceCountsOffset, drawcount);
    }

    pub fn call_multiDrawElementsInstancedWEBGL(instance: *runtime.Instance, mode: GLenum, countsList: *const anyopaque, countsOffset: u64, @"type": GLenum, offsetsList: *const anyopaque, offsetsOffset: u64, instanceCountsList: *const anyopaque, instanceCountsOffset: u64, drawcount: GLsizei) anyerror!void {
        
        return try WEBGL_multi_drawImpl.call_multiDrawElementsInstancedWEBGL(instance, mode, countsList, countsOffset, @"type", offsetsList, offsetsOffset, instanceCountsList, instanceCountsOffset, drawcount);
    }

};
