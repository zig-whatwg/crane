//! HTML "not restored reasons" (7.2.8): why a document was not served from
//! the back/forward cache, as a tree that mirrors its frames.
//!
//! A Document's "bfcache blocking details" collect the reasons "make document
//! unsalvageable" records (src/dom/bfcache.zig). When a top-level
//! traversable's document is unloaded, "build not restored reasons for a
//! top-level traversable and its descendants" copies them, frame by frame,
//! into this tree, kept with the active session history entry's document
//! state; the document a later traversal makes for that entry reports it
//! through PerformanceNavigationTiming.notRestoredReasons.
//!
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#nrr-struct
//! Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#make-document-unsalvageable

const std = @import("std");
const Allocator = std.mem.Allocator;

/// A not restored reason: the spec's list, and the user-agent specific
/// blocking reasons Crane reports. The strings are the spec's - and
/// Chrome's, the shipping implementation: its Intent to Ship (blink-dev,
/// "Back/forward cache NotRestoredReasons API", 2024) aligned Chromium's
/// web-exposed strings with these, lowercase "websocket" included, and
/// WPT's performance-timeline/not-restored-reasons and
/// websockets/back-forward-cache-* expect them.
pub const Reason = enum {
    // The spec's reasons.
    fetch,
    navigation_failure,
    parser_aborted,
    websocket,
    lock,
    masked,
    // User-agent specific blocking reasons.
    broadcastchannel_message,
    navigating,
    outstanding_network_request,
    rtc,
    sharedworker,
    unload_listener,
    webtransport,

    /// The reason's string: "navigation-failure" for .navigation_failure.
    pub fn name(self: Reason) []const u8 {
        return switch (self) {
            .fetch => "fetch",
            .navigation_failure => "navigation-failure",
            .parser_aborted => "parser-aborted",
            .websocket => "websocket",
            .lock => "lock",
            .masked => "masked",
            .broadcastchannel_message => "broadcastchannel-message",
            .navigating => "navigating",
            .outstanding_network_request => "outstanding-network-request",
            .rtc => "rtc",
            .sharedworker => "sharedworker",
            .unload_listener => "unload-listener",
            .webtransport => "webtransport",
        };
    }
};

/// A Document's "bfcache blocking details": a set of not restored reason
/// details - each one a reason - kept in the order they were first
/// recorded.
pub const BlockingDetails = struct {
    reasons: std.EnumSet(Reason) = .initEmpty(),
    /// The order of first recording ("append to a set").
    order: [std.meta.fields(Reason).len]Reason = undefined,
    len: usize = 0,

    /// "Append details to document's bfcache blocking details": a reason
    /// already in the set is not appended again.
    pub fn append(self: *BlockingDetails, reason: Reason) void {
        if (self.reasons.contains(reason)) return;
        self.reasons.insert(reason);
        self.order[self.len] = reason;
        self.len += 1;
    }

    pub fn items(self: *const BlockingDetails) []const Reason {
        return self.order[0..self.len];
    }
};

