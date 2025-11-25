// Debug querySelector failures - verbose output

var doc = new Document();
var body = doc.createElement("body");

var header = doc.createElement("header");
var main = doc.createElement("main");
var footer = doc.createElement("footer");
var div1 = doc.createElement("div");
var div2 = doc.createElement("div");
var div3 = doc.createElement("div");
var section1 = doc.createElement("section");
var section2 = doc.createElement("section");
var article = doc.createElement("article");
var p = doc.createElement("p");
var span = doc.createElement("span");
var a = doc.createElement("a");
var button = doc.createElement("button");
var input = doc.createElement("input");

body.appendChild(header);
body.appendChild(main);
main.appendChild(section1);
main.appendChild(section2);
section1.appendChild(div1);
section1.appendChild(div2);
section2.appendChild(div3);
section2.appendChild(article);
article.appendChild(p);
p.appendChild(span);
div1.appendChild(a);
div2.appendChild(button);
div3.appendChild(input);
body.appendChild(footer);

// Test child combinator
var test1 = body.querySelector("body > header");
console.log("Test: body > header === header:", test1 === header);

var test2 = body.querySelector("body > main");
console.log("Test: body > main === main:", test2 === main);

var test3 = body.querySelector("body > footer");
console.log("Test: body > footer === footer:", test3 === footer);

var test4 = body.querySelector("main > section");
console.log("Test: main > section === section1:", test4 === section1);

var test5 = body.querySelector("section > div");
console.log("Test: section > div === div1:", test5 === div1);

var test6 = body.querySelector("article > p");
console.log("Test: article > p === p:", test6 === p);

var test7 = body.querySelector("p > span");
console.log("Test: p > span === span:", test7 === span);

// Multi-level child
var test8 = body.querySelector("main > section > div");
console.log("Test: main > section > div === div1:", test8 === div1);

var test9 = body.querySelector("section > article > p");
console.log("Test: section > article > p === p:", test9 === p);

// Child vs descendant
var test10 = body.querySelector("body > section");
console.log("Test: body > section === null:", test10 === null);

// querySelectorAll tests
var sections = body.querySelectorAll("section");
console.log("Test: querySelectorAll('section').length === 2:", sections.length === 2);

var divs = body.querySelectorAll("div");
console.log("Test: querySelectorAll('div').length === 3:", divs.length === 3);

var mainSections = body.querySelectorAll("main section");
console.log("Test: querySelectorAll('main section').length === 2:", mainSections.length === 2);

var multiType = body.querySelectorAll("section, div");
console.log("Test: querySelectorAll('section, div').length === 5:", multiType.length === 5);
