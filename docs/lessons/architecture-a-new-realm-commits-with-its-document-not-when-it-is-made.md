# Architecture: A new realm commits with its document, not when it is made

**Date**: 2026-11-11
**Lesson**: HTML "create and initialize a Document object" makes the realm and its Window (step 7) and the document (step 9), and sets the Window's associated Document (step 10), all in one algorithm that cannot fail. Crane splits it in two: replaceRealm makes the realm, and commitResponse makes the document later. Each half can run out of memory. Making the first half failure-atomic is not enough. The realm replacement has to commit at step 10, the step that makes the spec's invariant ("every Window has its associated Document") true.

**Why**: Lane v8up b3f made createWindowRealm's failures leave the navigable on its old realm. The sweep then failed at failing allocation 146 (chat2) and 145 (server1), with no failure counted. The new realm had been made. The next allocation, the new Window's Location, failed and was swallowed, and every later allocation failed too. replaceRealm had already returned true and ended the old realm. The navigable was left on a new Window with no document, and script through the proxy got a SecurityError: no document, so no origin.

**What Happened**: The b3g brief suspected the recovery navigation's "already handed on" path. A diagnostic print at the failing round showed what was really there: the failing allocation's stack, the active window, its document, and the integration's realm. The cause was a failure after the step everyone was watching. Printing the facts found it in one run; the hypothesis would have cost several.

**Fix**: replaceRealm leaves the replacement pending (IFrameIntegration.pending_realm_replacement). Every caller of realmForDocument settles it with a `defer` (HTMLIFrameElement settleRealmReplacement):
- **Commit**: once the new Window has its document, the old realm ends and its popups move.
- **Abandon**: otherwise, the old realm is restored and its Window is active again. Then the new realm is ended with .global_detached, which detaches its global, so the proxy is left with V8's one state: no global, TypeError "no access".

**Takeaway**: **When a spec algorithm cannot fail and Crane's version of it can, commit at the step that makes the spec's invariant hold, and undo everything before it. At the failing round, print the failing allocation's stack and the state, before testing any hypothesis.**
