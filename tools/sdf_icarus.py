#!/usr/bin/env python3
"""Split a nextpnr SDF into something Icarus Verilog 12 can simulate.

Usage:
  python3 -I tools/sdf_icarus.py ROUTED.v ROUTED.sdf OUT.v OUT.sdf [min|typ|max]

Icarus 12's $sdf_annotate (checked with small cases, see
docs/design/videl-core-methodology.md) has three gaps for nextpnr output:
  * INTERCONNECT entries are parsed and silently ignored, so every wire
    delay is lost;
  * PORT (input-port delay) is a syntax error, so wire delays cannot be
    moved onto the sink ports either;
  * an INSTANCE name with a bare '.' (nextpnr writes "core.u_regs.n12_q"
    with DIVIDER /) is a syntax error; with the dot escaped ("core\\.u_regs")
    it is found.
So this script:
  1. rewrites the netlist so that each INTERCONNECT (source pin -> sink pin,
     delay d) becomes a delayed continuous assignment in front of that one
     sink pin:  wire \\ic$N ; assign #(rise, fall) \\ic$N = <net>;
     The delay is per sink, as in the SDF. A Verilog assign delay is
     inertial: a pulse shorter than the wire delay is swallowed, the usual
     SDF pulse-rejection default.
  2. writes an SDF holding only the CELL IOPATH delays, with escaped
     instance names, for $sdf_annotate. The models need specify paths for
     them (tools/ecp5_sim_compat.py adds them).
  3. Timing checks (SETUPHOLD) are dropped: Icarus does not evaluate them.
     A setup violation then shows up as a register capturing its input a
     cycle late, which the replay testbench reports as a mismatch.
The corner (min, typ, max; default max) picks one value of each
(min:typ:max) triple. max is the setup-critical corner.
"""
import re
import sys

vin, sin, vout, sout = sys.argv[1:5]
corner = {'min': 0, 'typ': 1, 'max': 2}[sys.argv[5] if len(sys.argv) > 5 else 'max']

sdf = open(sin).read()


def unesc(name):
    """SDF identifier (backslash escapes) -> plain instance/pin name."""
    return re.sub(r'\\(.)', r'\1', name)


def pick(triple):
    v = triple.strip('()').split(':')
    return int(float(v[corner] if len(v) == 3 else v[0]))


# ---- 1. INTERCONNECT -> per-sink delays ----------------------------------
ic = {}   # (instance, pin) -> (rise, fall)
for m in re.finditer(r'\(INTERCONNECT\s+(\S+)\s+(\S+)\s+(\([^)]*\))\s*(\([^)]*\))?\s*\)', sdf):
    dst = unesc(m.group(2))
    inst, pin = dst.rsplit('/', 1)
    rise = pick(m.group(3))
    fall = pick(m.group(4)) if m.group(4) else rise
    if rise or fall:
        ic[(inst, pin)] = (rise, fall)

v = open(vin).read()
# write_verilog instance:  TYPE #( params ) NAME ( .PIN(expr), ... );
inst_re = re.compile(r'(\n\s*\w+\s+(?:#\((?:.|\n)*?\)\s*)?)(\\\S+ |\w+)(\s*\()((?:.|\n)*?)(\);)')
conn_re = re.compile(r'\.(\w+)\(((?:[^()]|\([^()]*\))*)\)')
extra = []
n = [0]
used = set()


def fix_ports(name, ports):
    def sub(pm):
        pin, expr = pm.group(1), pm.group(2).strip()
        d = ic.get((name, pin))
        if not d or not expr:
            return pm.group(0)
        used.add((name, pin))
        n[0] += 1
        w = '\\ic$%d ' % n[0]
        # the space before ";" ends an escaped identifier such as \n[3]
        extra.append('  wire %s;\n  assign #(%d, %d) %s= %s ;\n' % (w, d[0], d[1], w, expr))
        return '.%s(%s)' % (pin, w)
    return conn_re.sub(sub, ports)


def fix_inst(m):
    raw = m.group(2)
    name = raw[1:].rstrip() if raw.startswith('\\') else raw
    return m.group(1) + m.group(2) + m.group(3) + fix_ports(name, m.group(4)) + m.group(5)


v = inst_re.sub(fix_inst, v)
e = v.rindex('endmodule')
v = '`timescale 1ps/1ps\n' + v[:e] + ''.join(extra) + v[e:]
open(vout, 'w').write(v)

# ---- 2. IOPATH-only SDF ---------------------------------------------------
def sexpr(text):
    """Parse SDF into nested lists of atoms (escapes kept in atoms)."""
    tok = re.findall(r'\(|\)|"[^"]*"|(?:\\.|[^\s()"])+', text)
    stack = [[]]
    for t in tok:
        if t == '(':
            stack.append([])
        elif t == ')':
            x = stack.pop()
            stack[-1].append(x)
        else:
            stack[-1].append(t)
    return stack[0][0]


cells = []
for c in sexpr(sdf):
    if not isinstance(c, list) or not c or c[0] != 'CELL':
        continue
    ctype = inst = None
    paths = []
    for x in c[1:]:
        if x[0] == 'CELLTYPE':
            ctype = x[1].strip('"')
        elif x[0] == 'INSTANCE':
            inst = x[1] if len(x) > 1 else ''
        elif x[0] == 'DELAY':
            for ab in x[1:]:
                for io in ab[1:]:
                    if io[0] == 'IOPATH':
                        r = ':'.join(io[3])
                        f = ':'.join(io[4]) if len(io) > 4 else r
                        paths.append((io[1], io[2], r, f))
    if not inst or not paths:
        continue
    name = unesc(inst)
    esc = re.sub(r'([^A-Za-z0-9_])', r'\\\1', name)
    lines = ['        (IOPATH %s %s (%d) (%d))' % (a, b, pick(r), pick(f)) for a, b, r, f in paths]
    cells.append('  (CELL\n    (CELLTYPE "%s")\n    (INSTANCE %s)\n    (DELAY\n      (ABSOLUTE\n%s\n      )\n    )\n  )'
                 % (ctype, esc, '\n'.join(lines)))
open(sout, 'w').write('(DELAYFILE\n  (SDFVERSION "3.0")\n  (DESIGN "top")\n  (VENDOR "nextpnr")\n'
                      '  (PROGRAM "tools/sdf_icarus.py")\n  (DIVIDER .)\n  (TIMESCALE 1ps)\n'
                      + '\n'.join(cells) + '\n)\n')

missing = len(ic) - len(used)
print('sdf_icarus: %d wire delays inserted (%s corner), %d cells with IOPATH delays%s'
      % (len(used), ['min', 'typ', 'max'][corner], len(cells),
         ', %d INTERCONNECT sinks not found in the netlist' % missing if missing else ''))
