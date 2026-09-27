# Architecture: Entering a realm entered the current isolate, not the realm's

**Date**: 2026-09-26
**Lesson**: realm_entry.agentOf used the Realm record's isolate, else the CURRENT isolate - so a realm of another agent with no Realm record (context_manager records ContextData.agent for every realm) was entered with a HandleScope of the wrong isolate around its context: "Cannot create a handle without a HandleScope".

**Fix**: agentOf prefers ContextData.agent.

**Takeaway**: **A realm's agent is recorded on it; "the current one" is only right for realms of the current agent.**
