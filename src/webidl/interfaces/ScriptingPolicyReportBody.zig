//! Generated from: csp-next.idl
//! Generated at: 2025-11-23T19:17:36Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ScriptingPolicyReportBodyImpl = @import("impls").ScriptingPolicyReportBody;
const ReportBody = @import("dictionaries").ReportBody;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const ScriptingPolicyReportBody = struct {
    pub const Meta = struct {
        pub const name = "ScriptingPolicyReportBody";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *ReportBody;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "violationType", "get_violationType", null },
            .{ "violationURL", "get_violationURL", null },
            .{ "violationSample", "get_violationSample", null },
            .{ "lineno", "get_lineno", null },
            .{ "colno", "get_colno", null },
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
            .{ "violationType", "get_violationType", null },
            .{ "violationURL", "get_violationURL", null },
            .{ "violationSample", "get_violationSample", null },
            .{ "lineno", "get_lineno", null },
            .{ "colno", "get_colno", null },
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
            violationType: runtime.DOMString = undefined,
            violationURL: ?runtime.USVString = null,
            violationSample: ?runtime.USVString = null,
            lineno: u32 = undefined,
            colno: u32 = undefined,
            _internal: ?*ScriptingPolicyReportBodyImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_colno = &get_colno,
        .get_lineno = &get_lineno,
        .get_violationSample = &get_violationSample,
        .get_violationType = &get_violationType,
        .get_violationURL = &get_violationURL,

        .call_toJSON = &call_toJSON,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ScriptingPolicyReportBodyImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ScriptingPolicyReportBodyImpl.deinit(instance);
    }

    pub fn get_violationType(instance: *runtime.Instance) anyerror!DOMString {
        return try ScriptingPolicyReportBodyImpl.get_violationType(instance);
    }

    pub fn get_violationURL(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try ScriptingPolicyReportBodyImpl.get_violationURL(instance);
    }

    pub fn get_violationSample(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try ScriptingPolicyReportBodyImpl.get_violationSample(instance);
    }

    pub fn get_lineno(instance: *runtime.Instance) anyerror!u32 {
        return try ScriptingPolicyReportBodyImpl.get_lineno(instance);
    }

    pub fn get_colno(instance: *runtime.Instance) anyerror!u32 {
        return try ScriptingPolicyReportBodyImpl.get_colno(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ScriptingPolicyReportBodyImpl.call_toJSON(instance);
    }

};
