//! Generated from: speech-api.idl
//! Generated at: 2025-11-23T19:47:42Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechRecognitionPhraseImpl = @import("impls").SpeechRecognitionPhrase;
const DOMString = @import("typedefs").DOMString;

pub const SpeechRecognitionPhrase = struct {
    pub const Meta = struct {
        pub const name = "SpeechRecognitionPhrase";
        pub const is_mixin = false;
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
            .{ "phrase", "get_phrase", null },
            .{ "boost", "get_boost", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "phrase", "get_phrase", null },
            .{ "boost", "get_boost", null },
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
            phrase: runtime.DOMString = undefined,
            boost: f32 = undefined,
            _internal: ?*SpeechRecognitionPhraseImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_boost = &get_boost,
        .get_phrase = &get_phrase,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SpeechRecognitionPhraseImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechRecognitionPhraseImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, phrase: DOMString, boost: f32) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SpeechRecognitionPhraseImpl.call_constructor(allocator, ctx, phrase, boost);
    }

    pub fn get_phrase(instance: *runtime.Instance) anyerror!DOMString {
        return try SpeechRecognitionPhraseImpl.get_phrase(instance);
    }

    pub fn get_boost(instance: *runtime.Instance) anyerror!f32 {
        return try SpeechRecognitionPhraseImpl.get_boost(instance);
    }

};
