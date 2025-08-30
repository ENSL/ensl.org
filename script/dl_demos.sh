cd /srv/ensl/files/demos/sputnik ||exit 1
lynx -cache=0 -dump -listonly "http://ensl.gk-servers.de/public/index.php?dir=demos/SPUNTIK-1/" | grep -E "(*\.gz$)|(*\.dem$)" | awk '{print $2}'|tee demlinks.txt && wget --content-disposition -nc -i demlinks.txt
rm demlinks.txt
lynx -cache=0 -dump -listonly "http://ensl.gk-servers.de/public/index.php?dir=demos/" | grep -E "(*\.gz$)|(*\.dem$)" | awk '{print $2}'|tee demlinks.txt && wget --content-disposition -nc -i demlinks.txt
rm demlinks.txt
