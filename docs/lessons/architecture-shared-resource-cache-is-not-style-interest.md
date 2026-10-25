# Architecture: Shared resource storage does not imply CSS interest

**Date**: 2026-10-22
**Lesson**: A document that allocated a shared resource cache has not necessarily used a CSS resource.

**Why**: SVG href loads and CSS image loads can share document-owned storage while having different triggers. An SVG image loads when its href changes. A used CSS image is selected at a rendering opportunity, after style and flat-tree eligibility are known.

**What Happened**: The first CSS resource invalidation path treated an existing StyleEngine resource state as proof of CSS interest. An SVG-only document therefore scheduled a CSS tree walk on an unrelated mutation. The native regression created only the SVG cache and then invalidated style; it reproduced the unwanted pending rendering request.

**Fix**: Keep an explicit CSS-interest bit inside the already-lazy resource state. Set it only when a stylesheet or inline/presentation attribute can introduce a CSS resource. Mutation invalidation checks that bit; creating the SVG cache does not set it. A tokenizer recognizes escaped resource syntax, but only computed values at the rendering opportunity decide what is fetched.

**Takeaway**: **Sharing lifetime and storage does not make two features share an activation condition.**
