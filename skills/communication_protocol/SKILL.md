# Communication Protocol Skill

## When to use this skill

**ALWAYS loaded** - This skill applies to every interaction and task.

## ⚠️ CRITICAL: Ask Clarifying Questions When Unclear

### Core Principle

**Never make assumptions when requirements are ambiguous. Always ask clarifying questions.**

---

## Question-Asking Protocol

### When You Must Ask Questions

Ask clarifying questions when:

1. **Ambiguous Requirements**
   - Request can be interpreted multiple ways
   - Technical terms have multiple meanings in context
   - Expected behavior is not explicitly stated

2. **Missing Critical Details**
   - Scope is not defined
   - Implementation details are unclear
   - Success criteria are not specified

3. **Conflicting Interpretations**
   - Request could mean opposite things
   - Different approaches would lead to incompatible results
   - Trade-offs between options are not clear

4. **Unclear Expectations**
   - Not sure what "done" looks like
   - Multiple valid approaches exist
   - Edge cases are not addressed

### How to Ask Questions

✅ **DO**:
- Ask **ONE question at a time**
- Wait for answer before asking next question
- Keep questions concise and focused
- Restate your understanding to confirm
- Provide context for why you're asking

❌ **DON'T**:
- Ask multiple questions in one message
- Overwhelm with options and explanations
- Proceed with assumptions "just to get started"
- Implement something hoping it's right

---

## Question Patterns

### Pattern 1: Clarify Ambiguity

```
"I want to make sure I understand: when you say [X], do you mean [interpretation A] or [interpretation B]?"
```

**Example**:
```
"When you say 'case-insensitive tag names,' do you mean:
- Normalize all tags to lowercase (so 'DIV' becomes 'div'), or
- Preserve casing but match case-insensitively (so 'DIV' and 'div' are treated the same)?"
```

### Pattern 2: Confirm Understanding

```
"Just to confirm my understanding: [restate requirement]. Is that correct?"
```

**Example**:
```
"Just to confirm: you want querySelector to accept any casing but only match elements 
with the exact case provided in the selector. So 'fooBar' would NOT match an element 
created with 'FooBar'. Is that correct?"
```

### Pattern 3: Fill Missing Details

```
"To implement this correctly, I need to know: [specific detail needed]?"
```

**Example**:
```
"To implement attribute handling correctly, I need to know: should 'data-id' and 
'DATA-ID' be stored as one attribute or two separate attributes?"
```

### Pattern 4: Clarify Scope

```
"What scope did you have in mind for this: [option A], [option B], or [option C]?"
```

**Example**:
```
"What scope for these tests: should I add them to Element only, or to the base Node 
class so all node types inherit the behavior?"
```

---

## Real-World Examples

### Example 1: Case-Insensitive Request

**User Request**: "This library should support case insensitive tagnames and attributes"

**Initial Understanding**: Could mean:
1. Normalize everything to lowercase
2. Preserve casing but match insensitively
3. Something else entirely

**Clarifying Questions**:
1. "Do you want tag names normalized (e.g., 'DIV' → 'div') or preserved ('DIV' stays 'DIV')?"
2. After answer: "And when querying with querySelector('FOO'), should it match elements created with 'foo', 'FOO', and 'Foo', or only exact matches?"
3. After answer: "Should the same behavior apply to attribute names?"

**Result**: Clear understanding that casing is preserved but matching is case-sensitive.

### Example 2: Test Location Request

**User Request**: "Add tests for case-insensitive behavior"

**Initial Understanding**: Could mean:
1. Tests in Element class
2. Tests in Node class (inherited by all)
3. Tests in both places
4. Tests in specific query selector files

**Clarifying Question**:
"Where should these tests go: in the Element class, or in the base Node class so all node types inherit the behavior?"

**Result**: Tests go in Node only, not in Element/Document/Text.

### Example 3: Implementation Request

**User Request**: "Optimize querySelector performance"

