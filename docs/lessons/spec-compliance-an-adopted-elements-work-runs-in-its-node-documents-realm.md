# Spec Compliance: An adopted element's work runs in its node document's realm, not the realm it was made in

**Date**: 2026-11-18
**Lesson**: When a spec says "the element's node document's relevant settings object" (a script's settings, a fetch's client), read the realm from the node document at that step - `Instance.ctx` is the realm the element was created in, and it does not change when the element is adopted into another realm's document.

**Why**: An element made by one document and inserted into an iframe's document is adopted: its node document changes, its wrapper and its `ctx` stay in the creating realm. Code that takes `element.ctx` as "the element's realm" is right only until the first cross-realm adoption, and the WPT tests that adopt across frames are exactly the ones that notice.

**What Happened**: Lane dom1 found the same mistake twice in one batch:
- `script_execution.runClassicScriptSource` ran an inline script in `element.ctx` (a stated deviation). WebCryptoAPI/algorithm-discards-context.https.window.js creates each child's script in the top-level document and appends it to an iframe's body: every script ran in the top-level realm, the second `let testId` was a redeclaration there, and the file was a harness ERROR (all three browsers pass 13/13).
- `HTMLImageElement.startImageFetch` set the request's client from `realmGlobal(instance.ctx)`, so an img made in a frame and moved to the parent before its update microtask reported its resource timing to the frame (resource-timing/resource_reparenting.html).

**Fix**: Take the realm from the node document at the step: `document.ctx` for "run a classic script" (the document execute-the-script-element already checked), the module environment's context instance = the document, and the img's update document link (`internal.document`) for its client. Keep the element's own realm where the code needs it for lifetime - the fetch list it is on, the hold on the element - which is a different question from whose settings object the spec names.

**Takeaway**: **"The element's node document's settings object" is the node document's realm at that step; `element.ctx` answers "where was it created", which an adoption leaves behind.**
