# Spec Compliance: Worker module imports use the existing client

**Date**: 2026-10-20
**Lesson**: A static worker import keeps its worker destination but routes through the existing worker's controller; the destination alone does not distinguish it from worker creation.

**Why**: HTML gives static descendants the worker graph's destination. Service Workers' Handle Fetch classifies worker destinations as non-subresources and expects a reserved client. A descendant fetched from the running worker has an existing client and no reservation. Treating that request as worker creation silently falls back to the network.

**What Happened**: Giving static worker graphs their correct worker/sharedworker destination exposed this distinction. Dedicated-worker interception fell from 3/3 to 2/3 while dynamic imports, whose destination stayed script, passed. The unchanged origin/CSP choice was not responsible. All three browsers pass the static interception case. Gecko's `nsContentUtils::IsNonSubresourceInternalPolicyType` excludes static-module policy types; WebKit's `WebSWServerConnection::createFetchTask` matches a new registration only for a resulting client, otherwise using the client's existing registration.

**Fix**: In Handle Fetch, classify CORS worker/sharedworker requests without a reservation as existing-client requests, requiring the corresponding worker client kind. Use step 10's controller and storage key, including for imports outside the registration scope. Keep the destination visible to FetchEvent and the network. Root loads with reservations continue through step 9. Tests cover dedicated/shared imports, absent or window clients, and root-load modes.

**Takeaway**: **When a request field becomes more precise, audit algorithms that used it as a proxy for creation or ownership; preserve the field and fix the classification.**

**References**: [Service Workers Handle Fetch](https://w3c.github.io/ServiceWorker/#on-fetch-request-algorithm); [Gecko's policy classification](https://github.com/mozilla-firefox/firefox/blob/main/dom/base/nsContentUtils.cpp) (`IsNonSubresourceInternalPolicyType`); [WebKit's fetch-task routing](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/NetworkProcess/ServiceWorker/WebSWServerConnection.cpp) (`createFetchTask`); [aligned stable WPT results](https://wpt.fyi/results/service-workers/service-worker/dedicated-worker-service-worker-interception.https.html?sha=0f26972422&label=master&label=stable&aligned).
