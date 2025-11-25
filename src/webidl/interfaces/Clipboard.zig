//! Generated from: clipboard-apis.idl
//! Generated at: 2025-11-25T19:42:24Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ClipboardImpl = @import("impls").Clipboard;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ClipboardUnsanitizedFormats = @import("dictionaries").ClipboardUnsanitizedFormats;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const ClipboardItems = @import("typedefs").ClipboardItems;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;

pub const Clipboard = struct {
    pub const Meta = struct {
        pub const name = "Clipboard";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "read", "call_read", 0 },
            .{ "readText", "call_readText", 0 },
            .{ "write", "call_write", 1 },
            .{ "writeText", "call_writeText", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "read",
            "readText",
            "write",
            "writeText",
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
            _internal: ?*ClipboardImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_read = &call_read,
        .call_readText = &call_readText,
        .call_write = &call_write,
        .call_writeText = &call_writeText,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ClipboardImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ClipboardImpl.deinit(instance);
    }

    pub fn call_read(instance: *runtime.Instance, formats: ClipboardUnsanitizedFormats) anyerror!*const anyopaque {
        
        return try ClipboardImpl.call_read(instance, formats);
    }

    pub fn call_write(instance: *runtime.Instance, data: ClipboardItems) anyerror!*const anyopaque {
        
        return try ClipboardImpl.call_write(instance, data);
    }

    pub fn call_readText(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ClipboardImpl.call_readText(instance);
    }

    pub fn call_writeText(instance: *runtime.Instance, data: DOMString) anyerror!*const anyopaque {
        
        return try ClipboardImpl.call_writeText(instance, data);
    }

};
