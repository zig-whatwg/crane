//! A traversable's session history: steps, push/replace, length and index,
//! traversal targets, and destroyed navigables (HTML 7.4.1, 7.4.6).

const std = @import("std");
const testing = std.testing;
const joint = @import("html_core").navigation.joint_history;

const top: u64 = 1;
const frame: u64 = 2;

test "a new traversable has one step; a push adds one, a replace none" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/a", null, "http://x.test");
    try testing.expectEqual(@as(u32, 1), h.lengthAndIndex().length);

    try h.commitDocument(top, "http://x.test/b", null, "http://x.test", .push);
    var li = h.lengthAndIndex();
    try testing.expectEqual(@as(u32, 2), li.length);
    try testing.expectEqual(@as(u32, 1), li.index);

    try h.commitDocument(top, "http://x.test/c", null, "http://x.test", .replace);
    li = h.lengthAndIndex();
    try testing.expectEqual(@as(u32, 2), li.length);
    try testing.expectEqualStrings("http://x.test/c", h.currentEntry(top).?.url);
}

test "a child's push is a step of the joint history; its initial entry is not" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/t", null, "http://x.test");
    try h.addInitialEntry(frame, "about:blank", null, "http://x.test");
    try testing.expectEqual(@as(u32, 1), h.lengthAndIndex().length);
    // The frame's first navigation replaces its initial about:blank.
    try h.commitDocument(frame, "http://x.test/f1", null, "http://x.test", .replace);
    try testing.expectEqual(@as(u32, 1), h.lengthAndIndex().length);
    try h.commitDocument(frame, "http://x.test/f2", null, "http://x.test", .push);
    try testing.expectEqual(@as(u32, 2), h.lengthAndIndex().length);
    // Back one step: the frame's entry there is f1; the top's is unchanged.
    const back = h.stepByDelta(-1).?;
    try testing.expectEqualStrings("http://x.test/f1", h.entryAt(frame, back).?.url);
    try testing.expectEqual(h.currentEntry(top).?, h.entryAt(top, back).?);
    try testing.expect(h.stepByDelta(-2) == null);
    try testing.expect(h.stepByDelta(1) == null);
}

test "pushing clears the forward history" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/1", null, "http://x.test");
    try h.commitDocument(top, "http://x.test/2", null, "http://x.test", .push);
    try h.commitDocument(top, "http://x.test/3", null, "http://x.test", .push);
    h.current_step = h.stepByDelta(-2).?;
    try h.commitDocument(top, "http://x.test/4", null, "http://x.test", .push);
    const li = h.lengthAndIndex();
    try testing.expectEqual(@as(u32, 2), li.length);
    try testing.expectEqual(@as(u32, 1), li.index);
}

test "same-document entries share the document state and carry state" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    var doc: u8 = 0;
    try h.addInitialEntry(top, "http://x.test/p", &doc, "http://x.test");
    const first_state = h.currentEntry(top).?.document_state;
    const s = try testing.allocator.dupe(u8, "state");
    try h.commitSameDocument(top, "http://x.test/p#x", .{ .string = s }, .push, null);
    const current = h.currentEntry(top).?;
    try testing.expectEqual(first_state, current.document_state);
    try testing.expectEqual(@as(?*anyopaque, &doc), current.document);
    try testing.expectEqualStrings("state", current.state.string);
}

test "a destroyed navigable's entries go, and the current step stays used" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/t", null, "http://x.test");
    try h.addInitialEntry(frame, "about:blank", null, "http://x.test");
    try h.commitDocument(frame, "http://x.test/f2", null, "http://x.test", .push);
    try testing.expectEqual(@as(u32, 2), h.lengthAndIndex().length);
    h.removeNavigable(frame);
    const li = h.lengthAndIndex();
    try testing.expectEqual(@as(u32, 1), li.length);
    try testing.expectEqual(@as(u32, 0), li.index);
}

test "a srcdoc document's resource stays with its entries, and a new document drops it" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/t", null, "http://x.test");
    try h.addInitialEntry(frame, "about:blank", null, "http://x.test");
    try h.commitDocument(frame, "about:srcdoc", null, "http://x.test", .push);
    try h.setCurrentResource(frame, "<p>one");
    const srcdoc_step = h.current_step;
    // A fragment navigation on it shares its document state, resource and all.
    try h.commitSameDocument(frame, "about:srcdoc#yo", .null, .push, null);
    try testing.expectEqualStrings("<p>one", h.currentEntry(frame).?.resource.?);
    // A new document has none of its own until it is given one.
    try h.commitDocument(frame, "http://x.test/f", null, "http://x.test", .push);
    try testing.expect(h.currentEntry(frame).?.resource == null);
    try testing.expectEqualStrings("<p>one", h.entryAt(frame, srcdoc_step).?.resource.?);
    // A replace is a new document state: the old resource goes with it.
    try h.commitDocument(frame, "about:srcdoc", null, "http://x.test", .replace);
    try h.setCurrentResource(frame, "<p>two");
    try h.commitDocument(frame, "about:srcdoc", null, "http://x.test", .replace);
    try testing.expect(h.currentEntry(frame).?.resource == null);
}

