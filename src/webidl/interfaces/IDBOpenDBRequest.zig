//! Generated from: IndexedDB.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IDBOpenDBRequestImpl = @import("impls").IDBOpenDBRequest;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const IDBRequest = @import("IDBRequest.zig").IDBRequest;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const IDBRequestReadyState = @import("enums").IDBRequestReadyState;
const IDBIndex = @import("IDBIndex.zig").IDBIndex;
const IDBTransaction = @import("IDBTransaction.zig").IDBTransaction;
const IDBObjectStore = @import("IDBObjectStore.zig").IDBObjectStore;
const IDBCursor = @import("IDBCursor.zig").IDBCursor;
const Event = @import("Event.zig").Event;
const Observable = @import("Observable.zig").Observable;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("EventListener.zig").EventListener;
const DOMException = @import("DOMException.zig").DOMException;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const IDBOpenDBRequest = struct {
    pub const Meta = struct {
        pub const name = "IDBOpenDBRequest";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = IDBRequest.State;
        pub const ParentInterface = IDBRequest;
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
            .{ "onblocked", "get_onblocked", "set_onblocked" },
            .{ "onupgradeneeded", "get_onupgradeneeded", "set_onupgradeneeded" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
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
            .{ "onblocked", "get_onblocked", "set_onblocked" },
            .{ "onupgradeneeded", "get_onupgradeneeded", "set_onupgradeneeded" },
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
            onblocked: typedefs.EventHandler = undefined,
            onupgradeneeded: typedefs.EventHandler = undefined,
            _internal: ?*IDBOpenDBRequestImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onblocked = &get_onblocked,
        .get_onupgradeneeded = &get_onupgradeneeded,

        .set_onblocked = &set_onblocked,
        .set_onupgradeneeded = &set_onupgradeneeded,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IDBOpenDBRequestImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return IDBOpenDBRequestImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBOpenDBRequestImpl.deinit(instance);
    }

    pub fn get_onblocked(instance: *runtime.Instance) anyerror!EventHandler {
        return try IDBOpenDBRequestImpl.get_onblocked(instance);
    }

    pub fn set_onblocked(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try IDBOpenDBRequestImpl.set_onblocked(instance, value);
    }

    pub fn get_onupgradeneeded(instance: *runtime.Instance) anyerror!EventHandler {
        return try IDBOpenDBRequestImpl.get_onupgradeneeded(instance);
    }

    pub fn set_onupgradeneeded(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try IDBOpenDBRequestImpl.set_onupgradeneeded(instance, value);
    }

};
