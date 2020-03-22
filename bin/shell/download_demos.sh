#!/bin/bash
lynx -cache=0 -dump -listonly "http://ensl.gk-servers.de/public/index.php?dir=demos/" | grep -E "(*\.gz$)|(*\.dem$)" | awk '{print $2}'|tee demlinks.txt && wget --content-disposition -nc -i demlinks.txt
