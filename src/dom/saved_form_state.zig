//! HTML 7.4.1 a session history entry's "persisted user state", for form
//! controls: what a document's controls held when it was left (saved into
//! the entry it showed, HTML 7.4.6.5 "save persisted state" step 2), and the
//! states a document made by a back/forward traversal to that entry gives
//! its new controls ("restore persisted state" step 2). HTML leaves the
//! state implementation-defined and suggests the values of form controls;
//! this is Blink's FormController state (core/html/forms/form_controller.cc),
//! which WebKit's FormController shares:
//!
//!   - the controls are grouped by a FORM KEY - the owner form's signature
//!     (its action URL without the query, and its first two named controls)
//!     and its index among the forms with that signature, or "No owner";
//!   - in each group every control saved a (name, type, values) triple, in
//!     tree order; values may be empty (the control kept its default), and a
//!     control still takes its place in its (name, type) queue then;
//!   - a new control takes the FIRST state queued for its form key, name and
//!     type (Blink SavedFormState::TakeControlState's Deque).
//!
//! The bytes an entry holds (`encode`) are Blink's state vector of strings,
//! each a u32 little-endian length and its bytes: a signature, then per
//! form its key, its control count and each control's name, type, value
//! count and values. `Saved` is a document's decoded copy - its FormController
//! saved_form_state_map_ - owned by the document (its interaction state,
//! dom.document_state) until the document goes.
//!
//! What a control saves and how it is restored, and when, are
//! html.forms.form_state's; this file is the data and its owner.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const document_state = @import("document_state.zig");

/// Changed whenever the encoding changes: bytes of another version are
/// dropped, not misread (Blink's FormStateSignature, "version 10").
pub const signature = "\n\r?% Crane serialized form state version 1 \n\r=&";

/// One control's saved state.
pub const ControlState = struct {
    name: []const u8,
    type: []const u8,
    /// Blink's FormControlState values; empty when the control kept its
    /// default (nothing to restore, but it holds its place in its queue).
    values: []const []const u8,
};

/// One form key's controls, in tree order.
pub const FormState = struct {
    key: []const u8,
    controls: []const ControlState,
};

fn appendString(allocator: Allocator, out: *std.ArrayList(u8), text: []const u8) Allocator.Error!void {
    var length: [4]u8 = undefined;
    std.mem.writeInt(u32, &length, @intCast(text.len), .little);
    try out.appendSlice(allocator, &length);
    try out.appendSlice(allocator, text);
}

fn appendCount(allocator: Allocator, out: *std.ArrayList(u8), count: usize) Allocator.Error!void {
    var buffer: [20]u8 = undefined;
    try appendString(allocator, out, std.fmt.bufPrint(&buffer, "{d}", .{count}) catch unreachable);
}

/// The bytes for `forms` (Blink DocumentState::ToStateVector), owned by
/// `allocator`; null when there is no form - an entry with no state.
pub fn encode(allocator: Allocator, forms: []const FormState) Allocator.Error!?[]u8 {
    if (forms.len == 0) return null;
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try appendString(allocator, &out, signature);
    for (forms) |form| {
        try appendString(allocator, &out, form.key);
        try appendCount(allocator, &out, form.controls.len);
        for (form.controls) |control| {
            try appendString(allocator, &out, control.name);
            try appendString(allocator, &out, control.type);
            try appendCount(allocator, &out, control.values.len);
            for (control.values) |value| try appendString(allocator, &out, value);
        }
    }
    return try out.toOwnedSlice(allocator);
}

