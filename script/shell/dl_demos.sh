mkdir -p /srv/ensl/files/demos/sputnik; cd /srv/ensl/files/demos/sputnik ||exit 1
lynx -cache=0 -dump -listonly "http://ensl.gk-servers.de/public/index.php?dir=demos/SPUNTIK-1/" | grep -E "(*\.gz$)|(*\.dem$)" | awk '{print $2}'|tee demlinks.txt && wget --content-disposition -nc -i demlinks.txt
rm demlinks.txt
lynx -cache=0 -dump -listonly "http://ensl.gk-servers.de/public/index.php?dir=demos/SPUNTIK-2/" | grep -E "(*\.gz$)|(*\.dem$)" | awk '{print $2}'|tee demlinks.txt && wget --content-disposition -nc -i demlinks.txt
rm demlinks.txt
lynx -cache=0 -dump -listonly "http://ensl.gk-servers.de/public/index.php?dir=demos/" | grep -E "(*\.gz$)|(*\.dem$)" | awk '{print $2}'|tee demlinks.txt && wget --content-disposition -nc -i demlinks.txt
rm demlinks.txt

mkdir -p /srv/ensl/files/logs/sputnik1; cd /srv/ensl/files/logs/sputnik1 ||exit 1
lynx -cache=0 -dump -listonly "http://ensl.gk-servers.de/public/index.php?dir=logs/SPUTNIK-1/" | grep -E "(*\.gz$)|(*\.log$)" | awk '{print $2}'|tee links.txt && wget --content-disposition -nc -i links.txt
rm links.txt

mkdir -p /srv/ensl/files/logs/sputnik2; cd /srv/ensl/files/logs/sputnik2 ||exit 1
lynx -cache=0 -dump -listonly "http://ensl.gk-servers.de/public/index.php?dir=logs/SPUTNIK-2/" | grep -E "(*\.gz$)|(*\.log$)" | awk '{print $2}'|tee links.txt && wget --content-disposition -nc -i links.txt
rm links.txt
