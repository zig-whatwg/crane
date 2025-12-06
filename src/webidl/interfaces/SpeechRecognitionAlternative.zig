//! Generated from: speech-api.idl
//! Generated at: 2025-12-05T20:30:47Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SpeechRecognitionAlternativeImpl = @import("impls").SpeechRecognitionAlternative;
const mixins = @import("mixins");
const DOMString = @import("typedefs").DOMString;

pub const SpeechRecognitionAlternative = struct {
    pub const Meta = struct {
        pub const name = "SpeechRecognitionAlternative";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "transcript", "get_transcript", null },
            .{ "confidence", "get_confidence", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "transcript", "get_transcript", null },
            .{ "confidence", "get_confidence", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            transcript: runtime.DOMString = undefined,
            confidence: f32 = undefined,
            _internal: ?*SpeechRecognitionAlternativeImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_confidence = &get_confidence,
        .get_transcript = &get_transcript,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SpeechRecognitionAlternativeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechRecognitionAlternativeImpl.deinit(instance);
    }

    pub fn get_transcript(instance: *runtime.Instance) anyerror!DOMString {
        return try SpeechRecognitionAlternativeImpl.get_transcript(instance);
    }

    pub fn get_confidence(instance: *runtime.Instance) anyerror!f32 {
        return try SpeechRecognitionAlternativeImpl.get_confidence(instance);
    }
};
