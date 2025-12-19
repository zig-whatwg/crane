//! Generated from: media-source.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SourceBufferListImpl = @import("impls").SourceBufferList;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const SourceBuffer = @import("interfaces").SourceBuffer;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const SourceBufferList = struct {
    pub const Meta = struct {
        pub const name = "SourceBufferList";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "length", "get_length", null },
            .{ "onaddsourcebuffer", "get_onaddsourcebuffer", "set_onaddsourcebuffer" },
            .{ "onremovesourcebuffer", "get_onremovesourcebuffer", "set_onremovesourcebuffer" },
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
            .{ "length", "get_length", null },
            .{ "onaddsourcebuffer", "get_onaddsourcebuffer", "set_onaddsourcebuffer" },
            .{ "onremovesourcebuffer", "get_onremovesourcebuffer", "set_onremovesourcebuffer" },
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
            length: u32 = undefined,
            onaddsourcebuffer: EventHandler = undefined,
            onremovesourcebuffer: EventHandler = undefined,
            _internal: ?*SourceBufferListImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_length = &get_length,
        .get_onaddsourcebuffer = &get_onaddsourcebuffer,
        .get_onremovesourcebuffer = &get_onremovesourcebuffer,

        .set_onaddsourcebuffer = &set_onaddsourcebuffer,
        .set_onremovesourcebuffer = &set_onremovesourcebuffer,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SourceBufferListImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return SourceBufferListImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SourceBufferListImpl.deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try SourceBufferListImpl.get_length(instance);
    }

    pub fn get_onaddsourcebuffer(instance: *runtime.Instance) anyerror!EventHandler {
        return try SourceBufferListImpl.get_onaddsourcebuffer(instance);
    }

    pub fn set_onaddsourcebuffer(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SourceBufferListImpl.set_onaddsourcebuffer(instance, value);
    }

    pub fn get_onremovesourcebuffer(instance: *runtime.Instance) anyerror!EventHandler {
        return try SourceBufferListImpl.get_onremovesourcebuffer(instance);
    }

    pub fn set_onremovesourcebuffer(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SourceBufferListImpl.set_onremovesourcebuffer(instance, value);
    }

    pub fn call_getter(instance: *runtime.Instance, index: u32) anyerror!*runtime.Instance {
        
        return try SourceBufferListImpl.call_getter(instance, index);
    }

};
