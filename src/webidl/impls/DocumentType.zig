//! Implementation for DocumentType interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-documenttype
//! WHATWG DOM Standard §4.7
//!
//! DocumentType nodes represent the <!DOCTYPE> declaration.
//! They have a name, publicId, and systemId.
//!
//! Migrated from: webidl/src/dom/DocumentType.zig

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const DocumentType = interfaces.DocumentType;

// Import related impls
const NodeImpl = @import("Node.zig");

pub const State = DocumentType.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

/// Internal state for DocumentType implementation
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The name of the doctype (e.g., "html" for <!DOCTYPE html>)
    name: []const u8,

    /// The public identifier (empty string if not specified)
    public_id: []const u8,

    /// The system identifier (empty string if not specified)
    system_id: []const u8,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .name = "",
            .public_id = "",
            .system_id = "",
        };
    }

    pub fn deinit(self: *InternalState) void {
        if (self.name.len > 0) self.allocator.free(self.name);
        if (self.public_id.len > 0) self.allocator.free(self.public_id);
        if (self.system_id.len > 0) self.allocator.free(self.system_id);
    }
};

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;
const Registry = runtime.InstanceRegistry(.document_type, InternalState);

/// Get the internal state from an instance
/// Made public for use by HTMLParser when creating DOCTYPE nodes.
pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // Its states left at its Browser's end (Browser.deinit).
    @import("dom").teardown_sweeps.install(.node_types, &sweepRemaining);
    // The parsers set a doctype's identifiers through `dom.node_creation`.
    @import("dom").node_creation.installDocumentType(.{ .set_ids = &setIdsHook });
}

/// A doctype's name, public ID and system ID, given at construction: DOM's
/// createDocumentType() and createHTMLDocument() make "a new doctype, with
/// name as its name, publicId as its public ID, and systemId as its system
/// ID" (WebKit's DocumentType::create(document, name, publicId, systemId)).
/// Each one not given is "".
pub const construction_args = .{ "name", "public_id", "system_id" };

/// DocumentType's own construction steps: the generated chain runs Node's first.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;

    // Initialize DocumentType internal state in global registry
    // The registry owns this block, so `Registry.remove` returns it to the
    // arena. With `set` it was dropped from the map and held to process
    // exit - 904 bytes per discarded element, measured.
    const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
    errdefer Registry.remove(instance);
    internal.* = InternalState.init(allocator);
    errdefer internal.deinit();
    const Args = @TypeOf(args);
    if (@hasField(Args, "name")) internal.name = try allocator.dupe(u8, args.name);
    if (@hasField(Args, "public_id")) internal.public_id = try allocator.dupe(u8, args.public_id);
    if (@hasField(Args, "system_id")) internal.system_id = try allocator.dupe(u8, args.system_id);
}

/// `dom.node_creation.setDoctypeIds`: the parser's DOCTYPE token's name,
/// public identifier and system identifier; a missing one stays "".
fn setIdsHook(doctype: *runtime.Instance, name: ?[]const u8, public_id: ?[]const u8, system_id: ?[]const u8) void {
    const internal = getInternal(doctype) orelse return;
    if (name) |n| internal.name = internal.allocator.dupe(u8, n) catch "";
    if (public_id) |p| internal.public_id = internal.allocator.dupe(u8, p) catch "";
    if (system_id) |s| internal.system_id = internal.allocator.dupe(u8, s) catch "";
}

/// DocumentType's own teardown: the generated chain runs Node's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    // Clean up from registry
    if (Registry.get(instance)) |internal| {
        internal.deinit();
    }
    Registry.remove(instance);
}

// =============================================================================
// Getters - DOM §4.7
// =============================================================================

/// Getter for name
/// DOM §4.7 - Returns this's name.
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.name);
}

/// Getter for publicId
/// DOM §4.7 - Returns this's public ID.
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_publicId(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.public_id);
}

/// Getter for systemId
/// DOM §4.7 - Returns this's system ID.
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_systemId(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.system_id);
}

// =============================================================================
// ChildNode Mixin Operations
// =============================================================================

// Import mixins for shared interface methods
const mixins = @import("mixins");

// =============================================================================
// Helper Functions
// =============================================================================

/// dom.teardown_sweeps: at its Browser's end, every DocumentType state still in
/// `scope`'s table - an orphan's no teardown reached - frees what it owns.
fn sweepRemaining(scope: *runtime.BrowserScope) void {
    Registry.deinitAllAndClear(scope);
}