/// The states for a document's new controls (Blink FormController's
/// saved_form_state_map_), each taken at most once.
pub const Saved = struct {
    arena: std.heap.ArenaAllocator,
    forms: []Form = &.{},
    /// Every control in the document had its turn (Blink's did_restore_all_).
    restored_all: bool = false,

    const Form = struct { key: []const u8, controls: []Control };
    const Control = struct { name: []const u8, type: []const u8, values: []const []const u8, taken: bool = false };

    const Reader = struct {
        bytes: []const u8,
        at: usize = 0,

        fn string(self: *Reader) error{Malformed}![]const u8 {
            if (self.bytes.len - self.at < 4) return error.Malformed;
            const length = std.mem.readInt(u32, self.bytes[self.at..][0..4], .little);
            self.at += 4;
            if (self.bytes.len - self.at < length) return error.Malformed;
            const text = self.bytes[self.at .. self.at + length];
            self.at += length;
            return text;
        }

        fn count(self: *Reader) error{Malformed}!usize {
            const n = std.fmt.parseInt(u32, try self.string(), 10) catch return error.Malformed;
            return n;
        }
    };

    /// `bytes` (from `encode`) decoded, owned by `allocator`; null for bytes
    /// of another version, malformed ones or no control (Blink
    /// ControlStatesFromStateVector clears its map on any of these).
    pub fn decode(allocator: Allocator, bytes: []const u8) Allocator.Error!?*Saved {
        const self = try allocator.create(Saved);
        self.* = .{ .arena = std.heap.ArenaAllocator.init(allocator) };
        errdefer self.destroy();
        const ok = self.read(bytes) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.Malformed => false,
        };
        if (!ok or self.isEmpty()) {
            self.destroy();
            return null;
        }
        return self;
    }

    fn read(self: *Saved, bytes: []const u8) (Allocator.Error || error{Malformed})!bool {
        const arena = self.arena.allocator();
        // The bytes belong to the entry, which may change or go: copied.
        var reader: Reader = .{ .bytes = try arena.dupe(u8, bytes) };
        if (!std.mem.eql(u8, try reader.string(), signature)) return false;
        var forms: std.ArrayList(Form) = .empty;
        while (reader.at < reader.bytes.len) {
            const key = try reader.string();
            const n = try reader.count();
            if (n == 0) return error.Malformed;
            const controls = try arena.alloc(Control, n);
            for (controls) |*control| {
                const name = try reader.string();
                const kind = try reader.string();
                const values = try arena.alloc([]const u8, try reader.count());
                for (values) |*value| value.* = try reader.string();
                // Blink SavedFormState::Deserialize: a type of lower case
                // letters and '-' (custom element names aside) or nothing.
                if (kind.len == 0) return error.Malformed;
                for (kind) |c| if (c != '-' and !std.ascii.isLower(c)) return error.Malformed;
                control.* = .{ .name = name, .type = kind, .values = values };
            }
            try forms.append(arena, .{ .key = key, .controls = controls });
        }
        self.forms = try forms.toOwnedSlice(arena);
        return true;
    }

    pub fn destroy(self: *Saved) void {
        const allocator = self.arena.child_allocator;
        self.arena.deinit();
        allocator.destroy(self);
    }

    /// Whether every state was taken (or there was none).
    pub fn isEmpty(self: *const Saved) bool {
        for (self.forms) |form| for (form.controls) |control| if (!control.taken) return false;
        return true;
    }

    /// The first state not yet taken that `form_key`'s form saved for a
    /// control named `name` of type `kind` (Blink TakeStateForControl), or
    /// null. Its values live as long as this Saved.
    pub fn take(self: *Saved, form_key: []const u8, name: []const u8, kind: []const u8) ?[]const []const u8 {
        for (self.forms) |form| {
            if (!std.mem.eql(u8, form.key, form_key)) continue;
            for (form.controls) |*control| {
                if (control.taken or !std.mem.eql(u8, control.name, name) or !std.mem.eql(u8, control.type, kind)) continue;
                control.taken = true;
                return control.values;
            }
            return null;
        }
        return null;
    }
};

/// `document`'s states for its new controls, if a traversal gave it some
/// that are not all taken.
pub fn of(document: *runtime.Instance) ?*Saved {
    const internal = document_state.Registry.get(document) orelse return null;
    const shared = internal.interaction_state orelse return null;
    return shared.saved_form_state;
}

/// Give `document` the states `bytes` encode (Blink
/// Document::SetStateForNewControls), replacing any it had. The document
/// owns them until `release` or its end.
pub fn set(document: *runtime.Instance, bytes: []const u8) Allocator.Error!void {
    const internal = document_state.Registry.get(document) orelse return;
    const saved = try Saved.decode(internal.allocator, bytes) orelse {
        release(document);
        return;
    };
    errdefer saved.destroy();
    const shared = try internal.ensureInteractionState();
    if (shared.saved_form_state) |old| old.destroy();
    shared.saved_form_state = saved;
}

/// Drop `document`'s states: every control had its turn.
pub fn release(document: *runtime.Instance) void {
    const internal = document_state.Registry.get(document) orelse return;
    const shared = internal.interaction_state orelse return;
    const saved = shared.saved_form_state orelse return;
    shared.saved_form_state = null;
    saved.destroy();
}
