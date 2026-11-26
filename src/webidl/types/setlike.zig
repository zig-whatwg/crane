//! WebIDL setlike declarations: an object's "set entries" (WebIDL 2.5.12).
//!
//! Spec: https://webidl.spec.whatwg.org/#idl-setlike
//!
//! "Objects implementing an interface that is declared to be setlike
//! represent an ordered set of values, initially empty, known as that
//! object's set entries." The impl owns its interface's set entries - a
//! `SetEntries(T)` - and reads them natively (CustomStateSet's `:state()`);
//! the binding defines the setlike members (3.7.12: size, has, forEach,
//! entries, keys, values, %Symbol.iterator%, and for a read-write setlike
//! add, delete and clear) over them. The generated interface hands them to the
//! binding (`setlikeEntries`); no member is an operation an impl implements
//! (docs/lessons/codegen-an-iterable-declaration-s-members-are-not-operations.md).
//!
//! Iteration is live (3.7.12.2: "The size of set, and the order of its
//! entries, might have changed while execution of this abstract operation was
//! paused"), as a JavaScript Set's is. Every entry carries the sequence number
//! it was appended with, increasing; an iterator keeps only the sequence of
//! the entry it yielded last and asks for the first entry after it (`after`).
//! So an entry deleted before the iterator reaches it is never yielded, a
//! deletion behind it moves nothing, and an append - a re-added value
//! included, which goes to the end - is yielded; after `empty()` the entries
//! appended next are yielded too. Nothing in the set points at an iterator:
//! no registry to unlink, no tombstone to compact, no finalizer. (Blink keeps
//! its CustomStateSet's iteration sources in a set that delete() adjusts;
//! Gecko and WebKit forward to a JavaScript Set kept beside the object.)

const std = @import("std");

/// The set entries of a setlike object whose values are `T`: `[]const u8`
/// for a string value type (the set keeps its own copy of each), or a scalar
/// compared with `==`.
pub fn SetEntries(comptime T: type) type {
    const owns_strings = T == []const u8;
    return struct {
        allocator: std.mem.Allocator,
        entries: std.ArrayList(Entry) = .empty,
        /// The sequence the next appended entry takes; 0 is "before every
        /// entry", where an iterator starts.
        next_sequence: u64 = 1,
        /// Optional change observer notified when entries are added, removed,
        /// or cleared (used by CustomStateSet for `:state()` style invalidation).
        on_change: ?ChangeHook = null,

        const Self = @This();

        pub const ChangeHook = struct {
            context: *anyopaque,
            callback: *const fn (*anyopaque) void,
        };

        pub const Entry = struct {
            sequence: u64,
            value: T,
        };

        fn notifyChanged(self: *Self) void {
            if (self.on_change) |hook| hook.callback(hook.context);
        }

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            if (owns_strings) {
                for (self.entries.items) |entry| self.allocator.free(entry.value);
            }
            self.entries.deinit(self.allocator);
            self.* = undefined;
        }

        fn eql(a: T, b: T) bool {
            if (owns_strings) return std.mem.eql(u8, a, b);
            return a == b;
        }

        fn indexOf(self: *const Self, value: T) ?usize {
            for (self.entries.items, 0..) |entry, index| {
                if (eql(entry.value, value)) return index;
            }
            return null;
        }

        /// The set's size (Infra: the number of items).
        pub fn size(self: *const Self) usize {
            return self.entries.items.len;
        }

        /// Whether the set contains `value`.
        pub fn contains(self: *const Self, value: T) bool {
            return self.indexOf(value) != null;
        }

        /// Infra "append" to an ordered set: nothing when the set contains
        /// `value`, otherwise `value` at the end (a string copied).
        pub fn append(self: *Self, value: T) !void {
            if (self.contains(value)) return;
            const stored = if (owns_strings) try self.allocator.dupe(u8, value) else value;
            errdefer if (owns_strings) self.allocator.free(stored);
            try self.entries.append(self.allocator, .{ .sequence = self.next_sequence, .value = stored });
            self.next_sequence += 1;
            self.notifyChanged();
        }

        /// Infra "remove" `value`; whether the set contained it.
        pub fn remove(self: *Self, value: T) bool {
            const index = self.indexOf(value) orelse return false;
            const entry = self.entries.orderedRemove(index);
            if (owns_strings) self.allocator.free(entry.value);
            self.notifyChanged();
            return true;
        }

        /// Infra "empty": the set keeps its identity and its sequence, so an
        /// iterator suspended over it yields what is appended afterwards.
        pub fn empty(self: *Self) void {
            const had_entries = self.entries.items.len != 0;
            if (owns_strings) {
                for (self.entries.items) |entry| self.allocator.free(entry.value);
            }
            self.entries.clearRetainingCapacity();
            if (had_entries) self.notifyChanged();
        }

        /// The first entry appended after the entry with sequence `sequence`
        /// (0: the first entry), or null: an iterator's next step. Entries
        /// are in sequence order, so a binary search finds it. The value is
        /// borrowed until the set changes.
        pub fn after(self: *const Self, sequence: u64) ?Entry {
            const items = self.entries.items;
            var low: usize = 0;
            var high: usize = items.len;
            while (low < high) {
                const middle = low + (high - low) / 2;
                if (items[middle].sequence <= sequence) low = middle + 1 else high = middle;
            }
            return if (low < items.len) items[low] else null;
        }

        /// The values in order, borrowed until the set changes.
        pub fn values(self: *const Self) ValueIterator {
            return .{ .entries = self.entries.items };
        }

        pub const ValueIterator = struct {
            entries: []const Entry,
            index: usize = 0,

            pub fn next(self: *ValueIterator) ?T {
                if (self.index >= self.entries.len) return null;
                defer self.index += 1;
                return self.entries[self.index].value;
            }
        };
    };
}

