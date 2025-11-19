//! Generated from: wasm-js-api.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ModuleImpl = @import("impls").Module;
const ModuleExportDescriptor = @import("dictionaries").ModuleExportDescriptor;
const ArrayBuffer = @import("interfaces").ArrayBuffer;
const BufferSource = @import("typedefs").BufferSource;
const ModuleImportDescriptor = @import("dictionaries").ModuleImportDescriptor;
const WebAssemblyCompileOptions = @import("dictionaries").WebAssemblyCompileOptions;
const DOMString = @import("typedefs").DOMString;

pub const Module = struct {
    pub const Meta = struct {
        pub const name = "Module";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "LegacyNamespace", .value = .{ .identifier = "WebAssembly" } },
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Module, .{
        .deinit_fn = &deinit_wrapper,

        .call_customSections = &call_customSections,
        .call_exports = &call_exports,
        .call_imports = &call_imports,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return ModuleImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ModuleImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, bytes: BufferSource, options: WebAssemblyCompileOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try ModuleImpl.constructor(instance, bytes, options);
        
        return instance;
    }

    pub fn call_exports(instance: *runtime.Instance, moduleObject: Module) anyerror!anyopaque {
        
        return try ModuleImpl.call_exports(instance, moduleObject);
    }

    pub fn call_imports(instance: *runtime.Instance, moduleObject: Module) anyerror!anyopaque {
        
        return try ModuleImpl.call_imports(instance, moduleObject);
    }

    pub fn call_customSections(instance: *runtime.Instance, moduleObject: Module, sectionName: DOMString) anyerror!anyopaque {
        
        return try ModuleImpl.call_customSections(instance, moduleObject, sectionName);
    }

};
