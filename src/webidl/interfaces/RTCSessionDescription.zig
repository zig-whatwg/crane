//! Generated from: webrtc.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RTCSessionDescriptionImpl = @import("impls").RTCSessionDescription;
const mixins = @import("mixins");
const RTCSessionDescriptionInit = @import("dictionaries").RTCSessionDescriptionInit;
const DOMString = @import("typedefs").DOMString;
const RTCSdpType = @import("enums").RTCSdpType;

pub const RTCSessionDescription = struct {
    pub const Meta = struct {
        pub const name = "RTCSessionDescription";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "type", "get_type", null },
            .{ "sdp", "get_sdp", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "type", "get_type", null },
            .{ "sdp", "get_sdp", null },
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
            @"type": RTCSdpType = undefined,
            sdp: runtime.DOMString = undefined,
            _internal: ?*RTCSessionDescriptionImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_sdp = &get_sdp,
        .get_type = &get_type,

        .call_toJSON = &call_toJSON,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCSessionDescriptionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return RTCSessionDescriptionImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCSessionDescriptionImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, descriptionInitDict: RTCSessionDescriptionInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RTCSessionDescriptionImpl.call_constructor(ctx, descriptionInitDict);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!RTCSdpType {
        return try RTCSessionDescriptionImpl.get_type(instance);
    }

    pub fn get_sdp(instance: *runtime.Instance) anyerror!DOMString {
        return try RTCSessionDescriptionImpl.get_sdp(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!RTCSessionDescriptionInit {
        return try RTCSessionDescriptionImpl.call_toJSON(instance);
    }

};
