#!/bin/bash
asciidoctor -a stylesheet=adoc-github.css specification.adoc
rm docs/index.html
mv specification.html docs/index.html
echo "==> Webage generated "
