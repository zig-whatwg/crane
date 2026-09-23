//! Generated from: webaudio.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AudioNodeImpl = @import("impls").AudioNode;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ChannelCountMode = @import("enums").ChannelCountMode;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const AudioParam = @import("interfaces").AudioParam;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;

pub const AudioNode = struct {
    pub const Meta = struct {
        pub const name = "AudioNode";
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
            .{ "context", "get_context", null },
            .{ "numberOfInputs", "get_numberOfInputs", null },
            .{ "numberOfOutputs", "get_numberOfOutputs", null },
            .{ "channelCount", "get_channelCount", "set_channelCount" },
            .{ "channelCountMode", "get_channelCountMode", "set_channelCountMode" },
            .{ "channelInterpretation", "get_channelInterpretation", "set_channelInterpretation" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "connect", "call_connect", 1 },
            .{ "disconnect", "call_disconnect", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "connect",
            "disconnect",
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
            .{ "context", "get_context", null },
            .{ "numberOfInputs", "get_numberOfInputs", null },
            .{ "numberOfOutputs", "get_numberOfOutputs", null },
            .{ "channelCount", "get_channelCount", "set_channelCount" },
            .{ "channelCountMode", "get_channelCountMode", "set_channelCountMode" },
            .{ "channelInterpretation", "get_channelInterpretation", "set_channelInterpretation" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            context: *runtime.Instance = undefined,
            numberOfInputs: u32 = undefined,
            numberOfOutputs: u32 = undefined,
            channelCount: u32 = undefined,
            channelCountMode: enums.ChannelCountMode = undefined,
            channelInterpretation: enums.ChannelInterpretation = undefined,
            _internal: ?*AudioNodeImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_channelCount = &get_channelCount,
        .get_channelCountMode = &get_channelCountMode,
        .get_channelInterpretation = &get_channelInterpretation,
        .get_context = &get_context,
        .get_numberOfInputs = &get_numberOfInputs,
        .get_numberOfOutputs = &get_numberOfOutputs,

        .set_channelCount = &set_channelCount,
        .set_channelCountMode = &set_channelCountMode,
        .set_channelInterpretation = &set_channelInterpretation,

        .call_connect = &call_connect,
        .call_disconnect = &call_disconnect,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AudioNodeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return AudioNodeImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioNodeImpl.deinit(instance);
    }

    pub fn get_context(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioNodeImpl.get_context(instance);
    }

    pub fn get_numberOfInputs(instance: *runtime.Instance) anyerror!u32 {
        return try AudioNodeImpl.get_numberOfInputs(instance);
    }

    pub fn get_numberOfOutputs(instance: *runtime.Instance) anyerror!u32 {
        return try AudioNodeImpl.get_numberOfOutputs(instance);
    }

    pub fn get_channelCount(instance: *runtime.Instance) anyerror!u32 {
        return try AudioNodeImpl.get_channelCount(instance);
    }

    pub fn set_channelCount(instance: *runtime.Instance, value: u32) anyerror!void {
        try AudioNodeImpl.set_channelCount(instance, value);
    }

    pub fn get_channelCountMode(instance: *runtime.Instance) anyerror!ChannelCountMode {
        return try AudioNodeImpl.get_channelCountMode(instance);
    }

    pub fn set_channelCountMode(instance: *runtime.Instance, value: ChannelCountMode) anyerror!void {
        try AudioNodeImpl.set_channelCountMode(instance, value);
    }

    pub fn get_channelInterpretation(instance: *runtime.Instance) anyerror!ChannelInterpretation {
        return try AudioNodeImpl.get_channelInterpretation(instance);
    }

    pub fn set_channelInterpretation(instance: *runtime.Instance, value: ChannelInterpretation) anyerror!void {
        try AudioNodeImpl.set_channelInterpretation(instance, value);
    }

    pub fn call_connect(instance: *runtime.Instance, destinationNode: *runtime.Instance, output: webidl.Opt(u32), input: webidl.Opt(u32)) anyerror!*runtime.Instance {
        return try AudioNodeImpl.call_connect(instance, destinationNode, output, input);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
        return try AudioNodeImpl.call_disconnect(instance);
    }

    pub fn call_connect__1(instance: *runtime.Instance, destinationParam: *runtime.Instance, output: webidl.Opt(u32)) anyerror!void {
        if (comptime @hasDecl(AudioNodeImpl, "call_connect__1")) {
            return try AudioNodeImpl.call_connect__1(instance, destinationParam, output);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_disconnect__1(instance: *runtime.Instance, output: u32) anyerror!void {
        if (comptime @hasDecl(AudioNodeImpl, "call_disconnect__1")) {
            return try AudioNodeImpl.call_disconnect__1(instance, output);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_disconnect__2(instance: *runtime.Instance, destinationNode: *runtime.Instance) anyerror!void {
        if (comptime @hasDecl(AudioNodeImpl, "call_disconnect__2")) {
            return try AudioNodeImpl.call_disconnect__2(instance, destinationNode);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_disconnect__3(instance: *runtime.Instance, destinationNode: *runtime.Instance, output: u32) anyerror!void {
        if (comptime @hasDecl(AudioNodeImpl, "call_disconnect__3")) {
            return try AudioNodeImpl.call_disconnect__3(instance, destinationNode, output);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_disconnect__4(instance: *runtime.Instance, destinationNode: *runtime.Instance, output: u32, input: u32) anyerror!void {
        if (comptime @hasDecl(AudioNodeImpl, "call_disconnect__4")) {
            return try AudioNodeImpl.call_disconnect__4(instance, destinationNode, output, input);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_disconnect__5(instance: *runtime.Instance, destinationParam: *runtime.Instance) anyerror!void {
        if (comptime @hasDecl(AudioNodeImpl, "call_disconnect__5")) {
            return try AudioNodeImpl.call_disconnect__5(instance, destinationParam);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_disconnect__6(instance: *runtime.Instance, destinationParam: *runtime.Instance, output: u32) anyerror!void {
        if (comptime @hasDecl(AudioNodeImpl, "call_disconnect__6")) {
            return try AudioNodeImpl.call_disconnect__6(instance, destinationParam, output);
        } else {
            return error.NotImplemented;
        }
    }

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "connect", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_connect", .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "AudioNode")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").AudioNode.State) } else .other)} }, .{ .kinds = &.{.numeric}, .optionality = .optional }, .{ .kinds = &.{.numeric}, .optionality = .optional } } },
            .{ .function = "call_connect__1", .implemented = @hasDecl(AudioNodeImpl, "call_connect__1"), .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "AudioParam")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").AudioParam.State) } else .other)} }, .{ .kinds = &.{.numeric}, .optionality = .optional } } },
        } },
        .{ "disconnect", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_disconnect", .args = &.{} },
            .{ .function = "call_disconnect__1", .implemented = @hasDecl(AudioNodeImpl, "call_disconnect__1"), .args = &.{.{ .kinds = &.{.numeric} }} },
            .{ .function = "call_disconnect__2", .implemented = @hasDecl(AudioNodeImpl, "call_disconnect__2"), .args = &.{.{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "AudioNode")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").AudioNode.State) } else .other)} }} },
            .{ .function = "call_disconnect__3", .implemented = @hasDecl(AudioNodeImpl, "call_disconnect__3"), .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "AudioNode")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").AudioNode.State) } else .other)} }, .{ .kinds = &.{.numeric} } } },
            .{ .function = "call_disconnect__4", .implemented = @hasDecl(AudioNodeImpl, "call_disconnect__4"), .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "AudioNode")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").AudioNode.State) } else .other)} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
            .{ .function = "call_disconnect__5", .implemented = @hasDecl(AudioNodeImpl, "call_disconnect__5"), .args = &.{.{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "AudioParam")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").AudioParam.State) } else .other)} }} },
            .{ .function = "call_disconnect__6", .implemented = @hasDecl(AudioNodeImpl, "call_disconnect__6"), .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "AudioParam")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").AudioParam.State) } else .other)} }, .{ .kinds = &.{.numeric} } } },
        } },
    };
};
