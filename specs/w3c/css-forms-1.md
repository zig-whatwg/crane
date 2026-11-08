## 1. Introduction

*This section is non-normative.*

User agents have long provided non-standard ways of styling form
controls. However, all of these controls are implemented inconsistently
across user agents, creating unnecessary friction for authors.

This module aims to define a set of form control parts in enough detail
that they can be used interoperably.

It also defines some new ways of customizing form controls, covering
common use cases that were previously only possible by implementing
custom controls from scratch, which was a lot of work, hard to get
right, and often broke either accessibility or platform conventions.

## 2. Opting Into [Basic Appearance: the [appearance: base](https://drafts.csswg.org/css-ui-4/#propdef-appearance) value]
Move definition of [appearance]
here.

Name:

[appearance](https://drafts.csswg.org/css-ui-4/#propdef-appearance)

[New values:](https://www.w3.org/TR/css-values/#value-defs)

base

When applied on a form control, [base] puts that
control in the [basic appearance] state.

A control that has [basic
appearance](#basic-appearance) is consistently styleable using standard CSS and the
pseudo-elements defined below, and applies overridable default styles
that are consistent across UAs. When a control is in that state, the
user agent applies styles from the [Appendix A: Basic Appearance User
Agent Stylesheet](#basic-appearance-stylesheet) to that control.

The user agent must also enable the pseudo-elements defined by [§ 4
Pseudo-Elements](#pseudo-elements). These pseudo-elements (excluding
[::picker()](#selectordef-picker)) always inherit
[appearance](https://drafts.csswg.org/css-ui-4/#propdef-appearance) from their [originating
element](https://drafts.csswg.org/selectors-4/#originating-element). The user agent may implement this using an
[appearance: inherit !important]
declaration.

[NOTE:] The inheritance prevents authors from mixing native and
non-native parts for the same control.

### 2.1. Design Principles for the [Basic Appearance]
The following design principles apply to the design of the [basic
appearance](#basic-appearance) stylesheet for form controls, in approximate order of
descending importance:

1. The styles are identical in every user agent.

2. The controls are recognizable and usable on their own without
 additional styles.

3. The controls target accessiblity out of the box, ideally passing
 [WCAG 2.2 AA standards](https://www.w3.org/TR/WCAG22/).

[NOTE:] Authors may need to do extra adjustments to ensure
their controls are accessible depending on any customizations as well as
the context the form control is placed into. The basic appearance does
not prevent adjustments by the author that are inaccessible.

1. The styles are consistent across controls...

 1. ...in look & feel.

 2. ...in how they are defined in code.

 3. ...in sizing and interaction.

2. The styles are easily adapted to the website's branding, without
 needing complex reset stylesheets:

 1. They use minimal code and are easy to override.

 2. They do not have a strong voice & tone of their own, and are
 visually as simple as possible.

 3. They inherit page styles rather than define new styles whenever
 possible.

 4. They are resilient to adjustments...

 1. ...when changed themselves (e.g. changing font, border,
 layout).

 2. ...when put in context (e.g. ready to be flex or grid
 children).

3. They are comprehensive:

 1. Covering all states for each control.

 2. Supporting all writing modes and color schemes.

For HTML form controls specifically, these principles are applied
through the required user agent stylesheet defined in [Appendix A: Basic
Appearance User Agent Stylesheet](#basic-appearance-stylesheet).

### 2.2. Examples

Refine these examples through
implementation, experimentation, bikeshedding and improvements to the
user agent stylesheet.

The main purpose of these examples is to show how the design principles
for the [basic appearance](#basic-appearance) apply in practice.

To apply the [basic
appearance](#basic-appearance) on individual controls, the following code is used:

```
input, textarea, meter, progress, button, select, fieldset, legend {
 appearance: base;
}
```

[NOTE:] The form layout used by the following examples is not
detailed.

#### 2.2.1. Default User Agent Colors

Here are the [basic
appearance](#basic-appearance) colors inheriting respectively the default light and
dark mode colors from the root element:

![Screenshot of the basic appearance with a light color
scheme](images/base-screenshot.png){height="437"
style="width: 50%; height: auto;" width="400"} ![Screenshot of the basic
appearance with a dark color
scheme](images/base-screenshot-dark.png){height="437"
style="width: 50%; height: auto;" width="400"}

#### 2.2.2. Color/Font Customization

Here are some examples of customization being done on top of the [basic
appearance](#basic-appearance):

```
form {
 font-family: "American Typewriter";
 background-color: rgb(254, 252, 221);
 color: rgb(131, 17, 0);
}

input, textarea, meter, progress, button, select, fieldset, legend {
 appearance: base;
}
```

![Screenshot of a customized basic appearance with brown text and a pale
yellow background](images/base-example-1.png){height="848"
style="width: 100%; height: auto;" width="775"}

```
form {
 font-family: "Courier New";
 font-size: 14px;
 background-color: rgb(0, 0, 0);
 color: rgb(0, 249, 0);
}

input, textarea, meter, progress, button, select, fieldset, legend {
 appearance: base;
}
```

![Screenshot of a customized basic appearance with green text and a
black background](images/base-example-2.png){height="863"
style="width: 100%; height: auto;" width="775"}

## 3. Styling Pickers

### 3.1. The [::picker() pseudo-element]
The [::picker()] pseudo-element represents the part of the
form control that pops out of the page.

``` prod
::picker() = ::picker( <form-control-identifier>+ )
<form-control-identifier> = select
```

The [::picker()](#selectordef-picker) pseudo-element only matches when the [originating
element](https://drafts.csswg.org/selectors-4/#originating-element) supports [basic
appearance](#basic-appearance) and has a popup picker. The specified
[\<form-control-identifier\>](#typedef-picker-form-control-identifier) must also match the [unique picker
name]
of the [originating element]. For
example, the [unique picker
name](#unique-picker-name)
for the
[`select`](https://html.spec.whatwg.org/multipage/form-elements.html#the-select-element) element is [select].

In order for the
[::picker()](#selectordef-picker) pseudo-element to be rendered, it and its
[originating
element](https://drafts.csswg.org/selectors-4/#originating-element) must both have a
[computed](https://drafts.csswg.org/css-cascade-5/#computed-value)
[appearance](https://drafts.csswg.org/css-ui-4/#propdef-appearance) of
[base](#valdef-appearance-base).

The following styles apply the [basic
appearance](#basic-appearance) to the select picker and the select and add some
additional styling to the picker:

```
select, select::picker(select) {
 appearance: base;
}
select::picker(select) {
 border: 5px solid red;
 background-color: blue;
}
```

[NOTE:] The non-functional form of
[::picker()](#selectordef-picker) currently doesn't work to prevent unintended styling
of pickers as new pickers become supported. Once styling for all form
control pickers is finalized, this non-functional form will work for all
pickers.

## 4. Pseudo-Elements

Form controls are composed of many parts that authors may want to style
separately, hence the need for user agents to provide pseudo-elements
for individual form controls.

The section below introduces a set of pseudo-elements that attempts to
cover the most common use cases, so they can be addressed in a
consistent manner across user agents.

Informative overview of form control pseudo-elements as applied to HTML

Control

Pseudo-elements

`<progress>`

 ├─ ''::slider-track''
 │ └─ ''::slider-fill''
 └─ ''::slider-thumb''

`<meter>`

`<input type=checkbox switch>`

`<input type=range>`

`<input type=checkbox>`

[::checkmark](#selectordef-checkmark)

`<input type=radio>`

`<input type=file>`

[::file-selector-button](#selectordef-file-selector-button)

`<input type=date>`

 ├─ ''::field-content''
 │ ├─ ''::field-component''
 │ └─ ''::field-separator''
 └─ ''::picker-icon''

See [§ 4.8 Styling Parts for Date/Time Input Fields: the
::field-component and ::field-separator
pseudo-elements](#date-time-pseudos)

`<input type=datetime-local>`

`<input type=time>`

`<input type=month>`

`<input type=week>`

`<input>` (with no type)

See [§ 4.5 Styling Parts for Text Fields: the ::placeholder,
::field-content, ::reveal-icon, and ::clear-icon
pseudo-elements](#field-pseudos)

`<input type=text>`

`<input type=search>`

`<input type=email>`

`<input type=password>`

`<input type=tel>`

`<input type=url>`

`<input type=number>`

See [§ 4.7 Styling Parts for Number Fields: the ::step-control,
::step-up and ::step-down pseudo-elements](#number-pseudos)

`<input type=color>`

[::color-swatch](#selectordef-color-swatch)

`<textarea>`

See [§ 4.6 Styling Parts for textareas: the ::placeholder and
::field-content pseudo-elements](#textarea-pseudos)

`<select>`

[::picker-icon](#selectordef-picker-icon)

`<option>`

[::checkmark](#selectordef-checkmark)

`<fieldset>` and `<legend>`

Buttons

Add illustrations.

### 4.1. Picker Opener Icon: the [::picker-icon pseudo-element]
The [::picker-icon] pseudo-element represents the part of the
control that represents the icon denoting the presence of the picker. It
is only generated when the [originating
element](https://drafts.csswg.org/selectors-4/#originating-element) has [basic
appearance](#basic-appearance) and if it opens a picker. It is a [fully styleable
pseudo-element](https://drafts.csswg.org/css-pseudo-4/#fully-styleable) and inherits from its [originating
element].

[::picker-icon](#selectordef-picker-icon) generates a box as if it was an child of its
[originating
element](https://drafts.csswg.org/selectors-4/#originating-element), after any boxes generated by the
[::after](https://drafts.csswg.org/css-pseudo-4/#selectordef-after) pseudo-element, with content as specified by
[content](https://drafts.csswg.org/css-content-3/#propdef-content).

### 4.2. File Selector Button: the [::file-selector-button pseudo-element]
The [::file-selector-button] pseudo-element represents
the button used to open a file picker, if the UA renders such a button.

It typically targets the
[`button`](https://html.spec.whatwg.org/multipage/form-elements.html#the-button-element) inside an
[`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element) element with `type=file`.

For example, the following
example should show a green border around the file selector button:

```
::file-selector-button { border: 3px solid green }
```

### 4.3. Styling Checkmarks: the [::checkmark pseudo-element]
The [::checkmark] pseudo-element represents an indicator of
whether the item is checked, and is present on checkboxes, radios, and
option elements.

It is only generated when the [originating
element](https://drafts.csswg.org/selectors-4/#originating-element) supports the
[:checked](https://drafts.csswg.org/selectors-4/#checked-pseudo) pseudo-class, and either has [basic
appearance](#basic-appearance) or an ancestor with [basic
appearance]. It is a [fully styleable
pseudo-element](https://drafts.csswg.org/css-pseudo-4/#fully-styleable) and inherits from its [originating
element].

For checkboxes and radio elements, it generates a box as if it was an
child of its [originating
element](https://drafts.csswg.org/selectors-4/#originating-element), between the boxes generated by the
[::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before) and
[::after](https://drafts.csswg.org/css-pseudo-4/#selectordef-after) pseudo-element, with content as specified by
[content](https://drafts.csswg.org/css-content-3/#propdef-content).

For option elements, it generates a box as if it was an child of its
[originating
element](https://drafts.csswg.org/selectors-4/#originating-element), preceding any boxes generated by the
[::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before) pseudo-element, with content as specified by
[content](https://drafts.csswg.org/css-content-3/#propdef-content).

The following example changes the
background image of a checkmark:

```
::checkmark { background-image: url(...) }
```

It may also be used in combination with `:indeterminate` to style the
indeterminate checkmark:

```
:indeterminate::checkmark { background-image: url(...) }
```

### 4.4. Styling Parts of [Slider-Like Controls: the [::slider-thumb](#selectordef-slider-thumb), [::slider-track](#selectordef-slider-track) and [::slider-fill](#selectordef-slider-fill) pseudo-elements]
[Slider-like controls] are form controls that represent progress.
That progress may be adjustable by the user.

The following pseudo-elements are provided to style their different
parts:

[::slider-thumb]

: The
 [::slider-thumb](#selectordef-slider-thumb) pseudo-element represents the portion that
 allows the user to adjust the progress of the control.

 [NOTE:] It is typically natively rendered as a circle in
 most user agents.

[::slider-track]
: The
 [::slider-track](#selectordef-slider-track) pseudo-element represents the portion
 containing both the progressed and unprogressed portions of the
 control.

[::slider-fill]

: The
 [::slider-fill](#selectordef-slider-fill) pseudo-element represents the portion
 containing the progressed portion of the control.

 When the progress of control is indeterminate (like with
 [\<progress\>]), the user agent must give this portion an
 inline-size of zero.

These pseudo-elements are [fully styleable
pseudo-elements](https://drafts.csswg.org/css-pseudo-4/#fully-styleable) and their structure is the following:

 <input type="range">
 ├─ ::slider-track
 │ └─ ::slider-fill
 └─ ::slider-thumb

The list of [slider-like
controls](#slider-like-controls) depends on the host language. For HTML, this
corresponds to:

- [`progress`](https://html.spec.whatwg.org/multipage/form-elements.html#the-progress-element)

- [`meter`](https://html.spec.whatwg.org/multipage/form-elements.html#the-meter-element)

- [`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element) elements with `type="range"`

- [`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element) elements with `type="checkbox" switch`

### 4.5. Styling Parts for Text Fields: the [::placeholder, [::field-content](#selectordef-field-content), [::reveal-icon](#selectordef-reveal-icon), and [::clear-icon](#selectordef-clear-icon) pseudo-elements]
[::placeholder]
: The
 [::placeholder](#selectordef-placeholder) pseudo-element represents the portion of the
 [`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element) that contains the placeholder text.

[::field-content]
: The
 [::field-content](#selectordef-field-content) pseudo-element represents the portion of the
 [`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element) that contains the editable text.

[::reveal-icon]

: The
 [::reveal-icon](#selectordef-reveal-icon) pseudo-element represents the portion of the
 [`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element) that allows the user to temporarily disable
 obscuring of [sensitive text
 input](#sensitive-text-input) when clicked if provided by the user agent.

 User agents providing
 [::reveal-icon](#selectordef-reveal-icon) may choose to remove it in some
 circumstances to help protect [sensitive text
 input](#sensitive-text-input) from being revealed unintentionally.

 :::
 Example mitigations to avoid unintentionally revealing [sensitive
 text input](#sensitive-text-input):
 - If focus moves away from the field, remove the
 [::reveal-icon](#selectordef-reveal-icon).
 - If script modifies field content, remove the
 [::reveal-icon](#selectordef-reveal-icon).
 - If the
 [::reveal-icon](#selectordef-reveal-icon) is removed due to either of the above, the
 user must delete the contents of the field to make the
 [::reveal-icon] appear
 again. This behavior prevents someone from making a minor change
 to field content to expose the
 [::reveal-icon] on an
 unattended device.
 - If the field is filled by a user agent autofill feature, remove
 the
 [::reveal-icon](#selectordef-reveal-icon).
 :::

[::clear-icon]

: The
 [::clear-icon](#selectordef-clear-icon) pseudo-element represents the portion of the
 [`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element) that allows the user to clear the
 [`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element) when clicked if provided by the user agent.

 With [appearance:
 textfield](https://drafts.csswg.org/css-ui-4/#propdef-appearance), the user agent must not generate this
 part.

[::field-content](#selectordef-field-content),
[::reveal-icon](#selectordef-reveal-icon), and
[::clear-icon](#selectordef-clear-icon) must be siblings.

Collect parts used by autofill.

Define how `::placeholder` interacts
with `::field-content`. [\[Issue
#11844\]](https://github.com/w3c/csswg-drafts/issues/11844)

### 4.6. Styling Parts for textareas: the [::placeholder and [::field-content](#selectordef-field-content) pseudo-elements]
[::placeholder](#selectordef-placeholder)
: The
 [::placeholder](#selectordef-placeholder) pseudo-element represents the portion of the
 [`textarea`](https://html.spec.whatwg.org/multipage/form-elements.html#the-textarea-element) that contains the placeholder text.

[::field-content](#selectordef-field-content)
: The
 [::field-content](#selectordef-field-content) pseudo-element represents the portion of the
 [`textarea`](https://html.spec.whatwg.org/multipage/form-elements.html#the-textarea-element) that contains the editable text.

Define something for the resizer.
[\[Issue #11850\]](https://github.com/w3c/csswg-drafts/issues/11850)

(#issue-b3d63442①) Define how `::placeholder` interacts
with `::field-content`. [\[Issue
#11844\]](https://github.com/w3c/csswg-drafts/issues/11844)

### 4.7. Styling Parts for Number Fields: the [::step-control, [::step-up](#selectordef-step-up) and [::step-down](#selectordef-step-down) pseudo-elements]
These pseudo-elements are provided for number inputs. They are [fully
styleable
pseudo-elements](https://drafts.csswg.org/css-pseudo-4/#fully-styleable).

[::step-control]
: The
 [::step-control](#selectordef-step-control) pseudo-element represents the portion of a
 number input that contains the up and down buttons.

[::step-up]
: The [::step-up](#selectordef-step-up) pseudo-element represents the button that
 increments the value inside a number input when activated.

[::step-down]
: The
 [::step-down](#selectordef-step-down) pseudo-element represents the button that
 decrements the value inside a number input when activated.

Their structure is defined as follows:

 <input type="number">
 ├─ ::field-content
 └─ ::step-control
 ├─ ::step-up
 └─ ::step-down

The following control:

``` highlight
<input type="number">
```

can be re-styled like this:

`[ + 2 - ]`

Insert real image.

using the following styles:

```
input[type=number] {
 appearance: base;
 &::step-control {
 display: contents;
 }
 &::step-up {
 order: 1;
 content: "+";
 }
 &::field-content {
 order: 2;
 }
 &::step-down {
 order: 3;
 content: "-";
 }
}
```

With [appearance:
textfield](https://drafts.csswg.org/css-ui-4/#propdef-appearance), the user agent must not generate this part.

### 4.8. Styling Parts for Date/Time Input Fields: the [::field-component and [::field-separator](#selectordef-field-separator) pseudo-elements]
[::field-component]
: The
 [::field-component](#selectordef-field-component) pseudo-element represents the portions of
 the control that contain the date/time component values.

[::field-separator]
: The
 [::field-separator](#selectordef-field-separator) pseudo-element represents the portions of
 the control that separate the date/time component values if the user
 agent provides those portions.

Those pseudo-elements are siblings. The exact structure of the control
is determined by internationalization and by the host language, but must
be consistent across user-agents.
[::field-component](#selectordef-field-component) and
[::field-separator](#selectordef-field-separator) pseudo-elements are all contained within a
[::field-content](#selectordef-field-content) pseudo-element.

The following
control:

``` highlight
<input type="date">
```

may render like this in US locales:

\[ 08 / 22 / 2024 \[v\]\]

(#issue-7cdd0a4e①) Insert real image.

The resulting tree is:

 <input type="date">
 ├─ ::field-content
 │ ├─ ::field-component (08)
 │ ├─ ::field-separator (/)
 │ ├─ ::field-component (22)
 │ ├─ ::field-separator (/)
 │ └─ ::field-component (2024)
 └─ ::picker-icon

### 4.9. Color Swatch: the [::color-swatch pseudo-element]
The [::color-swatch] pseudo-element represents the portion of
the control that displays the chosen color value.

For example, the following example
should make the input and its color swatch rounded:

```
input[type=color], ::color-swatch { border-radius: 100%; }
```

### 4.10. Compatibility With Vendor Pseudo-Element Extensions

When possible, the user agent should use aliasing to implement any
non-standard pseudo-elements.

When not possible, the user agent must reserve the standard
pseudo-elements for [appearance:
base](https://drafts.csswg.org/css-ui-4/#propdef-appearance) and use any non-standard ones for
[appearance: none].

## 5. Pseudo-Classes

### 5.1. Targeting Different Meter States: the [:low-value / [:high-value](#selectordef-high-value) / [:optimal-value](#selectordef-optimal-value) pseudo-classes]
Make sure this is able to replicate UA
logic. [\[Issue
#11336\]](https://github.com/w3c/csswg-drafts/issues/11336)

Link these to the HTML definitions.

The [:low-value] pseudo-class matches on a
[`meter`](https://html.spec.whatwg.org/multipage/form-elements.html#the-meter-element) element when its value is under the value specified
by the `low` HTML attribute.

The [:high-value] pseudo-class matches on a
[`meter`](https://html.spec.whatwg.org/multipage/form-elements.html#the-meter-element) element when its value is over the value specified
by the `high` HTML attribute.

The [:optimal-value] pseudo-class matches on a
[`meter`](https://html.spec.whatwg.org/multipage/form-elements.html#the-meter-element) element when its value is in the range determined
by the `optimum` / `low` / `high` HTML attributes.

### 5.2. Targeting Selects that are Listboxes

Define something. [\[Issue
#7422\]](https://github.com/w3c/csswg-drafts/issues/7422)

## 6. The [control-value() function]
This is not ready for implementation,
file an issue regarding this.

Consider privacy implications, regarding
data exfiltration. [\[Issue
#11860\]](https://github.com/w3c/csswg-drafts/issues/11860)

Consider adding more types. [\[Issue
#11842\]](https://github.com/w3c/csswg-drafts/issues/11842)

The [control-value()] function computes to the current value of
the form control it is on. If it is used on an element that is not a
form control, it returns an empty string.

``` prod
<control-value()> = control-value( <type>? )

<type> = '<' [ number | string ] '>'
```

If used on a pseudo-element, it is evaluated against its originating
element.

For example, to show
on the value of a range input next to it:

```
input[type=range]::after {
 content: control-value();
}
```

## 7. Styling Widgets

### 7.1. Switching form control sizing: the [field-sizing property]
Name:

[field-sizing]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

fixed
[\|](https://drafts.csswg.org/css-values-4/#comb-one) content

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

[fixed](#valdef-field-sizing-fixed)

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[elements with default preferred
size](#element-with-default-preferred-size)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

For the purpose of this specification, an [element with default
preferred size] is an element whose [intrinsic
size](https://drafts.csswg.org/css-sizing-3/#intrinsic-size) is fixed regardless of the size of its content. The
host language defines which elements are applicable to it. For example,
in HTML
[`textarea`](https://html.spec.whatwg.org/multipage/form-elements.html#the-textarea-element) is an [element with default preferred
size](#element-with-default-preferred-size).

[fixed]
: For [element with default preferred
 size](#element-with-default-preferred-size), the UA must set the [intrinsic
 size](https://drafts.csswg.org/css-sizing-3/#intrinsic-size) to the default preferred size defined by the host
 language for that element. Otherwise, the UA must behave the same as
 [content](#valdef-field-sizing-content).

[content]
: The UA must determine the element's [intrinsic
 size](https://drafts.csswg.org/css-sizing-3/#intrinsic-size) based on its content, and must ignore any default
 preferred size defined by the host language for that element. If the
 element is an [element with default preferred
 size](#element-with-default-preferred-size) and is listed in [compressible replaced
 elements](https://drafts.csswg.org/css-sizing-3/#min-content-zero),
 the UA must stop treating the element as a replaced element for
 [min-content
 contribution](https://drafts.csswg.org/css-sizing-3/#min-content-contribution).

For instance,
[`textarea`](https://html.spec.whatwg.org/multipage/form-elements.html#the-textarea-element) has a fixed size regardless of its content by
default:

[⎸] [The quick brown fox jumps over the lazy
dog.]

If [field-sizing:
content](#propdef-field-sizing) is applied, the size of the former should fit to a
text caret. [⎸]

If [field-sizing:
content](#propdef-field-sizing) is applied and its width property has a fixed
value like [width:
10em](https://drafts.csswg.org/css-sizing-3/#propdef-width), the element height depends on the number of
the content lines:

[The quick brown fox jumps over the lazy dog.⎸]

### 7.2. Fieldset layout

Move to HTML.

When a fieldset is in base appearance mode the layout and rendering
behaviour as
[defined](https://html.spec.whatwg.org/multipage/#the-fieldset-and-legend-elements:the-fieldset-element-2)
in the HTML specification, do not apply to the fieldset or its legend.

### 7.3. Changing the Orientation of a [Slider-Like Control: [slider-orientation]]
Rework this property.

Name:

[slider-orientation]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) left-to-right [\|]
right-to-left [\|] top-to-bottom
[\|] bottom-to-top

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

[auto]
: The [slider-like
 control](#slider-like-controls) orientation is defined by the writing mode and
 direction.

[left-to-right]
: The [slider-like
 control](#slider-like-controls) is rendered horizontally and
 [::slider-fill](#selectordef-slider-fill) is left-aligned within the control.

[right-to-left]
: The [slider-like
 control](#slider-like-controls) is rendered horizontally and
 [::slider-fill](#selectordef-slider-fill) is right-aligned within the control.

[top-to-bottom]
: The [slider-like
 control](#slider-like-controls) is rendered vertically and
 [::slider-fill](#selectordef-slider-fill) is top-aligned within the control.

[bottom-to-top]
: The [slider-like
 control](#slider-like-controls) is rendered vertically and
 [::slider-fill](#selectordef-slider-fill) is bottom-aligned within the control.

### 7.4. Obscuring sensitive input: the [input-security property]
The CSSWG has agreed that while we
believe that providing this piece of functionality to users is
important, doing it via CSS+JS is the wrong approach, and that instead
it should be built into user agents: this needs to work consistently
from site to site for it to be discoverable and understandable by users,
this needs to work even when JS is turned off, and this needs to have
consistently solid accessibility... We therefore intend to remove this
from the specification, and instead, we would like to see this behavior
specified in the HTML specification as part of the interaction model of
password fields. Holding off deleting until the situation with HTML is
clarified. See <https://github.com/w3c/csswg-drafts/issues/6788> and
<https://github.com/whatwg/html/issues/7293>.

Name:

[input-security]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) none

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

[auto](#valdef-input-security-auto)

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[sensitive text
inputs](#sensitive-text-input)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

For the purpose of this specification, a [sensitive text
input]
is a text input whose purpose is to accept sensitive input, as defined
by the host language. For example, in HTML
[`<input type=password>`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type-password-keyword) is a [sensitive text
input](#sensitive-text-input).

By default, user agents obscure the contents of [sensitive text
inputs](#sensitive-text-input) in order to prevent onlookers from seeing it. Users may
wish to temporarily disable this obscuring in order to confirm that
they've typed their sensitive information correctly. The
[input-security] property may be used by authors to enable or
disable this obscuring.

[none]
: The UA must not obscure the text in the control, so that it can be
 read by the user.

[auto]
: The UA should obscure the text in the control, so that it cannot be
 read by the user.

While the exact mechanism by which user agents obscure the text in the
control is undefined, user agents typically obscure [sensitive text
inputs](#sensitive-text-input) by replacing each character with some suitable
replacement such as U+002A ASTERISK (\*) or U+25CF BLACK CIRCLE (●).

For instance, given this style sheet

```
input[type=password] {
 input-security: auto;
}
```

and this HTML

```
<input type=password value=MySecret794>
```

a user agent might render the
[`<input type=password>`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type-password-keyword) like so:
[●●●●●●●●●●●]

## [Appendix A: Basic Appearance User Agent Stylesheet]
(#issue-10d6d5a6①) Move to HTML.

This section needs refining with
implementation.

### [Basics]
```
input,
textarea,
button,
::file-selector-button,
::color-swatch,
meter,
progress,
fieldset,
legend {
 color: inherit;
 font: inherit;
 box-sizing: border-box;
 background-color: transparent;
}

::checkmark,
::picker-icon,
::slider-track,
::slider-fill,
::slider-thumb,
::reveal-icon,
::clear-icon,
::field-content,
::field-component,
::field-separator,
::step-control,
::step-up,
::step-down,
::placeholder {
 box-sizing: border-box;
}
```

### [Layout]
```
input:not([type=file], [type=range], [type=checkbox][switch]),
textarea,
button,
::file-selector-button,
::slider-track {
 border: 1px solid currentColor;
 background-color: light-dark(transparent, alpha(from white / 4%));
}

fieldset {
 border: 1px solid currentColor;
}

input {
 align-content: unsafe center;
 align-items: unsafe center;
}
```

### [Sliders]
Refine meter, progress, switch and range
input styling. [\[Issue
#12267\]](https://github.com/w3c/csswg-drafts/issues/12267)

```
input[type="checkbox"][switch],
input[type="range"] {
 display: inline-flex;
 position: relative;
 align-items: center;
 inline-size: 100%;
}

input[type="checkbox"][switch]::slider-track,
input[type="range"]::slider-track,
meter::slider-track,
progress::slider-track {
 block-size: 1em;
 inline-size: 100%;
}

input[type=range]::slider-track {
 block-size: 0.5em;
}

input[type=checkbox][switch]::slider-track {
 border-radius: 1em;
}

input[type="checkbox"][switch]::slider-fill,
input[type="range"]::slider-fill,
meter::slider-fill,
progress::slider-fill {
 block-size: 100%;
 background-color: currentColor;
}

progress:indeterminate::slider-fill {
 inline-size: 0;
}

input[type="range"]::slider-fill,
input[type=checkbox][switch]::slider-fill {
 background-color: color-mix(currentColor 25%, transparent);
 border-radius: inherit;

 block-size: 100%;
}

input[type=checkbox][switch]::slider-fill {
 inline-size: 0%;
}

input[type="checkbox"][switch]:checked::slider-fill {
 inline-size: 100%;
}

input[type="checkbox"][switch]::slider-thumb,
input[type="range"]::slider-thumb {
 border-radius: 0;
 border: none;
 background-color: currentColor;
 appearance: none;
 inline-size: 1em;
 block-size: 1em;
 border-radius: 100%;
 position: absolute;
}

input[type=checkbox][switch]:checked::slider-thumb {
 inset-inline-end: 0;
}
```

### [Checkboxes & radios]
```
input[type=checkbox]:not([switch]),
input[type=radio] {
 /* These size rules ensure accessibility by following WCAG rules:
 * https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html */
 block-size: 1em;
 inline-size: 1em;
 font-size: max(1em, 24px);

 display: inline-flex;
 align-items: center;
 justify-content: center;
}

input[type=checkbox]:not([switch])::checkmark {
 content: '\2713' / '';
}

input[type=radio]::checkmark {
 content: '';
}

input[type=checkbox]:not([switch], :checked, :indeterminate)::checkmark {
input[type=radio]:not(:checked)::checkmark {
 visibility: hidden;
}

input[type=checkbox]:indeterminate::checkmark {
 content: '\2500' / '';
}

input[type=radio] {
 border-radius: 50%;
}

input[type=radio]:checked::checkmark {
 background-color: currentColor;
 display: inline-block;
 border-radius: inherit;
 height: 100%;
 width: 100%;
}
```

### [Buttons (and button-like controls)]
```
button,
::file-selector-button,
input:is([type="color"], [type="button"], [type="reset"], [type="submit"]) {
 border: 1px solid currentColor;
 background-color: transparent;
 color: inherit;
 /* Padding prevents the text from sticking to the borders.
 * optically centered to account for half leading */
 padding-block: 0.25em;
 padding-inline: 0.5em;

 border-radius: 4px;

 /* These min-size rules ensure accessibility by following WCAG rules:
 * https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html
 * The 1lh is there to make sure that options without text don't change
 * the block size of the button. */
 min-block-size: calc-size(auto, max(size, 24px, 1lh));
 min-inline-size: calc-size(auto, max(size, 24px));

 /* Push picker icon to the right of the box and have some space
 * in between it and the text. */
 display: inline-flex;
 gap: 0.5em;

 user-select: none;

 text-transform: initial;
 text-align: initial;
 text-indent: initial;
}

button:enabled:hover,
input:is([type="color"], [type="button"], [type="reset"], [type="submit"]):enabled:hover,
input[type="file"]:enabled::file-selector-button:hover {
 background-color: color-mix(currentColor 10%, transparent);
}

button:enabled:active,
input:is([type="color"], [type="button"], [type="reset"], [type="submit"]):enabled:active,
input[type="file"]:enabled::file-selector-button:active {
 background-color: color-mix(currentColor 20%, transparent);
}

button:disabled,
input:is([type="color"], [type="button"], [type="reset"], [type="submit"]):disabled,
input[type="file"]:disabled::file-selector-button {
 color: color-mix(currentColor 50%, transparent);
}
```

### [Color Input]
```
input[type="color"] {
 padding: 0;
 overflow: clip;
}

::color-swatch {
 inline-size: stretch;
 block-size: stretch;

 /* These prevent forced dark mode or forced colors mode from changing the background. */
 color-scheme: light only;
 forced-color-adjust: none;

 /* Uses a linear gradient to handle showing the alpha channel of chosen color */
 background: linear-gradient(control-value()), linear-gradient(to bottom right, black 50%, white 50%);
}
```

### [Selects]
See base appearance user agent styles specified in
[HTML](https://html.spec.whatwg.org/multipage/rendering.html#the-select-element-2).

#### [Text inputs]
```
textarea,
input {
 border-radius: 4px;
}
```

The above must apply to textareas and textual inputs only.

```
input::field-content {
 display: flow !important;
}

input::field-component,
input::field-separator {
 position: static !important;
}
```

## [Changes]
### [Since the [First Public Working Draft](https://www.w3.org/TR/2025/WD-css-forms-1-20250325/) of 25 March 2025]
- Added !important to select buttons inertness.
- Removed \"Appendix B: Explorations\" with obsolete ideas.
- Added \"slider-\" prefix to slider pseudo-elements.
- Moved
 [field-sizing](#propdef-field-sizing) and
 [input-security](#propdef-input-security) properties from css-ui-4.
- Added the
 [::reveal-icon](#selectordef-reveal-icon) pseudo-element.

## [Privacy Considerations]
No new privacy considerations have been reported on this specification.

## [Security Considerations]
No new security considerations have been reported on this specification.

## [Acknowledgements]
Thanks to Aditya Keerthi, Anne van Kesteren, Elika Etemad, Jen Simmons,
Joey Arhar, Jon Davis, Simon Fraser and Theresa O'Connor for their input
on this proposal.

Thanks to Ana Tudor for [her detailed
analysis](https://github.com/w3c/csswg-drafts/issues/4410#issuecomment-1087244943)
of `input[type=range]` styling.
