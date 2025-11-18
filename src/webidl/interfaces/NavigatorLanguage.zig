//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorLanguageImpl = @import("impls").NavigatorLanguage;
const FrozenArray<DOMString> = @import("interfaces").FrozenArray<DOMString>;

pub const NavigatorLanguage = struct {
    pub const Meta = struct {
        pub const name = "NavigatorLanguage";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            language: runtime.DOMString = undefined,
            languages: FrozenArray<DOMString> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NavigatorLanguage, .{
        .deinit_fn = &deinit_wrapper,

        .get_language = &get_language,
        .get_languages = &get_languages,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        NavigatorLanguageImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorLanguageImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_language(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorLanguageImpl.get_language(instance);
    }

    pub fn get_languages(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigatorLanguageImpl.get_languages(instance);
    }

};
