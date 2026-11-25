# Spec Compliance: A scheme answered outside Fetch drifts from Fetch

**Date**: 2026-11-24
**Lesson**: A caller that answers a data: (or blob:) URL with its own parser instead of Fetch's scheme fetch drifts from Fetch, and the drift hides gaps in Fetch's own algorithm too.

**Why**: HTML's worker script fetch is "fetch a request" for every scheme; only the checks on the response differ (MIME type only for HTTP(S) in a classic worker, always for a module script). A private parser re-decides what Fetch already decides - the default MIME type, how the MIME type is parsed, where the base64 marker may be - and nothing keeps the two in step.

**What Happened**: `src/html/workers/script_fetch.zig` answered `data:` worker scripts in `handleDataUrl`, its own parser: the default type was text/javascript (Fetch: text/plain;charset=US-ASCII), the type was everything before the first ';' (unparsed), base64 was any ";base64" in the metadata, and a module worker made no JavaScript MIME type check - so `new Worker("data:,...", {type: "module"})` ran, where Chrome 157 and Firefox 159 fire `error` (Safari 27.0 runs it; golden rule 2: the spec and the majority agree). Moving it onto `scheme_fetch.schemeFetch(.., "data", ..)` then showed that Fetch's `processDataUrl` itself skipped steps 13-14 (parse the MIME type; failure is text/plain;charset=US-ASCII) and the newer step 11 (spaces allowed between ";" and "base64", which all three browsers ship): nothing had needed the parsed type before.

**Fix**: The worker path calls scheme fetch "data" and applies the same response checks as a blob: script (`scriptFromLocalResponse`); `processDataUrl` implements steps 11-14 through mimesniff's parser and serializer (lane core1 b7).

**Takeaway**: **Reach a URL's bytes through Fetch's scheme fetch, never a second parser - and when you move a caller onto Fetch, test the Fetch algorithm's own steps against the spec: a gap nobody exercised surfaces then.**
