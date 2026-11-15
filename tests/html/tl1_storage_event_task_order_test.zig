//! A `storage` event is a task of the remote window's event loop, in order with the other tasks (lane tl1).
//!
//! HTML "broadcast" (the Storage interface): "queue a global task on the DOM manipulation task source given
//! remoteStorage's relevant global object to fire an event named storage". Blink, WebKit and Gecko queue a
//! task (the sources are cited at src/webidl/impls/Storage.zig queueStorageEvent). Crane armed a zero-delay
//! native timer, which the event loop's poll runs ahead of every queued task: the event overtook the tasks
//! queued before the storage change.
//!
//! Here a page posts a message to its same-origin frame, changes its local storage, and posts a second
//! message. The frame's window hears the three in the order they were queued.

const std = @import("std");
const h = @import("tl1_pending_timer_helpers.zig");

fn exercise() !void {
    // An iframe with no src: about:blank, the page's origin - two documents with one local storage area.
    const page = try h.Page.open("<!doctype html><body><iframe></iframe></body>", "http://127.0.0.1:65533/start");
    defer page.close();
    try page.run(h.frame_window ++
        \\globalThis.state = 'pending';
        \\globalThis.heard = [];
        \\frame.addEventListener('message', (e) => { heard.push('message ' + e.data); if (e.data === 'after') state = heard.join(', '); });
        \\frame.addEventListener('storage', (e) => heard.push('storage ' + e.key));
        \\frame.postMessage('before', '*');
        \\localStorage.setItem('tl1-order', 'value');
        \\frame.postMessage('after', '*');
        \\if (heard.length !== 0) throw new Error('something was delivered inline: ' + heard.join());
    );
    // On the timer: 'storage tl1-order, message before, message after'.
    try page.waitForState("message before, storage tl1-order, message after");
}

test "a storage event runs in order with the tasks queued before and after its change" {
    try h.onFreshThread(exercise);
}
