//! Generated from: html.idl
//! Generated at: 2025-11-28T19:11:17Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaErrorImpl = @import("impls").MediaError;
const mixins = @import("mixins");
const DOMString = @import("typedefs").DOMString;

pub const MediaError = struct {
    pub const Meta = struct {
        pub const name = "MediaError";
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
            .{ "code", "get_code", null },
            .{ "message", "get_message", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "MEDIA_ERR_ABORTED", "get_MEDIA_ERR_ABORTED" },
            .{ "MEDIA_ERR_NETWORK", "get_MEDIA_ERR_NETWORK" },
            .{ "MEDIA_ERR_DECODE", "get_MEDIA_ERR_DECODE" },
            .{ "MEDIA_ERR_SRC_NOT_SUPPORTED", "get_MEDIA_ERR_SRC_NOT_SUPPORTED" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "code", "get_code", null },
            .{ "message", "get_message", null },
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
            code: u16 = undefined,
            message: runtime.DOMString = undefined,
            _internal: ?*MediaErrorImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short MEDIA_ERR_ABORTED = 1;
    pub fn get_MEDIA_ERR_ABORTED() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short MEDIA_ERR_NETWORK = 2;
    pub fn get_MEDIA_ERR_NETWORK() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short MEDIA_ERR_DECODE = 3;
    pub fn get_MEDIA_ERR_DECODE() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned short MEDIA_ERR_SRC_NOT_SUPPORTED = 4;
    pub fn get_MEDIA_ERR_SRC_NOT_SUPPORTED() u16 {
        return 4;
    }

    const delegates = .{

        .get_MEDIA_ERR_ABORTED = &get_MEDIA_ERR_ABORTED,
        .get_MEDIA_ERR_DECODE = &get_MEDIA_ERR_DECODE,
        .get_MEDIA_ERR_NETWORK = &get_MEDIA_ERR_NETWORK,
        .get_MEDIA_ERR_SRC_NOT_SUPPORTED = &get_MEDIA_ERR_SRC_NOT_SUPPORTED,
        .get_code = &get_code,
        .get_message = &get_message,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaErrorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaErrorImpl.deinit(instance);
    }

    pub fn get_code(instance: *runtime.Instance) anyerror!u16 {
        return try MediaErrorImpl.get_code(instance);
    }

    pub fn get_message(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaErrorImpl.get_message(instance);
    }

};
