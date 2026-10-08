//! The form-associated custom elements that have a `form` content attribute,
//! by element and by the ID their attribute names: HTML 4.10.18.3's ID-target
//! condition ("When a listed form-associated element has a form attribute and
//! the ID of any of the elements in the tree changes ... or an element with
//! an ID is inserted into or removed from the Document ... reset the form
//! owner"). An ID that enters, leaves or changes in a tree costs one hash
//! lookup on its value; the elements found are reset, and nothing else is.
//!
//! The design is Blink's FormAttributeTargetObserver: an IdTargetObserver a
//! listed element registers under its form attribute's value, notified by its
//! TreeScope when an element with that ID is added or removed
//! (IdTargetObserverRegistry::NotifyObservers). Blink keeps one registry per
//! TreeScope; this one is the agent's, keyed by the value's hash, because
//! the element's form owner is re-derived from its own tree on every reset -
//! a hit from another tree, or a hash collision, costs one extra derivation
//! and never a wrong owner.
//!
//! Elements are kept by address with their slab generation and realm, and
//! leave when they are torn down or their realm ends (AgentState.cancelElement
//! and clearRealm); the caller checks an entry's generation before every
//! dereference, so an entry a teardown missed is dropped, never followed.
const std = @import("std");

pub fn FormIdObservers(comptime Element: type, comptime Realm: type) type {
    return struct {
        const Self = @This();

        pub const Entry = struct {
            realm: Realm,
            generation: u64,
            id_hash: u64,
        };

        by_element: std.AutoHashMapUnmanaged(Element, Entry) = .empty,
        by_id: std.AutoHashMapUnmanaged(u64, std.ArrayListUnmanaged(Element)) = .empty,

        pub fn hashId(id: []const u8) u64 {
            return std.hash.Wyhash.hash(0, id);
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            var lists = self.by_id.valueIterator();
            while (lists.next()) |list| list.deinit(allocator);
            self.by_id.deinit(allocator);
            self.by_element.deinit(allocator);
            self.* = .{};
        }

        pub fn count(self: *const Self) usize {
            return self.by_element.count();
        }

        pub fn get(self: *const Self, element: Element) ?Entry {
            return self.by_element.get(element);
        }

        /// Observe `element` under `entry.id_hash`, replacing whatever was
        /// kept at its address: the same element under another value, or a
        /// dead element at a reissued address.
        pub fn put(self: *Self, allocator: std.mem.Allocator, element: Element, entry: Entry) !void {
            if (self.by_element.getPtr(element)) |kept| {
                if (kept.id_hash == entry.id_hash) {
                    kept.* = entry;
                    return;
                }
                const old_hash = kept.id_hash;
                _ = self.by_element.remove(element);
                self.unlist(allocator, element, old_hash);
            }
            try self.by_element.ensureUnusedCapacity(allocator, 1);
            const list = try self.by_id.getOrPut(allocator, entry.id_hash);
            if (!list.found_existing) list.value_ptr.* = .empty;
            list.value_ptr.append(allocator, element) catch |err| {
                if (list.value_ptr.items.len == 0) {
                    list.value_ptr.deinit(allocator);
                    _ = self.by_id.remove(entry.id_hash);
                }
                _ = self.by_element.remove(element);
                return err;
            };
            self.by_element.putAssumeCapacity(element, entry);
        }

        pub fn remove(self: *Self, allocator: std.mem.Allocator, element: Element) void {
            const old = self.by_element.fetchRemove(element) orelse return;
            self.unlist(allocator, element, old.value.id_hash);
        }

        /// Every element of `realm`: its instances are about to be destroyed.
        pub fn removeRealm(self: *Self, allocator: std.mem.Allocator, realm: Realm) void {
            if (self.by_element.count() == 0) return;
            var doomed: std.ArrayListUnmanaged(Element) = .empty;
            defer doomed.deinit(allocator);
            var all = self.by_element.iterator();
            while (all.next()) |entry| {
                if (entry.value_ptr.realm != realm) continue;
                doomed.append(allocator, entry.key_ptr.*) catch break;
            } else {
                for (doomed.items) |element| self.remove(allocator, element);
                return;
            }
            // Out of memory for the list: one at a time.
            while (true) {
                var found: ?Element = null;
                var entries = self.by_element.iterator();
                while (entries.next()) |entry| {
                    if (entry.value_ptr.realm == realm) {
                        found = entry.key_ptr.*;
                        break;
                    }
                }
                self.remove(allocator, found orelse return);
            }
        }

        /// The elements observing an ID whose hash is `id_hash`, borrowed:
        /// copy them before resetting any, since a reset re-registers.
        pub fn matching(self: *const Self, id_hash: u64) []const Element {
            const list = self.by_id.getPtr(id_hash) orelse return &.{};
            return list.items;
        }

        fn unlist(self: *Self, allocator: std.mem.Allocator, element: Element, id_hash: u64) void {
            const list = self.by_id.getPtr(id_hash) orelse return;
            for (list.items, 0..) |item, i| {
                if (item == element) {
                    _ = list.swapRemove(i);
                    break;
                }
            }
            if (list.items.len == 0) {
                list.deinit(allocator);
                _ = self.by_id.remove(id_hash);
            }
        }
    };
}
