//! Generated from: web-nfc.idl
//! Generated at: 2025-11-23T19:47:42Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NDEFReaderImpl = @import("impls").NDEFReader;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const NDEFMessageSource = @import("typedefs").NDEFMessageSource;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const EventHandler = @import("typedefs").EventHandler;
const NDEFMakeReadOnlyOptions = @import("dictionaries").NDEFMakeReadOnlyOptions;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const NDEFScanOptions = @import("dictionaries").NDEFScanOptions;
const DOMString = @import("typedefs").DOMString;
const NDEFWriteOptions = @import("dictionaries").NDEFWriteOptions;

pub const NDEFReader = struct {
    pub const Meta = struct {
        pub const name = "NDEFReader";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onreading", "get_onreading", "set_onreading" },
            .{ "onreadingerror", "get_onreadingerror", "set_onreadingerror" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "scan", "call_scan", 0 },
            .{ "write", "call_write", 1 },
            .{ "makeReadOnly", "call_makeReadOnly", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "scan",
            "write",
            "makeReadOnly",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "onreading", "get_onreading", "set_onreading" },
            .{ "onreadingerror", "get_onreadingerror", "set_onreadingerror" },
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
            onreading: EventHandler = undefined,
            onreadingerror: EventHandler = undefined,
            _internal: ?*NDEFReaderImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onreading = &get_onreading,
        .get_onreadingerror = &get_onreadingerror,

        .set_onreading = &set_onreading,
        .set_onreadingerror = &set_onreadingerror,

        .call_makeReadOnly = &call_makeReadOnly,
        .call_scan = &call_scan,
        .call_write = &call_write,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NDEFReaderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NDEFReaderImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try NDEFReaderImpl.call_constructor(allocator, ctx);
    }

    pub fn get_onreading(instance: *runtime.Instance) anyerror!EventHandler {
        return try NDEFReaderImpl.get_onreading(instance);
    }

    pub fn set_onreading(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NDEFReaderImpl.set_onreading(instance, value);
    }

    pub fn get_onreadingerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try NDEFReaderImpl.get_onreadingerror(instance);
    }

    pub fn set_onreadingerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NDEFReaderImpl.set_onreadingerror(instance, value);
    }

    pub fn call_scan(instance: *runtime.Instance, options: NDEFScanOptions) anyerror!*const anyopaque {
        
        return try NDEFReaderImpl.call_scan(instance, options);
    }

    pub fn call_write(instance: *runtime.Instance, message: NDEFMessageSource, options: NDEFWriteOptions) anyerror!*const anyopaque {
        
        return try NDEFReaderImpl.call_write(instance, message, options);
    }

    pub fn call_makeReadOnly(instance: *runtime.Instance, options: NDEFMakeReadOnlyOptions) anyerror!*const anyopaque {
        
        return try NDEFReaderImpl.call_makeReadOnly(instance, options);
    }

};
