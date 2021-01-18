
#!/bin/bash

echo "bulk converting rst files into adoc.."

find ./ -name "*.rst" -type f | xargs -I @@ \
    bash -c 'kramdoc --format=GFM --wrap=ventilate --output=@@.adoc @@';
