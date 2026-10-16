# Debugging: A reuse test can open fresh connections

**Date**: 2026-10-14
**Lesson**: Verify the transport's reuse flag before treating a timing equality failure as a reused-connection timestamp bug.

**Why**: A test's name states its intended setup, not the network path the engine actually took. A fresh TLS connection with sub-millisecond measurements rounded to integer milliseconds can appear equal to fetchStart on most runs and differ across a coarsening boundary.

**What Happened**: After fixing Fetch's copied reuse timestamps, four resource-reuse files passed 10/10 each. The navigation secure-reuse control still passed only 18/20 on the final code, against BASE 20/20, failing twice with secureConnectionStart 0.1 versus fetchStart 0. A separate diagnostic binary logged the backend flag and existing timestamps for the innermost navigation: all 100 requests were fresh connections and all passed. The probe did not reproduce the failing round, so it establishes a false reuse premise, not a proven explanation of those two failures.

**Resolution**: Keep measured fresh-connection timings and the unresolved failure rate. The native regression explicitly distinguishes reused timestamps from fresh DNS/TCP/TLS intervals. Connection policy and fractional network measurements belong to the networking owner; never patch a getter to force equality just because the upstream test's name contains reuse. The temporary probe was removed and its diagnostic binary excluded from the accepted A/B.

**Takeaway**: **Record the path that ran, preserve failed controls, and distinguish a plausible mechanism from a reproduced cause.**
