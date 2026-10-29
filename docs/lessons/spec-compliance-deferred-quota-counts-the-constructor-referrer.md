# Spec Compliance: Deferred quota counts the constructor's referrer

**Date**: 2026-10-27
**Lesson**: Calculate fetchLater's request length before request population, using the Request getter's referrer serialization.

**Why**: Fetch's fetchLater step 12 calculates total request length before step 15 queues the request. Queueing then populates it from its client. Moving population earlier changes both the referrer counted for quota and the prescribed algorithm order.

**What Happened**: Fetch's total-request-length algorithm asks for a serialized referrer without spelling out the constructor's client/no-referrer sentinels. Its deferred-fetch quota WPT cases use an explicit empty referrer, so they do not settle the default. Chromium's FetchLaterUtil::CalculateRequestSize counts ReferrerString's length before population. The Request constructor stores about:client for its client sentinel. Chrome was the only fetchLater shipper; the integrator's Q15 ruling selected that behavior.

**Fix**: Pass the initial Request's getter serialization into totalRequestLength: about:client contributes 12 bytes, no-referrer contributes zero, and a URL contributes its serialized length. Keep population and referrer-policy application in queueing. Pin all three inputs natively. Source: [Chromium fetch_later_util.cc, revision 33aa7cdb](https://chromium.googlesource.com/chromium/src/+/33aa7cdb0fba62a372fb8102aeccdadd473cfb2c/third_party/blink/renderer/core/fetch/fetch_later_util.cc), alongside Fetch §4.12 and fetchLater steps 12–15.

**Takeaway**: **A quota checked before preparation must count the representation present at that point, rather than a later network representation.**
