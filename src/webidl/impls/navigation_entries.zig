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
/// generation) and its document is its navigable's active document.
pub fn scopeOf(window: *runtime.Instance, generation: u64) ?Scope {
    if (runtime.SlabAllocator.generationOf(window) != generation) return null;
    const navigable = BrowsingContext.ofWindow(@ptrCast(window)) orelse return null;
    const active = navigable.getActiveDocument() orelse return null;
    const document: *runtime.Instance = @ptrCast(@alignCast(active));
    const shown = interfaces.Window.get_document(window) catch return null;
    if (shown != document) return null;
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

/// StructuredSerializeForStorage(`value`): a primitive or string as it is,
/// an object through V8's serializer (which throws the DataCloneError).
pub fn serialize(allocator: std.mem.Allocator, value: runtime.JSValue) !joint_history.SerializedState {
    return switch (value) {
        .undefined => .undefined,
        .null => .null,
        .boolean => |b| .{ .boolean = b },
        .number => |n| .{ .number = n },
        .string => |s| .{ .string = try allocator.dupe(u8, s.data) },
        .handle => |h| blk: {
            const v8 = @import("v8");
            var no_transfer: [1]*v8.ffi.Value = undefined;
            var no_buffers: [1]v8.ffi.ArrayBufferTransferData = undefined;
            var size: usize = 0;
            var code: c_int = 0;
            const bytes = v8.ffi.v8_Value_StructuredSerializeWithTransfer(
                @ptrCast(@alignCast(h.ptr)),
                &no_transfer,
                0,
                &size,
                &no_buffers,
                &code,
            ) orelse return if (code == 3) error.ExceptionPending else error.DataCloneError;
            defer v8.ffi.v8_Free_SerializedBuffer(bytes);
            break :blk .{ .bytes = try allocator.dupe(u8, bytes[0..size]) };
        },
        // A platform object the binding handed over unwrapped: none is
        // [Serializable] here yet.
        .instance => error.DataCloneError,
    };
}

/// StructuredDeserialize(`state`) in the current realm - a fresh value each
/// call. An object comes back as a Global the caller (the binding) owns; a
/// string is borrowed from `state`, which outlives the binding's conversion.
pub fn deserialize(state: joint_history.SerializedState) !runtime.JSValue {
    return switch (state) {
        .undefined => runtime.JSValue.jsUndefined,
        .null => runtime.JSValue.jsNull,
        .boolean => |b| runtime.JSValue.fromBoolean(b),
        .number => |n| runtime.JSValue.fromNumber(n),
        .string => |s| .{ .string = .{ .data = s, .owned = false } },
        .bytes => |b| blk: {
            const v8 = @import("v8");
            const no_buffers: [1]v8.ffi.ArrayBufferTransferData = undefined;
            var code: c_int = 0;
            const value = v8.ffi.v8_Value_DeserializeWithTransfer_CrossIsolate(b.ptr, b.len, &no_buffers, 0, &code) orelse
                return error.DataCloneError;
            break :blk runtime.JSValue{ .handle = .{ .ptr = @ptrCast(value) } };
        },
    };
}
