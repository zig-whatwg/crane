//! DocumentOrShadowRoot's fullscreenElement, pointerLockElement and
//! pictureInPictureElement (lane perf2, batch 8): each is its node document's
//! one element of that kind, RETARGETED against `this` - a shadow root keeps
//! none of its own.
//!
//! - Fullscreen, "fullscreenElement getter steps": 1. a shadow root whose host
//!   is not connected answers null; 2. retarget the document's fullscreen
//!   element against this; 3. the candidate if it is in this's tree; 4. null.
//! - Picture-in-Picture 4.3: the same four steps over the Picture-in-Picture
//!   element.
//! - Pointer Lock 2.0, pointerLockElement: the element in pointer lock,
//!   retargeted against this, if the two are in the same tree; null otherwise.
//!
//! ShadowRoot's state carried all three (and an active element it never read
//! either: activeElement is computed from the focused area, html.focus) - 32
//! bytes a shadow root, never set - and its getters returned them as they were.
//! Document's returned the stored element without retargeting it, so an element
//! inside a shadow tree would have leaked out of document.fullscreenElement.
//!
//! The document's three elements are never set by Crane yet (no fullscreen,
//! pointer lock or Picture-in-Picture), so the test sets them in the document's
//! own state - dom.document_internals, the document's dom-level state - as the
//! request algorithms will.

const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const testing = std.testing;

fn Embedded(comptime State: type) type {
    return @FieldType(State, "_embedded");
}

test "ShadowRoot's state keeps none of the document's designated elements" {
    const S = Embedded(interfaces.ShadowRoot.State);
    var kept: usize = 0;
    inline for (.{ "fullscreen_element", "active_element", "picture_in_picture_element", "pointer_lock_element" }) |name| {
        if (@hasField(S, name)) {
            std.debug.print("{s} still has `{s}`\n", .{ @typeName(S), name });
            kept += 1;
        }
    }
    try testing.expectEqual(@as(usize, 0), kept);
}

const Fixture = struct {
    ctx: runtime.ContextData,
    document: ?*runtime.Instance = null,
    container: *runtime.Instance = undefined,
    shadows: [4]*runtime.Instance = undefined,
    shadow_count: usize = 0,

    fn init(self: *Fixture) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(testing.allocator);
        self.* = .{ .ctx = runtime.ContextData.init(testing.allocator, .{}) catch |err| {
            runtime.deinitializeRuntime();
            return err;
        } };
        errdefer self.deinit();
        self.document = try interfaces.Document.init(testing.allocator, &self.ctx);
        // The document element: everything below it is connected.
        self.container = try element(self.document.?, self.document.?, "div");
    }

    fn deinit(self: *Fixture) void {
        if (self.document) |document| interfaces.Document.deinit(document);
        for (self.shadows[0..self.shadow_count]) |shadow| interfaces.ShadowRoot.deinit(shadow);
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }

    fn element(document: *runtime.Instance, parent: *runtime.Instance, name: []const u8) !*runtime.Instance {
        const result = try interfaces.Document.call_createElementNS(document, .initInterned("http://www.w3.org/1999/xhtml"), .initInterned(name), .notPassed());
        errdefer dom.node_creation.destroyUninserted(result);
        _ = try interfaces.Node.call_appendChild(parent, result);
        return result;
    }

    fn attach(self: *Fixture, host: *runtime.Instance) !*runtime.Instance {
        const result = try interfaces.Element.call_attachShadow(host, .{ .mode = ._open_ });
        self.shadows[self.shadow_count] = result;
        self.shadow_count += 1;
        return result;
    }

    /// The document's rare data, where its three designated elements live.
    fn rare(self: *Fixture) !*dom.document_rare_data.DocumentRareData {
        const document = self.document.?;
        const internal = dom.document_internals.getInternal(document) orelse return error.NoDocumentState;
        return internal.ensureRareData(document);
    }
};

const Kind = enum { fullscreen, pointer_lock, picture_in_picture };

fn setDesignated(rare: *dom.document_rare_data.DocumentRareData, kind: Kind, element: ?*runtime.Instance) void {
    switch (kind) {
        .fullscreen => rare.fullscreen_element = element,
        .pointer_lock => rare.pointer_lock_element = element,
        .picture_in_picture => rare.picture_in_picture_element = element,
    }
}

