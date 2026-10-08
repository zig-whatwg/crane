# Spec Compliance: Script preparation runs after the batch connects

**Date**: 2026-10-07
**Lesson**: An HTML script element prepares in post-connection steps, after
the insertion algorithm connects the whole batch and snapshots those steps.

**Why**: Insertion steps run while the batch is still being connected. Script
execution can then observe missing later siblings, or a nested script can run
before the outer script's text has finished connecting. Post-connection steps
also check whether each node is still connected before running it: an earlier
script may remove a later script from the same fragment.

**What Happened**: The HTMLScriptElement hook used insertion steps. The isolated
Crane fragment probe failed while looking up a sibling that had not connected
yet, and the nested script probe executed in the wrong order. Both probes
passed after moving the hook to the existing post-connection registry and
checking the node's current connected flag.

**Fix**: Install post-connection steps from HTMLScriptElement.installHooks.
Keep the parser-inserted and already-started guards. WebKit's
[ScriptElement::postConnectionSteps](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/dom/ScriptElement.cpp)
uses the same phase for prepareScript; HTML's DOM insertion algorithm performs
the still-connected check before post-connection steps.

**Takeaway**: **The mutation phase determines what a running script can see.
A preparation trigger that runs script must match the specified phase, even
when a single appendChild appears to work in either phase.**
