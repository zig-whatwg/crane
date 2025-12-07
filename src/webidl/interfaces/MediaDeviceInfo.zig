//! Generated from: mediacapture-streams.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaDeviceInfoImpl = @import("impls").MediaDeviceInfo;
const mixins = @import("mixins");
const MediaDeviceKind = @import("enums").MediaDeviceKind;
const DOMString = @import("typedefs").DOMString;

pub const MediaDeviceInfo = struct {
    pub const Meta = struct {
        pub const name = "MediaDeviceInfo";
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
            .{ "deviceId", "get_deviceId", null },
            .{ "kind", "get_kind", null },
            .{ "label", "get_label", null },
            .{ "groupId", "get_groupId", null },
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
            .{ "deviceId", "get_deviceId", null },
            .{ "kind", "get_kind", null },
            .{ "label", "get_label", null },
            .{ "groupId", "get_groupId", null },
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
            deviceId: runtime.DOMString = undefined,
            kind: MediaDeviceKind = undefined,
            label: runtime.DOMString = undefined,
            groupId: runtime.DOMString = undefined,
            _internal: ?*MediaDeviceInfoImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_deviceId = &get_deviceId,
        .get_groupId = &get_groupId,
        .get_kind = &get_kind,
        .get_label = &get_label,

        .call_toJSON = &call_toJSON,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaDeviceInfoImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaDeviceInfoImpl.deinit(instance);
    }

    pub fn get_deviceId(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaDeviceInfoImpl.get_deviceId(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) anyerror!MediaDeviceKind {
        return try MediaDeviceInfoImpl.get_kind(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaDeviceInfoImpl.get_label(instance);
    }

    pub fn get_groupId(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaDeviceInfoImpl.get_groupId(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MediaDeviceInfoImpl.call_toJSON(instance);
    }

};
