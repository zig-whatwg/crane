//! Generated from: webxr-hit-test.idl
//! Generated at: 2025-11-29T05:01:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRTransientInputHitTestResultImpl = @import("impls").XRTransientInputHitTestResult;
const mixins = @import("mixins");
const XRInputSource = @import("interfaces").XRInputSource;
const XRHitTestResult = @import("interfaces").XRHitTestResult;

pub const XRTransientInputHitTestResult = struct {
    pub const Meta = struct {
        pub const name = "XRTransientInputHitTestResult";
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
            .{ "inputSource", "get_inputSource", null },
            .{ "results", "get_results", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "inputSource", "get_inputSource", null },
            .{ "results", "get_results", null },
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
            inputSource: *runtime.Instance = undefined,
            results: runtime.FrozenArray(XRHitTestResult) = undefined,
            cached_inputSource: ?*runtime.Instance = null,
            _internal: ?*XRTransientInputHitTestResultImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_inputSource = &get_inputSource,
        .get_results = &get_results,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRTransientInputHitTestResultImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRTransientInputHitTestResultImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_inputSource(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_inputSource) |cached| {
            return cached;
        }
        const value = try XRTransientInputHitTestResultImpl.get_inputSource(instance);
        state.own.cached_inputSource = value;
        return value;
    }

    pub fn get_results(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try XRTransientInputHitTestResultImpl.get_results(instance);
    }

};
