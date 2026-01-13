//! Generated from: wasm-js-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ModuleImpl = @import("impls").Module;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ModuleExportDescriptor = @import("dictionaries").ModuleExportDescriptor;
const BufferSource = @import("typedefs").BufferSource;
const ModuleImportDescriptor = @import("dictionaries").ModuleImportDescriptor;
const WebAssemblyCompileOptions = @import("dictionaries").WebAssemblyCompileOptions;
const DOMString = @import("typedefs").DOMString;

pub const Module = struct {
    pub const Meta = struct {
        pub const name = "Module";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "LegacyNamespace", .value = .{ .identifier = "WebAssembly" } },
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
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
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "exports", "call_static_exports", 1 },
            .{ "imports", "call_static_imports", 1 },
            .{ "customSections", "call_static_customSections", 2 },
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*ModuleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ModuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return ModuleImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ModuleImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, bytes: BufferSource, options: webidl.Opt(WebAssemblyCompileOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ModuleImpl.call_constructor(ctx, bytes, options);
    }

    pub fn call_static_imports(instance: *runtime.Instance, moduleObject: *runtime.Instance) anyerror!runtime.JSValue {
        
        return try ModuleImpl.call_static_imports(instance, moduleObject);
    }

    pub fn call_static_customSections(instance: *runtime.Instance, moduleObject: *runtime.Instance, sectionName: DOMString) anyerror!runtime.JSValue {
        
        return try ModuleImpl.call_static_customSections(instance, moduleObject, sectionName);
    }

    pub fn call_static_exports(instance: *runtime.Instance, moduleObject: *runtime.Instance) anyerror!runtime.JSValue {
        
        return try ModuleImpl.call_static_exports(instance, moduleObject);
    }

};
