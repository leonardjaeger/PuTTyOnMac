import cairosvg, io, json, os, re
from PIL import Image, ImageFilter
from gen import *
os.makedirs("svg",exist_ok=True); os.makedirs("png",exist_ok=True)
# --- Symbol-Fassungen (Master 256er-Raster)
A,C=master(); Ar,Cr=master(w=21,g=15); As,Cs=grid16()
T="TunnelTerminal Logo"; Tk="TunnelTerminal Logo (Kleinfassung 16/32 px)"
for name,txt in {
 "tunnel-symbol-black.svg":svg(A,C,"#000000"),
 "tunnel-symbol-white.svg":svg(Ar,Cr,"#FFFFFF"),
 "tunnel-symbol-ink.svg":svg(A,C,INK),
 "tunnel-symbol-farbe-hell.svg":svg(A,C,INK,AMBER_D),
 "tunnel-symbol-farbe-dunkel.svg":svg(Ar,Cr,CHALK,AMBER),
 "tunnel-klein-black.svg":svg(As,Cs,"#000000",title=Tk),
 "tunnel-klein-farbe-hell.svg":svg(As,Cs,INK,AMBER_D,title=Tk),
 "tunnel-klein-farbe-dunkel.svg":svg(As,Cs,CHALK,AMBER,title=Tk),
}.items(): open("svg/"+name,"w").write(txt)
os.makedirs("AppIcon.appiconset",exist_ok=True); os.makedirs("IconComposer-Ebenen",exist_ok=True); os.makedirs("web",exist_ok=True)
SQ=squircle(100,100,824)
def place(a,c,scale,cy_target, ccol=AMBER, acol=CHALK, mark_cy=126):
    tx=512-128*scale; ty=cy_target-mark_cy*scale
    return f'<g transform="translate({tx:.2f} {ty:.2f}) scale({scale})"><path fill="{acol}" d="{a}"/><path fill="{ccol}" d="{c}"/></g>'
def icon_svg(kind):
    if kind=="small":
        a,c=grid16(); g=place(a,c,2.75,512,mark_cy=128)
    else:
        a,c=master(); g=place(a,c,2.42,505)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><title>TunnelTerminal App-Icon</title>'
            f'<path fill="{INK}" d="{SQ}"/><path fill="none" stroke="#FFFFFF" stroke-opacity="0.12" stroke-width="4" d="{SQ}"/>{g}</svg>')
open("svg/app-icon-1024.svg","w").write(icon_svg("big"))
open("svg/app-icon-klein.svg","w").write(icon_svg("small"))
def render(svgtxt,size):
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svgtxt.encode(),output_width=size,output_height=size))).convert("RGBA")
def with_shadow(svgtxt,size):
    big=render(svgtxt,1024)
    al=big.getchannel("A")
    sh=Image.new("RGBA",(1024,1024),(0,0,0,0)); sh.putalpha(al.point(lambda v:int(v*0.30)))
    sh=sh.transform((1024,1024),Image.AFFINE,(1,0,0,0,1,-10)).filter(ImageFilter.GaussianBlur(10))
    out=Image.alpha_composite(sh,big)
    return out if size==1024 else (render(svgtxt,size) if size<=32 else out.resize((size,size),Image.LANCZOS))
entries=[]
for pt in (16,32,128,256,512):
    for sc in (1,2):
        px=pt*sc; kind="small" if px<=32 else "big"
        fn=f"icon_{pt}x{pt}{'@2x' if sc==2 else ''}.png"
        with_shadow(icon_svg(kind),px).save("AppIcon.appiconset/"+fn)
        entries.append({"filename":fn,"idiom":"mac","scale":f"{sc}x","size":f"{pt}x{pt}"})
json.dump({"images":entries,"info":{"author":"xcode","version":1}},open("AppIcon.appiconset/Contents.json","w"),indent=2)
with_shadow(icon_svg("big"),1024).save("png/app-icon-1024.png")
# Icon Composer layers (macOS 26 Liquid Glass) – no tile, 1024 canvas
a,c=master()
open("IconComposer-Ebenen/1-Hintergrund.svg","w").write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="{INK}"/></svg>')
open("IconComposer-Ebenen/2-Boegen.svg","w").write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">{place(a,"",2.42,505).replace(f"<path fill=\"{AMBER}\" d=\"\"/>","")}</svg>')
open("IconComposer-Ebenen/3-Cursor.svg","w").write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">{place("",c,2.42,505).replace(f"<path fill=\"{CHALK}\" d=\"\"/>","")}</svg>')
# Web icons
sa,sc_=grid16()
fav=(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256"><title>TunnelTerminal</title>'
     f'<rect width="256" height="256" rx="56" fill="{INK}"/>'
     f'<g transform="translate(16 16) scale(0.875)"><path fill="{CHALK}" d="{sa}"/><path fill="{AMBER}" d="{sc_}"/></g></svg>')
open("web/favicon.svg","w").write(fav)
for s in (16,32,48): render(fav,s).save(f"web/favicon-{s}.png")
render(fav,48).save("web/favicon.ico",sizes=[(16,16),(32,32),(48,48)])
def square(size,frac,kind="big"):
    a,c=master() if kind=="big" else grid16()
    sc=1024*frac/184; g=place(a,c,sc,505 if kind=="big" else 512, mark_cy=126 if kind=="big" else 128)
    s=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="{INK}"/>{g}</svg>'
    return render(s,size)
square(180,0.56).save("web/apple-touch-icon.png")
square(192,0.56).save("web/icon-192.png")
square(512,0.56).save("web/icon-512.png")
square(512,0.44).save("web/maskable-512.png")
square(512,0.50).save("png/avatar-512.png")
json.dump({"name":"TunnelTerminal","short_name":"TunnelTerminal","icons":[
  {"src":"/icon-192.png","sizes":"192x192","type":"image/png"},
  {"src":"/icon-512.png","sizes":"512x512","type":"image/png"},
  {"src":"/maskable-512.png","sizes":"512x512","type":"image/png","purpose":"maskable"}],
  "theme_color":INK,"background_color":INK,"display":"standalone"},open("web/site.webmanifest","w"),indent=2)
open("web/head-snippet.html","w").write('''<link rel="icon" href="/favicon.ico" sizes="48x48">
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="manifest" href="/site.webmanifest">
<meta name="theme-color" content="#16181D">
''')
# PNGs of symbol variants
for f in os.listdir("svg"):
    if f.startswith("tunnel-symbol"):
        render(open("svg/"+f).read(),1024).save("png/"+f.replace(".svg","-1024.png"))
print("ok")
