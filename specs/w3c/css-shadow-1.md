## 1. Introduction

Shadow DOM allows authors to separate their page into \"components\",
subtrees of markup whose details are only relevant to the component
itself, not the outside page. This reduces the chance of a style meant
for one part of the page accidentally over-applying and making a
different part of the page look wrong. However, this styling barrier
also makes it harder for a page to interact with its components when it
actually *wants* to do so.

This specification defines the
[::part()](#selectordef-part) pseudo-element, which allows an author to style
specific, purposely exposed elements in a [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree) from the outside page's context. In combination with
[custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property), which let the outside page pass particular values
(such as theme colors) into the component for it to do with as it will,
these pseudo-elements allow components and the outside page to interact
in safe, powerful ways, maintaining encapsulation without surrendering
all control.

The [:host](#selectordef-host) pseudo-class and its [functional
counterpart](https://drafts.csswg.org/selectors-4/#functional-pseudo-class)
[:host()](#selectordef-host-function) match the [shadow
tree's](https://dom.spec.whatwg.org/#concept-shadow-tree) [shadow
host](https://dom.spec.whatwg.org/#element-shadow-host).

Furthermore, the [::slotted]
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) and the related
[:has-slotted](#selectordef-has-slotted)
[pseudo-class](https://drafts.csswg.org/selectors-4/#pseudo-class) provide ways to interact with
[slots](https://dom.spec.whatwg.org/#concept-slot) and their assigned [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree).

Tests

General tests for shadow parts

------------------------------------------------------------------------

 This specification was originally titled CSS Scoping
Module Level 1. It has since been merged with CSS Shadow Parts Module
Level 1 and renamed to CSS Shadow Module Level 1 to better reflect its
comprehensive coverage of Shadow DOM features. The [scoped style
rules](https://drafts.csswg.org/css-cascade-6/#scoped-style-rules) feature initially described in this module has been
moved to
[\[css-cascade-6\]](#biblio-css-cascade-6 "CSS Cascading and Inheritance Level 6").

## 2. Default Styles for Custom Elements

**This section is **experimental**, and is under active discussion. Do
not implement without consulting the CSSWG.**

When defining [custom
elements](https://html.spec.whatwg.org/multipage/custom-elements.html#custom-element), one often wants to set up \"default\" styles for them,
akin to the user-agent styles that apply to built-in elements. This is,
unfortunately, hard to do in vanilla CSS, due to issues of scoping and
specificity---​the element in question might be used in [shadow
trees](https://dom.spec.whatwg.org/#concept-shadow-tree), and thus is unreachable by any selector targeting it
in the outermost document; and selectors, even low-specificity ones like
simple [type
selectors](https://drafts.csswg.org/selectors-4/#type-selector), can accidentally override author-level styles meant to
target the element.

To aid in this, this section defines a way to create a stylesheet of
\"default element styles\" for a given element. This stylesheet applies
across the entire document, in all [shadow
trees](https://dom.spec.whatwg.org/#concept-shadow-tree), and the rules in it apply at the [user-agent
origin](https://drafts.csswg.org/css-cascade-5/#cascade-origin-ua), so author-level rules automatically win.

[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window)s gain a private slot
[`[[defaultElementStylesMap]]`] which is a map of [local
names](https://dom.spec.whatwg.org/#concept-element-local-name) to
[stylesheets](https://drafts.csswg.org/css-syntax-3/#css-stylesheet).

These stylesheets must apply to every document in the window. They must
be interpreted as user agent stylesheets.

 This implies, in particular, that they apply to all
[shadow
trees](https://dom.spec.whatwg.org/#concept-shadow-tree) in every document, and that the declarations in them
are from the [user-agent
origin](https://drafts.csswg.org/css-cascade-5/#cascade-origin-ua).

For the purpose of the
[cascade](https://drafts.csswg.org/css-cascade-6/#cascade), these stylesheets are ordered after the user agent's
own stylesheets; their relative ordering doesn't matter as it is not
observable.

Within these stylesheets, [complex
selectors](https://drafts.csswg.org/selectors-4/#complex) must be treated as invalid. Every [compound
selector](https://drafts.csswg.org/selectors-4/#compound) must be treated as containing an additional [type
selector](https://drafts.csswg.org/selectors-4/#type-selector) that selects elements with the [local
name](https://dom.spec.whatwg.org/#concept-element-local-name) that the stylesheet is keyed with.

Do we need to restrict the
[at-rules](https://drafts.csswg.org/css-syntax-3/#at-rule) that can be used in these sheets? For example, do we
allow an
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule)? I'm going to leave it as allowed unless/until I
hear complaints.

This specification does not define how to add to, remove from, or
generally manipulate the
[`[[defaultElementStylesMap]]`](#dom-window-defaultelementstylesmap-slot). It is expected that other specifications, such as
[\[DOM\]](#biblio-dom "DOM Standard"), will define
ways to do so.

## 3. Shadow Encapsulation

### 3.1. Informative Explanation of Shadow DOM

*The following is a non-normative explanation of several concepts
normatively defined in the DOM Standard
[\[DOM\]](#biblio-dom "DOM Standard"), to aid in
understanding what this spec defines without having to fully grok the
DOM Standard.*

In addition to the qualities of an element tree defined in [Selectors
Level 4 § data-model](https://drafts.csswg.org/selectors/#data-model),
the DOM Standard adds several new concepts related to [shadow
trees](https://dom.spec.whatwg.org/#concept-shadow-tree), several of which are relevant to CSS.

An element can host a [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree), which is a special kind of document fragment with a
[shadow
root](https://dom.spec.whatwg.org/#concept-shadow-root) (a non-element node) at its root. Children of the
[shadow root] are ordinary elements and
other nodes. The element hosting the [shadow
tree] is its
[host](https://dom.spec.whatwg.org/#concept-documentfragment-host), or [shadow
host](https://dom.spec.whatwg.org/#element-shadow-host).

The elements in a [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree) are not
[descendants](https://dom.spec.whatwg.org/#concept-tree-descendant) of the [shadow
host](https://dom.spec.whatwg.org/#element-shadow-host) in general (including for the purposes of Selectors
like the [descendant
combinator](https://drafts.csswg.org/selectors-4/#descendant-combinator)). However, the [shadow
tree], when it exists, is used in the
construction of the [flattened element
tree](#flat-tree), which CSS uses
for all purposes *after* Selectors (including inheritance and box
construction).

Loosely, the [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree) is treated as the [shadow
host's](https://dom.spec.whatwg.org/#element-shadow-host) contents instead of its normal [light
tree](https://dom.spec.whatwg.org/#concept-light-tree) contents. However, some of its [light
tree] children can be \"pulled into\" the
[shadow tree] by assigning them to
[slots](https://dom.spec.whatwg.org/#concept-slot). This causes them to be treated as children of the
[slot] for CSS purposes. The
[slots] can then be assigned to
[slots] in deeper [shadow
trees]; luckily,
[slots] themselves don't generate boxes by
default, so you don't get an unpredictable cascade of
[`slot`](https://html.spec.whatwg.org/multipage/scripting.html#the-slot-element) wrapper elements disrupting your CSS.

If nothing is explicitly assigned to a
[slot](https://dom.spec.whatwg.org/#concept-slot), the [slot's] own children are
instead assigned to it, as a sort of \"default\" contents.

### 3.2. Shadow DOM and Selectors

#### 3.2.1. Matching Selectors Against Shadow Trees

When a selector is matched against a [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree), the selector match list is initially the [shadow
host](https://dom.spec.whatwg.org/#element-shadow-host), followed by all children of the [shadow
tree's] [shadow
root](https://dom.spec.whatwg.org/#concept-shadow-root) and their descendants, ordered by a pre-order
traversal.

Rewrite this against the newer call
forms of the matching algorithms.

 Remember that the
[descendants](https://dom.spec.whatwg.org/#concept-tree-descendant) of an element are based on the [light
tree](https://dom.spec.whatwg.org/#concept-light-tree)
[children](https://dom.spec.whatwg.org/#concept-tree-child) of the element, which does not include the [shadow
trees](https://dom.spec.whatwg.org/#concept-shadow-tree) of the element.

When a selector is [matched against a
tree](https://drafts.csswg.org/selectors-4/#match-a-selector-against-a-tree), its [tree context] is the
[root](https://dom.spec.whatwg.org/#concept-tree-root) of the `root elements` passed to the
algorithm. If the [tree context](#tree-context) is a [shadow
root](https://dom.spec.whatwg.org/#concept-shadow-root), that selector is being matched [in the context of a
shadow tree].

For example, any selector in a
stylesheet embedded in or linked from an element in a [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree) is [in the context of a shadow
tree](#in-the-context-of-a-shadow-tree). So is the argument to
[`querySelector()`](https://dom.spec.whatwg.org/#dom-parentnode-queryselector) when called from a [shadow
root](https://dom.spec.whatwg.org/#concept-shadow-root).

Declarations inherit the [tree
context](#tree-context) of the
selector that was matched to apply them.

Tests

#### 3.2.2. Selecting Shadow Hosts from within a Shadow Tree

A [shadow
host](https://dom.spec.whatwg.org/#element-shadow-host) is outside of the [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree) it hosts, and so would ordinarily be untargettable by
any selectors evaluated [in the context of the shadow
tree](#in-the-context-of-a-shadow-tree) (as selectors are limited to a single tree), but it is
sometimes useful to be able to style it from inside the [shadow
tree] context.

For the purpose of Selectors, a [shadow
host](https://dom.spec.whatwg.org/#element-shadow-host) also appears in its [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree), with the contents of the [shadow
tree] treated as its children. (In other
words, the [shadow host] is treated as
replacing the [shadow
root](https://dom.spec.whatwg.org/#concept-shadow-root) node.)

When considered within its own [shadow
trees](https://dom.spec.whatwg.org/#concept-shadow-tree), the [shadow
host](https://dom.spec.whatwg.org/#element-shadow-host) is
[featureless](https://drafts.csswg.org/selectors-4/#featureless). Only the
[:host](#selectordef-host),
[:host()](#selectordef-host-function), and
[:host-context()](#selectordef-host-context) pseudo-classes are allowed to match it.

Tests

Why is the shadow host so weird?

The [shadow
host](https://dom.spec.whatwg.org/#element-shadow-host) lives outside the [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree), and its markup is in control of the page author, not
the component author.

It would not be very good if a component used a particular class name
internally in a [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree) stylesheet, and the page author using the component
accidentally *also* used the same class name and put it on the [shadow
host](https://dom.spec.whatwg.org/#element-shadow-host). Such a situation would result in accidental styling
that is impossible for the component author to predict, and confusing
for the page author to debug.

However, there are still some reasonable use-cases for letting a
stylesheet in a [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree) style its [shadow
host](https://dom.spec.whatwg.org/#element-shadow-host). (For example, the component might want to be laid out
as a flexbox, requiring the [shadow
host] to be set to [display:
flex](https://drafts.csswg.org/css-display-4/#propdef-display).) So, to allow this situation but prevent
accidental styling, the [shadow host]
appears but is completely featureless and unselectable except through
[:host](#selectordef-host) and its related functional forms, which make it very
explicit when you're trying to match against markup provided by the page
author.

Tests

#### 3.2.3. Selecting Into the Light: the [:host, [:host()](#selectordef-host-function), and [:host-context()](#selectordef-host-context) pseudo-classes]
The [:host] pseudo-class, when evaluated [in the context of a shadow
tree](#in-the-context-of-a-shadow-tree), matches the [shadow
tree's](https://dom.spec.whatwg.org/#concept-shadow-tree) [shadow
host](https://dom.spec.whatwg.org/#element-shadow-host). In any other context, it matches nothing.

The [:host()] function pseudo-class has the syntax:

 :host( <compound-selector> )

When evaluated [in the context of a shadow
tree](#in-the-context-of-a-shadow-tree), it matches the [shadow
tree's](https://dom.spec.whatwg.org/#concept-shadow-tree) [shadow
host](https://dom.spec.whatwg.org/#element-shadow-host) if the [shadow host],
in its normal context, matches the selector argument. In any other
context, it matches nothing.

The
[specificity](https://drafts.csswg.org/selectors-4/#specificity) of
[:host](#selectordef-host) is that of a pseudo-class. The
[specificity] of
[:host()](#selectordef-host-function) is that of a pseudo-class, plus the
[specificity] of its argument.

 This is different from the specificity of similar
pseudo-classes, like
[:is()](https://drafts.csswg.org/selectors-4/#matches-pseudo) or
[:not()](https://drafts.csswg.org/selectors-4/#negation-pseudo), which *only* take the specificity of their
argument. This is because
[:host](#selectordef-host) is affirmatively selecting an element all by itself,
like a \"normal\" pseudo-class; it takes a selector argument for
syntactic reasons (we can't say that [:host.foo] matches but
[.foo] doesn't), but is otherwise identical to just using
[:host] followed by a selector.

For example, say you had a component
with a [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree) like the following:

 <x-foo class="foo">
 <"shadow tree">
 <div class="foo">...</div>
 </>
 </x-foo>

For a stylesheet within the [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree):

- [:host](#selectordef-host) matches the `<x-foo>` element.

- [x-foo] matches nothing.

- [.foo] matches only the `<div>` element.

- [.foo:host] matches nothing

- [:host(.foo)] matches the `<x-foo>` element.

Ordinary, selectors within a [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree) can't see elements outside the [shadow
tree] at all. Sometimes, however, it's
useful to select an ancestor that lies somewhere outside the shadow
tree, above it in the document.

For example, a group of components can
define a handful of color themes they know how to respond to. Page
authors could opt into a particular theme by adding a specific class to
the components, or higher up in the document.

The [:host-context()] functional pseudo-class tests whether
there is an ancestor, outside the [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree), which matches a particular selector. Its syntax is:

``` prod
:host-context( <compound-selector> )
```

When evaluated [in the context of a shadow
tree](#in-the-context-of-a-shadow-tree), the
[:host-context()](#selectordef-host-context) pseudo-class matches the [shadow
host](https://dom.spec.whatwg.org/#element-shadow-host), if the [shadow host]
or one of its [shadow-including
ancestors](https://dom.spec.whatwg.org/#concept-shadow-including-ancestor) matches the provided
[\<compound-selector\>](https://drafts.csswg.org/selectors-4/#typedef-compound-selector). In any other context, it matches
nothing.

The
[specificity](https://drafts.csswg.org/selectors-4/#specificity) of
[:host-context()](#selectordef-host-context) is that of a pseudo-class, plus the
[specificity] of its argument.

 This means that the selector pierces through shadow
boundaries on the way up, looking for elements that match its argument,
until it reaches the document root.

Tests

#### 3.2.4. Selecting Slot-Assigned Content: the [::slotted() pseudo-element]
The [::slotted()] pseudo-element represents the elements
[assigned, after
flattening,](https://dom.spec.whatwg.org/#find-flattened-slotables) to a
[slot](https://dom.spec.whatwg.org/#concept-slot). This pseudo-element only exists on
[slots].

The [::slotted()](#selectordef-slotted) pseudo-element is an *alias* for other elements
in the tree, and does not generate any boxes itself.

The grammar of the
[::slotted()](#selectordef-slotted) pseudo-element is:

``` prod
::slotted( <compound-selector> )
```

The [::slotted()](#selectordef-slotted) pseudo-element represents the elements that are:

- [assigned, after
 flattening,](https://dom.spec.whatwg.org/#find-flattened-slotables) to the
 [slot](https://dom.spec.whatwg.org/#concept-slot) that is [::slotted]'s originating element

- [matched](https://drafts.csswg.org/selectors-4/#match-a-selector-against-an-element) by its
 [\<compound-selector\>](https://drafts.csswg.org/selectors-4/#typedef-compound-selector) argument

Tests

The [::slotted()](#selectordef-slotted) pseudo-element can be followed by a
[tree-abiding
pseudo-element](https://drafts.csswg.org/css-pseudo-4/#tree-abiding), like [::slotted()::before], representing the
appropriate pseudo-element of the elements represented by the
[::slotted()] pseudo-element.

Tests

The
[specificity](https://drafts.csswg.org/selectors-4/#specificity) of
[::slotted()](#selectordef-slotted) is that of a pseudo-element, plus the
[specificity] of its argument.

For example, say you had a component
with both children and a shadow tree, like the following:

 <x-foo>
 <div id="one" slot="foo" class="foo">...</div>
 <div id="two" slot="foo">...</div>
 <div id="three" class="foo">
 <div id="four" slot="foo">...</div>
 </div>
 <"shadow tree">
 <div id="five">...</div>
 <div id="six">...</div>
 <slot name="foo"></slot>
 </"shadow tree">
 </x-foo>

For a stylesheet within the [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree), a selector like [::slotted(\*)] selects
[#one] and [#two] only, as they're the elements
[assigned](https://dom.spec.whatwg.org/#find-flattened-slotables) to the sole
[`slot`](https://html.spec.whatwg.org/multipage/scripting.html#the-slot-element) element. It will *not* select [#three] (no
`slot` attribute) nor [#four] (only direct
[children](https://dom.spec.whatwg.org/#concept-tree-child) of a [shadow
host](https://dom.spec.whatwg.org/#element-shadow-host) can be assigned to a
[slot](https://dom.spec.whatwg.org/#concept-slot)).

A selector like [::slotted(.foo)], on the other hand, will only
select [#one], as it matches [.foo], but [#two]
doesn't.

 Note that a selector like [::slotted(\*)] is
equivalent to [\*::slotted(\*)], where the
[\*](https://drafts.csswg.org/selectors-3/#x) selects many more elements than just the
[`slot`](https://html.spec.whatwg.org/multipage/scripting.html#the-slot-element) element. However, since only the
[`slot`](https://html.spec.whatwg.org/multipage/scripting.html#the-slot-element) elements are
[slots](https://dom.spec.whatwg.org/#concept-slot), they're the only elements with a
[::slotted()](#selectordef-slotted) pseudo-element as well.

[::slotted()](#selectordef-slotted) can only represent the *elements* assigned to the
[slot](https://dom.spec.whatwg.org/#concept-slot). [Slots] can also be assigned
text nodes, which can't be selected by
[::slotted()]. The only way to style
assigned text nodes is by styling the [slot]
and relying on inheritance.

Tests

#### 3.2.5. Matching on the Presence of Slot-Assigned Nodes: the [:has-slotted pseudo-class]
The [:has-slotted] pseudo-class matches
[`slot`](https://html.spec.whatwg.org/multipage/scripting.html#the-slot-element) elements which have a non-empty list of [flattened
slotted
nodes](https://dom.spec.whatwg.org/#find-flattened-slotables).

When
[:has-slotted](#selectordef-has-slotted) matches a slot with fallback content, we can
conclude that the fallback content is *not* being displayed.

 Even a single whitespace text node is sufficient to
make
[:has-slotted](#selectordef-has-slotted)\' apply. This is by design, so that the behavior
of this pseudo-class is consistent with the behavior of the
[`assignedNodes()`](https://html.spec.whatwg.org/multipage/scripting.html#dom-slot-assignednodes) method. A future version of this specification is
expected to introduce a way to exclude this case from matching.

 It is expected that a future version of this
specification will introduce a functional [:has-slotted()]
pseudo-class that allows more fine-grained matching by accepting a
selector argument.
[:has-slotted](#selectordef-has-slotted) is *not* an alias of [:has-slotted(\*)],
as the latter would not match slotted text nodes, but
[:has-slotted] does.

Tests

## 4. Shadow Trees and the Cascade

See [CSS Cascading 4 § 6.1 Cascade Sorting
Order](https://drafts.csswg.org/css-cascade-4/#cascade-sort).

Tests

### 4.1. Flattening the DOM into an Element Tree

While Selectors operates on the DOM tree as the host language presents
it, with separate trees that are unreachable via the standard
parent/[child](https://dom.spec.whatwg.org/#concept-tree-child) relationship, the rest of CSS needs a single unified
tree structure to work with. This is called the [flattened element
tree] (or [flat
tree](#flat-tree)), and is
constructed as follows:

1. Let `pending nodes` be a list of DOM nodes with
 associated parents, initially containing just the document's
 [root](https://dom.spec.whatwg.org/#concept-tree-root) element with no associated parent.

2. Repeatedly execute the following substeps until
 `pending nodes` is empty:

 1. Pop the first element from `pending nodes`, and
 assign it to `pending node`.

 2. Insert `pending node` into the [flat
 tree](#flat-tree) as a
 child of its associated parent. (If it has no associated parent,
 it's the document root---​just insert it into the [flat
 tree] as its root.)

 3. Perform one of the following, whichever is the first that
 matches:

 `pending node` is a [shadow host](https://dom.spec.whatwg.org/#element-shadow-host)
 : Append the child nodes of the [shadow
 root](https://dom.spec.whatwg.org/#concept-shadow-root) of the [shadow
 tree](https://dom.spec.whatwg.org/#concept-shadow-tree) it hosts to `pending nodes`,
 with `pending node` as their associated parent.

 `pending node` is a [slot](https://dom.spec.whatwg.org/#concept-slot)

 : [Find
 slottables](https://dom.spec.whatwg.org/#find-slotables) for `pending node`, and append
 them to `pending nodes`, with
 `pending node` as their associated parent.

 If no
 [slottables](https://dom.spec.whatwg.org/#concept-slotable) were found for `pending node`,
 instead append its
 [children](https://dom.spec.whatwg.org/#concept-tree-child) to `pending nodes`, with
 `pending node` as their associated parent.

 Otherwise,
 : Append the child nodes of `pending node`'s [light
 tree](https://dom.spec.whatwg.org/#concept-light-tree) to `pending nodes`, with
 `pending node` as their associated parent.

 In other words, the [flat
tree](#flat-tree) is the top-level
DOM tree, but [shadow
hosts](https://dom.spec.whatwg.org/#element-shadow-host) are filled with their [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree) children instead of their [light
tree](https://dom.spec.whatwg.org/#concept-light-tree) children (and this proceeds recursively if the [shadow
tree] contains any [shadow
hosts]), and
[slots](https://dom.spec.whatwg.org/#concept-slot) get filled with the nodes that are assigned to them
(and this proceeds recursively if the [slots]
are themselves assigned to a [slot] in a deeper
[shadow tree]).

A non-obvious result of this is that
elements assigned to a slot inherit from that slot, not their light-tree
parent or any deeper slots their slot gets assigned to. This means that
text nodes are styled by the shadow tree of their parent, with nobody
else capable of intervening in any way. Do we want an additional
pseudo-element for targeting those text nodes so they can be styled at
all slot-assignment levels, like normal elements can be? This implies it
needs to work for text nodes in the light tree before they're assigned
downwards, so this can't just be a
[::slotted()](#selectordef-slotted) variant. Luckily, this is a long-standing request!

#### 4.1.1. Slots and Slotted Elements in a Shadow Tree

[Slots](https://dom.spec.whatwg.org/#concept-slot) must act as if they were assigned [display:
contents](https://drafts.csswg.org/css-display-4/#propdef-display) via a rule in the [UA
origin](https://drafts.csswg.org/css-cascade-5/#cascade-origin-ua). This must be possible to override via
[display], so they *do* generate
boxes if desired.

 A non-obvious result of assigning elements to
[slots](https://dom.spec.whatwg.org/#concept-slot) is that they [inherit] from the
[slot] they're assigned to. Their original
[light
tree](https://dom.spec.whatwg.org/#concept-light-tree) parent, and any deeper [slots]
that their [slot] gets assigned to, don't
affect inheritance.

Tests

### 4.2. Name-Defining Constructs and Inheritance

[Shadow
trees](https://dom.spec.whatwg.org/#concept-shadow-tree) are meant to be an encapsulation boundary, allowing
independent authors to share code without accidentally polluting each
other's namespaces. For example, element IDs, which are generally meant
to be unique within a document, can be validly used multiple times as
long as each use is in a different [shadow
tree].

Similarly, several
[at-rules](https://drafts.csswg.org/css-syntax-3/#at-rule) in CSS, such as
[\@keyframes](https://drafts.csswg.org/css-animations-1/#at-ruledef-keyframes) or
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule), define a name that later at-rules or properties
can refer to them by. Like IDs, these names are globally exposed and
unique within a document; also like IDs, this restriction is now
loosened to being unique within a given [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree).

However, property inheritance can carry values from one tree to another,
which complicates referencing the correct definition of a given name.
Done naively, this can produce surprising and confusing results for
authors. This section defines a set of concepts to use in defining and
referencing \"global\" names in a way that respects encapsulation and
doesn't give surprising results.

If an at-rule or property defines a name that other CSS constructs can
refer to it by, such as a
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule)
[font-family](https://drafts.csswg.org/css-fonts-4/#descdef-font-face-font-family) name or an
[anchor-scope](https://drafts.csswg.org/css-anchor-position-1/#propdef-anchor-scope) name, it must be defined as a
[tree-scoped name]. [Tree-scoped
names](#css-tree-scoped-name) are associated with the
[root](https://dom.spec.whatwg.org/#concept-tree-root) of the
[element](https://dom.spec.whatwg.org/#concept-element) hosting the stylesheet that the at-rule or property is
declared in.

Additionally, [tree-scoped
names](#css-tree-scoped-name) can be [loosely
matched] or [strictly
matched], defaulting to
[loosely
matched](#tree-scoped-name-loosely-matched) unless otherwise specified. A [loosely
matched] [tree-scoped
name] can be matched by [tree-scoped
references](#css-tree-scoped-reference) (see below) in the same tree or descendant trees, while
a [strictly
matched](#tree-scoped-name-strictly-matched) [tree-scoped name] can
only be matched by [tree-scoped
references] in the exact same tree.

Properties or descriptors that reference a [tree-scoped
name](#css-tree-scoped-name), such as the
[font-family](https://drafts.csswg.org/css-fonts-4/#propdef-font-family) or
[animation-name](https://drafts.csswg.org/css-animations-1/#propdef-animation-name) properties, must define their value
as a [tree-scoped reference]. These references
implicitly capture a [node
tree](https://dom.spec.whatwg.org/#concept-node-tree)
[root](https://dom.spec.whatwg.org/#concept-tree-root) along with their specified value: unless otherwise
specified, the [root] of the
[element](https://dom.spec.whatwg.org/#concept-element) hosting the stylesheet that the property or descriptor
is declared in. This [root] reference stays
with the [tree-scoped
reference](#css-tree-scoped-reference) as it is inherited.

Tests

If a [tree-scoped
name](#css-tree-scoped-name) is [global] (such as
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) names), then when a [tree-scoped
reference](#css-tree-scoped-reference) is dereferenced to find it, first search only the
[tree-scoped names] associated with the
same
[root](https://dom.spec.whatwg.org/#concept-tree-root) as the [tree-scoped
reference]. If no relevant
[tree-scoped name] is found, and the
[root] is a [shadow
root](https://dom.spec.whatwg.org/#concept-shadow-root), then repeat this search in the
[root]'s
[host](https://dom.spec.whatwg.org/#concept-documentfragment-host)'s [node
tree](https://dom.spec.whatwg.org/#concept-node-tree) (recursively). (In other words, global [tree-scoped
names] "inherit" into descendant shadow
trees, so long as they don't define the same name themselves.)

If a [tree-scoped
name](#css-tree-scoped-name) is [local] to an element (such
as
[anchor-name](https://drafts.csswg.org/css-anchor-position-1/#propdef-anchor-name) or
[anchor-scope](https://drafts.csswg.org/css-anchor-position-1/#propdef-anchor-scope) values), then whether a
[tree-scoped
reference](#css-tree-scoped-reference) matches the [tree-scoped
name] on a given element depends on
whether the [tree-scoped name] is
[strictly](#tree-scoped-name-strictly-matched) or
[loosely](#tree-scoped-name-loosely-matched) matched. A [strictly
matched] [tree-scoped
name] only matches if both names are
associated with the same tree. A [loosely
matched] [tree-scoped
name] also matches if the [tree-scoped
name] is associated with an ancestor
tree.

If two [tree-scoped
names](#css-tree-scoped-name) are directly compared (for example, when comparing
[computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value)), they are considered to match only if their
identifiers match, *and* their
[root](https://dom.spec.whatwg.org/#concept-tree-root)s match exactly. (If one has a
[root] that's an ancestor of the other,
for example, they *do not* match.)

TODO: Fix all the at-rules that define
global names, and the properties that reference them, to use these
concepts.

Global names include:

- [\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule), referenced by
 [font-family](https://drafts.csswg.org/css-fonts-4/#propdef-font-family)

- [\@font-feature-values](https://drafts.csswg.org/css-fonts-4/#at-ruledef-font-feature-values), referenced by
 [font-family](https://drafts.csswg.org/css-fonts-4/#propdef-font-family)

- [\@keyframes](https://drafts.csswg.org/css-animations-1/#at-ruledef-keyframes), referenced by
 [animation-name](https://drafts.csswg.org/css-animations-1/#propdef-animation-name)

- [\@counter-style](https://drafts.csswg.org/css-counter-styles-3/#at-ruledef-counter-style), referenced by
 [list-style-type](https://drafts.csswg.org/css-lists-3/#propdef-list-style-type)

- [\@color-profile](https://drafts.csswg.org/css-color-5/#at-ruledef-profile), referenced by the
 [color()](https://drafts.csswg.org/css-color-5/#funcdef-color) function

- [\@font-palette-values](https://drafts.csswg.org/css-fonts-4/#at-ruledef-font-palette-values), referenced by
 [font-palette](https://drafts.csswg.org/css-fonts-4/#propdef-font-palette)

- others?

For example, given the following document (using the imaginary
\<::shadow\>\</::shadow\> markup to indicate an element's [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree)):

``` highlight
<p class=outer>Here's some text in the outer document's "foo" font.
<style>
 @font-face {
 font-family: foo;
 src: url(https://example.com/outer.woff);
 }
 body { font-family: foo; }
 my-component::part(text) { font-family: foo; }
</style>

<my-component>
 <::shadow>
 <p class=inner-default>I'm inheriting the outer document's font-family.
 <p class=inner-styled>And I'm explicitly styled to be in the component's "foo" font.
 <p class=part-styled part=text>
 I'm explicitly styled by the outer document,
 and get the outer document's "foo" font.
 <style>
 @font-face {
 font-family: foo;
 src: url(https://example.com/inner.woff);
 }
 .inner-styled { font-family: foo; }
 </style>
 </::shadow>
</my-component>
```

The [.outer] element references the outer
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule), using the \"outer.woff\" file.

The [.inner-default] element inherits the [font-family:
foo](https://drafts.csswg.org/css-fonts-4/#propdef-font-family) value from the outer document, using the same
[tree-scoped
reference](#css-tree-scoped-reference) as [.outer], and thus also uses the
\"outer.woff\" font file.

The [.inner-style] element, on the other hand, receives a
[font-family:
foo](https://drafts.csswg.org/css-fonts-4/#propdef-font-family) from the stylesheet inside the shadow, and
thus its [tree-scoped
reference](#css-tree-scoped-reference) refers to the shadow's [\@font-family], and it
uses the \"inner.woff\" file.

The [.part-styled] element also receives its style from the outer
document, tho by being directly set rather than by inheritance. Thus,
its [tree-scoped
reference](#css-tree-scoped-reference) also refer's to the outer document, and it uses the
\"outer.woff\" file.

Here is a more complex example,
showing three levels of trees, and illustrating precisely how
[tree-scoped
names](#css-tree-scoped-name) and [tree-scoped
references](#css-tree-scoped-reference) inherit.

``` highlight
<style>
 @font-face {
 font-family: foo;
 src: url(https://example.com/outer.woff);
 }
 body { font-family: foo; }
</style>

<child-component>
 <::shadow>
 <style>
 @font-face {
 font-family: foo;
 src: url(https://example.com/inner.woff);
 }
 </style>

 <grandchild-component>
 <::shadow>
 <p class=inner-default>
 I'm inheriting the outer document's "foo" font.
 </p>
 <p class=inner-search>
 And I can't find a local "foo" font,
 so I'm searching further up the tree,
 and find the shadow's "foo" font.
 </p>
 <style>
 .inner-search { font-family: foo; }
 </style>
 </::shadow>
 </grandchild-component>
 </::shadow>
</child-component>
```

Here, just as in the previous example, [.inner-default] is
inheriting the [font-family:
foo](https://drafts.csswg.org/css-fonts-4/#propdef-font-family) declared in the outer document, and so it
ends up referencing the outer document's
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule), and is rendered with the \"outer.woff\" file.

On the other hand, [.inner-search] receives its style from a
stylesheet in `<grandchild-component>`'s shadow tree, so it attempts to
find a
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) defining a [foo] font in that tree. There
is no such [\@font-face], so it starts
walking up the shadow trees, finding an appropriate
[\@font-face] in `<child-component>`,
so it's rendered with the \"inner.woff\" file.

#### 4.2.1. Serialized Tree-Scoped References

If a [tree-scoped
reference](#css-tree-scoped-reference) is serialized, it serializes only its value; the
associated
[root](https://dom.spec.whatwg.org/#concept-tree-root) is lost.

This implies that \`el.style.foo = getComputedStyle(el).foo;\` is not
necessarily a no-op, like it typically was before [shadow
trees](https://dom.spec.whatwg.org/#concept-shadow-tree) existed.

For example, given the following document (using the imaginary
\<::shadow\>\</::shadow\> markup to indicate an element's [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree)):

``` highlight
<p class=outer>Here's some text in the outer document's "foo" font.
<style>
 @font-face {
 font-family: foo;
 src: url(foo.woff);
 }
 body { font-family: foo; }
</style>

<my-component>
 <::shadow>
 <p class=inner-default>I'm inheriting the outer document's font-family.
 <p class=inner-styled>And I'm explicitly styled to be in the component's "foo" font.
 <style>
 @font-face {
 font-family: foo;
 src: url(https://example.com/foo.woff);
 }
 .inner-styled { font-family: foo; }
 </style>
 <script>
 const innerDefault = document.querySelector('.inner-default');
 const innerStyled = document.querySelector('.inner-styled');
 const defaultFont = getComputedStyle(innerDefault).fontFamily;
 const styledFont = getComputedStyle(innerStyled).fontFamily;

 console.log(defaultFont == styledFont); // true!
 </script>
 </::shadow>
</my-component>
```

The `.outer` element is styled with the outer document's \"foo\"
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule). The `.inner-default` element inherits
[font-family](https://drafts.csswg.org/css-fonts-4/#propdef-font-family) from the outer document, meaning it
inherits a [tree-scoped
reference](#css-tree-scoped-reference) referencing that outer document, and so it's in the
same font as `.outer`.

Meanwhile, `.inner-styled` is explicitly styled from inside the shadow
root, so it receives a fresh [tree-scoped
reference](#css-tree-scoped-reference) referencing its shadow tree, and it is instead styled
the shadow's own \"foo\"
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule).

Despite that, the script running inside the component sees the two
elements as having the same value for
[font-family](https://drafts.csswg.org/css-fonts-4/#propdef-font-family), because the
[root](https://dom.spec.whatwg.org/#concept-tree-root)-reference part of a [tree-scoped
reference](#css-tree-scoped-reference) is not preserved by serialization. If it were to set
`innerDefault.style.fontFamily = defaultFont;` (thus setting
the [font-family] property of
the element's attribute stylesheet, which lives in the shadow tree), the
`.inner-default` element would suddenly switch to the same font as
`.inner-styled`!

[\[css-typed-om-1\]](#biblio-css-typed-om-1 "CSS Typed OM Level 1")
is expected to reflect the
[root](https://dom.spec.whatwg.org/#concept-tree-root) reference of a [tree-scoped
reference](#css-tree-scoped-reference) in its
[reification](https://drafts.css-houdini.org/css-typed-om-1/#css-reify) rules for values, allowing authors to tell what [node
tree](https://dom.spec.whatwg.org/#concept-node-tree) the reference is taking its values from, and allowing
values to be transported across [node
trees] without changing their meaning.

## 5. Exposing a Shadow Element

Elements in a [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree) may be exported for styling by stylesheets outside the
tree using the part and exportparts attributes.

Each element has a [part name list] which is an
[ordered
set](https://infra.spec.whatwg.org/#ordered-set) of tokens.

Each element has a [forwarded part name
list] which is a
[list](https://infra.spec.whatwg.org/#list) of
[tuples](https://infra.spec.whatwg.org/#tuple) containing a
[string](https://infra.spec.whatwg.org/#string) for the inner part being forwarded and a
[string] giving the name it will be exposed as.

Each [shadow
root](https://dom.spec.whatwg.org/#concept-shadow-root) can be thought of as having a [part element
map] with keys that are
[strings](https://infra.spec.whatwg.org/#string) and values that are [ordered
sets](https://infra.spec.whatwg.org/#ordered-set) of elements.

The [part element
map](#shadow-root-part-element-map) is described only as part of the algorithm for
calculating style in this spec. It is not exposed via the DOM, as
calculating it may be expensive and exposing it could allow access to
elements inside closed shadow roots.

[Part element
maps](#shadow-root-part-element-map) are affected by the addition and removal of elements
and changes to the [part name
lists](#element-part-name-list) and [forwarded part name
lists](#element-forwarded-part-name-list) of elements in the DOM.

To [calculate the [part element
map](#shadow-root-part-element-map)] of a shadow root, `outerRoot`:

1. For each
 [descendant](https://dom.spec.whatwg.org/#concept-tree-descendant) `el` within `outerRoot`:

 1. For each `name` in `el`'s [part name
 list](#element-part-name-list),
 [append](https://infra.spec.whatwg.org/#list-append) `el` to `outerRoot`'s
 [part element
 map](#shadow-root-part-element-map)\[`name`\].

 2. If `el` is a [shadow
 host](https://dom.spec.whatwg.org/#element-shadow-host) itself then let `innerRoot` be its
 shadow root.

 3. [Calculate](#calculate-the-part-element-map) `innerRoot`'s [part element
 map](#shadow-root-part-element-map).

 4. For each `innerName`/`outerName` in
 `el`'s [forwarded part name
 list](#element-forwarded-part-name-list):

 1. If `innerName` is an ident:

 1. Let `innerParts` be `innerRoot`'s
 [part element
 map](#shadow-root-part-element-map)\[`innerName`\]

 2. [Append](https://infra.spec.whatwg.org/#list-append) the elements in `innerParts`
 to `outerRoot`'s [part element
 map](#shadow-root-part-element-map)\[`outerName`\]

 2. If `innerName` is a pseudo-element name:

 1. [Append](https://infra.spec.whatwg.org/#list-append) `innerRoot`'s
 pseudo-element(s) with that name to
 `outerRoot`'s [part element
 map](#shadow-root-part-element-map)\[`outerName`\].

### 5.1. Motivation

For custom elements to be fully useful and as capable as built-in
elements it should be possible for parts of them to be styled from
outside. Exactly what can be styled from outside should be controlled by
the element author. Also, it should be possible for a custom element to
present a stable \"API\" for styling. That is, the selector used to
style a part of a custom element should not expose or require knowledge
of the internal details of the element. The custom element author should
be able to change the internal details of the element while leaving the
selectors untouched.

The previous proposed method for styling inside the shadow tree, the
\>\>\> combinator, turned out to be *too powerful* for its own good; it
exposed too much of a component's internal structure to scrutiny,
defeating some of the encapsulation benefits that using Shadow DOM
brings. For this, and other performance-related reasons, the \>\>\>
combinator was eventually dropped.

This left us with using [custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property) as the only way to style into a shadow tree: the
component would advertise that it uses certain [custom
properties] to style its internals, and the
outer page could then set those properties as it wished on the [shadow
host](https://dom.spec.whatwg.org/#element-shadow-host), letting inheritance push the values down to where they
were needed. This works very well for many simple theming use-cases.

However, there are some cases where this falls down. If a component
wishes to allow arbitrary styling of something in its shadow tree, the
only way to do so is to define hundreds of [custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property) (one per CSS property they wish to allow control of),
which is obviously ridiculous for both usability and performance
reasons. The situation is compounded if authors wish to style the
component differently based on pseudo-classes like
[:hover](https://drafts.csswg.org/selectors-4/#hover-pseudo); the component needs to duplicate the [custom
properties] used for each pseudo-class (and
each combination, like [:hover:focus], resulting in a
combinatorial explosion). This makes the usability and performance
problems even worse.

We introduce [::part()](#selectordef-part) to handle this case much more elegantly and
performantly. Rather than bundling everything into [custom
property](https://drafts.csswg.org/css-variables-2/#custom-property) names, the functionality lives in selectors and style
rule syntax, like it's meant to. This is far more usable for both
component authors and component users, should have much better
performance, and allows for better encapsulation/API surface.

It's important to note that
[::part()](#selectordef-part) offers *absolutely zero new theoretical power*. It is
not a rehash of the [\>\>\>] combinator, it is simply a more
convenient and consistent syntax for something authors can already do
with [custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property). By separating out the explicitly \"published\" parts
of an element (the [part element
map](#shadow-root-part-element-map)) from the sub-parts that it merely happens to contain,
it also helps with encapsulation, as authors can use
[::part()] without fear of accidental
over-styling.

### 5.2. Naming a Shadow Element: the [`part` attribute]
Any element in a shadow tree can have a
[`part`] attribute. This
is used to expose the element outside of the [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree).

Tests

The part attribute is parsed as a space-separated list of tokens
representing the part names of this element.

 It's okay to give a part multiple names. The \"part
name\" should be considered similar to a class, not an id or tagname.

```
<style>
 c-e::part(textspan) { color: red; }
</style>

<template id="c-e-template">
 <span part="textspan">This text will be red</span>
</template>
<c-e></c-e>
<script>
 // Add template as custom element c-e
 ...
</script>
```

### 5.3. Forwarding a Shadow Element: the [`exportparts` attribute]
Any element in a shadow tree can have a
[`exportparts`]
attribute. If the element is a shadow host, this is used to allow
styling of parts from hosts inside the [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree) by rules outside this the [shadow
tree] (as if they were elements in the
same tree as the host, named by a part attribute).

Tests

The exportparts attribute is parsed as a comma-separated list of part
mappings. Each part mapping is one of:

`innerIdent : outerIdent`

: Adds `innerIdent`/`outerIdent` to el's [forwarded part name
 list](#element-forwarded-part-name-list).

`ident`

: Adds `ident`/`ident` to el's [forwarded part name
 list](#element-forwarded-part-name-list).

 This is shorthand for `ident : ident`.

`::ident : outerIdent`

: If `::ident` is the name of a [fully styleable
 pseudo-element](https://drafts.csswg.org/css-pseudo-4/#fully-styleable), adds `::ident`/`outerIdent` to el's [forward part
 name
 list](#element-forwarded-part-name-list). Otherwise, does nothing.

anything else

: Ignored for error-recovery / future compatibility.

 It's okay to map a sub-part to several names.

```
<style>
 c-e::part(textspan) { color: red; }
</style>

<template id="c-e-outer-template">
 <c-e-inner exportparts="innerspan: textspan"></c-e-inner>
</template>

<template id="c-e-inner-template">
 <span part="innerspan">
 This text will be red because the containing shadow
 host forwards innerspan to the document as "textspan"
 and the document style matches it.
 </span>
 <span part="textspan">
 This text will not be red because textspan in the document style
 cannot match against the part inside the inner custom element
 if it is not forwarded.
 </span>
</template>

<c-e></c-e>
<script>
 // Add template as custom elements c-e-inner, c-e-outer
 ...
</script>
```

For example, a [fully styleable
pseudo-element](https://drafts.csswg.org/css-pseudo-4/#fully-styleable) can be used in the
[`exportparts`](#element-attrdef-html-global-exportparts) attribute, to masquerade as a
[::part()](#selectordef-part) for the component it's in:

``` html
<template id=custom-element-template>
 <p exportparts="::before : preceding-text, ::after : following-text">
 Main text.
</template>
```

An element using that template can use a selector like
[x-component::part(preceding-text)] to target the
[p::before] pseudo-element in its shadow, so users of the
component don't need to know that the preceding text is implemented as a
pseudo-element.

### 5.4. Selecting a Shadow Element: the [::part() pseudo-element]
The [::part()] pseudo-element allows you to select
elements that have been exposed via a
[`part`](#element-attrdef-html-global-part) attribute. The syntax is:

``` prod
::part() = ::part( <ident>+ )
```

Tests

The [::part()](#selectordef-part) pseudo-element only matches anything when the
[originating
element](https://drafts.csswg.org/selectors-4/#originating-element) is a [shadow
host](https://dom.spec.whatwg.org/#element-shadow-host).

For example, if you have a custom
button that contains a \"label\" element that is exposed for styling
(via `part="label"`), you can select it with
[x-button::part(label)].

Part names act similarly to classes:
multiple elements can have the same part name, and a single element can
have multiple part names.

A tabstrip control might have multiple elements with `part="tab"`, all
of which are selected by [::part(tab)].

If a single tab is active at a time, it can be specially indicated with
`part="tab active"` and then selected by [::part(tab active)] (or
[::part(active tab)], as order doesn't matter).

The [::part()](#selectordef-part) pseudo-element is a [fully styleable
pseudo-element](https://drafts.csswg.org/css-pseudo-4/#fully-styleable). If the [originating
element's](https://drafts.csswg.org/selectors-4/#originating-element) [shadow
root's](https://dom.spec.whatwg.org/#concept-shadow-root) [part element
map](#shadow-root-part-element-map)
[contains](https://infra.spec.whatwg.org/#map-exists) the specified
[\<ident\>](https://drafts.csswg.org/css-values-4/#typedef-ident),
[::part()] represents the elements
keyed to that ident; if multiple idents are provided and the [part
element map] contains them all,
it represents the intersection of the elements keyed to each ident.
Otherwise, it matches nothing.

[::part()](#selectordef-part) pseudo-elements inherit according to their position
in the [originating
element's](https://drafts.csswg.org/selectors-4/#originating-element) shadow tree.

For example,
[x-panel::part(confirm-button)::part(label)] never matches
anything. This is because doing so would expose more structural
information than is intended.

If the `<x-panel>`'s internal confirm button had used something like
`part="label => confirm-label"` to forward the button's internal parts
up into the panel's own [part element
map](#shadow-root-part-element-map), then a selector like
[x-panel::part(confirm-label)] would select just the one button's
label, ignoring any other labels.

### [5.5. ][Extensions to the [`Element`](https://dom.spec.whatwg.org/#element) Interface]
```
partial interface Element {
 [SameObject, PutForwards=value] readonly attribute DOMTokenList part;
};
```

Tests

The part attribute's getter must return a DOMTokenList object whose
associated element is the context object and whose associated
attribute's local name is part. The token set of this particular
DOMTokenList object are also known as the element's parts.

Define this as a superglobal in the DOM
spec. [\[w3c/csswg-drafts Issue
#3424\]](https://github.com/w3c/csswg-drafts/issues/3424)

### 5.6. Microsyntaxes for parsing

#### 5.6.1. Rules for parsing part mappings

A [valid part mapping] is a
[tuple](https://infra.spec.whatwg.org/#tuple) of tokens separated by a U+003A COLON character and any
number of space characters before or after the U+003A COLON The tokens
must not contain U+003A COLON or U+002C COMMA characters.

The rules for parsing a part mapping are as follows:

1. Let `input` be the string being parsed.

2. Let `position` be a pointer into `input`,
 initially pointing at the start of the string.

3. [Collect a sequence of code
 points](https://infra.spec.whatwg.org/#collect-a-sequence-of-code-points) that are space characters

4. [Collect a sequence of code
 points](https://infra.spec.whatwg.org/#collect-a-sequence-of-code-points) that are not space characters or U+003A COLON
 characters, and let `first token` be the result.

5. If `first token` is empty then return error.

6. [Collect a sequence of code
 points](https://infra.spec.whatwg.org/#collect-a-sequence-of-code-points) that are space characters.

7. If the end of the `input` has been reached, return the
 [tuple](https://infra.spec.whatwg.org/#tuple) (`first token`,
 `first token`)

8. If character at `position` is not a U+003A COLON
 character, return error.

9. Consume the U+003A COLON character.

10. [Collect a sequence of code
 points](https://infra.spec.whatwg.org/#collect-a-sequence-of-code-points) that are space characters.

11. [Collect a sequence of code
 points](https://infra.spec.whatwg.org/#collect-a-sequence-of-code-points) that are not space characters or U+003A COLON
 characters. and let `second token` be the result.

12. If `second token` is empty then return error.

13. [Collect a sequence of code
 points](https://infra.spec.whatwg.org/#collect-a-sequence-of-code-points) that are space characters.

14. If `position` is not past the end of `input`
 then return error.

15. Return the
 [tuple](https://infra.spec.whatwg.org/#tuple) (`first token`,
 `second token`).

#### 5.6.2. Rules for parsing a list of part mappings

A [valid list of part mappings] is a number of valid part
mappings separated by a U+002C COMMA character and any number of space
characters before or after the U+002C COMMA

The rules for parsing a list of part mappings are as follow:

1. Let `input` be the string being parsed.

2. [Split the string `input` on
 commas](https://infra.spec.whatwg.org/#split-on-commas). Let `unparsed mappings` be the
 resulting list of strings.

3. Let `mappings` be an initially empty
 [list](https://infra.spec.whatwg.org/#list) of
 [tuples](https://infra.spec.whatwg.org/#tuple) of tokens. This [list] will be the
 result of this algorithm.

4. For each string `unparsed mapping` in
 `unparsed mappings`, run the following substeps:

 1. If `unparsed mapping` is empty or contains only space
 characters, continue to the next iteration of the loop.

 2. Let `mapping` be the result of parsing
 `unparsed mapping` using the rules for parsing part
 mappings.

 3. If `mapping` is an error then continue to the next
 iteration of the loop. This allows clients to skip over new
 syntax that is not understood.

 4. Append `mapping` to `mappings`.

## 6. Changes

The following significant changes were made since the [3 April 2014
Working Draft](https://www.w3.org/TR/2014/WD-css-scoping-1-20140403/).

- Defined that tree-scoped names inherit into descendant shadow trees

- Renamed [::content] to [::slotted].

- Define the flattened tree.

- Generally reorg and rebase the Shadow DOM section on top of current
 DOM.

- Punt [\@scope] and related things, and [::region] and
 related things, to the next level of the draft.

- Define the specificity of
 [:host](#selectordef-host),
 [:host()](#selectordef-host-function),
 [:host-context()](#selectordef-host-context), and
 [::slotted()](#selectordef-slotted)

- Remove the [\>\>\>] (previously called [/deep/])
 combinator.

- Define that tree-abiding pseudos are allowed after
 [::slotted()](#selectordef-slotted).

- Allow
 [\<compound-selector-list\>](https://drafts.csswg.org/selectors-4/#typedef-compound-selector-list) in all the pseudos.

- Define a way to create a stylesheet of default element styles for a
 given element.

- Make featureless elements match nothing.

- Define [in the context of a shadow
 tree](#in-the-context-of-a-shadow-tree).

- Merged
 [\[css-shadow-parts\]](#biblio-css-shadow-parts "CSS Shadow Parts Module Level 1")
 and renamed the specification to CSS Shadow Module Level 1. ([Issue
 #5809](https://github.com/w3c/csswg-drafts/issues/5809#issuecomment-910896765))

- Added support for multiple names in
 [::part()](#selectordef-part)

- Renamed \'part name map\' to [forwarded part name
 list](#element-forwarded-part-name-list)

- Restructured \'part element list\' algorithm

- Moved various
 [::part()](#selectordef-part) details to [fully styleable
 pseudo-element](https://drafts.csswg.org/css-pseudo-4/#fully-styleable)

- Added Web Platform Tests coverage

- Minor editorial improvements

## 7. Privacy Considerations

This specification introduces Shadow DOM and some shadow-piercing
capabilities, but this does not introduce any privacy issues ---​shadow
DOM, as currently specified, is intentionally not a privacy boundary
(and the parts of the UA that use shadow DOM and *do* have a privacy
boundary implicitly rely on protections not yet specified, which protect
them from the things defined in this specification).

## 8. Security Considerations

This specification introduces Shadow DOM and some shadow-piercing
capabilities, but this does not introduce any security issues ---​shadow
DOM, as currently specified, is intentionally not a security boundary,
merely a convenience for page authors. Exposing [shadow
trees](https://dom.spec.whatwg.org/#concept-shadow-tree) to selectors in this way introduces no new security
considerations. (And the parts of the UA that use shadow DOM and *do*
have a security boundary implicitly rely on protections not yet
specified, which protect them from the things defined in this
specification).
