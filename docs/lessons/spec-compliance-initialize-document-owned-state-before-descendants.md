# Spec Compliance: Initialize document-owned state before descendants

**Date**: 2026-10-06
**Lesson**: Establish a document's registry before creating elements that retain their registry association.

**Why**: A persistent association records the state at creation. Initializing the document later does not repair associations already stored on its descendants.

**What Happened**: An initial iframe document created html, head and body before Window.setDocument established its global custom element registry. Those elements retained null associations. Defining a custom element in the iframe and assigning body.innerHTML therefore failed to upgrade it, even though the document and Window subsequently returned the correct registry.

**Fix**: Follow HTML 7.3.2.1's order: step 15 supplies the new Document's registry, then step 22 creates its initial elements. Call the existing Document-owned registry hook before creating html/head/body, and clean up the uninserted document if allocation fails. Test both the initial elements' registry identities and construction through initial body.innerHTML.

**Takeaway**: **When descendants retain an association, owner initialization must precede descendant creation.**
