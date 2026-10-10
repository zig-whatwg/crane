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

/// Run `source` (which leaves `globalThis.weak`), turn the event loop until
/// `globalThis.done` is true (or a bound), and collect: whether the object went.
fn settledThenCollected(page: Page, source: []const u8) !bool {
    try page.run(source);
    var turns: usize = 0;
    while (turns < 200) : (turns += 1) {
        try page.turn();
        const answer = try page.evaluate("String(globalThis.done === true)");
        defer std.testing.allocator.free(answer);
        if (std.mem.eql(u8, answer, "true")) break;
    }
    return collected(page);
}

fn mutationObserverObservingManyNodes() !void {
    const page = try Page.open();
    defer page.close();
    try std.testing.expect(try settledThenCollected(page,
        \\globalThis.done = true;
        \\globalThis.weak = (() => {
        \\  const mo = new MutationObserver(() => {});
        \\  for (const n of [document.createElement('a'), document.createElement('b'), document.body]) mo.observe(n, { childList: true });
        \\  mo.observe(document.body, { attributes: true });
        \\  mo.disconnect();
        \\  return new WeakRef(mo);
        \\})();
    ));
}

test "a MutationObserver that observed several nodes keeps itself once, and goes once disconnected" {
    try onFreshThread(mutationObserverObservingManyNodes);
}

fn messagePortsStartedAndClosed() !void {
    const page = try Page.open();
    defer page.close();
    try std.testing.expect(try settledThenCollected(page,
        \\globalThis.done = false;
        \\globalThis.weak = (() => {
        \\  // Listeners reach the ports only through globals they delete: a
        \\  // listener closing over its own target keeps it until refcount
        \\  // step 8 (decision D7).
        \\  const { port1, port2 } = new MessageChannel();
        \\  globalThis.ports = [port1, port2];
        \\  port1.onmessage = () => { for (const p of globalThis.ports) p.close(); delete globalThis.ports; globalThis.done = true; };
        \\  port1.start();
        \\  port2.start();
        \\  port2.postMessage('one');
        \\  return new WeakRef(port1);
        \\})();
    ));
}

test "a MessagePort started several times keeps itself once, and goes once closed" {
    try onFreshThread(messagePortsStartedAndClosed);
}

fn eventSourceClosed() !void {
    const page = try Page.open();
    defer page.close();
    try std.testing.expect(try settledThenCollected(page,
        \\globalThis.done = false;
        \\globalThis.weak = (() => {
        \\  globalThis.source = new EventSource('http://127.0.0.1:9/rc4-events');
        \\  const source = globalThis.source;
        \\  source.onerror = () => { globalThis.source.close(); delete globalThis.source; globalThis.done = true; };
        \\  return new WeakRef(source);
        \\})();
    ));
}

test "an EventSource keeps itself once while connecting, and goes once closed" {
    try onFreshThread(eventSourceClosed);
}

fn workerTerminated() !void {
    const page = try Page.open();
    defer page.close();
    try std.testing.expect(try settledThenCollected(page,
        \\globalThis.done = false;
        \\globalThis.weak = (() => {
        \\  globalThis.worker = new Worker('data:text/javascript,postMessage(1)');
        \\  const worker = globalThis.worker;
        \\  worker.onmessage = () => { globalThis.worker.terminate(); globalThis.worker.terminate(); delete globalThis.worker; globalThis.done = true; };
        \\  return new WeakRef(worker);
        \\})();
    ));
}

test "a Worker terminated (twice) releases its keep once, and goes" {
    try onFreshThread(workerTerminated);
}

fn imageLoadedTwice() !void {
    const page = try Page.open();
    defer page.close();
    try std.testing.expect(try settledThenCollected(page,
        \\globalThis.done = false;
        \\globalThis.loads = 0;
        \\globalThis.weak = (() => {
        \\  const img = document.createElement('img');
        \\  img.onload = img.onerror = () => { if (++globalThis.loads >= 1) globalThis.done = true; };
        \\  img.src = 'data:image/gif;base64,R0lGODlhAQABAAAAACw=';
        \\  img.src = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==';
        \\  return new WeakRef(img);
        \\})();
    ));
}

test "an image whose source changed while loading keeps itself once, and goes once settled" {
    try onFreshThread(imageLoadedTwice);
}

fn performanceObserverDisconnectedTwice() !void {
    const page = try Page.open();
    defer page.close();
    try std.testing.expect(try settledThenCollected(page,
        \\globalThis.done = true;
        \\globalThis.weak = (() => {
        \\  const observer = new PerformanceObserver(() => {});
        \\  observer.observe({ type: 'mark' });
        \\  observer.observe({ type: 'measure' });
        \\  observer.disconnect();
        \\  observer.disconnect();
        \\  return new WeakRef(observer);
        \\})();
    ));
}

test "a PerformanceObserver disconnected twice releases its keep once, and goes" {
    try onFreshThread(performanceObserverDisconnectedTwice);
}

fn slotSignaledAgainFromItsListener() !void {
    const page = try Page.open();
    defer page.close();
    try std.testing.expect(try settledThenCollected(page,
        \\globalThis.done = false;
        \\globalThis.weak = (() => {
        \\  globalThis.host = document.createElement('div');
        \\  const host = globalThis.host;
        \\  const root = host.attachShadow({ mode: 'open' });
        \\  const slot = root.appendChild(document.createElement('slot'));
        \\  document.body.append(host);
        \\  globalThis.fired = 0;
        \\  slot.addEventListener('slotchange', () => {
        \\    // Signaled again from its own event: the second signal's keep is
        \\    // its own, and the first one's still ends.
        \\    if (++globalThis.fired == 1) globalThis.host.append(document.createElement('i'));
        \\    else { globalThis.host.remove(); delete globalThis.host; globalThis.done = true; }
        \\  });
        \\  host.append(document.createElement('b'));
        \\  return new WeakRef(host);
        \\})();
    ));
}

test "a slot signaled again from its own slotchange releases each signal's keep" {
    try onFreshThread(slotSignaledAgainFromItsListener);
}
