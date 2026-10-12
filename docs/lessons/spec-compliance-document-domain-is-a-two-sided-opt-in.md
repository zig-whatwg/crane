# Spec Compliance: document.domain is a two-sided opt-in

**Date**: 2026-10-11
**Lesson**: Same origin-domain must distinguish an unset domain from an explicitly set domain, even when both effective domains are the original host.

**Why**: An origin's serialization excludes its domain. The document.domain getter returns the effective domain, so it also hides whether the origin's domain is null. Neither value alone can authorize cross-document access.

**What Happened**: Crane's Window.document check read the explicit domain, but contentDocument used the original tuple cached during navigation and frameElement compared origin strings. A setter on only the parent left both accessors exposed, and matching setters on different hosts still left them inaccessible. New fetched-frame regressions reproduce both outcomes on aa2d7708dc.

**Fix**: Compare canonical original origins alongside their separately stored, nullable domains. Equal non-null domains require equal schemes and ignore hosts and ports. Otherwise both domains must be null and the original origins must match. Read current domains from known documents without first calling a security-checked document getter. Keep ordinary same-origin and origin serialization independent of domain relaxation.

Read the domain for each access. Document owns its domain string and replaces that buffer on the next assignment; a borrowed domain slice must not be kept in a cached origin across that mutation.

Inherited documents also need shared origin identity: an about:blank document's own domain storage is not an adequate substitute. Do not add active-parent traversal or reinterpret a missing domain to hide that separate ownership problem.

When the shared record is a separate dependency, preserve the existing inherited-origin lookup explicitly and verify it against the baseline. In this change, the first comparison gained 17 upstream passes but lost document-domain-nested-navigate; retaining the existing lookup for inherited documents restored that pass while keeping network documents' strict opt-in.

Measure successful HTTP-origin access too. The about:blank allocation benchmark missed a common-path regression: 50,000 fetched-frame contentDocument reads rose from 2.3 ms to 559.4 ms because each read called allocating URL and origin getters. Step 2.2 needs only the original same-origin comparison when both current domain slots are null. Keep that branch free of those allocations, with the original-container identity check; adopted containers and set domains still need the full comparison.

The model follows HTML's [same origin-domain algorithm](https://html.spec.whatwg.org/multipage/browsers.html#same-origin-domain) and WebKit's [SecurityOrigin::isSameOriginDomain](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/page/SecurityOrigin.cpp), which distinguishes both-set from neither-set domains.

**Takeaway**: **An unchanged document.domain getter does not mean unchanged access: setting it is an explicit opt-in, and both origins must opt in.**
