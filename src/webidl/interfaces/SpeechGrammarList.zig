//! Generated from: speech-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechGrammarListImpl = @import("impls").SpeechGrammarList;
const SpeechGrammar = @import("interfaces").SpeechGrammar;

pub const SpeechGrammarList = struct {
    pub const Meta = struct {
        pub const name = "SpeechGrammarList";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            length: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SpeechGrammarList, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,

        .call_addFromString = &call_addFromString,
        .call_addFromURI = &call_addFromURI,
        .call_item = &call_item,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SpeechGrammarListImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechGrammarListImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try SpeechGrammarListImpl.constructor(instance);
        
        return instance;
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try SpeechGrammarListImpl.get_length(instance);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!SpeechGrammar {
        
        return try SpeechGrammarListImpl.call_item(instance, index);
    }

    pub fn call_addFromURI(instance: *runtime.Instance, src: DOMString, weight: f32) anyerror!void {
        
        return try SpeechGrammarListImpl.call_addFromURI(instance, src, weight);
    }

    pub fn call_addFromString(instance: *runtime.Instance, string: DOMString, weight: f32) anyerror!void {
        
        return try SpeechGrammarListImpl.call_addFromString(instance, string, weight);
    }

};
