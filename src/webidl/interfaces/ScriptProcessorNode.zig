//! Generated from: webaudio.idl
//! Generated at: 2025-11-23T16:59:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ScriptProcessorNodeImpl = @import("impls").ScriptProcessorNode;
const AudioNode = @import("interfaces").AudioNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const ChannelCountMode = @import("enums").ChannelCountMode;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const AudioParam = @import("interfaces").AudioParam;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const ScriptProcessorNode = struct {
    pub const Meta = struct {
        pub const name = "ScriptProcessorNode";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AudioNode;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onaudioprocess", "get_onaudioprocess", "set_onaudioprocess" },
            .{ "bufferSize", "get_bufferSize", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
            "connect",
            "connect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "onaudioprocess", "get_onaudioprocess", "set_onaudioprocess" },
            .{ "bufferSize", "get_bufferSize", null },
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
            onaudioprocess: EventHandler = undefined,
            bufferSize: i32 = undefined,
            _internal: ?*ScriptProcessorNodeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_bufferSize = &get_bufferSize,
        .get_onaudioprocess = &get_onaudioprocess,

        .set_onaudioprocess = &set_onaudioprocess,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ScriptProcessorNodeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ScriptProcessorNodeImpl.deinit(instance);
    }

    pub fn get_onaudioprocess(instance: *runtime.Instance) anyerror!EventHandler {
        return try ScriptProcessorNodeImpl.get_onaudioprocess(instance);
    }

    pub fn set_onaudioprocess(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ScriptProcessorNodeImpl.set_onaudioprocess(instance, value);
    }

    pub fn get_bufferSize(instance: *runtime.Instance) anyerror!i32 {
        return try ScriptProcessorNodeImpl.get_bufferSize(instance);
    }

};