/// The set entries of a setlike<DOMString>, <USVString> or <ByteString>.
pub const Strings = SetEntries([]const u8);

/// The set entries of a setlike whose value type is an interface
/// (setlike<FontFace>), as the binding reads them: a view of the list the
/// impl keeps, and traces, itself - a platform object in a set must stay
/// alive while the set does, which only its owner's traced edges say (the
/// FontFaceSet's members, css-font-loading's Set). The values are the
/// platform objects (`runtime.Instance`s; opaque here, below the runtime).
///
/// Iteration (`after`) is the impl's: Gecko's and WebKit's FontFaceSet
/// iterators keep an index into the set's ordered list (Gecko
/// FontFaceSetIterator::Next, WebKit FontFaceSet::Iterator::next), and a
/// view whose entries are reordered (CSS-connected faces first, in rule
/// order) answers by position: `sequence` is the position after the entry.
pub const PlatformObjects = struct {
    context: *anyopaque,
    vtable: *const VTable,

    pub const Entry = struct {
        sequence: u64,
        value: *anyopaque,
    };

    pub const VTable = struct {
        size: *const fn (context: *anyopaque) usize,
        contains: *const fn (context: *anyopaque, value: *anyopaque) bool,
        after: *const fn (context: *anyopaque, sequence: u64) ?Entry,
        /// A read-write setlike whose interface does not declare add,
        /// delete and clear itself (3.7.12.8-10): the binding's members
        /// change the impl's list through these (Highlight's ranges). Null
        /// where the interface declares its own (FontFaceSet).
        append: ?*const fn (context: *anyopaque, value: *anyopaque) anyerror!void = null,
        remove: ?*const fn (context: *anyopaque, value: *anyopaque) bool = null,
        empty: ?*const fn (context: *anyopaque) void = null,
    };

    /// The set's size.
    pub fn size(self: *const PlatformObjects) usize {
        return self.vtable.size(self.context);
    }

    /// Whether the set contains the platform object `value`.
    pub fn contains(self: *const PlatformObjects, value: *anyopaque) bool {
        return self.vtable.contains(self.context, value);
    }

    /// An iterator's next step after the entry with `sequence` (0: before
    /// the first), or null.
    pub fn after(self: *const PlatformObjects, sequence: u64) ?Entry {
        return self.vtable.after(self.context, sequence);
    }

    /// Infra "append" the platform object `value`, which the impl traces;
    /// error.NotSupported where the impl's interface declares add itself.
    pub fn append(self: *PlatformObjects, value: *anyopaque) anyerror!void {
        const f = self.vtable.append orelse return error.NotSupported;
        return f(self.context, value);
    }

    /// Infra "remove" `value`; whether the set contained it.
    pub fn remove(self: *PlatformObjects, value: *anyopaque) bool {
        const f = self.vtable.remove orelse return false;
        return f(self.context, value);
    }

    /// Infra "empty".
    pub fn empty(self: *PlatformObjects) void {
        const f = self.vtable.empty orelse return;
        f(self.context);
    }
};

/// The name the webidl module re-exports (root.zig).
pub const Setlike = SetEntries;
