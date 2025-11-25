//! Generated from: speech-api.idl
//! Generated at: 2025-11-25T20:02:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechGrammarListImpl = @import("impls").SpeechGrammarList;
const SpeechGrammar = @import("interfaces").SpeechGrammar;
const DOMString = @import("typedefs").DOMString;

pub const SpeechGrammarList = struct {
    pub const Meta = struct {
        pub const name = "SpeechGrammarList";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "length", "get_length", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "item", "call_item", 1 },
            .{ "addFromURI", "call_addFromURI", 1 },
            .{ "addFromString", "call_addFromString", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "item",
            "addFromURI",
            "addFromString",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", null },
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
            length: u32 = undefined,
            _internal: ?*SpeechGrammarListImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_length = &get_length,

        .call_addFromString = &call_addFromString,
        .call_addFromURI = &call_addFromURI,
        .call_item = &call_item,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SpeechGrammarListImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechGrammarListImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SpeechGrammarListImpl.call_constructor(allocator, ctx);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try SpeechGrammarListImpl.get_length(instance);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!*runtime.Instance {
        
        return try SpeechGrammarListImpl.call_item(instance, index);
    }

    pub fn call_addFromURI(instance: *runtime.Instance, src: DOMString, weight: f32) anyerror!void {
        
        return try SpeechGrammarListImpl.call_addFromURI(instance, src, weight);
    }

    pub fn call_addFromString(instance: *runtime.Instance, string: DOMString, weight: f32) anyerror!void {
        
        return try SpeechGrammarListImpl.call_addFromString(instance, string, weight);
    }

};
