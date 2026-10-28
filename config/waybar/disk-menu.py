#!/usr/bin/env python3
import json, os, shutil, subprocess, sys

XOFF = "-60"

if subprocess.run(["pgrep", "-x", "wofi"], capture_output=True).returncode == 0:
    subprocess.run(["pkill", "-x", "wofi"])
    sys.exit()

def human(n):
    for u in "BKMGT":
        if n < 1024 or u == "T":
            return f"{n:.0f}{u}" if u in "BK" else f"{n:.1f}{u}"
        n /= 1024

def pick(lines, prompt, height=380):
    r = subprocess.run(
        ["wofi", "--dmenu", "--hide-search", "--location", "5", "--xoffset", XOFF,
         "--width", "380", "--height", str(height), "--prompt", prompt],
        input="\n".join(lines) + "\n", capture_output=True, text=True)
    return r.stdout.strip()

def truthy(v):
    return v in (True, 1, "1", "true")

def walk(devs, parent_ext=False):
    for d in devs:
        ext = parent_ext or truthy(d.get("rm")) or truthy(d.get("hotplug"))
        yield d, ext
        yield from walk(d.get("children") or [], ext)

data = json.loads(subprocess.check_output(
    ["lsblk", "-J", "-b", "-o", "NAME,PATH,SIZE,TYPE,MOUNTPOINTS,LABEL,FSTYPE,RM,HOTPLUG"]))

internal, external, actions = [], [], {}
for d, ext in walk(data["blockdevices"]):
    fs = d.get("fstype")
    if not fs or fs in ("swap", "crypto_LUKS", "LVM2_member", "linux_raid_member"):
        continue
    if d.get("type") in ("loop", "rom"):
        continue
    mps = [m for m in (d.get("mountpoints") or []) if m and not m.startswith("[")]
    if not ext and not mps:
        continue
    mp = mps[0] if mps else None
    dev = d["path"]
    name = d.get("label") or os.path.basename(dev)
    if mp == "/":
        name = "Internal"
    name = name[:14]
    if mp:
        t, u, _ = shutil.disk_usage(mp)
        line = f"● {name:<14} {human(u)} / {human(t)}   {mp}"
    else:
        line = f"○ {name:<14} {human(int(d.get('size') or 0))}   (not mounted)"
    actions[line] = (dev, mp, ext)
    (external if ext else internal).append((mp != "/", name, line))

internal.sort()
external.sort()

lines = ["── Internal ──"] + [x[2] for x in internal]
lines += ["── External ──"] + ([x[2] for x in external] or ["(no external drives)"])

choice = pick(lines, "Storage")
item = actions.get(choice)
if not item or not item[2]:
    sys.exit()

dev, mp, _ = item
cmd = ["udisksctl", "unmount" if mp else "mount", "-b", dev]
r = subprocess.run(cmd, capture_output=True, text=True)
text = (r.stdout or r.stderr).strip().splitlines()
pick([text[0] if text else "Done"], "Storage", 90)
