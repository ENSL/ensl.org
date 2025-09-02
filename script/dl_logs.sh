cd /srv/ensl/files/logs/sputnik1 ||exit 1
lynx -cache=0 -dump -listonly "http://ensl.gk-servers.de/public/index.php?dir=logs/SPUTNIK-1/" | grep -E "(*\.gz$)|(*\.log$)" | awk '{print $2}'|tee links.txt && wget --content-disposition -nc -i links.txt
