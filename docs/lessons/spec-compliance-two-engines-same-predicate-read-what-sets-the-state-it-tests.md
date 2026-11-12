# Spec compliance: Two engines' "same" predicate is the same only if the same things set the state it tests

**Date**: 2026-11-11
**Lesson**: "Chrome and Safari both apply the step only to a dirty value" was true of the two `if` statements and false of the behaviour: the engines mean different things by dirty. Before following a majority on a condition, read every write of the state the condition tests, in each engine, and split the behaviour into the cases those writes create. The majority is counted per case.

**Why**: A deviation from the spec text is licensed by golden rule 2 only where the browsers' majority differs from it. An engine's predicate is one line; what makes it true is spread over the file. Two engines can share the line and differ in a case that one of them reaches through a write the other does not have, and in that case the majority can be the spec's side. Taking the predicate from the engine whose state happens to match ours then widens the deviation past its evidence.

**What Happened**: Lane nd2 batch 4 made an input's `type` change step run with `value` already in the attribute list, and step 1 of the type change steps ("set the element's value content attribute to the element's value") rewrote clean value attributes at parse and clone. The ruling, made from a recollection of the two engines, was "step 1 for a dirty value only, as Chrome and Safari do", on the condition that both were read in source first. Read in source:

- Blink `HTMLInputElement::UpdateType`: `if (HasDirtyValue() && !non_attribute_value_.empty()) setAttribute(value...)`. `has_dirty_value_` is the spec's dirty value flag; Blink's step 2 clears it.
- WebKit `HTMLInputElement::updateType`: `if (auto dirtyValue = std::exchange(m_valueIfDirty, { }); !dirtyValue.isEmpty()) setAttribute...`, and `hasDirtyValue()` is `!m_valueIfDirty.isNull()`. The recollection was right. But WebKit's step 2, eleven lines below, STORES the value: `m_valueIfDirty = sanitizeValue(attributeWithoutSynchronization(valueAttr))`. After hidden -> text with a value attribute, WebKit's value is "dirty" with no script write.
- Gecko `HandleTypeChange` writes whenever the old value is not empty: the spec.

So there were two cases, not one. A value that only ever came from the attribute: Chrome and Safari do not write, Firefox does (2 to 1 against the text). A value step 2 took from the attribute (hidden -> text -> hidden): Safari and Firefox write, Chrome does not (2 to 1 FOR the text). Crane's dirty flag is Blink's, so "dirty-only" on it alone would have followed Chrome alone in the second case, where main agreed with two browsers and the spec. WPT could not have caught it: every type-change test dirties the value first (type-change-state.html is 380/380 in all three).

**Fix**:
1. Read the predicate AND every assignment to the state it tests, in each engine (`grep -n 'm_valueIfDirty\|has_dirty_value_'`), before writing the condition down. Cite files and lines as read, with the revision.
2. List the cases those writes create (here: never stored; stored by script or the user; stored by an earlier type change; reset since) and write each browser's result per case in a small table.
3. Count the majority per case (AGENTS.md golden rule 2, "mechanism by mechanism"). Deviate from the spec only in the cases where the majority does; if the cases together are one shipping browser's behaviour, say whose.
4. Give our state what it needs to tell the cases apart (here one bit, `value_taken_by_type_change`, beside the dirty value), and pin every case with a test - including the ones that already pass, so a simpler predicate cannot replace it unnoticed.
5. Send the table to the integrator before the expensive gates: a ruling made from a recollection is a ruling on the recollection.

**Takeaway**: **A majority on a condition is a majority only case by case: read what sets the state each engine's predicate tests, tabulate the cases those writes create, and deviate from the spec only where two of three do.**
