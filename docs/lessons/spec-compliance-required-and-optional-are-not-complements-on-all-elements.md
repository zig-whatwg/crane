# Spec Compliance: Required and optional apply to control categories

**Date**: 2026-10-10
**Lesson**: Select a pseudo-class's element category before evaluating its boolean state, and verify disputed categories against browsers.

**Why**: `:optional` is not the negation of `:required` for every element. A div matches neither. Input states add another distinction: the required attribute is inapplicable to hidden inputs, but Chrome and Safari still match those inputs against `:optional`.

**What Happened**: Implementing HTML 4.16.3 in row 14 exposed a difference between its prose restricting optional input states and the browsers. In the aligned stable wpt.fyi run at cc74d2669f (2026-10-06), `html/semantics/selectors/pseudo-classes/required-optional-hidden.html` passed 1/1 in Chrome and Safari, 0/1 in Firefox; all three harnesses completed normally. Blink's `HTMLInputElement::IsRequiredFormControl` applies the input type's SupportsRequired predicate. The majority determines Crane's observable behavior.

**Fix**: Have the HTML helper return an optional boolean: null for an inapplicable element, true for a required control, false for an optional control. An unsupported input state returns false, including when it carries a required attribute. Keep the category test separate from willValidate: a disabled required control still matches `:required` even though it is barred from constraint validation.

**Takeaway**: **Negate state only after establishing that the pseudo-class applies to the element.**

References: [WPT case](https://wpt.fyi/results/html/semantics/selectors/pseudo-classes/required-optional-hidden.html), [Blink input implementation](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/html/forms/html_input_element.cc).
