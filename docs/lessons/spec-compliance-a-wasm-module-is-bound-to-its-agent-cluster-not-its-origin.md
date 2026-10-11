# Spec Compliance: A WebAssembly.Module is bound to its agent cluster, not its origin

**Date**: 2026-10-05
**Lesson**: When WPT files contradict each other on a cross-origin rule, settle it with the spec text and the three engines' current wpt.fyi runs. Implement the rule that the spec and the majority of engines share, and accept the files written for the outlier.

**Why**: A WebAssembly.Module can be deserialized only in the agent cluster that serialized it (WebAssembly Web API section 3, deserialization step 3). HTML keys a similar-origin window agent's cluster by SITE ("obtain a similar-origin window agent" step 2). It uses the origin only for a document that sent `Origin-Agent-Cluster: ?1` in a secure context, or when the browsing context group is cross-origin isolated. The `Origin-Agent-Cluster` section states the consequence itself: without the header, a WebAssembly.Module CAN be sent to a same-site cross-origin document. Chromium adds a rule of its own, a same-ORIGIN check for messages that carry a module (Blink MessagePort::CreateMessageEvent, `IsOriginCheckRequired`). WPT holds files for both behaviours, and no single rule passes all of them.

**What Happened**: Serializing a module in the V8 adapter (lane serial, 2026-10-05) made 9 files of wasm/serialization/module/ pass. Two files that had passed by accident, because no module ever arrived, now timed out:
- share-module-cross-origin-fails.sub.html (a www1 frame);
- cross-origin-module-sharing-fails.html. Its first subtest posts to `get_host_info().OTHER_ORIGIN`, which is `{{domains[www2]}}`, another same-site host.
At the same time, window-similar-but-cross-origin-success.sub.html and window-domain-success.sub.html (also www1 frames) began to pass. The question was whether to add Blink's same-origin check as a stated deviation. The current stable wpt.fyi runs (revision 564b9b1eb1 - Chrome 154 run 5082563667558400, Firefox 157 run 5147324123971584, Safari 27 run 5068288941096960, Edge 154 run 6230501655576576) split along the spec line:

| File | Chrome / Edge | Firefox | Safari |
|---|---|---|---|
| share-module-cross-origin-fails.sub | pass | TIMEOUT | TIMEOUT |
| cross-origin-module-sharing-fails | pass 2/2 | TIMEOUT | TIMEOUT |
| window-domain-success.sub | TIMEOUT | pass | pass |
| window-similar-but-cross-origin-success.sub | TIMEOUT | pass | pass |

**Fix**: Keep the spec's site-keyed clusters, which is what Firefox and Safari do. `html/agent_clusters.zig` keys a Window realm's cluster by the site of its origin, and by the origin only when it is cross-origin isolated (Crane has no `Origin-Agent-Cluster` header). It is the host's `engine.HostHooks.agentClusterOf`, which the V8 adapter checks in `GetWasmModuleFromId`. The two "-fails" files are accepted as TIMEOUTs, the same result Firefox and Safari report.

**Status** (2026-10-11, lane wasmser, which ported lane serial's change to main): upstream WPT agreed. web-platform-tests 1c54118ac3 (2026-10-09, "Fix and extend cross-origin WebAssembly.Module sharing tests") removed share-module-cross-origin-fails.sub.html as contradicting window-similar-but-cross-origin-success.sub.html (the same-origin rule is only a proposal, WebAssembly/spec#1303), and renamed cross-origin-module-sharing-fails.html to window-cross-site-failure.html, posting to `HTTP_NOTSAMESITE_ORIGIN` because its `OTHER_ORIGIN` "is same site". It added window-same-site-success.sub.html and window-cross-origin-isolated.https.sub.html. The two TIMEOUTs in Crane's pinned tree are obsolete upstream.

The same lane found that other suites use module messages as their probe for agent clusters. html/browsers/origin/origin-keyed-agent-clusters/ (resources/helpers.mjs) decides "different agent cluster" by posting a WebAssembly.Module and expecting messageerror. Every such check passed while no module could deserialize, and once modules crossed, the directory lost 69 subtests and 6 files went NONE-PASSED. Those were accidental passes, blocked on the Origin-Agent-Cluster header, which Chrome and Firefox implement (wpt.fyi: directory Chrome 285/375, Firefox 370/375, Safari 73/375). Only the 1-in-4 sample caught it. **When a change makes a probe real, A/B every suite that uses that probe, not just the suite the change is for.**

**Takeaway**: **A test that passes because a feature is missing proves nothing. When implementing the feature breaks it, read the spec's own note on the case and compare the three engines' wpt.fyi runs before adding a deviation. If two engines and the spec agree, the test that fails was written for the third engine.**
