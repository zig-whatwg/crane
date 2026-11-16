//! Pointer Events 4: a top-level traversable's active pointers and their
//! pointer capture (section 8, "Pointer capture"; 3.1.2 "The primary
//! pointer"; 3.1.3 "Firing events using the PointerEvent interface").
//!
//! The state is the traversable's (`BrowsingContext.active_pointers`, on a
//! top-level context): every tab has its own pointers, as in a browser. The
//! mouse is always an active pointer ("A mouse ... is always active" in
//! practice: Chrome, Firefox and Safari accept setPointerCapture(1) with no
//! press, pointerevents/pointerevent_setpointercapture_inactive_button_mouse
//! .html PASS in all three at wpt.fyi 2358bd4835), so its entry is made the
//! first time it is needed; a touch contact or a pen is active from the
//! moment the embedder's input layer (html.user_input) says so until it
//! leaves the surface.
//!
//! A shared helper (src/dom, AGENTS.md "The impls boundary" rule 3): the
//! callers - Element's capture methods and html.user_input, which fires the
//! events - find the traversable and the nodes; this keeps the state and the
//! steps on it.
//!
//! Spec: https://w3c.github.io/pointerevents/#pointer-capture

const std = @import("std");
const runtime = @import("runtime");
const html_core = @import("html_core");
const document_activity = @import("document_activity.zig");

pub const ActivePointers = @FieldType(html_core.BrowsingContext, "active_pointers");
pub const Entry = ActivePointers.Entry;
pub const Ref = ActivePointers.Ref;

/// A pointer's pointerType.
pub const Kind = enum(u8) {
    mouse,
    pen,
    touch,
};

/// The pointerId of the user agent's one mouse (WebDriver 15.2.3 reserves
/// 0 and 1 for mouse-type pointers; every engine reports 1).
pub const mouse_id: i32 = 1;

