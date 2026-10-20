# Architecture: A document parsed as its body arrives owns its fetch

**Date**: 2026-10-20
**Lesson**: Once a navigation commits at the response's headers, the fetch must live as long as the body's reader - the document's parser - and no longer; the navigation record that started it is gone before the body is.

**Why**: An AsyncFetch asks its client every turn whether it is still there (`alive`) and terminates the fetch when it is not. A frame navigation's client was its navigation record, which `runCommit` removes before it commits. With a body still arriving, the next sweep would have failed the body mid-document. The other way round, a client that always answers "alive" lets an over fetch survive its agent: `AgentFetches.deinit` leaves live fetches where they are.

**What Happened**: Lane streamnav made iframe and popup navigations stream (HTML 7.5.1 "load an HTML document": each networking task fills the parser's input byte stream; implied EOF when no more bytes come). 16 moving-between-documents files needed the server's one-second gap between `<streaming-element>` and the script to exist in the frame's DOM. Three ownership traps came up:
1. **The redirect's own body.** With `startStreaming`, a manual redirect is handed over at its headers too, its body still in its pipe. fetchDone freed that response in a `defer`, after `followManualRedirect` had started the next hop, so the pipe's release ran `stopProducing` against the NEW transfer. Free the redirect response first.
2. **The holder changes hands.** The body moves record -> response -> parser. The fetch's client becomes a `StreamedBody` whose `alive` asks the current holder: the record (`fetchAlive`), then the parser (`holds`: not detached, realm alive).
3. **Letting go ends the fetch.** `StreamedBody.release` releases the pipe, which stops the transfer, and terminates the fetch at once. Waiting for the next pump's `nextOver` can be too late at Browser teardown.

**Fix**: src/html/navigation/fetch_integration.zig `StreamedBody`/`BodyHandoff`; HTMLIFrameElement `fetchDone`/`respond`/`streamBody`; scripted_parser `createStreaming`/`readNetworkInput`. Non-HTML responses still commit whole: the result waits in `ArrivingResponse` and is settled as `settleCollected` would. The transfer never pauses for them (`pause_body = false`): they take no bytes until the end.

**Takeaway**: **When a response is committed at its headers, hand the fetch to whoever reads the body, and terminate it when the reader lets go: neither the initiator's lifetime nor "always alive" is right.** Release a followed redirect's streamed response before starting the next hop.
