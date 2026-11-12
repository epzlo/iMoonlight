import math, sys
from PIL import Image, ImageDraw, ImageFilter
S=4096
img=Image.new('RGB',(S,S),'#0b0908')
# fundo: radial quente
bg=Image.new('L',(S,S),0); d=ImageDraw.Draw(bg)
for r in range(S//1,0,-16):
    v=int(255*max(0,1-r/(S*0.75))**1.6)
    d.ellipse([S/2-r,S*0.46-r,S/2+r,S*0.46+r],fill=v)
warm=Image.new('RGB',(S,S),'#2a1d19')
img=Image.composite(warm,img,bg)
d=ImageDraw.Draw(img)
cx,cy=S/2,S*0.5
# olho (vesica) em latão
W,H=S*0.80,S*0.46
R=(W*W/4+H*H/4)/H  # raio dos arcos
pts=[]
half=math.asin((W/2)/R)
for i in range(181):
    a=-half+2*half*i/180
    pts.append((cx+R*math.sin(a), cy+H/2-R*(1-math.cos(a))- (R-H/2) + (R-H/2)))
top=[(cx+R*math.sin(a), (cy-H/2+R)-R*math.cos(a)) for a in [ -half+2*half*i/180 for i in range(181)]]
bot=[(cx+R*math.sin(a), (cy+H/2-R)+R*math.cos(a)) for a in [ half-2*half*i/180 for i in range(181)]]
eye=top+bot
d.polygon(eye,fill='#c8a15a')
# borda interna escura
inner=[(cx+(x-cx)*0.94,cy+(y-cy)*0.86) for x,y in eye]
d.polygon(inner,fill='#16110f')
# íris
ir=S*0.165
mask=Image.new('L',(S,S),0); ImageDraw.Draw(mask).polygon(inner,fill=255)
iris=Image.new('RGB',(S,S),'#16110f'); di=ImageDraw.Draw(iris)
for k in range(60,0,-1):
    r=ir*k/60
    t=k/60
    col=(int(0x5a+(0xd9-0x5a)*(1-t)**0.8*0.0+ (0xa3-0x5a)*(1-abs(t-0.55))), int(0x14+0x10*(1-t)), int(0x16+0x10*(1-t)))
    di.ellipse([cx-r,cy-r,cx+r,cy+r],fill=col)
# anel de latão fino na íris
di.ellipse([cx-ir,cy-ir,cx+ir,cy+ir],outline='#c8a15a',width=int(S*0.008))
# pupila em fenda
pw,ph=S*0.05,S*0.27
di.ellipse([cx-pw,cy-ph/2,cx+pw,cy+ph/2],fill='#050403')
# brilho
di.ellipse([cx+S*0.055,cy-S*0.095,cx+S*0.095,cy-S*0.055],fill='#efe7de')
img.paste(iris,(0,0),mask)
img=img.resize((1024,1024),Image.LANCZOS)
img.save(sys.argv[1])
