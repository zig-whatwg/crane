# Spec Compliance: Reused connection times copy fetch start

**Date**: 2026-10-14
**Lesson**: A reused connection's timing fields must copy the fetch record's post-redirect start, not a later network-start clock reading.

**Why**: Fetch's HTTP-network fetch step 8.2 supplies the post-redirect start to clamp-and-coarsen step 1. Resource Timing converts that same field to fetchStart. Different moments can straddle a 100-microsecond coarsening boundary even when the network connection took no time to obtain.

**What Happened**: Crane built reused connection timings from the network request's later start. Resource and navigation timing equality assertions intermittently differed by 0.1 ms across unrelated lanes. A deterministic native test with fetch start 10.125 and network start 100.375 failed with expected 10.125, found 100.375. Cleartext reuse also copied a nonzero time into secureConnectionStart.

**Fix**: Pass post_redirect_start_time separately to the connection-timing recorder and copy it for reuse. Keep the measured network start for fresh connection offsets and request/response times. Preserve zero for cleartext TLS timing, following browsers rather than Fetch clamp step 1's unconditional TLS field. Blink's [PerformanceResourceTiming::secureConnectionStart](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/timing/performance_resource_timing.cc) returns zero without secure transport and fetchStart for secure reuse. The upstream connection-reuse tests and the Crane repeated direct/redirected requests verify exact equality; native tests pin the different clock values and preserve fresh DNS/TCP/TLS intervals.

**Takeaway**: **When two API timestamps describe the same moment, copy the moment; never obtain it twice or hide the difference with a tolerance.**