**Initial Understanding**: Could mean:
1. Focus on simple selectors (.class, #id)
2. Focus on complex selectors (descendant, child)
3. Focus on attribute selectors
4. Optimize all equally

**Clarifying Question**:
"Which selector types should I prioritize optimizing: simple class/ID selectors, complex combinators, or attribute selectors?"

**Result**: Focus effort where it matters most to the user.

---

## Decision Tree: Should I Ask?

```
Receive request
    ↓
Can I implement this with 100% confidence I understand what's wanted?
    ↓                              ↓
   YES                            NO
    ↓                              ↓
Proceed with                   Is this a trivial detail
implementation                 I can reasonably infer?
                                   ↓              ↓
                                  YES            NO
                                   ↓              ↓
                               Proceed         ASK ONE
                                           CLARIFYING QUESTION
                                                  ↓
                                            Wait for answer
                                                  ↓
                                            Still unclear?
                                                  ↓
                                            Ask next question
```

---

## Common Scenarios Requiring Questions

### 1. Technical Behavior Ambiguity

❓ "case-insensitive" - normalize or match-insensitively?
❓ "support any casing" - preserve or convert?
❓ "optimize performance" - which operations?
❓ "add validation" - at what point? what errors?

### 2. Scope Ambiguity

❓ "add tests" - where? how many? what coverage?
❓ "implement feature X" - for all node types or specific ones?
❓ "update documentation" - which files? what level of detail?

### 3. Design Trade-offs

❓ "make it faster" - at expense of memory? code complexity?
❓ "add feature X" - breaking change or backward compatible?
❓ "refactor code" - change public API or internal only?

### 4. Incomplete Specifications

❓ "add custom elements" - full Web Components spec or basic support?
❓ "add events" - bubbling? capturing? default actions?
❓ "add mutations" - MutationObserver? or simpler callback?

---

## Integration with Other Skills

This communication protocol skill works WITH all other skills:

### With whatwg_compliance:
- ✅ Ask: "The spec has multiple interpretations here. Which should I follow?"
- ✅ Ask: "Should I implement HTML-specific steps or skip them for generic DOM?"

### With testing_requirements:
- ✅ Ask: "Should tests go in unit tests or WPT tests?"
- ✅ Ask: "What level of coverage: happy path only or comprehensive edge cases?"

### With zig_standards:
- ✅ Ask: "Should this use comptime or runtime? What are the performance requirements?"
- ✅ Ask: "Should this allocate or use existing memory?"

### With performance_optimization:
- ✅ Ask: "Should I optimize for speed or memory?"
- ✅ Ask: "What are the expected common cases?"

---

## Anti-Patterns to Avoid

### ❌ Anti-Pattern 1: Assumption Cascade

```
User: "Make attributes case-insensitive"
Agent: *assumes normalization to lowercase*
Agent: *implements full normalization*
Agent: *writes tests for normalized behavior*
Agent: *updates documentation for normalization*
Result: WRONG - User wanted case-sensitive matching!
```

**Should have asked**: "Do you mean normalize to lowercase, or match case-insensitively?"

### ❌ Anti-Pattern 2: Option Overload

```
User: "Add support for custom elements"
Agent: "Do you want:
  A) Full Web Components spec with lifecycle callbacks?
  B) Hyphenated name validation only?
  C) Custom element registry?
  D) Shadow DOM support?
  E) :defined pseudo-class?
  F) Autonomous vs customized?
  ..."
Result: User overwhelmed, unclear which combination they need
```

**Should have asked**: "Should custom elements follow the Web Components spec, or just allow any element name?"

### ❌ Anti-Pattern 3: Paralysis by Analysis

```
Agent: *spends 10 minutes analyzing edge cases*
Agent: *still uncertain about 1 detail*
Agent: *proceeds anyway hoping for the best*
Result: Implements wrong behavior
```

**Should have done**: Ask the question after 30 seconds of uncertainty.

---

## Success Metrics

You're following this skill correctly when:

✅ User says "yes, exactly" after your clarifying question
✅ Implementation matches user expectations on first try
✅ No rework needed due to misunderstanding
✅ User feels heard and understood
✅ Requirements are crystal clear before coding starts

You're NOT following this skill when:

❌ User says "no, I meant..." after you've implemented something
❌ You have to rewrite significant code due to misunderstanding
❌ Multiple rounds of "that's not what I wanted"
❌ You make assumptions and hope they're correct
❌ You implement first, ask questions later

---

## Quick Reference

**Golden Rule**: When in doubt, ask. One question. Wait for answer. Repeat if needed.

**Question Format**: Concise, focused, one at a time.

**When to Ask**: Ambiguity, missing details, multiple interpretations, unclear expectations.

**When NOT to Ask**: Trivial implementation details you can reasonably infer.

**Success**: User confirms understanding, implementation is right the first time.

---

## Activation

This skill is **ALWAYS ACTIVE** for every request. Before starting any implementation, verification, or significant work, ask yourself:

*"Am I 100% certain I understand what's being asked and what 'done' looks like?"*

If the answer is not "YES", ask a clarifying question.

**Remember**: It takes 30 seconds to ask a question. It takes 30 minutes to fix code built on wrong assumptions.
