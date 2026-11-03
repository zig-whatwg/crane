//! A worker realm's host (html.worker_host WorkerHost) is found from the
//! realm itself, on any thread (lane gstate4): it was one list per thread,
//! searched by realm, so a lookup from any thread but the worker's own found
//! nothing (docs/lessons/architecture-a-threadlocal-listener-list-splits-a-browser-when-its-work-moves-threads.md).
const std = @import("std");
const cases = @import("html").worker_host.scope_lookup_test_cases;

test "a worker realm's host is found from the realm on another thread" {
    try cases.foundFromAnotherThread();
}
