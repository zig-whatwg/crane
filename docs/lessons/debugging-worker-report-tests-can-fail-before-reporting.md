# Debugging: Worker report tests can fail before reporting

**Date**: 2026-10-18

**Lesson**: When a worker's assertions pass but its report harness errors, verify the top-level script response's cookies before changing violation delivery.

**Why**: A worker receives its Browser's cookie jar when its global starts, but its script is fetched earlier, on the creator's thread. Giving the eventual global a jar does not give that earlier request one. Fetch correctly skips cookie storage when the request has no jar.

**What Happened**: Both Trusted Types dedicated-worker report files passed their worker assertions, then errored when `checkReport.sub.js` tried to trim a cookie value that did not exist. The script response supplies the report identifier with `Set-Cookie`. The isolated dedicated/shared response-cookie test failed both cases on the frozen baseline. Separately, each worker credentials WPT passed 22/33: seven root-fetch failures came from the same missing jar, while four import-graph failures had another owner.

**Fix**: Pass the creator's existing Browser jar into the dedicated and shared root-script fetch options and then the internal request. Borrow it for the fetch; use Fetch's existing locking `http_integration` paths. Pass module workers' parsed credentials option at the same call sites, while classic workers keep `same-origin`. Otherwise supplying the jar exposes an `omit` regression that a null jar had hidden. Pin both outgoing `Cookie` and incoming `Set-Cookie`, plus concurrent workers in two Browsers using separate leak-checking allocators.

The algorithms are HTML's [fetch a classic worker script](https://html.spec.whatwg.org/multipage/webappapis.html#fetch-a-classic-worker-script), [fetch a module worker script graph](https://html.spec.whatwg.org/multipage/webappapis.html#fetch-a-module-worker-script-tree), and Fetch's [parse and store response Set-Cookie headers](https://fetch.spec.whatwg.org/#set-cookie-header).

**Takeaway**: **Trace the harness prerequisite back to the exact request producer; adding a missing client input also makes its previously inert request options observable.**
