//! A worker's timers are WindowOrWorkerGlobalScope's operations where WebIDL
//! puts them: WorkerGlobalScope includes the mixin, so setTimeout,
//! clearTimeout, setInterval and clearInterval are properties of
//! WorkerGlobalScope.prototype (WebIDL 3.7.3, "interface prototype object":
//! a regular operation of an interface - its mixins' included - is a
//! property of its prototype), and the worker's global, a
//! DedicatedWorkerGlobalScope, inherits them; none is its own property. Only
//! a [Global] interface's own members (Window's) live on the global object.
//!
//! Chrome, Firefox and Safari all have them there (wpt.fyi 2358bd4835,
//! html/dom/idlharness.any.worker.html: "WorkerGlobalScope interface: self
//! must inherit property "setTimeout(TimerHandler, optional long, any...)"
//! with the proper type", and the same for the other three: PASS in all
//! three). The timers keep working: a Function with its arguments, a string,
//! an interval cleared from its own callback, and a cleared timeout.
const std = @import("std");
const testing = std.testing;
const h = @import("tl1_pending_timer_helpers.zig");

fn exercise() !void {
    const page = try h.Page.open("<!doctype html><body></body>", "http://127.0.0.1:65533/start");
    defer page.close();
    const worker_source =
        \\"const names = ['setTimeout', 'clearTimeout', 'setInterval', 'clearInterval'];" +
        \\"const misplaced = names.filter((n) => Object.prototype.hasOwnProperty.call(self, n) ||" +
        \\"  !Object.prototype.hasOwnProperty.call(WorkerGlobalScope.prototype, n) || self[n] !== WorkerGlobalScope.prototype[n]);" +
        \\"if (misplaced.length) { postMessage('misplaced: ' + misplaced.join()); }" +
        \\"else {" +
        \\"  const seen = [];" +
        \\"  setTimeout((a, b) => seen.push('fn ' + a + b), 1, 'x', 'y');" +
        \\"  self.order = seen; setTimeout('order.push(\"string\")', 2);" +
        \\"  clearTimeout(setTimeout(() => seen.push('cleared ran'), 3));" +
        \\"  let runs = 0; const id = setInterval(() => { runs++; if (runs === 2) { clearInterval(id); seen.push('interval x2'); } }, 4);" +
        \\"  setTimeout(() => postMessage(seen.join()), 60);" +
        \\"}"
    ;
    try page.run("globalThis.state = 'pending';\n" ++
        "globalThis.worker = new Worker(URL.createObjectURL(new Blob([" ++ worker_source ++ "], { type: 'text/javascript' })));\n" ++
        \\worker.onmessage = e => { state = e.data; };
        \\worker.onerror = (e) => { state = 'worker error: ' + e.message; };
    );
    try page.waitForState("fn xy,string,interval x2");
}

test "a worker's timers are WorkerGlobalScope.prototype's operations, inherited by its global, and they run" {
    try h.onFreshThread(exercise);
}
