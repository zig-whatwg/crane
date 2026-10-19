# Spec Compliance: Child removal does not prepare a script

**Date**: 2026-10-19
**Lesson**: A children-changed callback needs the kind of change when browser behavior distinguishes removal from insertion.

**Why**: DOM runs children-changed steps after insertion, removal, moving a child, and CharacterData replacement. HTML's current script text does not distinguish those changes, but all three browsers skip preparation on pure child removal (DOM issues 808/1261 and HTML issues 10188/4354; no newer spec rule is involved).

**What Happened**: A connected script with an initially unsupported type became executable when its child was removed. Crane's callback only received the parent, so it could not preserve preparation on insertion and text replacement while skipping removal.

**Fix**: Carry inserted, removed, or replaced_data through the existing notification. A move notifies the old parent with removed and the new parent with inserted. Only script callbacks skip removal; style callbacks still update on every change. WebKit's SVGScriptElement forwards to ScriptElement::childrenChanged, which requires childChange.isInsertion(), supporting the same SVG removal behavior. A native regression checks removal, later insertion and CharacterData replacement; WPT checks both HTML and SVG.

**Takeaway**: **Preserve the mutation's reason at the notification boundary; do not infer it from the parent's resulting state.**