fn isUuid(text: []const u8) bool {
    if (text.len != 36) return false;
    for (text, 0..) |c, i| {
        if (i == 8 or i == 13 or i == 18 or i == 23) {
            if (c != '-') return false;
        } else if (!std.ascii.isHex(c) or std.ascii.isUpper(c)) return false;
    }
    return text[14] == '4';
}

test "each entry has a navigation API key and id; a replace keeps the key, a push does not" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/a", null, "http://x.test");
    const first = h.currentEntry(top).?;
    try testing.expect(isUuid(&first.api_key));
    try testing.expect(isUuid(&first.api_id));
    try testing.expect(!std.mem.eql(u8, &first.api_key, &first.api_id));
    const key_a = first.api_key;
    const id_a = first.api_id;

    // A replace by a same-origin document keeps the key, with a new id.
    try h.commitDocument(top, "http://x.test/b", null, "http://x.test", .replace);
    const replaced = h.currentEntry(top).?;
    try testing.expectEqualSlices(u8, &key_a, &replaced.api_key);
    try testing.expect(!std.mem.eql(u8, &id_a, &replaced.api_id));

    // A replace by a cross-origin document does not keep it.
    try h.commitDocument(top, "http://y.test/c", null, "http://y.test", .replace);
    try testing.expect(!std.mem.eql(u8, &key_a, &h.currentEntry(top).?.api_key));
    const key_c = h.currentEntry(top).?.api_key;

    // A push is a new key and id.
    try h.commitDocument(top, "http://y.test/d", null, "http://y.test", .push);
    try testing.expect(!std.mem.eql(u8, &key_c, &h.currentEntry(top).?.api_key));
}

test "a same-document entry keeps its origin; replace keeps the key; navigation API state carries or resets" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/p", null, "http://x.test");
    const state = try testing.allocator.dupe(u8, "api");
    try h.setCurrentApiState(top, .{ .string = state });
    const key = h.currentEntry(top).?.api_key;

    // A fragment navigation carries the navigation API state over (null).
    try h.commitSameDocument(top, "http://x.test/p#a", .null, .push, null);
    try testing.expectEqualStrings("api", h.currentEntry(top).?.api_state.string);
    try testing.expectEqualStrings("http://x.test", h.currentEntry(top).?.origin);
    try testing.expect(!std.mem.eql(u8, &key, &h.currentEntry(top).?.api_key));

    // pushState/replaceState: a fresh one (undefined); replace keeps the key.
    const key_a = h.currentEntry(top).?.api_key;
    try h.commitSameDocument(top, "http://x.test/q", .null, .replace, .undefined);
    try testing.expect(h.currentEntry(top).?.api_state == .undefined);
    try testing.expectEqualSlices(u8, &key_a, &h.currentEntry(top).?.api_key);
}

test "the navigation API sees the navigable's contiguous same-origin entries" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/1", null, "http://x.test");
    try h.commitDocument(top, "http://x.test/2", null, "http://x.test", .push);
    try h.commitDocument(top, "http://y.test/3", null, "http://y.test", .push);
    try h.commitDocument(top, "http://x.test/4", null, "http://x.test", .push);
    try h.commitDocument(top, "http://x.test/5", null, "http://x.test", .push);
    // Back to step 1 (x.test/2): the run is x.test/1 and x.test/2 only.
    h.current_step = 1;
    var entries: std.ArrayListUnmanaged(*joint.Entry) = .empty;
    defer entries.deinit(testing.allocator);
    const index = try h.apiEntries(top, testing.allocator, &entries);
    try testing.expectEqual(@as(usize, 2), entries.items.len);
    try testing.expectEqual(@as(usize, 1), index);
    try testing.expectEqualStrings("http://x.test/1", entries.items[0].url);
    // At the last step: x.test/4 and x.test/5.
    h.current_step = 4;
    const last = try h.apiEntries(top, testing.allocator, &entries);
    try testing.expectEqual(@as(usize, 2), entries.items.len);
    try testing.expectEqual(@as(usize, 1), last);
    try testing.expectEqualStrings("http://x.test/4", entries.items[0].url);
    // Another navigable's entries are not in it.
    try h.addInitialEntry(frame, "about:blank", null, "http://x.test");
    _ = try h.apiEntries(top, testing.allocator, &entries);
    try testing.expectEqual(@as(usize, 2), entries.items.len);
}

