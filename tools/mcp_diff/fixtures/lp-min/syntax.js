function inspectItem(t){const{price:e,label:n}=t;let r=0;for(let o=0;o<2;o++){r+=e}try{throw new Error(n)}catch(i){return r+":"+i.message}}window.minSyntax=inspectItem;
//# sourceMappingURL=syntax.js.map
