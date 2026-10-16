# Spec Compliance: Local history keeps policy and refreshes required CSP

**Date**: 2026-10-16
**Lesson**: A restored local document keeps its historical enforced policies while its newly computed required CSP constrains later descendants.

**Why**: CSP Embedded Enforcement's serialized requirement and a document's enforced CSP list serve different purposes. HTML's policy-container clone copies the enforced list; it does not copy the required-CSP metadata.

**What Happened**: Returning the history clone immediately discarded the requirement computed for the traversal. Four about:blank/srcdoc regressions, with unchanged and stronger attributes, kept the correct image policy but sent a null Sec-Required-CSP on the next network grandchild request.

**Fix**: Clone the stored container and copy the navigation's required-CSP string into the returned clone. Do not append that requirement to its enforced policies. Chrome 154's RenderFrameHostImpl::TakeNewDocumentPropertiesFromNavigation records the current requirement at commit (render_frame_host_impl.cc:17120), while NavigationPolicyContainerBuilder::ComputeFinalPolicies restores the old policy list (navigation_policy_container_builder.cc:295-302). CSPEE's draft leaves local history unspecified.

**Takeaway**: **Check both the restored document's enforcement and the requirement sent by its next descendant. One passing image assertion cannot establish both.**
