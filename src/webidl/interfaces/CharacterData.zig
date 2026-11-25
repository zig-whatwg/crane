//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CharacterDataImpl = @import("impls").CharacterData;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Node = @import("interfaces").Node;
const NonDocumentTypeChildNode = @import("mixins").NonDocumentTypeChildNode;
const ChildNode = @import("mixins").ChildNode;
const Document = @import("interfaces").Document;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const SetHTMLOptions = @import("dictionaries").SetHTMLOptions;
const SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions = @import("typedefs").SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions;
const NodeList = @import("interfaces").NodeList;
const USVString = @import("typedefs").USVString;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const Element = @import("interfaces").Element;
const TrustedHTMLOrDOMString = @import("typedefs").TrustedHTMLOrDOMString;
const EventListenerOptionsOrBoolean = @import("typedefs").EventListenerOptionsOrBoolean;
const EventListener = @import("interfaces").EventListener;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const WritableStream = @import("interfaces").WritableStream;
const AddEventListenerOptionsOrBoolean = @import("typedefs").AddEventListenerOptionsOrBoolean;
const DOMString = @import("typedefs").DOMString;

pub const CharacterData = struct {
    pub const Meta = struct {
        pub const name = "CharacterData";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Node.State;
        pub const ParentInterface = Node;
        pub const MixinTypes = &.{
            NonDocumentTypeChildNode,
            ChildNode,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "data", "get_data", "set_data" },
            .{ "length", "get_length", null },
            .{ "previousElementSibling", "get_previousElementSibling", null },
            .{ "nextElementSibling", "get_nextElementSibling", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "substringData", "call_substringData", 2 },
            .{ "appendData", "call_appendData", 1 },
            .{ "insertData", "call_insertData", 2 },
            .{ "deleteData", "call_deleteData", 2 },
            .{ "replaceData", "call_replaceData", 3 },
            .{ "beforeHTML", "call_beforeHTML", 1 },
            .{ "afterHTML", "call_afterHTML", 1 },
            .{ "replaceWithHTML", "call_replaceWithHTML", 1 },
            .{ "streamBeforeHTML", "call_streamBeforeHTML", 0 },
            .{ "streamAfterHTML", "call_streamAfterHTML", 0 },
            .{ "streamReplaceWithHTML", "call_streamReplaceWithHTML", 0 },
            .{ "beforeHTMLUnsafe", "call_beforeHTMLUnsafe", 1 },
            .{ "afterHTMLUnsafe", "call_afterHTMLUnsafe", 1 },
            .{ "replaceWithHTMLUnsafe", "call_replaceWithHTMLUnsafe", 1 },
            .{ "streamBeforeHTMLUnsafe", "call_streamBeforeHTMLUnsafe", 0 },
            .{ "streamAfterHTMLUnsafe", "call_streamAfterHTMLUnsafe", 0 },
            .{ "streamReplaceWithHTMLUnsafe", "call_streamReplaceWithHTMLUnsafe", 0 },
            .{ "before", "call_before", 0 },
            .{ "after", "call_after", 0 },
            .{ "replaceWith", "call_replaceWith", 0 },
            .{ "remove", "call_remove", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "substringData",
            "appendData",
            "insertData",
            "deleteData",
            "replaceData",
            "beforeHTML",
            "afterHTML",
            "replaceWithHTML",
            "streamBeforeHTML",
            "streamAfterHTML",
            "streamReplaceWithHTML",
            "beforeHTMLUnsafe",
            "afterHTMLUnsafe",
            "replaceWithHTMLUnsafe",
            "streamBeforeHTMLUnsafe",
            "streamAfterHTMLUnsafe",
            "streamReplaceWithHTMLUnsafe",
            "before",
            "after",
            "replaceWith",
            "remove",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "getRootNode",
            "hasChildNodes",
            "normalize",
            "cloneNode",
            "isEqualNode",
            "isSameNode",
            "compareDocumentPosition",
            "contains",
            "lookupPrefix",
            "lookupNamespaceURI",
            "isDefaultNamespace",
            "insertBefore",
            "appendChild",
            "replaceChild",
            "removeChild",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "data", "get_data", "set_data" },
            .{ "length", "get_length", null },
            .{ "previousElementSibling", "get_previousElementSibling", null },
            .{ "nextElementSibling", "get_nextElementSibling", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// Members marked with [Unscopable] extended attribute
        pub const unscopables = .{
            "before",
            "after",
            "replaceWith",
            "remove",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*CharacterDataImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_data = &get_data,
        .get_length = &get_length,
        .get_nextElementSibling = &get_nextElementSibling,
        .get_previousElementSibling = &get_previousElementSibling,

        .set_data = &set_data,

        .call_after = &call_after,
        .call_afterHTML = &call_afterHTML,
        .call_afterHTMLUnsafe = &call_afterHTMLUnsafe,
        .call_appendData = &call_appendData,
        .call_before = &call_before,
        .call_beforeHTML = &call_beforeHTML,
        .call_beforeHTMLUnsafe = &call_beforeHTMLUnsafe,
        .call_deleteData = &call_deleteData,
        .call_insertData = &call_insertData,
        .call_remove = &call_remove,
        .call_replaceData = &call_replaceData,
        .call_replaceWith = &call_replaceWith,
        .call_replaceWithHTML = &call_replaceWithHTML,
        .call_replaceWithHTMLUnsafe = &call_replaceWithHTMLUnsafe,
        .call_streamAfterHTML = &call_streamAfterHTML,
        .call_streamAfterHTMLUnsafe = &call_streamAfterHTMLUnsafe,
        .call_streamBeforeHTML = &call_streamBeforeHTML,
        .call_streamBeforeHTMLUnsafe = &call_streamBeforeHTMLUnsafe,
        .call_streamReplaceWithHTML = &call_streamReplaceWithHTML,
        .call_streamReplaceWithHTMLUnsafe = &call_streamReplaceWithHTMLUnsafe,
        .call_substringData = &call_substringData,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("CharacterData has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(CharacterDataImpl, "init") and @hasDecl(CharacterDataImpl, "initOwn")) @compileError("CharacterDataImpl defines both init and initOwn");
        if (comptime @hasDecl(CharacterDataImpl, "init")) return CharacterDataImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(CharacterDataImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try CharacterDataImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CharacterDataImpl, "init")) return false;
        if (comptime @hasDecl(CharacterDataImpl, "construction_args")) {
            inline for (CharacterDataImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CharacterDataImpl, "deinit") and @hasDecl(CharacterDataImpl, "deinitOwn")) @compileError("CharacterDataImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CharacterDataImpl, "deinit")) return CharacterDataImpl.deinit(instance);
        if (comptime @hasDecl(CharacterDataImpl, "deinitOwn")) CharacterDataImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CharacterData")) {
            if (comptime @hasDecl(impls.CharacterData, "installHooks")) impls.CharacterData.installHooks();
        }
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_data(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try CharacterDataImpl.get_data(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_data(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        try CharacterDataImpl.set_data(instance, value);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try CharacterDataImpl.get_length(instance);
    }

    pub const get_previousElementSibling = mixins.NonDocumentTypeChildNode.get_previousElementSibling;

    pub const get_nextElementSibling = mixins.NonDocumentTypeChildNode.get_nextElementSibling;

    pub const call_before = mixins.ChildNode.call_before;

    pub const call_replaceWithHTML = mixins.NonDocumentTypeChildNode.call_replaceWithHTML;

    pub const call_afterHTMLUnsafe = mixins.NonDocumentTypeChildNode.call_afterHTMLUnsafe;

    pub const call_streamReplaceWithHTML = mixins.NonDocumentTypeChildNode.call_streamReplaceWithHTML;

    pub const call_remove = mixins.ChildNode.call_remove;

    pub const call_afterHTML = mixins.NonDocumentTypeChildNode.call_afterHTML;

    pub const call_beforeHTMLUnsafe = mixins.NonDocumentTypeChildNode.call_beforeHTMLUnsafe;

    pub const call_streamAfterHTMLUnsafe = mixins.NonDocumentTypeChildNode.call_streamAfterHTMLUnsafe;

    pub const call_after = mixins.ChildNode.call_after;

    pub fn call_appendData(instance: *runtime.Instance, data: runtime.DOMString) anyerror!void {
        return try CharacterDataImpl.call_appendData(instance, data);
    }

    pub fn call_substringData(instance: *runtime.Instance, offset: u32, count: u32) anyerror!runtime.DOMString {
        return try CharacterDataImpl.call_substringData(instance, offset, count);
    }

    pub fn call_insertData(instance: *runtime.Instance, offset: u32, data: runtime.DOMString) anyerror!void {
        return try CharacterDataImpl.call_insertData(instance, offset, data);
    }

    pub const call_beforeHTML = mixins.NonDocumentTypeChildNode.call_beforeHTML;

    pub fn call_replaceData(instance: *runtime.Instance, offset: u32, count: u32, data: runtime.DOMString) anyerror!void {
        return try CharacterDataImpl.call_replaceData(instance, offset, count, data);
    }

    pub const call_replaceWithHTMLUnsafe = mixins.NonDocumentTypeChildNode.call_replaceWithHTMLUnsafe;

    pub fn call_deleteData(instance: *runtime.Instance, offset: u32, count: u32) anyerror!void {
        return try CharacterDataImpl.call_deleteData(instance, offset, count);
    }

    pub const call_streamBeforeHTML = mixins.NonDocumentTypeChildNode.call_streamBeforeHTML;

    pub const call_streamAfterHTML = mixins.NonDocumentTypeChildNode.call_streamAfterHTML;

    pub const call_replaceWith = mixins.ChildNode.call_replaceWith;

    pub const call_streamBeforeHTMLUnsafe = mixins.NonDocumentTypeChildNode.call_streamBeforeHTMLUnsafe;

    pub const call_streamReplaceWithHTMLUnsafe = mixins.NonDocumentTypeChildNode.call_streamReplaceWithHTMLUnsafe;

    /// WebIDL [LegacyNullToEmptyString]: the values null converts to "" for
    /// (bit i = argument i; an attribute setter's value is bit 0).
    pub const legacy_null_to_empty = .{
        .{ "set_data", 0b1 },
    };

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "call_before",
        "call_replaceWithHTML",
        "call_afterHTMLUnsafe",
        "call_streamReplaceWithHTML",
        "call_remove",
        "call_afterHTML",
        "call_beforeHTMLUnsafe",
        "call_after",
        "call_beforeHTML",
        "call_replaceWithHTMLUnsafe",
        "call_replaceWith",
        "call_streamReplaceWithHTMLUnsafe",
    };
};
