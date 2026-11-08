# Draws the original harvestable-tree sprite (bushy canopy, glowing fruit) as SVG; render tree.svg to a 1024px transparent PNG.
# Caller: run by hand, output goes to assets/world2d/final/enemies/Tree.png.
# Generates an original bushy tree with glowing fruit as SVG, renders to PNG with Playwright.
import random, sys
random.seed(int(sys.argv[1]) if len(sys.argv)>1 else 7)
W=1024
OUT=18
# canopy clumps (cx, cy, r)
clumps=[(512,330,150),(372,380,120),(652,380,125),(300,470,95),(724,470,98),(440,470,120),(590,475,120),(512,250,110),(400,280,95),(625,285,95),(512,520,105),(240,440,60),(790,440,62),(300,330,70),(720,330,72),(512,160,70),(380,560,70),(650,565,72),(230,520,50),(800,525,52)]
trunk = "M462 780 C 474 730, 484 690, 480 640 C 440 600, 400 560, 372 520 L 404 500 C 430 535, 465 570, 495 590 C 500 540, 505 500, 512 470 L 540 470 C 538 510, 534 550, 532 588 C 560 565, 595 530, 622 500 L 652 520 C 620 560, 580 605, 545 640 C 542 690, 554 730, 568 780 C 540 795, 490 795, 462 780 Z"
roots = "M420 792 C 450 772, 466 762, 472 748 L 558 748 C 564 762, 582 772, 612 792 C 560 808, 470 808, 420 792 Z"
fruits=[(410,360),(565,300),(655,430),(470,455),(330,470),(600,520),(760,470),(505,190),(420,540),(280,410),(700,330)]
s=[]
s.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{W}" viewBox="0 0 {W} {W}">')
s.append('''<defs>
<radialGradient id="glow"><stop offset="0" stop-color="#d8ff7a" stop-opacity="0.85"/><stop offset="0.45" stop-color="#a6ff3c" stop-opacity="0.35"/><stop offset="1" stop-color="#7dff20" stop-opacity="0"/></radialGradient>
<radialGradient id="fruit" cx="0.38" cy="0.35" r="0.7"><stop offset="0" stop-color="#f4ffc2"/><stop offset="0.35" stop-color="#c8ff4e"/><stop offset="1" stop-color="#5fc41c"/></radialGradient>
<linearGradient id="bark" x1="0" x2="1"><stop offset="0" stop-color="#7a4a36"/><stop offset="0.5" stop-color="#5c3426"/><stop offset="1" stop-color="#3e2219"/></linearGradient>
</defs>''')
# outline pass
s.append(f'<g stroke="#120d10" stroke-width="{OUT*2}" stroke-linejoin="round" fill="#120d10">')
s.append(f'<path d="{roots}"/><path d="{trunk}"/>')
for x,y,r in clumps: s.append(f'<circle cx="{x}" cy="{y}" r="{r}"/>')
s.append('</g>')
s.append(f'<path d="{roots}" fill="#4a2a1f"/><path d="{trunk}" fill="url(#bark)"/>')
# bark lines
s.append('<g stroke="#2a1610" stroke-width="7" fill="none" stroke-linecap="round"><path d="M505 770 C 500 730, 510 700, 506 670"/><path d="M530 760 C 528 735, 534 715, 530 700"/></g>')
# canopy: dark base, mid, highlights
for x,y,r in clumps: s.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#1f4d2b"/>')
for x,y,r in clumps: s.append(f'<circle cx="{x-r*0.08}" cy="{y-r*0.12}" r="{r*0.86}" fill="#2f7038"/>')
for x,y,r in clumps: s.append(f'<ellipse cx="{x-r*0.25}" cy="{y-r*0.38}" rx="{r*0.45}" ry="{r*0.28}" fill="#4f9a45" opacity="0.9"/>')
# leaf tufts
random.seed(3)
for i in range(26):
    x,y,r=random.choice(clumps)
    import math
    a=random.uniform(0,2*math.pi); d=random.uniform(0.2,0.75)*r
    px,py=x+math.cos(a)*d,y+math.sin(a)*d
    rot=random.uniform(-40,40)
    s.append(f'<path transform="translate({px:.0f},{py:.0f}) rotate({rot:.0f})" d="M-16 6 Q 0 -22 16 6 Q 0 0 -16 6Z" fill="#62b350" opacity="0.8"/>')
# fruit glow
for x,y in fruits: s.append(f'<circle cx="{x}" cy="{y}" r="84" fill="url(#glow)"/>')
for x,y in fruits:
    s.append(f'<path d="M{x} {y-24} q 6 -16 18 -18" stroke="#120d10" stroke-width="7" fill="none" stroke-linecap="round"/>')
    s.append(f'<circle cx="{x}" cy="{y}" r="31" fill="url(#fruit)" stroke="#120d10" stroke-width="7"/>')
    s.append(f'<ellipse cx="{x-9}" cy="{y-10}" rx="8" ry="5" fill="#ffffff" opacity="0.9"/>')
s.append('</svg>')
open('tree.svg','w').write("\n".join(s))
