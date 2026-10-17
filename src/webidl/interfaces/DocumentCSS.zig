//! Generated from: DOM-Style.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DocumentCSSImpl = @import("impls").DocumentCSS;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DocumentStyle = @import("interfaces").DocumentStyle;
const Element = @import("interfaces").Element;
const StyleSheetList = @import("interfaces").StyleSheetList;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const DOMString = @import("typedefs").DOMString;

pub const DocumentCSS = struct {
    pub const Meta = struct {
        pub const name = "DocumentCSS";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = DocumentStyle.State;
        pub const ParentInterface = DocumentStyle;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getOverrideStyle", "call_getOverrideStyle", 2 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getOverrideStyle",
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
            _internal: ?*DocumentCSSImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_getOverrideStyle = &call_getOverrideStyle,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("DocumentCSS has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(DocumentCSSImpl, "init") and @hasDecl(DocumentCSSImpl, "initOwn")) @compileError("DocumentCSSImpl defines both init and initOwn");
        if (comptime @hasDecl(DocumentCSSImpl, "init")) return DocumentCSSImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(DocumentCSSImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try DocumentCSSImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(DocumentCSSImpl, "init")) return false;
        if (comptime @hasDecl(DocumentCSSImpl, "construction_args")) {
            inline for (DocumentCSSImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(DocumentCSSImpl, "deinit") and @hasDecl(DocumentCSSImpl, "deinitOwn")) @compileError("DocumentCSSImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(DocumentCSSImpl, "deinit")) return DocumentCSSImpl.deinit(instance);
        if (comptime @hasDecl(DocumentCSSImpl, "deinitOwn")) DocumentCSSImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "DocumentCSS")) {
            if (comptime @hasDecl(impls.DocumentCSS, "installHooks")) impls.DocumentCSS.installHooks();
        }
    }

    pub fn call_getOverrideStyle(instance: *runtime.Instance, elt: *runtime.Instance, pseudoElt: DOMString) anyerror!*runtime.Instance {
        return try DocumentCSSImpl.call_getOverrideStyle(instance, elt, pseudoElt);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_getOverrideStyle", 0, "Element" },
    };
};
