import sys
for f in sys.argv[1:]:
    b=open(f,'rb').read().replace(b'\r\n',b'\n')
    h=0
    for c in b: h=(h*31+c)%2147483647
    print(f, f"{len(b)}:{h}")
