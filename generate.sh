#!/bin/bash
asciidoctor -a stylesheet=adoc-github.css OMNIBUS.adoc
rm docs/index.html
mv OMNIBUS.html docs/index.html
echo "==> Webage generated "
