//! Generated from: keyboard-lock.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const KeyboardImpl = @import("impls").Keyboard;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("EventTarget.zig").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const KeyboardLayoutMap = @import("KeyboardLayoutMap.zig").KeyboardLayoutMap;
const EventHandler = @import("typedefs").EventHandler;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("Event.zig").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("EventListener.zig").EventListener;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("Observable.zig").Observable;

pub const Keyboard = struct {
    pub const Meta = struct {
        pub const name = "Keyboard";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onlayoutchange", "get_onlayoutchange", "set_onlayoutchange" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "lock", "call_lock", 0 },
            .{ "unlock", "call_unlock", 0 },
            .{ "getLayoutMap", "call_getLayoutMap", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "lock",
            "unlock",
            "getLayoutMap",
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
            .{ "onlayoutchange", "get_onlayoutchange", "set_onlayoutchange" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onlayoutchange: typedefs.EventHandler = undefined,
            _internal: ?*KeyboardImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onlayoutchange = &get_onlayoutchange,

        .set_onlayoutchange = &set_onlayoutchange,

        .call_getLayoutMap = &call_getLayoutMap,
        .call_lock = &call_lock,
        .call_unlock = &call_unlock,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return KeyboardImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return KeyboardImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        KeyboardImpl.deinit(instance);
    }

    pub fn get_onlayoutchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try KeyboardImpl.get_onlayoutchange(instance);
    }

    pub fn set_onlayoutchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try KeyboardImpl.set_onlayoutchange(instance, value);
    }

    pub fn call_unlock(instance: *runtime.Instance) anyerror!void {
        return try KeyboardImpl.call_unlock(instance);
    }

    pub fn call_getLayoutMap(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try KeyboardImpl.call_getLayoutMap(instance);
    }

    pub fn call_lock(instance: *runtime.Instance, keyCodes: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        
        return try KeyboardImpl.call_lock(instance, keyCodes);
    }

};
