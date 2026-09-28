# Architecture: A per-agent hook serves every realm kind in the agent

**Date**: 2026-09-27
**Lesson**: Installing HostLoadImportedModule on the window agent made it the handler for every import() in that isolate - including ShadowRealm.prototype.importValue, whose realm is not a Window.

**Why**: V8 keeps one HostImportModuleDynamically callback per isolate. ShadowRealm.prototype.importValue calls it with the ShadowRealm's own context current (V8 13.1 `Runtime_ShadowRealmImportValue` runs in the eval realm), so the host's hook receives a realm whose global object is no Window. The legacy per-context handler had quietly served those realms. The protocol's hook did not.

**What Happened**: With the window agent's module_hooks installed (navigation's 9ad3de9fa, re-landed on R31), loadImportedModule rejected every ShadowRealm import with "import() is not supported here". crane/shadow-realm.advanced went from 44/47 to 38/47, and crane/shadow-realm.basic became a harness ERROR. The R31-only A/B that checked the dynamic-import files the revert was about never ran a ShadowRealm.

**Fix**: HTML's ShadowRealm integration gives a ShadowRealm a synthetic realm settings object. The fix records its principal realm on the realm record (`runtime.ContextData.principal_realm`, set by the V8 adapter's shadow_realm.zig), resolves and fetches through the principal Window's document, and gives it a module map of its own. Its module records are made in the ShadowRealm (`module_script.Environment.realm_override`). All of this landed in the commit before the hooks, so the hooks never ran without it. Against main, which still used the legacy handler, crane/shadow-realm.advanced went from ERROR 44/47 to OK 47/47.

**Takeaway**: **Before installing a hook per agent, list every kind of realm the agent can hold (Window, frame, ShadowRealm, worklet) and give each one a path through it, or a deliberate rejection.**
