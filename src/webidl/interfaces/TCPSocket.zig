//! Generated from: direct-sockets.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TCPSocketImpl = @import("impls").TCPSocket;
const mixins = @import("mixins");
const TCPSocketOptions = @import("dictionaries").TCPSocketOptions;
const TCPSocketOpenInfo = @import("dictionaries").TCPSocketOpenInfo;
const DOMString = @import("typedefs").DOMString;

pub const TCPSocket = struct {
    pub const Meta = struct {
        pub const name = "TCPSocket";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            opened: runtime.Promise(TCPSocketOpenInfo) = undefined,
            closed: runtime.Promise(void) = undefined,
            _internal: ?*TCPSocketImpl.InternalState = null,
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
        return TCPSocketImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TCPSocketImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, remoteAddress: DOMString, remotePort: u16, options: webidl.Opt(TCPSocketOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TCPSocketImpl.call_constructor(allocator, ctx, remoteAddress, remotePort, options.value);
    }

    pub fn get_opened(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try TCPSocketImpl.get_opened(instance);
    }

    pub fn get_closed(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try TCPSocketImpl.get_closed(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try TCPSocketImpl.call_close(instance);
    }

};
