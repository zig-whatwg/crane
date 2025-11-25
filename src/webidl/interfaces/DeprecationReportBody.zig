//! Generated from: deprecation-reporting.idl
//! Generated at: 2025-11-25T14:21:39Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DeprecationReportBodyImpl = @import("impls").DeprecationReportBody;
const ReportBody = @import("dictionaries").ReportBody;
const DOMString = @import("typedefs").DOMString;

pub const DeprecationReportBody = struct {
    pub const Meta = struct {
        pub const name = "DeprecationReportBody";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *ReportBody;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "id", "get_id", null },
            .{ "anticipatedRemoval", "get_anticipatedRemoval", null },
            .{ "message", "get_message", null },
            .{ "sourceFile", "get_sourceFile", null },
            .{ "lineNumber", "get_lineNumber", null },
            .{ "columnNumber", "get_columnNumber", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "id", "get_id", null },
            .{ "anticipatedRemoval", "get_anticipatedRemoval", null },
            .{ "message", "get_message", null },
            .{ "sourceFile", "get_sourceFile", null },
            .{ "lineNumber", "get_lineNumber", null },
            .{ "columnNumber", "get_columnNumber", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            id: runtime.DOMString = undefined,
            anticipatedRemoval: ?*const anyopaque = null,
            message: runtime.DOMString = undefined,
            sourceFile: ?runtime.DOMString = null,
            lineNumber: ?u32 = null,
            columnNumber: ?u32 = null,
            _internal: ?*DeprecationReportBodyImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_anticipatedRemoval = &get_anticipatedRemoval,
        .get_columnNumber = &get_columnNumber,
        .get_id = &get_id,
        .get_lineNumber = &get_lineNumber,
        .get_message = &get_message,
        .get_sourceFile = &get_sourceFile,

        .call_toJSON = &call_toJSON,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DeprecationReportBodyImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DeprecationReportBodyImpl.deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try DeprecationReportBodyImpl.get_id(instance);
    }

    pub fn get_anticipatedRemoval(instance: *runtime.Instance) anyerror!?*const anyopaque {
        return try DeprecationReportBodyImpl.get_anticipatedRemoval(instance);
    }

    pub fn get_message(instance: *runtime.Instance) anyerror!DOMString {
        return try DeprecationReportBodyImpl.get_message(instance);
    }

    pub fn get_sourceFile(instance: *runtime.Instance) anyerror!?DOMString {
        return try DeprecationReportBodyImpl.get_sourceFile(instance);
    }

    pub fn get_lineNumber(instance: *runtime.Instance) anyerror!?u32 {
        return try DeprecationReportBodyImpl.get_lineNumber(instance);
    }

    pub fn get_columnNumber(instance: *runtime.Instance) anyerror!?u32 {
        return try DeprecationReportBodyImpl.get_columnNumber(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try DeprecationReportBodyImpl.call_toJSON(instance);
    }

};
