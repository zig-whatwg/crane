//! Generated from: html.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DragEventImpl = @import("impls").DragEvent;
const mixins = @import("mixins");
const MouseEvent = @import("interfaces").MouseEvent;
const UIEventInit = @import("dictionaries").UIEventInit;
const Window = @import("interfaces").Window;
const EventTarget = @import("interfaces").EventTarget;
const InputDeviceCapabilities = @import("interfaces").InputDeviceCapabilities;
const DragEventInit = @import("dictionaries").DragEventInit;
const DataTransfer = @import("interfaces").DataTransfer;
const MouseEventInit = @import("dictionaries").MouseEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const DOMString = @import("typedefs").DOMString;
const EventInit = @import("dictionaries").EventInit;

pub const DragEvent = struct {
    pub const Meta = struct {
        pub const name = "DragEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *MouseEvent;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "dataTransfer", "get_dataTransfer", null },
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
            "initUIEvent",
            "getModifierState",
            "initMouseEvent",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "dataTransfer", "get_dataTransfer", null },
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
            dataTransfer: ?*runtime.Instance = null,
            _internal: ?*DragEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_dataTransfer = &get_dataTransfer,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DragEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DragEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: webidl.Opt(DragEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DragEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict.value);
    }

    pub fn get_dataTransfer(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DragEventImpl.get_dataTransfer(instance);
    }

};