test "a navigable's own session history entries are counted apart from its children's" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try testing.expectEqual(@as(usize, 0), h.entryCount(top));
    try h.addInitialEntry(top, "http://x.test/t", null, "http://x.test");
    try h.addInitialEntry(frame, "about:blank", null, "http://x.test");
    try testing.expectEqual(@as(usize, 1), h.entryCount(top));
    // The frame's pushes are steps of the joint history, not entries of the
    // top-level traversable's own.
    try h.commitDocument(frame, "http://x.test/f1", null, "http://x.test", .push);
    try h.commitDocument(frame, "http://x.test/f2", null, "http://x.test", .push);
    try testing.expectEqual(@as(usize, 1), h.entryCount(top));
    try testing.expectEqual(@as(usize, 3), h.entryCount(frame));
    try h.commitDocument(top, "http://x.test/u", null, "http://x.test", .push);
    try testing.expectEqual(@as(usize, 2), h.entryCount(top));
}

test "a document committed before its parser ran reaches every entry of its document state" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/a", null, "http://x.test");
    // The entry goes in before the document exists; a pushState during the
    // parse shares its document state.
    try h.commitDocument(top, "http://x.test/b", null, "http://x.test", .push);
    const state = h.currentEntry(top).?.document_state;
    try h.commitSameDocument(top, "http://x.test/b#1", .null, .push, null);
    var document: u8 = 0;
    h.setDocumentOfState(state, &document);
    try testing.expectEqual(@as(?*anyopaque, &document), h.currentEntry(top).?.document);
    try testing.expectEqual(@as(?*anyopaque, &document), h.entryAt(top, h.currentEntry(top).?.step - 1).?.document);
    // The first entry, another document state, is untouched.
    try testing.expect(h.entryAt(top, 0).?.document == null);
}

test "a prepared entry is the entry the commit makes: its id, key and navigation API id" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/a", null, "http://x.test");
    const key_a = h.currentEntry(top).?.api_key;

    // A push: a new id, key and navigation API id, reserved before the commit.
    const pushed = h.prepareDocument(top, "http://x.test", .push);
    try testing.expect(isUuid(&pushed.api_key));
    try testing.expect(!std.mem.eql(u8, &key_a, &pushed.api_key));
    try h.commitPreparedDocument(top, "http://x.test/b", null, "http://x.test", .push, pushed);
    const b = h.currentEntry(top).?;
    try testing.expectEqual(pushed.id, b.id);
    try testing.expectEqualSlices(u8, &pushed.api_key, &b.api_key);
    try testing.expectEqualSlices(u8, &pushed.api_id, &b.api_id);
    const key_b = b.api_key;

    // A same-origin replace keeps the key it replaces (finalize a
    // cross-document navigation step 9.3); the id and navigation API id are new.
    const same = h.prepareDocument(top, "http://x.test", .replace);
    try testing.expectEqualSlices(u8, &key_b, &same.api_key);
    try testing.expect(same.id != pushed.id);
    try h.commitPreparedDocument(top, "http://x.test/c", null, "http://x.test", .replace, same);
    try testing.expectEqual(same.id, h.currentEntry(top).?.id);
    try testing.expectEqualSlices(u8, &same.api_id, &h.currentEntry(top).?.api_id);

    // A cross-origin replace does not.
    const cross = h.prepareDocument(top, "http://y.test", .replace);
    try testing.expect(!std.mem.eql(u8, &key_b, &cross.api_key));

    // An id reserved and never committed is never handed out again.
    try h.commitDocument(top, "http://x.test/d", null, "http://x.test", .push);
    try testing.expect(h.currentEntry(top).?.id != cross.id);
}

test "an activation belongs to its document state until another document takes it" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/a", null, "http://x.test");
    try testing.expect(h.activationOf(h.currentEntry(top).?.document_state) == null);
    const from = try h.snapshot(h.currentEntry(top).?);

    try h.commitDocument(top, "http://x.test/b", null, "http://x.test", .push);
    const b = h.currentEntry(top).?;
    const state_b = b.document_state;
    try h.setActivation(b.id, .{ .navigation_type = .push, .previous = from, .entry = try h.snapshot(b) });
    const recorded = h.activationOf(state_b).?;
    try testing.expectEqual(joint.NavigationType.push, recorded.navigation_type);
    try testing.expectEqualStrings("http://x.test/a", recorded.previous.?.url);
    try testing.expectEqualStrings("http://x.test/b", recorded.entry.url);

    // A pushState entry shares the document state, and so its activation;
    // a same-document replace of the activated entry keeps it too.
    try h.commitSameDocument(top, "http://x.test/b#1", .null, .push, null);
    try testing.expect(h.activationOf(state_b) == recorded);
    try h.commitSameDocument(top, "http://x.test/b#2", .null, .replace, null);
    try testing.expect(h.activationOf(state_b) == recorded);

    // A reload's new document takes the state's activation over: one per state.
    const reloaded = h.currentEntry(top).?;
    try h.setActivation(reloaded.id, .{ .navigation_type = .reload, .previous = try h.snapshot(reloaded), .entry = try h.snapshot(reloaded) });
    try testing.expectEqual(joint.NavigationType.reload, h.activationOf(state_b).?.navigation_type);

    // A cross-document replace is a new document state: the old one's goes.
    try h.commitDocument(top, "http://x.test/c", null, "http://x.test", .replace);
    try testing.expect(h.activationOf(h.currentEntry(top).?.document_state) == null);
}

