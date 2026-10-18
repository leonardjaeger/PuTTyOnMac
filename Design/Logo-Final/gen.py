"""Tunnel mark generator. All geometry on a 256 grid; base line y=BASE."""
import math
CX=128
INK="#16181D"; CHALK="#EEEBE4"; AMBER="#FFB224"; AMBER_D="#C77700"

def portal(R, w, cy, base, thin=1.0):
    # outer arc centre (CX,cy); inner arc centre raised by `thin` -> crown thinner than legs (optical)
    r=R-w; ci=cy-thin
    return (f"M{CX-R} {base}V{cy}A{R} {R} 0 0 1 {CX+R} {cy}V{base}H{CX+r}V{ci}"
            f"A{r} {r} 0 0 0 {CX-r} {ci}V{base}Z")

def master(w=22, g=14, R1=92, base=214, cy=130, cur=(28,42), thin=1.0):
    R2=R1-w-g
    arches=portal(R1,w,cy,base,thin)+" "+portal(R2,w,cy,base,thin)
    cw,ch=cur
    cursor=f"M{CX-cw/2} {base}V{base-ch}H{CX+cw/2}V{base}Z"
    return arches, cursor

def small(w=34, R=98, base=220, cy=134, cur=(40,62), thin=1.5):
    arches=portal(R,w,cy,base,thin)
    cw,ch=cur
    cursor=f"M{CX-cw/2} {base}V{base-ch}H{CX+cw/2}V{base}Z"
    return arches, cursor

def svg(arches, cursor, a_col="#000", c_col=None, bg=None, title="TunnelTerminal Logo", vb=256):
    c_col=c_col or a_col
    b=f'<rect width="{vb}" height="{vb}" fill="{bg}"/>' if bg else ''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {vb} {vb}"><title>{title}</title>{b}'
            f'<path fill="{a_col}" d="{arches}"/><path fill="{c_col}" d="{cursor}"/></svg>')

def squircle(x, y, s, n=5.0, steps=720):
    a=s/2; cx=x+a; cy=y+a; pts=[]
    for i in range(steps):
        t=2*math.pi*i/steps; c=math.cos(t); si=math.sin(t)
        pts.append((cx+a*math.copysign(abs(c)**(2/n),c), cy+a*math.copysign(abs(si)**(2/n),si)))
    return "M"+" L".join(f"{px:.2f} {py:.2f}" for px,py in pts)+"Z"

def grid16():
    """Pixel-hinted cut for 16/32 px: every edge on the 16-unit grid (1 px at 16 px)."""
    arches=("M32 224V128A96 96 0 0 1 224 128V224H192V128A64 64 0 0 0 64 128V224Z")
    cursor="M112 224V160H144V224Z"
    return arches, cursor