/// `instance`, as an identity with its slab generation.
pub fn refOf(instance: *runtime.Instance) Ref {
    return .{ .node = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
}

/// The object a Ref names, while it still means it.
pub fn get(ref: ?Ref) ?*runtime.Instance {
    const r = ref orelse return null;
    const instance: *runtime.Instance = @ptrCast(@alignCast(r.node));
    if (runtime.SlabAllocator.generationOf(instance) != r.generation) return null;
    return instance;
}

/// Whether `ref` names `instance`.
pub fn names(ref: ?Ref, instance: *runtime.Instance) bool {
    const target = get(ref) orelse return false;
    return target == instance;
}

/// The active pointer `id` of `pointers`; the mouse's entry is made when it
/// is first asked for (it is always active). Null: no such active pointer,
/// or no room for the mouse's entry.
pub fn find(pointers: *ActivePointers, id: i32) ?*Entry {
    for (pointers.items[0..pointers.count]) |*entry| if (entry.id == id) return entry;
    if (id == mouse_id) return activate(pointers, id, .mouse);
    return null;
}

/// Make `id` an active pointer of `pointers` (a touch contact placed, a pen
/// in range); its entry, kept if it was already active. Null when every
/// slot is taken: more simultaneous pointers than this user agent tracks
/// (Pointer Events 3.1.3.3 lets a user agent suppress those).
pub fn activate(pointers: *ActivePointers, id: i32, kind: Kind) ?*Entry {
    for (pointers.items[0..pointers.count]) |*entry| if (entry.id == id) return entry;
    if (pointers.count == ActivePointers.capacity) return null;
    pointers.items[pointers.count] = .{ .id = id, .kind = @backingInt(kind) };
    pointers.count += 1;
    return &pointers.items[pointers.count - 1];
}

/// `id` is no longer an active pointer (a touch contact lifted, a pen out of
/// range).
pub fn deactivate(pointers: *ActivePointers, id: i32) void {
    for (pointers.items[0..pointers.count], 0..) |entry, i| {
        if (entry.id != id) continue;
        pointers.items[i] = pointers.items[pointers.count - 1];
        pointers.count -= 1;
        return;
    }
}

/// Drop every touch contact of `pointers` whose active document is no
/// longer fully active (`document_activity`): the document it was touching
/// has gone - its frame was removed or navigated away - so the contact's
/// events have nowhere to go, and the input layer, which finds this state
/// through a document, cannot reach it to say the contact lifted
/// (html.user_input `inFullyActiveDocument` says what the engines do). Run
/// as a touch contact is placed, before it is asked whether it is primary.
/// The mouse and a pen are devices, active with or without a document, and
/// stay.
pub fn dropContactsOfGoneDocuments(pointers: *ActivePointers) void {
    var i: usize = 0;
    while (i < pointers.count) {
        const entry = pointers.items[i];
        const gone = entry.kind == @backingInt(Kind.touch) and if (entry.active_document) |ref|
            !document_activity.fullyActive(ref.node, ref.generation)
        else
            false;
        if (!gone) {
            i += 1;
            continue;
        }
        pointers.items[i] = pointers.items[pointers.count - 1];
        pointers.count -= 1;
    }
}

/// 3.1.2: whether a pointer of `kind` that becomes active now is the
/// primary pointer of its type - "The first pointer to become active for a
/// particular pointer type ... becomes the primary pointer": no other
/// active pointer of that type is in contact (the mouse is always primary).
pub fn wouldBePrimary(pointers: *ActivePointers, id: i32, kind: Kind) bool {
    if (kind == .mouse) return true;
    for (pointers.items[0..pointers.count]) |entry| {
        if (entry.id != id and entry.kind == @backingInt(kind) and entry.buttons_active) return false;
    }
    return true;
}

pub const SetError = error{ NotFoundError, InvalidStateError };

/// 8.2 "Setting pointer capture", `element.setPointerCapture(id)`, after
/// the caller found `element`'s traversable's `pointers`: whether it is
/// connected, its node document, and whether that document has a pointer
/// lock element.
pub fn setPointerCapture(pointers: *ActivePointers, id: i32, element: *runtime.Instance, connected: bool, document: ?*runtime.Instance, locked: bool) SetError!void {
    // Steps 1-2: "If the pointerId provided as the method's argument does
    // not match any of the active pointers, then throw a NotFoundError".
    const pointer = find(pointers, id) orelse return error.NotFoundError;
    // Step 3: "If the element is not connected, throw an InvalidStateError".
    if (!connected) return error.InvalidStateError;
    // Step 4: a locked element in its node document.
    if (locked) return error.InvalidStateError;
    // Step 5: "If the pointer is not in the active buttons state or the
    // element's node document is not the active document of the pointer,
    // then terminate these steps."
    if (!pointer.buttons_active) return;
    const doc = document orelse return;
    if (!names(pointer.active_document, doc)) return;
    // Step 6: "set the pending pointer capture target override to the
    // Element on which this method was invoked."
    pointer.pending = refOf(element);
}

/// 8.3 "Releasing pointer capture", `element.releasePointerCapture(id)`.
pub fn releasePointerCapture(pointers: *ActivePointers, id: i32, element: *runtime.Instance) error{NotFoundError}!void {
    // Step 1: no active pointer with that pointerId: NotFoundError.
    const pointer = find(pointers, id) orelse return error.NotFoundError;
    // Step 2: "If hasPointerCapture is false for the Element with the
    // specified pointerId, then terminate these steps."
    if (!names(pointer.pending, element)) return;
    // Step 3: "clear the pending pointer capture target override, if set."
    pointer.pending = null;
}

/// 4.1 hasPointerCapture(pointerId): "returns true if the pending pointer
/// capture target override for pointerId is set to the element on which
/// this method is invoked, and false otherwise."
pub fn hasPointerCapture(pointers: *ActivePointers, id: i32, element: *runtime.Instance) bool {
    for (pointers.items[0..pointers.count]) |entry| {
        if (entry.id == id) return names(entry.pending, element);
    }
    return false;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "the mouse is always active; other pointers only while activated" {
    var pointers: ActivePointers = .{};
    try testing.expect(find(&pointers, 2) == null);
    try testing.expect(find(&pointers, mouse_id) != null);
    try testing.expectEqual(@as(usize, 1), pointers.count);
    const touch = activate(&pointers, 2, .touch).?;
    touch.buttons_active = true;
    try testing.expect(find(&pointers, 2) == touch);
    // A second touch in contact is not primary; the first one is.
    try testing.expect(!wouldBePrimary(&pointers, 3, .touch));
    try testing.expect(wouldBePrimary(&pointers, 2, .touch));
    try testing.expect(wouldBePrimary(&pointers, 4, .pen));
    deactivate(&pointers, 2);
    try testing.expect(find(&pointers, 2) == null);
    try testing.expect(wouldBePrimary(&pointers, 3, .touch));
}

test "capacity bounds the active pointers" {
    var pointers: ActivePointers = .{};
    for (0..ActivePointers.capacity) |i| try testing.expect(activate(&pointers, @intCast(i + 2), .touch) != null);
    try testing.expect(activate(&pointers, 100, .touch) == null);
}