test "a recorded activation names the entry as it was committed and the entry the navigation left" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/a", null, "http://x.test");
    const previous = try h.snapshot(h.currentEntry(top).?);
    const prepared = h.prepareDocument(top, "http://x.test", .push);
    // The pageswap event's target, before the commit makes it.
    var target = try h.preparedSnapshot(top, "http://x.test/b", "http://x.test", prepared);
    defer target.deinit(testing.allocator);
    try testing.expect(h.entryById(prepared.id) == null);
    try h.commitPreparedDocument(top, "http://x.test/b", null, "http://x.test", .push, prepared);
    try h.recordActivation(prepared.id, .push, previous);
    const recorded = h.activationOf(h.currentEntry(top).?.document_state).?;
    try testing.expectEqual(target.id, recorded.entry.id);
    try testing.expectEqualSlices(u8, &target.api_key, &recorded.entry.api_key);
    try testing.expectEqualStrings("http://x.test/a", recorded.previous.?.url);
    // An entry that is not there takes nothing, and leaks nothing.
    const stray = try h.snapshot(h.currentEntry(top).?);
    try testing.expectError(error.NoSuchEntry, h.recordActivation(9999, .reload, stray));
}

test "a child navigable's first entry takes the step its parent's document began at" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    var doc: u8 = 0;
    try h.addInitialEntry(top, "http://x.test/t", &doc, "http://x.test");
    // A fragment navigation: a second step on the same document.
    try h.commitSameDocument(top, "http://x.test/t#1", .null, .push, null);
    try testing.expectEqual(@as(u32, 1), h.current_step);
    // A frame added now belongs to its parent's document, which began at
    // step 0 ("create a new child navigable" 12.3-12.4).
    try h.addChildInitialEntry(frame, top, "about:blank", null, "http://x.test");
    try testing.expectEqual(@as(u32, 0), h.currentEntry(frame).?.step);
    try h.commitDocument(frame, "http://x.test/f", null, "http://x.test", .replace);
    // Back to step 0: the frame is still on its entry.
    h.current_step = 0;
    try testing.expectEqualStrings("http://x.test/f", h.currentEntry(frame).?.url);
    // A push at step 0 truncates the parent's forward entry, not the frame's
    // current one.
    try h.commitSameDocument(top, "http://x.test/t#b", .null, .push, null);
    try testing.expectEqualStrings("http://x.test/f", h.currentEntry(frame).?.url);
    try testing.expectEqual(@as(usize, 1), h.entryCount(frame));
    try testing.expectEqual(@as(usize, 2), h.entryCount(top));
    // A navigable whose parent has no entries yet starts at the current step.
    try h.addChildInitialEntry(3, 99, "about:blank", null, "http://x.test");
    try testing.expectEqual(h.current_step, h.currentEntry(3).?.step);
}

test "a traversal to a frame's entry goes to the nearest step where the frame shows it" {
    // navigation-api/navigation-methods/disambigaute-*.html: the top pushes
    // (#top), then the frame does (#1). The frame's first entry is current at
    // steps 0 and 1; its back() goes to step 1 - the nearest - and leaves the
    // top where it is, as Blink and Gecko do.
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/t", null, "http://x.test");
    try h.addInitialEntry(frame, "http://x.test/f", null, "http://x.test");
    try h.commitSameDocument(top, "http://x.test/t#top", .null, .push, null);
    try h.commitSameDocument(frame, "http://x.test/f#1", .null, .push, null);
    try testing.expectEqual(@as(u32, 2), h.current_step);
    const frame_first = h.entryAt(frame, 0).?;
    try testing.expectEqual(frame_first, h.entryAt(frame, 1).?);
    // Back: the latest step at or before the current one.
    try testing.expectEqual(@as(u32, 1), h.nearestStepOf(frame_first));
    // Forward from step 0: the frame's later entry is current from step 2 on.
    h.current_step = 0;
    try testing.expectEqual(@as(u32, 2), h.nearestStepOf(h.entryAt(frame, 2).?));
    // The top's first entry, from step 2: only step 0 shows it.
    h.current_step = 2;
    try testing.expectEqual(@as(u32, 0), h.nearestStepOf(h.entryAt(top, 0).?));
}
