//! Generated from: html.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorLanguageImpl = @import("impls").NavigatorLanguage;
const DOMString = @import("typedefs").DOMString;

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
            languages: runtime.FrozenArray(runtime.DOMString) = undefined,
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
        return NavigatorLanguageImpl.init(allocator, State, &vtable);
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
