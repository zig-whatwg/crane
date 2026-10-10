//! keepPlatformObjectAlive is counted (refcount step 4, design 2.3): each keep
//! is ended by exactly one release. An owner whose reason toggles - an
//! IntersectionObserver observing something, a media element with pending
//! work - keeps once and releases once, with a flag of its own; one that kept
//! on every toggle would keep its object until its realm ended.
//!
//! Each case lets its object's activity begin several times and end, drops
//! every reference, collects, and asks a WeakRef whether the object went.

const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const onFreshThread = helpers.onFreshThread;
const Page = helpers.Page;

/// After `setup` (which leaves `globalThis.weak`, a WeakRef to the object),
/// two collections and event loop turns: whether the object was collected.
fn collected(page: Page) !bool {
    for (0..3) |_| {
        try page.turn();
        try page.run("collectNow()");
    }
    const answer = try page.evaluate("String(weak.deref() === undefined)");
    defer std.testing.allocator.free(answer);
    if (!std.mem.eql(u8, answer, "true")) std.debug.print("weak.deref() === undefined: {s}\n", .{answer});
    return std.mem.eql(u8, answer, "true");
}

fn observerObservingManyTargetsGoesOnceItObservesNone() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.weak = (() => {
        \\  const io = new IntersectionObserver(() => {});
        \\  const targets = [document.createElement('div'), document.createElement('p'), document.createElement('span')];
        \\  for (const t of targets) { document.body.append(t); io.observe(t); }
        \\  for (const t of targets) io.unobserve(t);
        \\  io.observe(targets[0]);
        \\  io.disconnect();
        \\  return new WeakRef(io);
        \\})();
    );
    try std.testing.expect(try collected(page));
}

test "an IntersectionObserver that observed several targets keeps itself once, and goes when it observes none" {
    try onFreshThread(observerObservingManyTargetsGoesOnceItObservesNone);
}

fn mediaElementWithManyTasksGoesOnceIdle() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.weak = (() => {
        \\  const audio = document.createElement('audio');
        \\  // Several queued media tasks at once: each queue syncs the
        \\  // element's activity while the last is still pending.
        \\  audio.src = 'data:,not-media';
        \\  audio.load();
        \\  audio.load();
        \\  audio.pause();
        \\  return new WeakRef(audio);
        \\})();
    );
    try std.testing.expect(try collected(page));
}

test "a media element whose tasks were queued several times keeps itself once, and goes when idle" {
    try onFreshThread(mediaElementWithManyTasksGoesOnceIdle);
}

// An owner that releases more than it kept would end ANOTHER owner's keep
// under a count: the extra release is an error log in Debug (fatal here), so
// each of these fails if its owner releases twice.

fn broadcastChannelClosedTwiceReleasesOnce() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.weak = (() => {
        \\  const channel = new BroadcastChannel('rc4-owners');
        \\  channel.close();
        \\  channel.close();
        \\  return new WeakRef(channel);
        \\})();
    );
    // Collected: its deinit must not release again.
    try std.testing.expect(try collected(page));
}

test "a BroadcastChannel closed twice releases its keep once, and its teardown none" {
    try onFreshThread(broadcastChannelClosedTwiceReleasesOnce);
}

fn webSocketThatClosedReleasesOnce() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.closed = false;
        \\globalThis.weak = (() => {
        \\  const socket = new WebSocket('ws://127.0.0.1:9/');
        \\  socket.onclose = () => { globalThis.closed = true; };
        \\  return new WeakRef(socket);
        \\})();
    );
    var turns: usize = 0;
    while (turns < 200) : (turns += 1) {
        try page.turn();
        const answer = try page.evaluate("String(closed)");
        defer std.testing.allocator.free(answer);
        if (std.mem.eql(u8, answer, "true")) break;
    }
    // Closed: the close task released the constructor's keep, and the
    // socket's teardown must not release again.
    try std.testing.expect(try collected(page));
}

test "a WebSocket whose connection closed releases its keep once, and its teardown none" {
    try onFreshThread(webSocketThatClosedReleasesOnce);
}
