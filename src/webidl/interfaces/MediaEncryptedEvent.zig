//! Generated from: encrypted-media.idl
//! Generated at: 2025-11-23T16:59:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaEncryptedEventImpl = @import("impls").MediaEncryptedEvent;
const Event = @import("interfaces").Event;
const MediaEncryptedEventInit = @import("dictionaries").MediaEncryptedEventInit;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const MediaEncryptedEvent = struct {
    pub const Meta = struct {
        pub const name = "MediaEncryptedEvent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "initDataType", "get_initDataType", null },
            .{ "initData", "get_initData", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "initDataType", "get_initDataType", null },
            .{ "initData", "get_initData", null },
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
            initDataType: runtime.DOMString = undefined,
            initData: ?runtime.ArrayBuffer = null,
            _internal: ?*MediaEncryptedEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_initData = &get_initData,
        .get_initDataType = &get_initDataType,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaEncryptedEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaEncryptedEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: MediaEncryptedEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MediaEncryptedEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_initDataType(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaEncryptedEventImpl.get_initDataType(instance);
    }

    pub fn get_initData(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try MediaEncryptedEventImpl.get_initData(instance);
    }

};
