//! Generated from: webgpu.idl
//! Generated at: 2025-11-25T13:07:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUCompilationMessageImpl = @import("impls").GPUCompilationMessage;
const GPUCompilationMessageType = @import("enums").GPUCompilationMessageType;
const DOMString = @import("typedefs").DOMString;

pub const GPUCompilationMessage = struct {
    pub const Meta = struct {
        pub const name = "GPUCompilationMessage";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "message", "get_message", null },
            .{ "type", "get_type", null },
            .{ "lineNum", "get_lineNum", null },
            .{ "linePos", "get_linePos", null },
            .{ "offset", "get_offset", null },
            .{ "length", "get_length", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "message", "get_message", null },
            .{ "type", "get_type", null },
            .{ "lineNum", "get_lineNum", null },
            .{ "linePos", "get_linePos", null },
            .{ "offset", "get_offset", null },
            .{ "length", "get_length", null },
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
            message: runtime.DOMString = undefined,
            @"type": GPUCompilationMessageType = undefined,
            lineNum: u64 = undefined,
            linePos: u64 = undefined,
            offset: u64 = undefined,
            length: u64 = undefined,
            _internal: ?*GPUCompilationMessageImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_length = &get_length,
        .get_lineNum = &get_lineNum,
        .get_linePos = &get_linePos,
        .get_message = &get_message,
        .get_offset = &get_offset,
        .get_type = &get_type,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPUCompilationMessageImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUCompilationMessageImpl.deinit(instance);
    }

    pub fn get_message(instance: *runtime.Instance) anyerror!DOMString {
        return try GPUCompilationMessageImpl.get_message(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!GPUCompilationMessageType {
        return try GPUCompilationMessageImpl.get_type(instance);
    }

    pub fn get_lineNum(instance: *runtime.Instance) anyerror!u64 {
        return try GPUCompilationMessageImpl.get_lineNum(instance);
    }

    pub fn get_linePos(instance: *runtime.Instance) anyerror!u64 {
        return try GPUCompilationMessageImpl.get_linePos(instance);
    }

    pub fn get_offset(instance: *runtime.Instance) anyerror!u64 {
        return try GPUCompilationMessageImpl.get_offset(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u64 {
        return try GPUCompilationMessageImpl.get_length(instance);
    }

};
