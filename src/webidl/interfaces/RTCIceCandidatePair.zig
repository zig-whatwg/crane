//! Generated from: webrtc.idl
//! Generated at: 2025-11-28T03:24:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCIceCandidatePairImpl = @import("impls").RTCIceCandidatePair;
const RTCIceCandidate = @import("interfaces").RTCIceCandidate;

pub const RTCIceCandidatePair = struct {
    pub const Meta = struct {
        pub const name = "RTCIceCandidatePair";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "local", "get_local", null },
            .{ "remote", "get_remote", null },
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
            .{ "local", "get_local", null },
            .{ "remote", "get_remote", null },
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
            local: *runtime.Instance = undefined,
            remote: *runtime.Instance = undefined,
            cached_local: ?*runtime.Instance = null,
            cached_remote: ?*runtime.Instance = null,
            _internal: ?*RTCIceCandidatePairImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_local = &get_local,
        .get_remote = &get_remote,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCIceCandidatePairImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCIceCandidatePairImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_local(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_local) |cached| {
            return cached;
        }
        const value = try RTCIceCandidatePairImpl.get_local(instance);
        state.own.cached_local = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_remote(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_remote) |cached| {
            return cached;
        }
        const value = try RTCIceCandidatePairImpl.get_remote(instance);
        state.own.cached_remote = value;
        return value;
    }

};
