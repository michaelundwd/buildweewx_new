FILES=../conf-fragments/*.conf
for f in $FILES
do
	echo "Processing $f"
	echo ""
done


#!/bin/bash

if [ ! -f ext_installed ]; then
    touch ext_installed
    for file in *; do
        weewx_ext $file
    done
else
    echo "ext_installed file found, skipping execution of weewx_ext."
fi
