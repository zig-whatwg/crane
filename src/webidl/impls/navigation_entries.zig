//! The navigation API's view of a window's navigable (HTML 7.2.6.3): the
//! navigable and its traversable's session history while the window's
//! document is fully active, whether entries and events are disabled, and
//! navigation API state serialized for the history and deserialized for
//! getState(). Shared by Navigation and NavigationHistoryEntry.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const html_core = @import("html_core");
const BrowsingContext = html_core.window.BrowsingContext;
const joint_history = html_core.navigation.joint_history;
const history_documents = @import("history_documents.zig");
const engine = @import("engine");

/// A window whose document is fully active: its navigable, that document,
/// and the traversable's session history (with entries for the navigable
/// and its ancestors).
pub const Scope = struct {
    window: *runtime.Instance,
    navigable: *BrowsingContext,
    document: *runtime.Instance,
    history: *joint_history.JointHistory,
};

/// `window`'s scope - when it is still the window it was (its slab
/// generation) and its navigable's active window, whose document is then
/// the navigable's active document.
///
/// Asked of the navigable, never through `window.document`: that getter is
/// script's, with script's cross-origin check against the incumbent realm,
/// and this is asked on behalf of whatever script is running - the top
/// page's, navigating a cross-origin frame, made every frame's navigation
/// API see its own document as not fully active, and "fire a push/replace/
/// reload navigate event" canceled the navigation (see
/// docs/lessons/architecture-a-frame-s-load-event-has-exactly-one-owner-and.md:
/// engine code asking about a frame must not use the getters script uses).
pub fn scopeOf(window: *runtime.Instance, generation: u64) ?Scope {
    if (runtime.SlabAllocator.generationOf(window) != generation) return null;
    const navigable = BrowsingContext.ofWindow(@ptrCast(window)) orelse return null;
    const active = navigable.getActiveDocument() orelse return null;
    const document: *runtime.Instance = @ptrCast(@alignCast(active));
    const history = navigable.ensureHistoryEntries(&history_documents.infoOf) catch return null;
    return .{ .window = window, .navigable = navigable, .document = document, .history = history };
}

/// "Has entries and events disabled": the document is not fully active (no
/// scope), is the initial about:blank, or has an opaque origin.
pub fn disabled(scope: ?Scope) bool {
    const s = scope orelse return true;
    if (@import("dom").document_lifecycle.isInitialAboutBlank(s.document)) return true;
    const current = s.history.currentEntry(s.navigable.id) orelse return true;
    return std.mem.eql(u8, current.origin, "null");
}

/// StructuredSerializeForStorage(`value`) for a session history entry: a
/// primitive or string as it is, anything else through the engine's
/// serializer, in `realm`. `error.DataCloneError` means "throw a
/// DataCloneError" (nothing is thrown yet); `error.ExceptionPending` means
/// script threw while serializing (a getter).
pub fn serialize(realm: runtime.Context, allocator: std.mem.Allocator, value: runtime.JSValue) !joint_history.SerializedState {
    return switch (value) {
        .undefined => .undefined,
        .null => .null,
        .boolean => |b| .{ .boolean = b },
        .number => |n| .{ .number = n },
        .string => |s| .{ .string = try allocator.dupe(u8, s.data) },
        .handle, .instance => .{ .bytes = try engine.structuredSerializeForStorage(realm, value, allocator) },
    };
}

/// StructuredDeserialize(`state`) in `realm` - a fresh value each call,
/// OWNED by the caller: release it, or `take()` it as an operation's result.
pub fn deserialize(realm: runtime.Context, state: joint_history.SerializedState) !engine.Owned {
    return switch (state) {
        .undefined => engine.retainValue(realm, runtime.JSValue.jsUndefined),
        .null => engine.retainValue(realm, runtime.JSValue.jsNull),
        .boolean => |b| engine.retainValue(realm, runtime.JSValue.fromBoolean(b)),
        .number => |n| engine.retainValue(realm, runtime.JSValue.fromNumber(n)),
        .string => |s| engine.retainValue(realm, runtime.JSValue.fromStringRef(s)),
        .bytes => |b| engine.structuredDeserialize(realm, b),
    };
}