/// HTML's "not restored reasons" struct. Every slice is OWNED by the
/// allocator `deinit` is given.
pub const NotRestoredReasons = struct {
    /// The container iframe's src attribute, encoded-parsed-and-serialized
    /// (or its value as is, if that fails); null for a non-iframe container.
    src: ?[]const u8 = null,
    /// The container iframe's id attribute ("" when it has none); null for a
    /// non-iframe container.
    id: ?[]const u8 = null,
    /// The container iframe's name attribute ("" when it has none); null for
    /// a non-iframe container.
    name: ?[]const u8 = null,
    /// The document's URL, serialized; null for a cross-origin descendant.
    url: ?[]const u8 = null,
    /// A clone of the document's bfcache blocking details; null for a
    /// cross-origin descendant.
    reasons: ?[]const Reason = null,
    /// One per document-tree child navigable, in their order; null for a
    /// cross-origin descendant.
    children: ?[]NotRestoredReasons = null,

    pub fn deinit(self: *NotRestoredReasons, allocator: Allocator) void {
        inline for (.{ "src", "id", "name", "url" }) |field| {
            if (@field(self, field)) |value| allocator.free(value);
        }
        if (self.reasons) |reasons| allocator.free(reasons);
        if (self.children) |children| {
            for (children) |*child| child.deinit(allocator);
            allocator.free(children);
        }
        self.* = .{};
    }

    /// A deep copy, OWNED by `allocator`.
    pub fn clone(self: *const NotRestoredReasons, allocator: Allocator) Allocator.Error!NotRestoredReasons {
        var copy: NotRestoredReasons = .{};
        errdefer copy.deinit(allocator);
        inline for (.{ "src", "id", "name", "url" }) |field| {
            if (@field(self, field)) |value| @field(copy, field) = try allocator.dupe(u8, value);
        }
        if (self.reasons) |reasons| copy.reasons = try allocator.dupe(Reason, reasons);
        if (self.children) |children| {
            const made = try allocator.alloc(NotRestoredReasons, children.len);
            for (made) |*child| child.* = .{};
            copy.children = made;
            for (children, made) |*from, *to| to.* = try from.clone(allocator);
        }
        return copy;
    }

    /// Whether this document's own reasons are not empty (the "masked" test
    /// of "build not restored reasons for a top-level traversable" step 5.2).
    pub fn hasReasons(self: *const NotRestoredReasons) bool {
        const reasons = self.reasons orelse return false;
        return reasons.len > 0;
    }

    /// "Build not restored reasons for a top-level traversable" steps
    /// 5.3-5.5 for a cross-origin descendant: its URL, reasons and children
    /// are not exposed (src, id and name, its container's, stay).
    pub fn mask(self: *NotRestoredReasons, allocator: Allocator) void {
        if (self.url) |url| allocator.free(url);
        self.url = null;
        if (self.reasons) |reasons| allocator.free(reasons);
        self.reasons = null;
        if (self.children) |children| {
            for (children) |*child| child.deinit(allocator);
            allocator.free(children);
        }
        self.children = null;
    }
};

const testing = std.testing;

test "blocking details are a set, in the order first recorded" {
    var details: BlockingDetails = .{};
    details.append(.websocket);
    details.append(.fetch);
    details.append(.websocket);
    try testing.expectEqualSlices(Reason, &.{ .websocket, .fetch }, details.items());
}

test "every reason's string is the spec's" {
    try testing.expectEqualStrings("navigation-failure", Reason.navigation_failure.name());
    try testing.expectEqualStrings("parser-aborted", Reason.parser_aborted.name());
    try testing.expectEqualStrings("websocket", Reason.websocket.name());
    try testing.expectEqualStrings("unload-listener", Reason.unload_listener.name());
    try testing.expectEqualStrings("broadcastchannel-message", Reason.broadcastchannel_message.name());
}

test "a clone owns its copy, and masking drops a descendant's URL, reasons and children" {
    const allocator = testing.allocator;
    var leaf: NotRestoredReasons = .{ .url = try allocator.dupe(u8, "http://b.test/"), .reasons = try allocator.dupe(Reason, &.{.lock}) };
    var children = try allocator.alloc(NotRestoredReasons, 1);
    children[0] = leaf;
    leaf = .{};
    var root: NotRestoredReasons = .{
        .url = try allocator.dupe(u8, "http://a.test/"),
        .reasons = try allocator.dupe(Reason, &.{}),
        .children = children,
    };
    defer root.deinit(allocator);
    var copy = try root.clone(allocator);
    defer copy.deinit(allocator);
    try testing.expectEqualStrings("http://b.test/", copy.children.?[0].url.?);
    try testing.expect(copy.children.?[0].hasReasons());
    try testing.expect(!copy.hasReasons());
    copy.children.?[0].mask(allocator);
    try testing.expect(copy.children.?[0].url == null);
    try testing.expect(copy.children.?[0].reasons == null);
    // The original is untouched.
    try testing.expectEqualStrings("http://b.test/", root.children.?[0].url.?);
}

test "a clone that runs out of memory frees what it made" {
    const allocator = testing.allocator;
    var root: NotRestoredReasons = .{ .url = try allocator.dupe(u8, "http://a.test/"), .reasons = try allocator.dupe(Reason, &.{ .fetch, .masked }) };
    defer root.deinit(allocator);
    var index: usize = 0;
    while (index < 3) : (index += 1) {
        var failing = testing.FailingAllocator.init(allocator, .{ .fail_index = index });
        if (root.clone(failing.allocator())) |made| {
            var copy = made;
            copy.deinit(failing.allocator());
        } else |err| try testing.expectEqual(error.OutOfMemory, err);
    }
}
