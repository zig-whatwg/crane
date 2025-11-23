//! Generated from: speech-api.idl
//! Generated at: 2025-11-23T14:26:30Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechSynthesisVoiceImpl = @import("impls").SpeechSynthesisVoice;
const DOMString = @import("typedefs").DOMString;

pub const SpeechSynthesisVoice = struct {
    pub const Meta = struct {
        pub const name = "SpeechSynthesisVoice";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "voiceURI", "get_voiceURI", null },
            .{ "name", "get_name", null },
            .{ "lang", "get_lang", null },
            .{ "localService", "get_localService", null },
            .{ "default", "get_default", null },
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
            .{ "voiceURI", "get_voiceURI", null },
            .{ "name", "get_name", null },
            .{ "localService", "get_localService", null },
            .{ "default", "get_default", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
            .{ "lang", "get_lang", null },
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            voiceURI: runtime.DOMString = undefined,
            name: runtime.DOMString = undefined,
            lang: runtime.DOMString = undefined,
            localService: bool = undefined,
            default: bool = undefined,
            _internal: ?*SpeechSynthesisVoiceImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_default = &get_default,
        .get_lang = &get_lang,
        .get_localService = &get_localService,
        .get_name = &get_name,
        .get_voiceURI = &get_voiceURI,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SpeechSynthesisVoiceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechSynthesisVoiceImpl.deinit(instance);
    }

    pub fn get_voiceURI(instance: *runtime.Instance) anyerror!DOMString {
        return try SpeechSynthesisVoiceImpl.get_voiceURI(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try SpeechSynthesisVoiceImpl.get_name(instance);
    }

    pub fn get_lang(instance: *runtime.Instance) anyerror!DOMString {
        return try SpeechSynthesisVoiceImpl.get_lang(instance);
    }

    pub fn get_localService(instance: *runtime.Instance) anyerror!bool {
        return try SpeechSynthesisVoiceImpl.get_localService(instance);
    }

    pub fn get_default(instance: *runtime.Instance) anyerror!bool {
        return try SpeechSynthesisVoiceImpl.get_default(instance);
    }

};
