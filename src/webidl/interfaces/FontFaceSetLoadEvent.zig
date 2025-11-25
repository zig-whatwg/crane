//! Generated from: css-font-loading.idl
//! Generated at: 2025-11-25T20:02:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FontFaceSetLoadEventImpl = @import("impls").FontFaceSetLoadEvent;
const Event = @import("interfaces").Event;
const CSSOMString = @import("typedefs").CSSOMString;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const FontFaceSetLoadEventInit = @import("dictionaries").FontFaceSetLoadEventInit;
const FontFace = @import("interfaces").FontFace;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const FontFaceSetLoadEvent = struct {
    pub const Meta = struct {
        pub const name = "FontFaceSetLoadEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "fontfaces", "get_fontfaces", null },
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
            .{ "fontfaces", "get_fontfaces", null },
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
            fontfaces: runtime.FrozenArray(FontFace) = undefined,
            cached_fontfaces: ?runtime.FrozenArray(FontFace) = null,
            _internal: ?*FontFaceSetLoadEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_fontfaces = &get_fontfaces,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FontFaceSetLoadEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FontFaceSetLoadEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": CSSOMString, eventInitDict: FontFaceSetLoadEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try FontFaceSetLoadEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    /// Extended attributes: [SameObject]
    pub fn get_fontfaces(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_fontfaces) |cached| {
            return cached;
        }
        const value = try FontFaceSetLoadEventImpl.get_fontfaces(instance);
        state.own.cached_fontfaces = value;
        return value;
    }

};
