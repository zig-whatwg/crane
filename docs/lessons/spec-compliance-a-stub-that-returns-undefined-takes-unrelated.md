# Spec Compliance: A stub that returns `undefined` takes unrelated suites down with it

**Date**: 2026-09-22
**Lesson**: An impl that returns `undefined` where its IDL says `sequence<T>` breaks every script that chains off the result, not just its own tests.

**Why**: There is no marshalling layer - an impl's return value IS the JS return
value. `undefined` has no `.indexOf`, no `.length`, no iterator, so the caller
gets a TypeError at a line that has nothing to do with the stub.

**What Happened**: `URLSearchParams.call_getAll` was

```zig
// For now return undefined - full array support requires V8 array creation
// TODO: Create V8 array with string values
return .undefined;
```

`websockets/constants.sub.js` line 27 is
`params.getAll("wpt_flags").indexOf(flag)`, inside `url_has_flag`, which line 6
calls - eleven lines BEFORE `const SCHEME_DOMAIN_PORT`. The TypeError aborted
the script with that binding created but uninitialised, so every
`websockets/*.any.js` that includes it then died in `CreateWebSocket` with
`ReferenceError: Cannot access 'SCHEME_DOMAIN_PORT' before initialization`.

45 files, window AND worker, none of which ever constructed a WebSocket. The
whole WebSocket surface read as "untested"; it was unreachable. The one test
that named the real defect, `url/urlsearchparams-getall.any.js`, was sitting at
`passed 0, failed 4` in a different directory.

Note the two shapes it presented as: the worker runs reported ERROR, because
`importScripts` propagates the throw to the harness, while the window runs
reported TIMEOUT, because a failed `<script>` tag does not - same cause, two
statuses, neither naming it.

**Fix**: build the array (`v8_Array_New` + `v8_Array_Set`, disposing each
element Global after `Set` takes its own reference). The no-match case returns
an EMPTY array, not undefined - that is what the spec's "empty list" means.

**Takeaway**: **A stub returning `undefined` is not a smaller version of the
feature, it is a trap for its callers.** When a whole directory fails before
reaching the code under test, read the failing SCRIPT top to bottom and find the
first call that leaves the file - the defect is usually in another subsystem
that has its own quietly-failing test.
