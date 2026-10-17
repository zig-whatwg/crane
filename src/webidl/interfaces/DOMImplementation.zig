//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DOMImplementationImpl = @import("impls").DOMImplementation;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Document = @import("interfaces").Document;
const DocumentType = @import("interfaces").DocumentType;
const XMLDocument = @import("interfaces").XMLDocument;
const DOMString = @import("typedefs").DOMString;

pub const DOMImplementation = struct {
    pub const Meta = struct {
        pub const name = "DOMImplementation";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "createDocumentType", "call_createDocumentType", 3 },
            .{ "createDocument", "call_createDocument", 2 },
            .{ "createHTMLDocument", "call_createHTMLDocument", 0 },
            .{ "hasFeature", "call_hasFeature", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createDocumentType",
            "createDocument",
            "createHTMLDocument",
            "hasFeature",
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
            _internal: ?*DOMImplementationImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_createDocument = &call_createDocument,
        .call_createDocumentType = &call_createDocumentType,
        .call_createHTMLDocument = &call_createHTMLDocument,
        .call_hasFeature = &call_hasFeature,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("DOMImplementation has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(DOMImplementationImpl, "init") and @hasDecl(DOMImplementationImpl, "initOwn")) @compileError("DOMImplementationImpl defines both init and initOwn");
        if (comptime @hasDecl(DOMImplementationImpl, "init")) return DOMImplementationImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(DOMImplementationImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try DOMImplementationImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(DOMImplementationImpl, "init")) return false;
        if (comptime @hasDecl(DOMImplementationImpl, "construction_args")) {
            inline for (DOMImplementationImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(DOMImplementationImpl, "deinit") and @hasDecl(DOMImplementationImpl, "deinitOwn")) @compileError("DOMImplementationImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(DOMImplementationImpl, "deinit")) return DOMImplementationImpl.deinit(instance);
        if (comptime @hasDecl(DOMImplementationImpl, "deinitOwn")) DOMImplementationImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "DOMImplementation")) {
            if (comptime @hasDecl(impls.DOMImplementation, "installHooks")) impls.DOMImplementation.installHooks();
        }
    }

    /// Extended attributes: [NewObject]
    pub fn call_createHTMLDocument(instance: *runtime.Instance, title: webidl.Opt(DOMString)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try DOMImplementationImpl.call_createHTMLDocument(instance, title);
    }

    pub fn call_hasFeature(instance: *runtime.Instance) anyerror!bool {
        return try DOMImplementationImpl.call_hasFeature(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createDocument(instance: *runtime.Instance, namespace: ?DOMString, qualifiedName: DOMString, doctype: webidl.Opt(?*runtime.Instance)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try DOMImplementationImpl.call_createDocument(instance, namespace, qualifiedName, doctype);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createDocumentType(instance: *runtime.Instance, name: DOMString, publicId: DOMString, systemId: DOMString) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try DOMImplementationImpl.call_createDocumentType(instance, name, publicId, systemId);
    }

    /// WebIDL [LegacyNullToEmptyString]: the values null converts to "" for
    /// (bit i = argument i; an attribute setter's value is bit 0).
    pub const legacy_null_to_empty = .{
        .{ "call_createDocument", 0b10 },
    };

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_createDocument", 2, "DocumentType" },
    };
};
