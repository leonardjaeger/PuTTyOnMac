from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.boundsPen import BoundsPen
from gen import *
F="/usr/share/fonts/opentype/inter/"
def text_path(txt, font, size, x0=0, base=0, track=0):
    f=TTFont(F+font); gs=f.getGlyphSet(); cmap=f.getBestCmap(); upm=f['head'].unitsPerEm; hm=f['hmtx']
    s=size/upm; pen=SVGPathPen(gs); x=x0; bp=BoundsPen(gs)
    for ch in txt:
        g=cmap[ord(ch)]
        if ch=="l": g="l.ss02"
        tp=TransformPen(pen,(s,0,0,-s,x,base)); gs[g].draw(tp)
        tb=TransformPen(bp,(s,0,0,-s,x,base)); gs[g].draw(tb)
        x+=hm[g][0]*s+track
    return pen.getCommands(), x, bp.bounds
def lockup(kind, a_col, c_col, t1_col, t2_col, bg=None, split="weight", w2name="Terminal"):
    A,C=master()
    if kind=="h":
        # symbol 256 box scaled to height 120, text cap-height matched to arch legs
        sc=120/176; sy=-38*sc   # mark bbox y 38..214 -> 0..120
        g=f'<g transform="translate({-36*sc:.1f} {sy:.1f}) scale({sc:.4f})"><path fill="{a_col}" d="{A}"/><path fill="{c_col}" d="{C}"/></g>'
        size=104; base=120; x0=184*sc+44
        w1="Inter-SemiBold.otf"; w2="Inter-SemiBold.otf" if split!="weight" else "Inter-Regular.otf"
        p1,x,_=text_path("Tunnel",w1,size,x0,base,-2.5)
        p2,x2,_=text_path(w2name,w2,size,x+9,base,-1)
        W=x2+4; H=120
        body=g+f'<path fill="{t1_col}" d="{p1}"/><path fill="{t2_col}" d="{p2}"/>'
    else:
        sc=1.0
        g=f'<g transform="translate({(-36+ (0))} {-38})"><path fill="{a_col}" d="{A}"/><path fill="{c_col}" d="{C}"/></g>'
        size=64
        w1="Inter-SemiBold.otf"; w2="Inter-Regular.otf" if split=="weight" else w1
        p1,x,_=text_path("Tunnel",w1,size,0,0,-1.5); p2,x2,_=text_path(w2name,w2,size,x+5.5,0,-0.5)
        tw=x2; W=max(184,tw)+0; ox=(W-tw)/2; mx=(W-184)/2
        g=f'<g transform="translate({mx-36:.1f} -38)"><path fill="{a_col}" d="{A}"/><path fill="{c_col}" d="{C}"/></g>'
        base=176+40+46
        body=g+f'<g transform="translate({ox:.1f} {base})"><path fill="{t1_col}" d="{p1}"/><path fill="{t2_col}" d="{p2}"/></g>'
        H=base+14
    pad=40
    b=f'<rect x="{-pad}" y="{-pad}" width="{W+2*pad}" height="{H+2*pad}" fill="{bg}"/>' if bg else ''
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{-pad} {-pad} {W+2*pad:.1f} {H+2*pad:.1f}"><title>Tunnel{w2name} Logo</title>{b}{body}</svg>'
