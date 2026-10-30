# Spec Compliance: User validity belongs to committed control state

**Date**: 2026-10-27
**Lesson**: Track user validity in the input, select and textarea owners, and let selectors read it without changing it.

**Why**: Constraint validity and user validity answer different questions. A required empty control can be invalid before any user commit, while a script value write must not mark it as user-valid or user-invalid. Reset and cloning also have distinct requirements.

**What Happened**: Crane's selector predicates returned false for both user-validity pseudo-classes because their owner state was missing. Deriving a flag from a dirty value or checkedness would incorrectly mark script writes. Gating all activation on event.isTrusted would also disagree with Firefox and Safari for successful scripted checkbox and radio clicks (the 2026-10-27 three-browser Q24 probe).

**Fix**: Give only the three control owners the flag, initially false. Update it at the existing successful commit and form-submission steps, before observable change/validation callbacks. Clear it in reset steps and leave cloning at the default. Use the existing form-controls hooks across module boundaries. Pin successful activation, canceled activation, script setters, untouched radio-group members, lazy reset allocation and every allocation failure.

**Takeaway**: **A selector reads the owner's committed state; it must not infer or manufacture the state from an unrelated dirty flag.**
