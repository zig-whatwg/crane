//! Generated from: css-font-loading.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FontFaceSetLoadEventImpl = @import("impls").FontFaceSetLoadEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Event = @import("Event.zig").Event;
const CSSOMString = @import("typedefs").CSSOMString;
const EventTarget = @import("EventTarget.zig").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const FontFaceSetLoadEventInit = @import("dictionaries").FontFaceSetLoadEventInit;
const FontFace = @import("FontFace.zig").FontFace;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const FontFaceSetLoadEvent = struct {
    pub const Meta = struct {
        pub const name = "FontFaceSetLoadEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
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
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            fontfaces: runtime.JSValue = undefined,
            cached_fontfaces: ?runtime.JSValue = null,
            _internal: ?*FontFaceSetLoadEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_fontfaces = &get_fontfaces,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FontFaceSetLoadEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return FontFaceSetLoadEventImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FontFaceSetLoadEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": CSSOMString, eventInitDict: webidl.Opt(FontFaceSetLoadEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try FontFaceSetLoadEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    /// Extended attributes: [SameObject]
    pub fn get_fontfaces(instance: *runtime.Instance) anyerror!runtime.JSValue {
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
