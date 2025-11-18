//! Generated from: speech-api.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechGrammarListImpl = @import("../impls/SpeechGrammarList.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        SpeechGrammarListImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SpeechGrammarListImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try SpeechGrammarListImpl.constructor(state);
        
        return instance;
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return SpeechGrammarListImpl.get_length(state);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyopaque {
        const state = instance.getState(State);
        
        return SpeechGrammarListImpl.call_item(state, index);
    }

    pub fn call_addFromURI(instance: *runtime.Instance, src: runtime.DOMString, weight: f32) anyopaque {
        const state = instance.getState(State);
        
        return SpeechGrammarListImpl.call_addFromURI(state, src, weight);
    }

    pub fn call_addFromString(instance: *runtime.Instance, string: runtime.DOMString, weight: f32) anyopaque {
        const state = instance.getState(State);
        
        return SpeechGrammarListImpl.call_addFromString(state, string, weight);
    }

};
