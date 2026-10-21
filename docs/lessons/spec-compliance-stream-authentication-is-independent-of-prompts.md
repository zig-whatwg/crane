# Spec Compliance: Stream authentication is independent of prompts

**Date**: 2026-10-21
**Lesson**: An actionable authentication challenge can reject an unreplayable upload before the browser decides whether a prompt can be shown.

**Why**: Fetch's HTTP-network-or-cache algorithm gates its 401 retry steps on a traversable for user prompts. Chromium's network loader separately rejects an authentication challenge for a Fetch streaming upload before checking the observer or login-prompt policy. Workers therefore still reject that challenge.

**What Happened**: Crane rejected a streamed upload's 401 in windows, but returned the response in dedicated and service workers. The full upload WPT lost two assertions despite the window assertion passing. Aligned stable results at WPT revision `0f26972422b15f587e2afbd38dbb6ea2397fded0` show Chrome passing this assertion. Firefox and Safari fail streaming-upload feature detection and do not implement the feature; their failures cannot establish a competing behavior.

**Fix**: Keep the existing credentials policy and supported Basic challenge parser. Before returning a worker or CORS 401, reject a null-source upload when the response carries an actionable challenge. Preserve a bare or unsupported 401, omitted credentials, replayable bodies, successful responses and streaming 421 responses. Use the existing network-error path; no new retry or lifetime mechanism is needed.

**Takeaway**: **Separate replay eligibility from prompt availability, and compare only browsers that implement the feature.**

Evidence: [Fetch HTTP-network-or-cache fetch](https://fetch.spec.whatwg.org/#http-network-or-cache-fetch), [Chromium URLLoader::OnAuthRequired](https://github.com/chromium/chromium/blob/main/services/network/url_loader.cc), [Chromium HttpNetworkTransaction::HandleAuthChallenge](https://github.com/chromium/chromium/blob/main/net/http/http_network_transaction.cc), [worker upload results](https://wpt.fyi/results/fetch/api/basic/request-upload.h2.any.worker.html?sha=0f26972422&label=master&label=stable).
