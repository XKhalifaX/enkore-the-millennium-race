import re
P=r"C:/Users/khali/OneDrive/المستندات/enkore--the-milennium-race/Scenes/Prototype_Race.tscn"
CAR_IDS={"2_k0ien","10_ewpl2"}   # vehicle_sys_test.tscn, AI_Sedan.tscn
lines=open(P,encoding="utf-8").read().split("\n")
name=parent=inst=None
def cls():
    if inst in CAR_IDS: return "CAR"
    if parent=="Checkpoints": return "SKIP"     # inherits the scaled Checkpoints parent
    if parent=="Grid": return "MARKER"          # spawn transform copied to cars -> no size scale
    if name=="DirectionalLight3D": return "SKIP"
    return "ARENA"
def fmt(v):
    s=("%.6f"%v).rstrip("0").rstrip(".")
    return s if s and s!="-0" else "0"
out=[]
report=[]
for ln in lines:
    h=re.match(r'\[node name="([^"]+)"',ln)
    if h:
        name=h.group(1)
        p=re.search(r'parent="([^"]*)"',ln); parent=p.group(1) if p else None
        i=re.search(r'instance=ExtResource\("([^"]+)"\)',ln); inst=i.group(1) if i else None
        out.append(ln); continue
    t=re.match(r'(\s*transform = Transform3D\()([^)]+)(\).*)',ln)
    if t:
        nums=[float(x) for x in t.group(2).split(",")]
        c=cls()
        if c=="ARENA":
            nums=[v*2 for v in nums]
        elif c in ("CAR","MARKER"):
            nums[9]*=2; nums[11]*=2      # x,z origin only
        report.append((name,c))
        out.append(t.group(1)+", ".join(fmt(v) for v in nums)+t.group(3)); continue
    out.append(ln)
open(P,"w",encoding="utf-8",newline="\n").write("\n".join(out))
print("%-22s %s"%("node","action"))
for n,c in report: print("  %-20s %s"%(n[:20],c))
