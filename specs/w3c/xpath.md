
\[[**[p]**revious](copyright-notice.html "W3C Copyright Notices and Licenses"){accesskey="p"}\]
 
\[[**[n]**ext](idl-definitions.html "IDL Definitions"){accesskey="n"}\]
 
\[[**[c]**ontents](Overview.html#contents "Table of Contents"){accesskey="c"}\]
  \[[**[i]**ndex](def-index.html "Index"){accesskey="i"}\]

------------------------------------------------------------------------

26 February 2004

# 1. Document Object Model XPath

*Editor*:
: Ray Whitmer, Netscape/AOL

## Table of contents

- [1.1 Introduction](#Introduction)
- [1.2 Mapping DOM to XPath](#Mapping)
 - [1.2.1 Element Nodes](#ElementNodes)
 - [1.2.2 Attribute Nodes](#AttributeNodes)
 - [1.2.3 Namespace Nodes](#NamespaceNodes)
 - [1.2.4 Text Nodes](#TextNodes)
 - [1.2.5 Entity Reference Nodes](#EntityReferences)
 - [1.2.6 Comment Nodes](#CommentNodes)
 - [1.2.7 Processing Instruction Nodes](#PINodes)
 - [1.2.8 Document order](#DocumentOrder)
- [1.3 Conformance](#Conformance)
- [1.4 Interfaces](#Interfaces)
 - [XPathException](#XPathException),
 [XPathExceptionCode](#XPathExceptionCode),
 [XPathEvaluator](#XPathEvaluator),
 [XPathExpression](#XPathExpression),
 [XPathNSResolver](#XPathNSResolver), [XPathResult](#XPathResult),
 [XPathNamespace](#XPathNamespace)

## 1.1 Introduction

XPath 1.0 \[[XPath 1.0](references.html#XPath10)\]
is becoming an important part of a variety of many specifications
including XForms, XPointer, XSL, XML Query, and so on. It is also a
clear advantage for user applications which use DOM to be able to use
XPath expressions to locate nodes automatically and declaratively.

This specification was created to map between the Document Object
Model\'s representation of the W3C Information Set and XPath\'s
[model](glossary.html#dt-model) to permit XPath functions to be supplied
and results returned within the framework of DOM
[API](glossary.html#dt-API)s in a standard, interoperable way, allowing
also for [liveness](glossary.html#dt-live) of data, which is not
addressed by the XPath specification but is present in results coming
from the DOM hierarchy.

## 1.2 Mapping DOM to XPath

This section presents a mapping between the Document Object Model \[[DOM
Level 2 Core](references.html#DOM2Core)\] and the
XPath 1.0 \[[XPath 1.0](references.html#XPath10)\]
model for the purposes of implementing the APIs.

### 1.2.1 Element Nodes

The DOM model uses `Element` nodes to represent [*Element Information
Items*](https://www.w3.org/TR/2004/REC-xml-infoset-20040204/#infoitem.element).
These nodes of a document are directly used to represent the elements of
an XPath result.

### 1.2.2 Attribute Nodes

The DOM model uses `Attr` nodes to represent [*Attribute Information
Items*](https://www.w3.org/TR/2004/REC-xml-infoset-20040204/#infoitem.attribute)
of attribute and namespace attribute properties of [*Element Information
Item*](https://www.w3.org/TR/2004/REC-xml-infoset-20040204/#infoitem.element).
These nodes have no parent, but have an `ownerElement` which can be used
as XPath defines an attribute\'s parent.

XPath 1.0 does not make available the namespace attributes of an
element. The DOM implementation of XPath 1.0 using these defined
interfaces never directly returns `Attr` nodes of namespace attributes,
but returned `Element` nodes still contain them.

### 1.2.3 Namespace Nodes

The XPath model expects namespace nodes for each in-scope namespace to
be attached to each [element](glossary.html#dt-element). DOM only
maintains the namespace attributes instead of replicating in-scope
namespaces on each `Element` where they are in-scope. The DOM
implementation of XPath produces a new node of type
`XPATH_NAMESPACE_NODE`, defined in the
[`XPathNamespace`](xpath.html#XPathNamespace) interface, to properly
preserve identity and ordering in a way that is compatible with XPath.
This node type is only visible using the XPath evaluation methods.

The set of in-scope namespaces of an element is the default xml
namespace combined with the contributions of namespace attributes of the
current and all ancestor elements. In addition to explicit namespace
attributes, any element has an implicit declaration of its own prefix,
if any, or if no prefix then of the default namespace, which is enforced
during namespace serialization, fixup, and lookup, which must be added
to the set of in-scope namespaces when generating namespace nodes for an
element. This causes the set of namespace nodes to be consistent with
serialization, fixup, and lookup of namespaces in DOM Level 3.

### 1.2.4 Text Nodes

The XPath model relies on the XML Information Set \[[XML Information
Set](references.html#InfoSet)\] ands represents
[*Character Information
Items*](https://www.w3.org/TR/2004/REC-xml-infoset-20040204/#infoitem.character)
in a single logical text node where DOM may have multiple fragmented
`Text` nodes due to cdata sections, entity references, etc. Instead of
returning multiple nodes where XPath sees a single logical text node,
only the first non-empty DOM `Text` or `CDATASection` node of any
logical XPath text will be returned in the node set. Applications using
XPath in an environment with fragmented text nodes must manually gather
the text of a single logical text node possibly from multiple nodes
beginning with the first `Text` node or `CDATASection` node returned by
the implementation.

**Note:** In an attempt to better implement the XML Information Set, DOM
Level 3 Core \[[DOM Level 3 Core](references.html#DOMCore)\] adds the attribute `wholeText` on the `Text` interface
for retrieving the whole text for [logically-adjacent Text
nodes](glossary.html#dt-logically-adjacent-text-nodes) and the method
`replaceWholeText` for replacing those nodes.

### 1.2.5 Entity Reference Nodes

The DOM model may represent [*Unexpanded Entity Reference Information
Items*](https://www.w3.org/TR/2004/REC-xml-infoset-20040204/#infoitem.rse)
or may provide the position and URI of expanded entity hierarchies by
using `EntityReference` nodes. XPath 1.0 does not preserve corresponding
information.

Where the node represents an unexpanded entity reference, it is skipped
as dictated by the XPath specifications for all infoset items besides
those specifically processed.

Where there is a hierarchy underneath the node, these nodes are
processed as though they were siblings of the entity reference, as is
consistent with the rest of the DOM specification.

`EntityReference` nodes found within a DOM hierarchy are never returned
as a node of the result, but returned nodes may contain or be contained
within an `EntityReference` node. Text may be split partially inside and
partially outside of an `EntityReference` node, but this is solved by
handling `Text` nodes as described in the previous section.

### 1.2.6 Comment Nodes

The DOM model uses `Comment` nodes to represent [*Comment Information
Items*](https://www.w3.org/TR/2004/REC-xml-infoset-20040204/#infoitem.comment).
These nodes of a document are directly used to represent the comments of
an XPath result.

### 1.2.7 Processing Instruction Nodes

The DOM model uses `ProcessingInstruction` nodes to represent
[*Processing Instruction Information
Items*](https://www.w3.org/TR/2004/REC-xml-infoset-20040204/#infoitem.pi).
These nodes of a document are directly used to represent the processing
instructions of an XPath result.

### 1.2.8 Document order

The [document order](glossary.html#dt-document-order) of nodes in the
DOM Core has been defined to be compatible with the [*XPath document
order*](https://www.w3.org/TR/1999/REC-xpath-19991116#dt-document-order).
The XPath DOM extends the document order of the DOM Core to include the
[`XPathNamespace`](xpath.html#XPathNamespace) nodes. Element nodes occur
before their children. The attribute nodes and namespace nodes of an
element occur before the children of the element. The namespace nodes
are defined to occur before the attribute nodes. The relative order of
namespace nodes is implementation-dependent. The relative order of
attribute nodes is implementation-dependent. The `compareTreePosition`
method on the `Node` interface defined in the DOM Core must compare the
[`XPathNamespace`](xpath.html#XPathNamespace) nodes using this
extended document order if the XPath DOM module is supported.

**Note:** It is possible that in future versions of XPath, the order of
namespace nodes or other aspects of document order may change
incompatibly.

## 1.3 Conformance

This section explains conformance to DOM Level 3 XPath Module.

A DOM implementation must not return `true` to
`hasFeature("xpath", "3.0")` unless the implementation conforms to that
module. As documented in \[[DOM Level 3
Core](references.html#DOMCore)\], if a `null` or
empty string is passed in for the second parameter, then conformance is
still required to some version of the DOM XPath Module or `false` must
be returned.

A conformant implementation is DOM Level 3 XPath must support all the
interfaces as specified in that specification. In addition to
implementing the interfaces in the DOM XPath Module, a conforming
implementation must correctly implement each part of the XPath 1.0
specification when evaluating expressions including Location Paths,
Expressions, the Core Function Library, and the mapping between DOM and
the XPath 1.0 data model described in the DOM Level 3 XPath Module. The
XPath `id()`function must return the corresponding element, if any,
returned by the DOM method `Document.getElementById`.

After meeting the requirements for conformance, a conforming
implementation may implement additional functions and variables.
Applications which evaluate expressions using these extensions will not
necessarily be portable to other implementations of the DOM Level 3
XPath Module.

## 1.4 Interfaces

An implementation is DOM Level 3 XPath conformant if it supports the
Core module defined in \[[DOM Level 2
Core](references.html#DOM2Core)\] and the module
defined in this specification. An implementation conforms to a DOM
module if it supports all the interfaces for that module and the
associated semantics.

A DOM application may use the `hasFeature(feature, version)` method of
the `DOMImplementation` interface with parameter values \"XPath\" and
\"3.0\" (respectively) to determine whether or not the XPath module is
supported by the implementation. In order to fully support this module,
an implementation must also support the \"Core\" feature defined in the
DOM Level 2 Core specification \[[DOM Level 2
Core](references.html#DOM2Core)\].

A DOM implementation must not return `true` to the
`hasFeature(feature, version)` method of the DOMImplementation interface
for that feature unless the implementation conforms to that module. The
version number for the feature used in this document is `"3.0"`.

**Exception *[XPathException]***

: A new exception has been created for exceptions specific to these
 XPath interfaces.

 \
 **IDL Definition**

 : ::: idl-code

 exception XPathException {
 unsigned short code;
 };
 // XPathExceptionCode
 const unsigned short INVALID_EXPRESSION_ERR = 51;
 const unsigned short TYPE_ERR = 52;
 :::

 \

 **Definition group *[XPathExceptionCode]***

 :

 **Defined Constants**

 :

 [`INVALID_EXPRESSION_ERR`]
 : If the expression has a syntax error or otherwise is not
 a legal expression according to the rules of the
 specific [`XPathEvaluator`](xpath.html#XPathEvaluator)
 or contains specialized extension functions or variables
 not supported by this implementation.

 [`TYPE_ERR`]
 : If the expression cannot be converted to return the
 specified type.

**Interface *[XPathEvaluator]***

: The evaluation of XPath expressions is provided by `XPathEvaluator`.
 In a DOM implementation which supports the XPath 3.0 feature, as
 described above, the `XPathEvaluator` interface will be implemented
 on the same object which implements the `Document` interface
 permitting it to be obtained by the usual binding-specific method
 such as casting or by using the DOM Level 3 getInterface method. In
 this case the implementation obtained from the Document supports the
 XPath DOM module and is compatible with the XPath 1.0 specification.

 Evaluation of expressions with specialized extension functions or
 variables may not work in all implementations and is, therefore, not
 portable. `XPathEvaluator` implementations may be available from
 other sources that could provide specific support for specialized
 extension functions or variables as would be defined by other
 specifications.

 \
 **IDL Definition**

 : ::: idl-code

 interface XPathEvaluator {
 XPathExpression createExpression(in DOMString expression,
 in XPathNSResolver resolver)
 raises(XPathException,
 DOMException);
 XPathNSResolver createNSResolver(in Node nodeResolver);
 DOMObject evaluate(in DOMString expression,
 in Node contextNode,
 in XPathNSResolver resolver,
 in unsigned short type,
 in DOMObject result)
 raises(XPathException,
 DOMException);
 };
 :::

 \

 **Methods**

 :

 [`createExpression`]

 : ::::::::: method
 Creates a parsed XPath expression with resolved namespaces.
 This is useful when an expression will be reused in an
 application since it makes it possible to compile the
 expression string into a more efficient internal form and
 preresolve all [namespace
 prefixes](glossary.html#dt-namespaceprefix) which occur
 within the expression.

 :::: parameters
 **Parameters**

 ::: paramtable

 `expression` of type `DOMString`
 : The XPath expression string to be parsed.\

 `resolver` of type [`XPathNSResolver`](xpath.html#XPathNSResolver)
 : The `resolver` permits translation of all prefixes,
 including the `xml` namespace prefix, within the XPath
 expression into appropriate [namespace
 URIs](glossary.html#dt-namespaceURI). If this is
 specified as `null`, any [namespace
 prefix](glossary.html#dt-namespaceprefix) within the
 expression will result in `DOMException` being thrown
 with the code `NAMESPACE_ERR`.\
 :::
 ::::

 :::: return
 **Return Value**

 ::: returntable
 ------------------------------------------------- --------------------------------------------
 [`XPathExpression`](xpath.html#XPathExpression) The compiled form of the XPath expression.
 ------------------------------------------------- --------------------------------------------
 :::
 ::::

 :::: exceptions
 **Exceptions**

 ::: exceptiontable
 ----------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 [`XPathException`](xpath.html#XPathException) INVALID_EXPRESSION_ERR: Raised if the expression is not legal according to the rules of the `XPathEvaluator`.
 `DOMException` NAMESPACE_ERR: Raised if the expression contains [namespace prefixes](glossary.html#dt-namespaceprefix) which cannot be resolved by the specified [`XPathNSResolver`](xpath.html#XPathNSResolver).
 ----------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 :::
 ::::
 :::::::::

 [`createNSResolver`]

 : :::::::: method
 Adapts any DOM node to resolve namespaces so that an XPath
 expression can be easily evaluated relative to the context
 of the node where it appeared within the document. This
 adapter works like the DOM Level 3 method
 `lookupNamespaceURI` on nodes in resolving the namespaceURI
 from a given prefix using the current information available
 in the node\'s hierarchy at the time lookupNamespaceURI is
 called. also correctly resolving the implicit xml prefix.

 :::: parameters
 **Parameters**

 ::: paramtable

 `nodeResolver` of type `Node`
 : The node to be used as a context for namespace
 resolution.\
 :::
 ::::

 :::: return
 **Return Value**

 ::: returntable
 ------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------
 [`XPathNSResolver`](xpath.html#XPathNSResolver) [`XPathNSResolver`](xpath.html#XPathNSResolver) which resolves namespaces with respect to the definitions in scope for a specified node.
 ------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------
 :::
 ::::

 :::
 **No Exceptions**
 :::
 ::::::::

 [`evaluate`]

 : ::::::::: method
 Evaluates an XPath expression string and returns a result of
 the specified type if possible.

 :::: parameters
 **Parameters**

 ::: paramtable

 `expression` of type `DOMString`
 : The XPath expression string to be parsed and evaluated.\

 `contextNode` of type `Node`
 : The `context` is context node for the evaluation of this
 XPath expression. If the XPathEvaluator was obtained by
 casting the `Document` then this must be owned by the
 same document and must be a `Document`, `Element`,
 `Attribute`, `Text`, `CDATASection`, `Comment`,
 `ProcessingInstruction`, or
 [`XPathNamespace`](xpath.html#XPathNamespace) node. If
 the context node is a `Text` or a `CDATASection`, then
 the context is interpreted as the whole logical text
 node as seen by XPath, unless the node is empty in which
 case it may not serve as the XPath context.\

 `resolver` of type [`XPathNSResolver`](xpath.html#XPathNSResolver)
 : The `resolver` permits translation of all prefixes,
 including the `xml` namespace prefix, within the XPath
 expression into appropriate [namespace
 URIs](glossary.html#dt-namespaceURI). If this is
 specified as `null`, any [namespace
 prefix](glossary.html#dt-namespaceprefix) within the
 expression will result in `DOMException` being thrown
 with the code `NAMESPACE_ERR`.\

 `type` of type `unsigned short`
 : If a specific `type` is specified, then the result will
 be returned as the corresponding type.\
 For XPath 1.0 results, this must be one of the codes of
 the [`XPathResult`](xpath.html#XPathResult) interface.\

 `result` of type `DOMObject`
 : The `result` specifies a specific result object which
 may be reused and returned by this method. If this is
 specified as `null`or the implementation does not reuse
 the specified result, a new result object will be
 constructed and returned.\
 For XPath 1.0 results, this object will be of type
 [`XPathResult`](xpath.html#XPathResult).\
 :::
 ::::

 :::: return
 **Return Value**

 ::: returntable
 +-----------------------------------+------------------------------------------+
 | `DOMObject` | The result of the evaluation of the |
 | | XPath expression.\ |
 | | For XPath 1.0 results, this object will |
 | | be of type |
 | | [`XPathResult`](xpath.html#XPathResult). |
 +-----------------------------------+------------------------------------------+
 :::
 ::::

 :::: exceptions
 **Exceptions**

 ::: exceptiontable
 +-----------------------------------------------+--------------------------------------------------+
 | [`XPathException`](xpath.html#XPathException) | INVALID_EXPRESSION_ERR: Raised if the expression |
 | | is not legal according to the rules of the |
 | | `XPathEvaluator`i |
 | | |
 | | TYPE_ERR: Raised if the result cannot be |
 | | converted to return the specified type. |
 +-----------------------------------------------+--------------------------------------------------+
 | `DOMException` | NAMESPACE_ERR: Raised if the expression contains |
 | | [namespace |
 | | prefixes](glossary.html#dt-namespaceprefix) |
 | | which cannot be resolved by the specified |
 | | [`XPathNSResolver`](xpath.html#XPathNSResolver). |
 | | |
 | | WRONG_DOCUMENT_ERR: The Node is from a document |
 | | that is not supported by this `XPathEvaluator`. |
 | | |
 | | NOT_SUPPORTED_ERR: The Node is not a type |
 | | permitted as an XPath context node or the |
 | | request type is not permitted by this |
 | | `XPathEvaluator`. |
 +-----------------------------------------------+--------------------------------------------------+
 :::
 ::::
 :::::::::

**Interface *[XPathExpression]***

: The `XPathExpression` interface represents a parsed and resolved
 XPath expression.

 \
 **IDL Definition**

 : ::: idl-code

 interface XPathExpression {
 DOMObject evaluate(in Node contextNode,
 in unsigned short type,
 in DOMObject result)
 raises(XPathException,
 DOMException);
 };
 :::

 \

 **Methods**

 :

 [`evaluate`]

 : ::::::::: method
 Evaluates this XPath expression and returns a result.

 :::: parameters
 **Parameters**

 ::: paramtable

 `contextNode` of type `Node`
 : The `context` is context node for the evaluation of this
 XPath expression.\
 If the XPathEvaluator was obtained by casting the
 `Document` then this must be owned by the same document
 and must be a `Document`, `Element`, `Attribute`,
 `Text`, `CDATASection`, `Comment`,
 `ProcessingInstruction`, or
 [`XPathNamespace`](xpath.html#XPathNamespace) node.\
 If the context node is a `Text` or a `CDATASection`,
 then the context is interpreted as the whole logical
 text node as seen by XPath, unless the node is empty in
 which case it may not serve as the XPath context.\

 `type` of type `unsigned short`
 : If a specific `type` is specified, then the result will
 be coerced to return the specified type relying on XPath
 conversions and fail if the desired coercion is not
 possible. This must be one of the type codes of
 [`XPathResult`](xpath.html#XPathResult).\

 `result` of type `DOMObject`
 : The `result` specifies a specific result object which
 may be reused and returned by this method. If this is
 specified as `null`or the implementation does not reuse
 the specified result, a new result object will be
 constructed and returned.\
 For XPath 1.0 results, this object will be of type
 [`XPathResult`](xpath.html#XPathResult).\
 :::
 ::::

 :::: return
 **Return Value**

 ::: returntable
 +-----------------------------------+------------------------------------------+
 | `DOMObject` | The result of the evaluation of the |
 | | XPath expression.\ |
 | | For XPath 1.0 results, this object will |
 | | be of type |
 | | [`XPathResult`](xpath.html#XPathResult). |
 +-----------------------------------+------------------------------------------+
 :::
 ::::

 :::: exceptions
 **Exceptions**

 ::: exceptiontable
 +-----------------------------------------------+-----------------------------------+
 | [`XPathException`](xpath.html#XPathException) | TYPE_ERR: Raised if the result |
 | | cannot be converted to return the |
 | | specified type. |
 +-----------------------------------------------+-----------------------------------+
 | `DOMException` | WRONG_DOCUMENT_ERR: The Node is |
 | | from a document that is not |
 | | supported by the XPathEvaluator |
 | | that created this |
 | | `XPathExpression`. |
 | | |
 | | NOT_SUPPORTED_ERR: The Node is |
 | | not a type permitted as an XPath |
 | | context node or the request type |
 | | is not permitted by this |
 | | `XPathExpression`. |
 +-----------------------------------------------+-----------------------------------+
 :::
 ::::
 :::::::::

**Interface *[XPathNSResolver]***

: The `XPathNSResolver` interface permit `prefix` strings in the
 expression to be properly bound to `namespaceURI` strings.
 [`XPathEvaluator`](xpath.html#XPathEvaluator) can construct an
 implementation of `XPathNSResolver` from a node, or the interface
 may be implemented by any application.

 \
 **IDL Definition**

 : ::: idl-code

 interface XPathNSResolver {
 DOMString lookupNamespaceURI(in DOMString prefix);
 };
 :::

 \

 **Methods**

 :

 [`lookupNamespaceURI`]

 : :::::::: method
 Look up the [namespace URI](glossary.html#dt-namespaceURI)
 associated to the given [namespace
 prefix](glossary.html#dt-namespaceprefix). The XPath
 evaluator must never call this with a `null` or empty
 argument, because the result of doing this is undefined.

 :::: parameters
 **Parameters**

 ::: paramtable

 `prefix` of type `DOMString`
 : The prefix to look for.\
 :::
 ::::

 :::: return
 **Return Value**

 ::: returntable
 ------------- ---------------------------------------------------------------------------------------------------
 `DOMString` Returns the associated [namespace URI](glossary.html#dt-namespaceURI) or `null` if none is found.
 ------------- ---------------------------------------------------------------------------------------------------
 :::
 ::::

 :::
 **No Exceptions**
 :::
 ::::::::

**Interface *[XPathResult]***

: The `XPathResult` interface represents the result of the evaluation
 of an XPath 1.0 expression within the context of a particular node.
 Since evaluation of an XPath expression can result in various result
 types, this object makes it possible to discover and manipulate the
 type and value of the result.

 \
 **IDL Definition**

 : ::: idl-code

 interface XPathResult {

 // XPathResultType
 const unsigned short ANY_TYPE = 0;
 const unsigned short NUMBER_TYPE = 1;
 const unsigned short STRING_TYPE = 2;
 const unsigned short BOOLEAN_TYPE = 3;
 const unsigned short UNORDERED_NODE_ITERATOR_TYPE = 4;
 const unsigned short ORDERED_NODE_ITERATOR_TYPE = 5;
 const unsigned short UNORDERED_NODE_SNAPSHOT_TYPE = 6;
 const unsigned short ORDERED_NODE_SNAPSHOT_TYPE = 7;
 const unsigned short ANY_UNORDERED_NODE_TYPE = 8;
 const unsigned short FIRST_ORDERED_NODE_TYPE = 9;

 readonly attribute unsigned short resultType;
 readonly attribute double numberValue;
 // raises(XPathException) on retrieval

 readonly attribute DOMString stringValue;
 // raises(XPathException) on retrieval

 readonly attribute boolean booleanValue;
 // raises(XPathException) on retrieval

 readonly attribute Node singleNodeValue;
 // raises(XPathException) on retrieval

 readonly attribute boolean invalidIteratorState;
 readonly attribute unsigned long snapshotLength;
 // raises(XPathException) on retrieval

 Node iterateNext()
 raises(XPathException,
 DOMException);
 Node snapshotItem(in unsigned long index)
 raises(XPathException);
 };
 :::

 \

 **Definition group *[XPathResultType]***

 : An integer indicating what type of result this is.

 If a specific `type` is specified, then the result will be
 returned as the corresponding type, using [*XPath type
 conversions*](https://www.w3.org/TR/1999/REC-xpath-19991116#section-Expressions)
 where required and possible.

 **Defined Constants**

 :

 [`ANY_TYPE`]
 : This code does not represent a specific type. An
 evaluation of an XPath expression will never produce
 this type. If this type is requested, then the
 evaluation returns whatever type naturally results from
 evaluation of the expression.\
 If the natural result is a node set when `ANY_TYPE` was
 requested, then `UNORDERED_NODE_ITERATOR_TYPE` is always
 the resulting type. Any other representation of a node
 set must be explicitly requested.

 [`ANY_UNORDERED_NODE_TYPE`]
 : The result is a [*node
 set*](https://www.w3.org/TR/1999/REC-xpath-19991116#node-sets)
 as defined by \[[XPath
 1.0](references.html#XPath10)\] and
 will be accessed as a single node, which may be `null`if
 the node set is empty. Document modification does not
 invalidate the node, but may mean that the result node
 no longer corresponds to the current document. This is a
 convenience that permits optimization since the
 implementation can stop once any node in the resulting
 set has been found.\
 If there is more than one node in the actual result, the
 single node returned might not be the first in document
 order.

 [`BOOLEAN_TYPE`]
 : The result is a
 [*boolean*](https://www.w3.org/TR/1999/REC-xpath-19991116#booleans)
 as defined by \[[XPath
 1.0](references.html#XPath10)\].
 Document modification does not invalidate the boolean,
 but may mean that reevaluation would not yield the same
 boolean.

 [`FIRST_ORDERED_NODE_TYPE`]
 : The result is a [*node
 set*](https://www.w3.org/TR/1999/REC-xpath-19991116#node-sets)
 as defined by \[[XPath
 1.0](references.html#XPath10)\] and
 will be accessed as a single node, which may be `null`
 if the node set is empty. Document modification does not
 invalidate the node, but may mean that the result node
 no longer corresponds to the current document. This is a
 convenience that permits optimization since the
 implementation can stop once the first node in document
 order of the resulting set has been found.\
 If there are more than one node in the actual result,
 the single node returned will be the first in document
 order.

 [`NUMBER_TYPE`]
 : The result is a
 [*number*](https://www.w3.org/TR/1999/REC-xpath-19991116#numbers)
 as defined by \[[XPath
 1.0](references.html#XPath10)\].
 Document modification does not invalidate the number,
 but may mean that reevaluation would not yield the same
 number.

 [`ORDERED_NODE_ITERATOR_TYPE`]
 : The result is a node set as defined by \[[XPath
 1.0](references.html#XPath10)\] that
 will be accessed iteratively, which will produce
 document-ordered nodes. Document modification
 invalidates the iteration.

 [`ORDERED_NODE_SNAPSHOT_TYPE`]
 : The result is a [*node
 set*](https://www.w3.org/TR/1999/REC-xpath-19991116#node-sets)
 as defined by \[[XPath
 1.0](references.html#XPath10)\] that
 will be accessed as a snapshot list of nodes that will
 be in original document order. Document modification
 does not invalidate the snapshot but may mean that
 reevaluation would not yield the same snapshot and nodes
 in the snapshot may have been altered, moved, or removed
 from the document.

 [`STRING_TYPE`]
 : The result is a
 [*string*](https://www.w3.org/TR/1999/REC-xpath-19991116#strings)
 as defined by \[[XPath
 1.0](references.html#XPath10)\].
 Document modification does not invalidate the string,
 but may mean that the string no longer corresponds to
 the current document.

 [`UNORDERED_NODE_ITERATOR_TYPE`]
 : The result is a [*node
 set*](https://www.w3.org/TR/1999/REC-xpath-19991116#node-sets)
 as defined by \[[XPath
 1.0](references.html#XPath10)\] that
 will be accessed iteratively, which may not produce
 nodes in a particular order. Document modification
 invalidates the iteration.\
 This is the default type returned if the result is a
 node set and `ANY_TYPE` is requested.

 [`UNORDERED_NODE_SNAPSHOT_TYPE`]
 : The result is a [*node
 set*](https://www.w3.org/TR/1999/REC-xpath-19991116#node-sets)
 as defined by \[[XPath
 1.0](references.html#XPath10)\] that
 will be accessed as a snapshot list of nodes that may
 not be in a particular order. Document modification does
 not invalidate the snapshot but may mean that
 reevaluation would not yield the same snapshot and nodes
 in the snapshot may have been altered, moved, or removed
 from the document.

 **Attributes**

 :

 [`booleanValue`] of type `boolean`, readonly
 : The value of this boolean result.\
 :::: exceptions
 **Exceptions on retrieval**

 ::: exceptiontable
 ----------------------------------------------- ---------------------------------------------------------
 [`XPathException`](xpath.html#XPathException) TYPE_ERR: raised if `resultType` is not `BOOLEAN_TYPE`.
 ----------------------------------------------- ---------------------------------------------------------
 :::
 ::::

 [`invalidIteratorState`] of type `boolean`, readonly
 : Signifies that the iterator has become invalid. True if
 `resultType` is `UNORDERED_NODE_ITERATOR_TYPE` or
 `ORDERED_NODE_ITERATOR_TYPE` and the document has been
 modified since this result was returned.\

 [`numberValue`] of type `double`, readonly
 : The value of this number result. If the native double type
 of the DOM binding does not directly support the exact IEEE
 754 result of the XPath expression, then it is up to the
 definition of the binding to specify how the XPath number is
 converted to the native binding number.\
 :::: exceptions
 **Exceptions on retrieval**

 ::: exceptiontable
 ----------------------------------------------- --------------------------------------------------------
 [`XPathException`](xpath.html#XPathException) TYPE_ERR: raised if `resultType` is not `NUMBER_TYPE`.
 ----------------------------------------------- --------------------------------------------------------
 :::
 ::::

 [`resultType`] of type `unsigned short`, readonly
 : A code representing the type of this result, as defined by
 the type constants.\

 [`singleNodeValue`] of type `Node`, readonly
 : The value of this single node result, which may be `null`.\
 :::: exceptions
 **Exceptions on retrieval**

 ::: exceptiontable
 ----------------------------------------------- -------------------------------------------------------------------------------------------------
 [`XPathException`](xpath.html#XPathException) TYPE_ERR: raised if `resultType` is not `ANY_UNORDERED_NODE_TYPE` or `FIRST_ORDERED_NODE_TYPE`.
 ----------------------------------------------- -------------------------------------------------------------------------------------------------
 :::
 ::::

 [`snapshotLength`] of type `unsigned long`, readonly
 : The number of nodes in the result snapshot. Valid values for
 snapshotItem indices are `0` to `snapshotLength-1`
 inclusive.\
 :::: exceptions
 **Exceptions on retrieval**

 ::: exceptiontable
 ----------------------------------------------- ---------------------------------------------------------------------------------------------------------
 [`XPathException`](xpath.html#XPathException) TYPE_ERR: raised if `resultType` is not `UNORDERED_NODE_SNAPSHOT_TYPE` or `ORDERED_NODE_SNAPSHOT_TYPE`.
 ----------------------------------------------- ---------------------------------------------------------------------------------------------------------
 :::
 ::::

 [`stringValue`] of type `DOMString`, readonly
 : The value of this string result.\
 :::: exceptions
 **Exceptions on retrieval**

 ::: exceptiontable
 ----------------------------------------------- --------------------------------------------------------
 [`XPathException`](xpath.html#XPathException) TYPE_ERR: raised if `resultType` is not `STRING_TYPE`.
 ----------------------------------------------- --------------------------------------------------------
 :::
 ::::

 **Methods**

 :

 [`iterateNext`]

 : :::::::: method
 Iterates and returns the next node from the node set or
 `null`if there are no more nodes.

 :::: return
 **Return Value**

 ::: returntable
 -------- ------------------------
 `Node` Returns the next node.
 -------- ------------------------
 :::
 ::::

 :::: exceptions
 **Exceptions**

 ::: exceptiontable
 ----------------------------------------------- ---------------------------------------------------------------------------------------------------------
 [`XPathException`](xpath.html#XPathException) TYPE_ERR: raised if `resultType` is not `UNORDERED_NODE_ITERATOR_TYPE` or `ORDERED_NODE_ITERATOR_TYPE`.
 `DOMException` INVALID_STATE_ERR: The document has been mutated since the result was returned.
 ----------------------------------------------- ---------------------------------------------------------------------------------------------------------
 :::
 ::::

 :::
 **No Parameters**
 :::
 ::::::::

 [`snapshotItem`]

 : ::::::::: method
 Returns the `index`th item in the snapshot collection. If
 `index` is greater than or equal to the number of nodes in
 the list, this method returns `null`. Unlike the iterator
 result, the snapshot does not become invalid, but may not
 correspond to the current document if it is mutated.

 :::: parameters
 **Parameters**

 ::: paramtable

 `index` of type `unsigned long`
 : Index into the snapshot collection.\
 :::
 ::::

 :::: return
 **Return Value**

 ::: returntable
 -------- -----------------------------------------------------------------------------------------------
 `Node` The node at the `index`th position in the `NodeList`, or `null` if that is not a valid index.
 -------- -----------------------------------------------------------------------------------------------
 :::
 ::::

 :::: exceptions
 **Exceptions**

 ::: exceptiontable
 ----------------------------------------------- ---------------------------------------------------------------------------------------------------------
 [`XPathException`](xpath.html#XPathException) TYPE_ERR: raised if `resultType` is not `UNORDERED_NODE_SNAPSHOT_TYPE` or `ORDERED_NODE_SNAPSHOT_TYPE`.
 ----------------------------------------------- ---------------------------------------------------------------------------------------------------------
 :::
 ::::
 :::::::::

**Interface *[XPathNamespace]***

: The `XPathNamespace` interface is returned by
 [`XPathResult`](xpath.html#XPathResult) interfaces to represent the
 XPath namespace node type that DOM lacks. There is no public
 constructor for this node type. Attempts to place it into a
 hierarchy or a NamedNodeMap result in a `DOMException` with the code
 `HIERARCHY_REQUEST_ERR`. This node is [read
 only](glossary.html#dt-readonly-node), so methods or setting of
 attributes that would mutate the node result in a DOMException with
 the code `NO_MODIFICATION_ALLOWED_ERR`.

 The core specification describes attributes of the `Node` interface
 that are different for different node types but does not describe
 `XPATH_NAMESPACE_NODE`, so here is a description of those attributes
 for this node type. All attributes of `Node` not described in this
 section have a `null` or `false` value.

 `ownerDocument` matches the `ownerDocument` of the `ownerElement`
 even if the element is later adopted.

 `nodeName` is always the string \"`#namespace`\".

 `prefix` is the prefix of the namespace represented by the node.

 `localName` is the same as `prefix`.

 `nodeType` is equal to `XPATH_NAMESPACE_NODE`.

 `namespaceURI` is the namespace URI of the namespace represented by
 the node.

 `nodeValue` is the same as `namespaceURI`.

 `adoptNode`, `cloneNode`, and `importNode` fail on this node type by
 raising a `DOMException` with the code `NOT_SUPPORTED_ERR`.

 **Note:** In future versions of the XPath specification, the
 definition of a namespace node may be changed incomatibly, in which
 case incompatible changes to field values may be required to
 implement versions beyond XPath 1.0.

 \
 **IDL Definition**

 : ::: idl-code

 interface XPathNamespace : Node {

 // XPathNodeType
 const unsigned short XPATH_NAMESPACE_NODE = 13;

 readonly attribute Element ownerElement;
 };
 :::

 \

 **Definition group *[XPathNodeType]***

 : An integer indicating which type of node this is.

 **Note:** There is currently only one type of node which is
 specific to XPath. The numbers in this list must not collide
 with the values assigned to core node types.

 **Defined Constants**

 :

 [`XPATH_NAMESPACE_NODE`]
 : The node is a `Namespace`.

 **Attributes**

 :

 [`ownerElement`] of type `Element`, readonly
 : The `Element` on which the namespace was in scope when it
 was requested. This does not change on a returned namespace
 node even if the document changes such that the namespace
 goes out of scope on that
 [element](glossary.html#dt-element) and this node is no
 longer found there by XPath.\

------------------------------------------------------------------------

\[[**[p]**revious](copyright-notice.html "W3C Copyright Notices and Licenses")\]
  \[[**[n]**ext](idl-definitions.html "IDL Definitions")\]  
\[[**[c]**ontents](Overview.html#contents "Table of Contents")\]
  \[[**[i]**ndex](def-index.html "Index")\]
