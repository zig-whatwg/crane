//! Generated from: webtransport.idl
//! Generated at: 2025-11-23T16:59:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebTransportErrorImpl = @import("impls").WebTransportError;
const DOMException = @import("interfaces").DOMException;
const WebTransportErrorOptions = @import("dictionaries").WebTransportErrorOptions;
const DOMString = @import("typedefs").DOMString;
const WebTransportErrorSource = @import("enums").WebTransportErrorSource;

pub const WebTransportError = struct {
    pub const Meta = struct {
        pub const name = "WebTransportError";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *DOMException;
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
            .{ "source", "get_source", null },
            .{ "streamErrorCode", "get_streamErrorCode", null },
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
            .{ "source", "get_source", null },
            .{ "streamErrorCode", "get_streamErrorCode", null },
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
            source: WebTransportErrorSource = undefined,
            streamErrorCode: ?u32 = null,
            _internal: ?*WebTransportErrorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_source = &get_source,
        .get_streamErrorCode = &get_streamErrorCode,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WebTransportErrorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebTransportErrorImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, message: DOMString, options: WebTransportErrorOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try WebTransportErrorImpl.call_constructor(allocator, ctx, message, options);
    }

    pub fn get_source(instance: *runtime.Instance) anyerror!WebTransportErrorSource {
        return try WebTransportErrorImpl.get_source(instance);
    }

    pub fn get_streamErrorCode(instance: *runtime.Instance) anyerror!u32 {
        return try WebTransportErrorImpl.get_streamErrorCode(instance);
    }

};
