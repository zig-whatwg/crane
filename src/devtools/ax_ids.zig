//! Accessibility node ids for objects with no DOM node (lane a11y1): a
//! pseudo-element's text, an inline text box. Chrome gives such an AXObject
//! a generated AXID - negative, from -1000000002 downward (Blink
//! AXObjectCacheImpl::GenerateAXID from ui::kFirstGeneratedRendererNodeID,
//! -1000000001) - kept while the object lives; an object with a DOM node uses
//! the node's DOMNodeId, which is CDP's backendNodeId (CreateAndInit).
//!
//! Crane builds its tree on demand and keeps nothing, so a nodeless object is
//! named by where it is - its parent's id and its ordinal among the parent's
//! nodeless children - and this table gives that place the same id every time
//! it is asked, as Chrome's live object keeps its AXID. One table per Browser
//! (a supplement of its scope, as NodeIds), names only: it holds no node.

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const AxIds = struct {
    allocator: Allocator,
    by_place: std.AutoHashMapUnmanaged(Place, i64) = .empty,
    /// The next id to give (GenerateAXID decrements first).
    last: i64 = first_generated,

    /// ui::kFirstGeneratedRendererNodeID.
    pub const first_generated: i64 = -1000000001;

    pub const Place = struct {
        /// The parent's AX node id.
        parent: i64,
        ordinal: u32,
    };

    pub fn init(allocator: Allocator) AxIds {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *AxIds) void {
        self.by_place.deinit(self.allocator);
    }

    /// The id of the nodeless object at `place`, given on first ask.
    pub fn idOf(self: *AxIds, place: Place) Allocator.Error!i64 {
        const entry = try self.by_place.getOrPut(self.allocator, place);
        if (!entry.found_existing) {
            self.last -= 1;
            entry.value_ptr.* = self.last;
        }
        return entry.value_ptr.*;
    }
};

test "a nodeless object keeps its generated id, and the ids run down from Chrome's first" {
    var ids = AxIds.init(std.testing.allocator);
    defer ids.deinit();
    const a = try ids.idOf(.{ .parent = 7, .ordinal = 0 });
    const b = try ids.idOf(.{ .parent = 7, .ordinal = 1 });
    try std.testing.expectEqual(@as(i64, -1000000002), a);
    try std.testing.expectEqual(@as(i64, -1000000003), b);
    try std.testing.expectEqual(a, try ids.idOf(.{ .parent = 7, .ordinal = 0 }));
}
