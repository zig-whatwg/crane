//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DocumentStyleImpl = @import("impls").DocumentStyle;
const StyleSheetList = @import("interfaces").StyleSheetList;

pub const DocumentStyle = struct {
    pub const Meta = struct {
        pub const name = "DocumentStyle";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            styleSheets: StyleSheetList = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DocumentStyle, .{
        .deinit_fn = &deinit_wrapper,

        .get_styleSheets = &get_styleSheets,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return DocumentStyleImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DocumentStyleImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_styleSheets(instance: *runtime.Instance) anyerror!StyleSheetList {
        return try DocumentStyleImpl.get_styleSheets(instance);
    }

};
