#!/bin/bash
cd src
asciidoctor -b html5 index.adoc
rm public/index.html
mv src/index.html public/
echo "==> Documentation Generated"