fn shadowGetter(kind: Kind, shadow: *runtime.Instance) !?*runtime.Instance {
    return switch (kind) {
        .fullscreen => interfaces.ShadowRoot.get_fullscreenElement(shadow),
        .pointer_lock => interfaces.ShadowRoot.get_pointerLockElement(shadow),
        .picture_in_picture => interfaces.ShadowRoot.get_pictureInPictureElement(shadow),
    };
}

fn documentGetter(kind: Kind, document: *runtime.Instance) !?*runtime.Instance {
    return switch (kind) {
        .fullscreen => interfaces.Document.get_fullscreenElement(document),
        .pointer_lock => interfaces.Document.get_pointerLockElement(document),
        .picture_in_picture => interfaces.Document.get_pictureInPictureElement(document),
    };
}

/// Pointer Lock 2.0's example: `#canvas1` in `#host1`'s shadow root is the
/// element; the document reads `#host1`, root1 reads `#canvas1`, and root2 -
/// for which the retargeted element `#host1` is in another tree - reads null.
fn retargetedForEachScope(kind: Kind) !void {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const host1 = try Fixture.element(f.document.?, f.container, "div");
    const root1 = try f.attach(host1);
    const canvas1 = try Fixture.element(f.document.?, root1, "canvas");
    const host2 = try Fixture.element(f.document.?, f.container, "div");
    const root2 = try f.attach(host2);
    _ = try Fixture.element(f.document.?, root2, "canvas");

    const rare = try f.rare();
    setDesignated(rare, kind, canvas1);
    defer setDesignated(rare, kind, null);

    try testing.expectEqual(@as(?*runtime.Instance, host1), try documentGetter(kind, f.document.?));
    try testing.expectEqual(@as(?*runtime.Instance, canvas1), try shadowGetter(kind, root1));
    try testing.expectEqual(@as(?*runtime.Instance, null), try shadowGetter(kind, root2));

    // An element in the document's own tree reads as itself from the
    // document and as null from a shadow root (a different tree).
    setDesignated(rare, kind, host2);
    try testing.expectEqual(@as(?*runtime.Instance, host2), try documentGetter(kind, f.document.?));
    try testing.expectEqual(@as(?*runtime.Instance, null), try shadowGetter(kind, root1));
    try testing.expectEqual(@as(?*runtime.Instance, null), try shadowGetter(kind, root2));

    // None designated: null everywhere.
    setDesignated(rare, kind, null);
    try testing.expectEqual(@as(?*runtime.Instance, null), try documentGetter(kind, f.document.?));
    try testing.expectEqual(@as(?*runtime.Instance, null), try shadowGetter(kind, root1));
}

test "fullscreenElement is the document's fullscreen element retargeted against each scope" {
    try retargetedForEachScope(.fullscreen);
}

test "pointerLockElement is the element in pointer lock retargeted against each scope" {
    try retargetedForEachScope(.pointer_lock);
}

test "pictureInPictureElement is the document's Picture-in-Picture element retargeted against each scope" {
    try retargetedForEachScope(.picture_in_picture);
}

/// Fullscreen and Picture-in-Picture step 1: "If this is a shadow root and
/// its host is not connected, then return null" - even for an element inside
/// that very shadow tree. (Pointer Lock 2.0 has no such step.)
fn disconnectedHostReadsNull(kind: Kind) !void {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const host = try Fixture.element(f.document.?, f.container, "div");
    const root = try f.attach(host);
    const inner = try Fixture.element(f.document.?, root, "video");

    const rare = try f.rare();
    setDesignated(rare, kind, inner);
    defer setDesignated(rare, kind, null);
    try testing.expectEqual(@as(?*runtime.Instance, inner), try shadowGetter(kind, root));

    _ = try interfaces.Node.call_removeChild(f.container, host);
    defer _ = interfaces.Node.call_appendChild(f.container, host) catch unreachable;
    try testing.expectEqual(@as(?*runtime.Instance, null), try shadowGetter(kind, root));
}

test "a shadow root whose host is not connected reads no fullscreen element" {
    try disconnectedHostReadsNull(.fullscreen);
}

test "a shadow root whose host is not connected reads no Picture-in-Picture element" {
    try disconnectedHostReadsNull(.picture_in_picture);
}
