//! Generated from: webxr.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRPermissionStatusImpl = @import("impls").XRPermissionStatus;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PermissionStatus = @import("PermissionStatus.zig").PermissionStatus;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const PermissionState = @import("enums").PermissionState;
const EventHandler = @import("typedefs").EventHandler;
const Event = @import("Event.zig").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("EventListener.zig").EventListener;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("Observable.zig").Observable;

pub const XRPermissionStatus = struct {
    pub const Meta = struct {
        pub const name = "XRPermissionStatus";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = PermissionStatus.State;
        pub const ParentInterface = PermissionStatus;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "granted", "get_granted", "set_granted" },
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
            .{ "granted", "get_granted", "set_granted" },
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
            granted: runtime.JSValue = undefined,
            _internal: ?*XRPermissionStatusImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_granted = &get_granted,

        .set_granted = &set_granted,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRPermissionStatusImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return XRPermissionStatusImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRPermissionStatusImpl.deinit(instance);
    }

    pub fn get_granted(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try XRPermissionStatusImpl.get_granted(instance);
    }

    pub fn set_granted(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        try XRPermissionStatusImpl.set_granted(instance, value);
    }

};
