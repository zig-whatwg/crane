//! Generated from: speech-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SpeechSynthesisVoiceImpl = @import("impls").SpeechSynthesisVoice;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const SpeechSynthesisVoice = struct {
    pub const Meta = struct {
        pub const name = "SpeechSynthesisVoice";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            voiceURI: typedefs.DOMString = undefined,
            name: typedefs.DOMString = undefined,
            lang: typedefs.DOMString = undefined,
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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SpeechSynthesisVoiceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return SpeechSynthesisVoiceImpl.init(allocator, StateType, vtable_ptr, ctx);
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
