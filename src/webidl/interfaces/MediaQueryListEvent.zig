//! Generated from: cssom-view.idl
//! Generated at: 2025-11-23T20:06:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaQueryListEventImpl = @import("impls").MediaQueryListEvent;
const Event = @import("interfaces").Event;
const CSSOMString = @import("typedefs").CSSOMString;
const MediaQueryListEventInit = @import("dictionaries").MediaQueryListEventInit;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const MediaQueryListEvent = struct {
    pub const Meta = struct {
        pub const name = "MediaQueryListEvent";
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
            .{ "media", "get_media", null },
            .{ "matches", "get_matches", null },
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
            .{ "media", "get_media", null },
            .{ "matches", "get_matches", null },
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
            media: CSSOMString = undefined,
            matches: bool = undefined,
            _internal: ?*MediaQueryListEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_matches = &get_matches,
        .get_media = &get_media,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaQueryListEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaQueryListEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": CSSOMString, eventInitDict: MediaQueryListEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MediaQueryListEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_media(instance: *runtime.Instance) anyerror!CSSOMString {
        return try MediaQueryListEventImpl.get_media(instance);
    }

    pub fn get_matches(instance: *runtime.Instance) anyerror!bool {
        return try MediaQueryListEventImpl.get_matches(instance);
    }

};
