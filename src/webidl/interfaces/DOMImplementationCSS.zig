//! Generated from: DOM-Style.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DOMImplementationCSSImpl = @import("impls").DOMImplementationCSS;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMImplementation = @import("interfaces").DOMImplementation;
const Document = @import("interfaces").Document;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const DocumentType = @import("interfaces").DocumentType;
const XMLDocument = @import("interfaces").XMLDocument;
const DOMString = @import("typedefs").DOMString;

pub const DOMImplementationCSS = struct {
    pub const Meta = struct {
        pub const name = "DOMImplementationCSS";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = DOMImplementation.State;
        pub const ParentInterface = DOMImplementation;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "createCSSStyleSheet", "call_createCSSStyleSheet", 2 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createCSSStyleSheet",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "createDocumentType",
            "createDocument",
            "createHTMLDocument",
            "hasFeature",
        };

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
            _internal: ?*DOMImplementationCSSImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_createCSSStyleSheet = &call_createCSSStyleSheet,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("DOMImplementationCSS has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(DOMImplementationCSSImpl, "init") and @hasDecl(DOMImplementationCSSImpl, "initOwn")) @compileError("DOMImplementationCSSImpl defines both init and initOwn");
        if (comptime @hasDecl(DOMImplementationCSSImpl, "init")) return DOMImplementationCSSImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(DOMImplementationCSSImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try DOMImplementationCSSImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(DOMImplementationCSSImpl, "init")) return false;
        if (comptime @hasDecl(DOMImplementationCSSImpl, "construction_args")) {
            inline for (DOMImplementationCSSImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(DOMImplementationCSSImpl, "deinit") and @hasDecl(DOMImplementationCSSImpl, "deinitOwn")) @compileError("DOMImplementationCSSImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(DOMImplementationCSSImpl, "deinit")) return DOMImplementationCSSImpl.deinit(instance);
        if (comptime @hasDecl(DOMImplementationCSSImpl, "deinitOwn")) DOMImplementationCSSImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "DOMImplementationCSS")) {
            if (comptime @hasDecl(impls.DOMImplementationCSS, "installHooks")) impls.DOMImplementationCSS.installHooks();
        }
    }

    pub fn call_createCSSStyleSheet(instance: *runtime.Instance, title: DOMString, media: DOMString) anyerror!*runtime.Instance {
        return try DOMImplementationCSSImpl.call_createCSSStyleSheet(instance, title, media);
    }
};
