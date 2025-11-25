//! Generated from: css-scroll-snap-2.idl
//! Generated at: 2025-11-25T20:02:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SnapEventImpl = @import("impls").SnapEvent;
const Event = @import("interfaces").Event;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const SnapEventInit = @import("dictionaries").SnapEventInit;
const Node = @import("interfaces").Node;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const SnapEvent = struct {
    pub const Meta = struct {
        pub const name = "SnapEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "snapTargetBlock", "get_snapTargetBlock", null },
            .{ "snapTargetInline", "get_snapTargetInline", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "snapTargetBlock", "get_snapTargetBlock", null },
            .{ "snapTargetInline", "get_snapTargetInline", null },
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
            snapTargetBlock: ?*runtime.Instance = null,
            snapTargetInline: ?*runtime.Instance = null,
            _internal: ?*SnapEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_snapTargetBlock = &get_snapTargetBlock,
        .get_snapTargetInline = &get_snapTargetInline,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SnapEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SnapEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: SnapEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SnapEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_snapTargetBlock(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try SnapEventImpl.get_snapTargetBlock(instance);
    }

    pub fn get_snapTargetInline(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try SnapEventImpl.get_snapTargetInline(instance);
    }

};
