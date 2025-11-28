//! Generated from: datacue.idl
//! Generated at: 2025-11-28T18:57:55Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DataCueImpl = @import("impls").DataCue;
const mixins = @import("mixins");
const TextTrackCue = @import("interfaces").TextTrackCue;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const TextTrack = @import("interfaces").TextTrack;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const DataCue = struct {
    pub const Meta = struct {
        pub const name = "DataCue";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *TextTrackCue;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "value", "get_value", "set_value" },
            .{ "type", "get_type", null },
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
            .{ "value", "get_value", "set_value" },
            .{ "type", "get_type", null },
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
            value: *const anyopaque = undefined,
            @"type": runtime.DOMString = undefined,
            _internal: ?*DataCueImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_type = &get_type,
        .get_value = &get_value,

        .set_value = &set_value,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DataCueImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DataCueImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, startTime: f64, endTime: f64, value: *const anyopaque, @"type": webidl.Opt(DOMString)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DataCueImpl.call_constructor(allocator, ctx, startTime, endTime, value, @"type");
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try DataCueImpl.get_value(instance);
    }

    pub fn set_value(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try DataCueImpl.set_value(instance, value);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try DataCueImpl.get_type(instance);
    }

};
