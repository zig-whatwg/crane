//! Generated from: webgpu.idl
//! Generated at: 2025-12-07T19:33:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const GPUDebugCommandsMixinImpl = @import("impls").GPUDebugCommandsMixin;
const mixins = @import("mixins");
const USVString = @import("interfaces").USVString;

pub const GPUDebugCommandsMixin = struct {
    pub const Meta = struct {
        pub const name = "GPUDebugCommandsMixin";
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
            .{ "pushDebugGroup", "call_pushDebugGroup", 1 },
            .{ "popDebugGroup", "call_popDebugGroup", 0 },
            .{ "insertDebugMarker", "call_insertDebugMarker", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "pushDebugGroup",
            "popDebugGroup",
            "insertDebugMarker",
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
            _internal: ?*GPUDebugCommandsMixinImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_insertDebugMarker = &call_insertDebugMarker,
        .call_popDebugGroup = &call_popDebugGroup,
        .call_pushDebugGroup = &call_pushDebugGroup,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPUDebugCommandsMixinImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUDebugCommandsMixinImpl.deinit(instance);
    }

    pub fn call_insertDebugMarker(instance: *runtime.Instance, markerLabel: runtime.USVString) anyerror!void {
        
        return try GPUDebugCommandsMixinImpl.call_insertDebugMarker(instance, markerLabel);
    }

    pub fn call_pushDebugGroup(instance: *runtime.Instance, groupLabel: runtime.USVString) anyerror!void {
        
        return try GPUDebugCommandsMixinImpl.call_pushDebugGroup(instance, groupLabel);
    }

    pub fn call_popDebugGroup(instance: *runtime.Instance) anyerror!void {
        return try GPUDebugCommandsMixinImpl.call_popDebugGroup(instance);
    }

};
