//! Generated from: web-smart-card.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SmartCardContextImpl = @import("impls").SmartCardContext;
const mixins = @import("mixins");
const SmartCardReaderStateIn = @import("dictionaries").SmartCardReaderStateIn;
const SmartCardGetStatusChangeOptions = @import("dictionaries").SmartCardGetStatusChangeOptions;
const SmartCardAccessMode = @import("enums").SmartCardAccessMode;
const SmartCardConnectOptions = @import("dictionaries").SmartCardConnectOptions;
const SmartCardConnectResult = @import("dictionaries").SmartCardConnectResult;
const DOMString = @import("typedefs").DOMString;

pub const SmartCardContext = struct {
    pub const Meta = struct {
        pub const name = "SmartCardContext";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "DedicatedWorker", "SharedWorker", "Window" } } },
            .{ .name = "SecureContext" },
            .{ .name = "IsolatedContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .DedicatedWorker = true,
            .SharedWorker = true,
            .Window = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "listReaders", "call_listReaders", 0 },
            .{ "getStatusChange", "call_getStatusChange", 1 },
            .{ "connect", "call_connect", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "listReaders",
            "getStatusChange",
            "connect",
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
            _internal: ?*SmartCardContextImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_connect = &call_connect,
        .call_getStatusChange = &call_getStatusChange,
        .call_listReaders = &call_listReaders,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SmartCardContextImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SmartCardContextImpl.deinit(instance);
    }

    pub fn call_listReaders(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try SmartCardContextImpl.call_listReaders(instance);
    }

    pub fn call_getStatusChange(instance: *runtime.Instance, readerStates: *const anyopaque, options: webidl.Opt(SmartCardGetStatusChangeOptions)) anyerror!*const anyopaque {
        
        return try SmartCardContextImpl.call_getStatusChange(instance, readerStates, options);
    }

    pub fn call_connect(instance: *runtime.Instance, readerName: DOMString, accessMode: SmartCardAccessMode, options: webidl.Opt(SmartCardConnectOptions)) anyerror!*const anyopaque {
        
        return try SmartCardContextImpl.call_connect(instance, readerName, accessMode, options);
    }

};
