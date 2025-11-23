//! Generated from: direct-sockets.idl
//! Generated at: 2025-11-23T19:17:35Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TCPServerSocketImpl = @import("impls").TCPServerSocket;
const TCPServerSocketOptions = @import("dictionaries").TCPServerSocketOptions;
const DOMString = @import("typedefs").DOMString;
const TCPServerSocketOpenInfo = @import("dictionaries").TCPServerSocketOpenInfo;

pub const TCPServerSocket = struct {
    pub const Meta = struct {
        pub const name = "TCPServerSocket";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "SecureContext" },
            .{ .name = "IsolatedContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "opened", "get_opened", null },
            .{ "closed", "get_closed", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "close", "call_close", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "close",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "opened", "get_opened", null },
            .{ "closed", "get_closed", null },
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
            opened: runtime.Promise(TCPServerSocketOpenInfo) = undefined,
            closed: runtime.Promise(void) = undefined,
            _internal: ?*TCPServerSocketImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_closed = &get_closed,
        .get_opened = &get_opened,

        .call_close = &call_close,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TCPServerSocketImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TCPServerSocketImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, localAddress: DOMString, options: TCPServerSocketOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TCPServerSocketImpl.call_constructor(allocator, ctx, localAddress, options);
    }

    pub fn get_opened(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try TCPServerSocketImpl.get_opened(instance);
    }

    pub fn get_closed(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try TCPServerSocketImpl.get_closed(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try TCPServerSocketImpl.call_close(instance);
    }

};
