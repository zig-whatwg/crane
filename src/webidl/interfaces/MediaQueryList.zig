//! Generated from: cssom-view.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaQueryListImpl = @import("impls").MediaQueryList;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const CSSOMString = @import("typedefs").CSSOMString;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const MediaQueryList = struct {
    pub const Meta = struct {
        pub const name = "MediaQueryList";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
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
            .{ "onchange", "get_onchange", "set_onchange" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "addListener", "call_addListener", 1 },
            .{ "removeListener", "call_removeListener", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "addListener",
            "removeListener",
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
            .{ "media", "get_media", null },
            .{ "matches", "get_matches", null },
            .{ "onchange", "get_onchange", "set_onchange" },
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
            media: typedefs.CSSOMString = undefined,
            matches: bool = undefined,
            onchange: typedefs.EventHandler = undefined,
            _internal: ?*MediaQueryListImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_matches = &get_matches,
        .get_media = &get_media,
        .get_onchange = &get_onchange,

        .set_onchange = &set_onchange,

        .call_addListener = &call_addListener,
        .call_removeListener = &call_removeListener,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaQueryListImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return MediaQueryListImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaQueryListImpl.deinit(instance);
    }

    pub fn get_media(instance: *runtime.Instance) anyerror!CSSOMString {
        return try MediaQueryListImpl.get_media(instance);
    }

    pub fn get_matches(instance: *runtime.Instance) anyerror!bool {
        return try MediaQueryListImpl.get_matches(instance);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaQueryListImpl.get_onchange(instance);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaQueryListImpl.set_onchange(instance, value);
    }

    pub fn call_addListener(instance: *runtime.Instance, callback: ??*runtime.CallbackWrapper) anyerror!void {
        
        return try MediaQueryListImpl.call_addListener(instance, callback);
    }

    pub fn call_removeListener(instance: *runtime.Instance, callback: ??*runtime.CallbackWrapper) anyerror!void {
        
        return try MediaQueryListImpl.call_removeListener(instance, callback);
    }

};
