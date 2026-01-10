//! Generated from: speech-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SpeechSynthesisEventImpl = @import("impls").SpeechSynthesisEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Event = @import("Event.zig").Event;
const EventTarget = @import("EventTarget.zig").EventTarget;
const SpeechSynthesisEventInit = @import("dictionaries").SpeechSynthesisEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const SpeechSynthesisUtterance = @import("SpeechSynthesisUtterance.zig").SpeechSynthesisUtterance;
const DOMString = @import("typedefs").DOMString;

pub const SpeechSynthesisEvent = struct {
    pub const Meta = struct {
        pub const name = "SpeechSynthesisEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "utterance", "get_utterance", null },
            .{ "charIndex", "get_charIndex", null },
            .{ "charLength", "get_charLength", null },
            .{ "elapsedTime", "get_elapsedTime", null },
            .{ "name", "get_name", null },
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
            .{ "utterance", "get_utterance", null },
            .{ "charIndex", "get_charIndex", null },
            .{ "charLength", "get_charLength", null },
            .{ "elapsedTime", "get_elapsedTime", null },
            .{ "name", "get_name", null },
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
            utterance: *runtime.Instance = undefined,
            charIndex: u32 = undefined,
            charLength: u32 = undefined,
            elapsedTime: f32 = undefined,
            name: typedefs.DOMString = undefined,
            _internal: ?*SpeechSynthesisEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_charIndex = &get_charIndex,
        .get_charLength = &get_charLength,
        .get_elapsedTime = &get_elapsedTime,
        .get_name = &get_name,
        .get_utterance = &get_utterance,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SpeechSynthesisEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return SpeechSynthesisEventImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechSynthesisEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": DOMString, eventInitDict: SpeechSynthesisEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SpeechSynthesisEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    pub fn get_utterance(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SpeechSynthesisEventImpl.get_utterance(instance);
    }

    pub fn get_charIndex(instance: *runtime.Instance) anyerror!u32 {
        return try SpeechSynthesisEventImpl.get_charIndex(instance);
    }

    pub fn get_charLength(instance: *runtime.Instance) anyerror!u32 {
        return try SpeechSynthesisEventImpl.get_charLength(instance);
    }

    pub fn get_elapsedTime(instance: *runtime.Instance) anyerror!f32 {
        return try SpeechSynthesisEventImpl.get_elapsedTime(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try SpeechSynthesisEventImpl.get_name(instance);
    }

};
