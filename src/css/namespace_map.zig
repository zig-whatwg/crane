//! A style sheet's namespace prefixes (CSS Namespaces 3 §2, the @namespace
//! rule): an IMMUTABLE, reference-counted map from prefix to namespace URI,
//! plus the default namespace. Shared, not copied: a pending-substitution
//! value retains its sheet's map, and so may the selector engine; the map
//! may outlive the sheet's compiled contents (CSSOM mutation, copies).
//!
//! Nothing here is attr()-specific (Values 5 §8.7 reads it through the
//! substitution Host).
//!
//! Spec: https://drafts.csswg.org/css-namespaces-3/#declaration
const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Entry = struct {
    prefix: []const u8,
    namespace: []const u8,
};

pub const NamespaceMap = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    entries: []const Entry,
    /// The default namespace (an @namespace rule without a prefix), or null.
    default: ?[]const u8,

    /// A map owning copies of `entries` and `default`, with one reference.
    /// Prefixes compare case-sensitively (CSS Namespaces 3 §2: "prefixes are
    /// case-sensitive"); a later entry for a prefix wins (§2: "if a
    /// namespace prefix ... is declared more than once, only the last
    /// declaration shall be used").
    pub fn create(allocator: Allocator, entries: []const Entry, default: ?[]const u8) Allocator.Error!*NamespaceMap {
        const self = try allocator.create(NamespaceMap);
        errdefer allocator.destroy(self);
        const owned = try allocator.alloc(Entry, entries.len);
        var copied: usize = 0;
        errdefer {
            for (owned[0..copied]) |e| {
                allocator.free(e.prefix);
                allocator.free(e.namespace);
            }
            allocator.free(owned);
        }
        for (entries, owned) |e, *copy| {
            const prefix = try allocator.dupe(u8, e.prefix);
            errdefer allocator.free(prefix);
            copy.* = .{ .prefix = prefix, .namespace = try allocator.dupe(u8, e.namespace) };
            copied += 1;
        }
        const default_copy = if (default) |d| try allocator.dupe(u8, d) else null;
        self.* = .{ .allocator = allocator, .entries = owned, .default = default_copy };
        return self;
    }

    pub fn retain(self: *NamespaceMap) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }

    pub fn release(self: *NamespaceMap) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        const allocator = self.allocator;
        for (self.entries) |e| {
            allocator.free(e.prefix);
            allocator.free(e.namespace);
        }
        allocator.free(self.entries);
        if (self.default) |d| allocator.free(d);
        allocator.destroy(self);
    }

    /// The namespace URI `prefix` names, or null for an undeclared prefix.
    pub fn lookup(self: *const NamespaceMap, prefix: []const u8) ?[]const u8 {
        var i = self.entries.len;
        while (i > 0) {
            i -= 1;
            if (std.mem.eql(u8, self.entries[i].prefix, prefix)) return self.entries[i].namespace;
        }
        return null;
    }
};

const testing = std.testing;

test "lookup: declared prefixes, case-sensitively; the last declaration wins" {
    const map = try NamespaceMap.create(testing.allocator, &.{
        .{ .prefix = "svg", .namespace = "http://www.w3.org/2000/svg" },
        .{ .prefix = "x", .namespace = "urn:first" },
        .{ .prefix = "x", .namespace = "urn:second" },
    }, null);
    defer map.release();
    try testing.expectEqualStrings("http://www.w3.org/2000/svg", map.lookup("svg").?);
    try testing.expectEqualStrings("urn:second", map.lookup("x").?);
    try testing.expect(map.lookup("SVG") == null);
    try testing.expect(map.lookup("undeclared") == null);
    try testing.expect(map.default == null);
}

test "the default namespace, and an empty namespace URI" {
    const map = try NamespaceMap.create(testing.allocator, &.{.{ .prefix = "none", .namespace = "" }}, "http://www.w3.org/1999/xhtml");
    defer map.release();
    try testing.expectEqualStrings("http://www.w3.org/1999/xhtml", map.default.?);
    try testing.expectEqualStrings("", map.lookup("none").?);
}

test "the map is shared by reference and freed with its last one" {
    const map = try NamespaceMap.create(testing.allocator, &.{.{ .prefix = "a", .namespace = "urn:a" }}, "urn:d");
    map.retain();
    map.release();
    try testing.expectEqualStrings("urn:a", map.lookup("a").?);
    map.release();
}

fn createAll(allocator: Allocator) !void {
    const map = try NamespaceMap.create(allocator, &.{
        .{ .prefix = "a", .namespace = "urn:a" },
        .{ .prefix = "b", .namespace = "urn:b" },
    }, "urn:default");
    map.release();
}

test "allocation failure frees what was copied" {
    try testing.checkAllAllocationFailures(testing.allocator, createAll, .{});
}
