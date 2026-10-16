# Spec Compliance: Blanket CSP acceptance is not subsumption

**Date**: 2026-10-16
**Lesson**: CSP Embedded Enforcement has two acceptance paths with different effects on the child's enforced policies.

**Why**: Compatible nonces subsume by presence rather than equality, so implicitly accepted response policies must not also be intersected with the embedder's different nonce. Blanket acceptance explicitly permits the embedder to add its policy.

**What Happened**: The May 2026 draft skips appending a subsumed requirement on both paths. Chrome 154's NavigationRequest::CheckCSPEmbeddedEnforcement unconditionally appends on blanket acceptance, and skips only on implicit acceptance. Upstream nonce tests cover only the latter. Firefox and Safari do not ship CSPEE and cannot resolve this difference.

**Fix**: Follow the shipping implementation, with the integrator's ruling recorded in row 43 Q3. Native and Crane tests require both nonce policies on blanket acceptance and only the response nonce on implicit acceptance. The implementation comment links the difference to the draft's compatible-nonce note and Chrome 154.0.8037.92's release source.

**Takeaway**: **Check both the acceptance decision and the policy installed afterward; equal decisions can hide different enforcement.**
