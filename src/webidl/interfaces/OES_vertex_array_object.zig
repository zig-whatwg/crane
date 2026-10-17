//! Generated from: OES_vertex_array_object.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const OES_vertex_array_objectImpl = @import("impls").OES_vertex_array_object;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GLenum = @import("typedefs").GLenum;
const WebGLVertexArrayObjectOES = @import("interfaces").WebGLVertexArrayObjectOES;
const GLboolean = @import("typedefs").GLboolean;

pub const OES_vertex_array_object = struct {
    pub const Meta = struct {
        pub const name = "OES_vertex_array_object";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "LegacyNoInterfaceObject" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "createVertexArrayOES", "call_createVertexArrayOES", 0 },
            .{ "deleteVertexArrayOES", "call_deleteVertexArrayOES", 1 },
            .{ "isVertexArrayOES", "call_isVertexArrayOES", 1 },
            .{ "bindVertexArrayOES", "call_bindVertexArrayOES", 1 },
        };

        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "VERTEX_ARRAY_BINDING_OES", "get_VERTEX_ARRAY_BINDING_OES" },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createVertexArrayOES",
            "deleteVertexArrayOES",
            "isVertexArrayOES",
            "bindVertexArrayOES",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*OES_vertex_array_objectImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum VERTEX_ARRAY_BINDING_OES = 34229;
    pub fn get_VERTEX_ARRAY_BINDING_OES() GLenum {
        return 34229;
    }

    const delegates = .{
        .get_VERTEX_ARRAY_BINDING_OES = &get_VERTEX_ARRAY_BINDING_OES,

        .call_bindVertexArrayOES = &call_bindVertexArrayOES,
        .call_createVertexArrayOES = &call_createVertexArrayOES,
        .call_deleteVertexArrayOES = &call_deleteVertexArrayOES,
        .call_isVertexArrayOES = &call_isVertexArrayOES,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("OES_vertex_array_object has no construction argument '" ++ field.name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(OES_vertex_array_objectImpl, "init") and @hasDecl(OES_vertex_array_objectImpl, "initOwn")) @compileError("OES_vertex_array_objectImpl defines both init and initOwn");
        if (comptime @hasDecl(OES_vertex_array_objectImpl, "init")) return OES_vertex_array_objectImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(OES_vertex_array_objectImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try OES_vertex_array_objectImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(OES_vertex_array_objectImpl, "init")) return false;
        if (comptime @hasDecl(OES_vertex_array_objectImpl, "construction_args")) {
            inline for (OES_vertex_array_objectImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return false;
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(OES_vertex_array_objectImpl, "deinit") and @hasDecl(OES_vertex_array_objectImpl, "deinitOwn")) @compileError("OES_vertex_array_objectImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(OES_vertex_array_objectImpl, "deinit")) return OES_vertex_array_objectImpl.deinit(instance);
        if (comptime @hasDecl(OES_vertex_array_objectImpl, "deinitOwn")) OES_vertex_array_objectImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "OES_vertex_array_object")) {
            if (comptime @hasDecl(impls.OES_vertex_array_object, "installHooks")) impls.OES_vertex_array_object.installHooks();
        }
    }

    pub fn call_createVertexArrayOES(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try OES_vertex_array_objectImpl.call_createVertexArrayOES(instance);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isVertexArrayOES(instance: *runtime.Instance, arrayObject: ?*runtime.Instance) anyerror!GLboolean {
        return try OES_vertex_array_objectImpl.call_isVertexArrayOES(instance, arrayObject);
    }

    pub fn call_deleteVertexArrayOES(instance: *runtime.Instance, arrayObject: ?*runtime.Instance) anyerror!void {
        return try OES_vertex_array_objectImpl.call_deleteVertexArrayOES(instance, arrayObject);
    }

    pub fn call_bindVertexArrayOES(instance: *runtime.Instance, arrayObject: ?*runtime.Instance) anyerror!void {
        return try OES_vertex_array_objectImpl.call_bindVertexArrayOES(instance, arrayObject);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_isVertexArrayOES", 0, "WebGLVertexArrayObjectOES" },
        .{ "call_deleteVertexArrayOES", 0, "WebGLVertexArrayObjectOES" },
        .{ "call_bindVertexArrayOES", 0, "WebGLVertexArrayObjectOES" },
    };
};
