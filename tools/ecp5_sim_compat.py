#!/usr/bin/env python3
"""Make Yosys's ECP5 simulation models usable for nextpnr routed netlists.

Usage: python3 -I tools/ecp5_sim_compat.py <yosys>/share/yosys/ecp5/cells_sim.v OUT.v

Writes a patched copy of cells_sim.v (the original is not touched). Found with
Yosys 0.52 + nextpnr-ecp5 0.9 (Ubuntu packages); see
docs/design/videl-core-methodology.md, "Gate-level timing simulation".

1. Unrouted inputs. nextpnr leaves an unused fabric input unconnected and
   records the value it needs in the cell's *MUX parameter ("INV" on an open
   pin means 0). On ECP5 an unrouted fabric input reads 1. The models
   turn the z into x, so here an open fabric input reads 1: LUT inputs
   A-D and the LUT5 mux select M of TRELLIS_COMB, and every DP16KD pin.
   The carry-in FCI is a dedicated wire, not fabric; an open FCI at the
   start of a chain reads 0. (For the Videl core, open FCI and M give the
   same result read as 0 or 1, so only the LUT-input level is confirmed.)
2. TRELLIS_FF: nextpnr's SD parameter (SD="0": D from M, SD="1": from DI)
   is missing from the model, which always uses DI.
3. TRELLIS_IO: accept DATAMUX_ODDR / DATAMUX_MDDR (only "PADDO" is used).
4. DCCA (global clock buffer) has no model: added.
5. DP16KD has no behaviour in the model (ports and parameters only):
   replaced by a behavioural model for equal port widths 1/2/4/9/18,
   NOREG/OUTREG, NORMAL/WRITETHROUGH/READBEFOREWRITE, CSDECODE, SYNC/ASYNC
   output reset, byte enables in 18-bit mode. INITVAL must be all zero
   (other contents are reported, not loaded).
6. TRELLIS_COMB in CCU2 mode declares a local "wire FCO" that shadows the
   FCO output, so carries between slices are never driven (z).
7. TRELLIS_COMB chooses its OFX mux (L6MUX21 or PFUMX) by IS_Z1, which
   nextpnr 0.9 does not write: chosen by whether FXA/FXB are connected.
8. Path delays: plain specify paths for every IOPATH nextpnr writes
   (TRELLIS_COMB, DP16KD and DCCA have none; TRELLIS_FF's are conditional),
   so tools/sdf_icarus.py's SDF can annotate them.
The pre-route vs routed comparison in hdl/videl/syn/gatesim.sh is the check
that these readings are right: any wrong guess shows up as a mismatch.
"""
import re
import sys

src, dst = sys.argv[1], sys.argv[2]
s = open(src).read()


def module_span(name):
    a = s.index('module %s(' % name)
    b = s.index('endmodule', a) + len('endmodule')
    return a, b


def replace_module(name, fn):
    global s
    a, b = module_span(name)
    s = s[:a] + fn(s[a:b]) + s[b:]


# 2. TRELLIS_FF
def ff(body):
    # 8. one plain CLK => Q path, so nextpnr's (IOPATH CLK Q) binds (the
    #    model's paths are conditional and name DI, not the SD-selected D)
    a = body.index('\tspecify')
    b = body.index('endspecify', a) + len('endspecify')
    body = body[:a] + '\tspecify\n\t\t(CLK => Q) = 0;\n\tendspecify' + body[b:]
    body = body.replace('Q <= DI;', 'Q <= D;')
    assert body.count('Q <= D;') == 2, 'TRELLIS_FF model changed'
    return body.replace('\tparameter GSR = "ENABLED";',
                        '\tparameter GSR = "ENABLED";\n\tparameter SD = "1";\n'
                        '\twire D = (SD == "0") ? M : DI;', 1)


# 1. TRELLIS_COMB open inputs
def comb(body):
    # 6. CCU2 mode declares a local "wire FCO = ..." that shadows the FCO
    #    output port, so the port is never driven: carry chains between
    #    slices read z. Assign the port instead.
    assert body.count('wire FCO =') == 1, 'TRELLIS_COMB model changed'
    body = body.replace('wire FCO =', 'assign FCO =')
    # 7. OFX is the L6MUX of FXA/FXB in the second COMB of a slice and the
    #    PFUMX of F1/F in the first. The model picks by IS_Z1, which nextpnr
    #    0.9 does not write; pick by whether FXA/FXB are connected instead.
    m = re.search(r'\s*if \(IS_Z1\)\s*L6MUX21 lutx_mux \(\.D0\(FXA\), \.D1\(FXB\), '
                  r'\.SD\(M\), \.Z\(OFX\)\);\s*else\s*PFUMX lut5_mux \(\.ALUT\(F1\), '
                  r'\.BLUT\(F\), \.C0\(M\), \.Z\(OFX\)\);', body)
    assert m, 'TRELLIS_COMB model changed (OFX mux)'
    body = body[:m.start()] + """
\t\twire ofx_l6, ofx_pfu;
\t\tL6MUX21 lutx_mux (.D0(FXA), .D1(FXB), .SD(M), .Z(ofx_l6));
\t\tPFUMX lut5_mux (.ALUT(F1), .BLUT(F), .C0(M), .Z(ofx_pfu));
\t\tassign OFX = (IS_Z1 || FXA !== 1'bz || FXB !== 1'bz) ? ofx_l6 : ofx_pfu;""" + body[m.end():]
    body = body.replace(': FCI;', ': FCI_;').replace('(l4o & FCI)', '(l4o & FCI_)')
    body = body.replace('.SD(M)', '.SD(M_)').replace('.C0(M)', '.C0(M_)')
    for x in 'ABCD':
        body = body.replace('.%s(%s)' % (x, x), '.%s(%s_)' % (x, x))
    body = body.replace('{A, C, B, D}', '{A_, C_, B_, D_}')
    assert body.count('FCI_') == 2 and body.count('M_)') == 2, 'TRELLIS_COMB model changed'
    assert body.count('.A(A_)') == 3 and 'A_, C_' in body, 'TRELLIS_COMB model changed'
    # 8. path delays for nextpnr's IOPATHs (the model has none)
    paths = [(i, 'F') for i in ('A', 'B', 'C', 'D', 'FCI')]
    paths += [(i, 'FCO') for i in ('A', 'B', 'FCI')]
    paths += [(i, 'OFX') for i in ('A', 'B', 'C', 'D', 'M', 'F1', 'FXA', 'FXB')]
    spec = '\tspecify\n' + ''.join('\t\t(%s => %s) = 0;\n' % p for p in paths) + '\tendspecify\n'
    e = body.rindex('endmodule')
    body = body[:e] + spec + body[e:]
    decl = "\twire FCI_ = (FCI === 1'bz) ? 1'b0 : FCI;\n"
    decl += ''.join("\twire %s_ = (%s === 1'bz) ? 1'b1 : %s;\n" % (x, x, x)
                    for x in ('A', 'B', 'C', 'D', 'M'))
    p = body.index('\tparameter MODE')
    return body[:p] + decl + body[p:]


# 3. TRELLIS_IO
def io(body):
    p = body.index('\tparameter DIR = "INPUT";')
    return (body[:p] + '\tparameter DATAMUX_ODDR = "PADDO";\n'
            '\tparameter DATAMUX_MDDR = "PADDO";\n' + body[p:])


replace_module('TRELLIS_FF', ff)
replace_module('TRELLIS_COMB', comb)
replace_module('TRELLIS_IO', io)


# 5. DP16KD: drop the empty model, append a behavioural one
def dp16kd():
    a, b = module_span('DP16KD')
    hdr = s[a:s.index(');', a) + 2]
    params = re.findall(r'parameter\s+(?:\[[^\]]*\]\s*)?(\w+)\s*=\s*([^;]+);', s[a:b])
    out = [hdr]
    for k, v in params:
        out.append('\tparameter %s = %s;' % (k, v.strip()))

    def pin(p):
        mux = p + 'MUX'
        out.append("\twire %s_o = (%s === 1'bz) ? 1'b1 : %s;" % (p, p, p))
        out.append('\twire %s_ = (%s == "INV") ? ~%s_o : (%s == "0" || %s == "0 ") ? 1\'b0 :'
                   ' (%s == "1" || %s == "1 ") ? 1\'b1 : %s_o;'
                   % (p, mux, p, mux, mux, mux, mux, p))

    for port in 'AB':
        for i in range(18):
            pin('DI%s%d' % (port, i))
        for i in range(14):
            pin('AD%s%d' % (port, i))
        for c in ('CE', 'OCE', 'WE', 'RST', 'CS0', 'CS1', 'CS2'):
            pin(c[:-1] + port + c[-1] if c.startswith('CS') else c + port)
        pin('CLK' + port)
    out.append('''
\treg mem [0:18431];
\tinteger k;
\tinitial begin
\t\tfor (k = 0; k < 18432; k = k + 1) mem[k] = 1'b0;
\t\tif ({INITVAL_00, INITVAL_01, INITVAL_02, INITVAL_03} !== 0 ||
\t\t    {INITVAL_10, INITVAL_20, INITVAL_30, INITVAL_3F} !== 0)
\t\t\t$display("%m: DP16KD INITVAL contents are not modelled (RAM starts at 0)");
\t\tif (DATA_WIDTH_A != DATA_WIDTH_B)
\t\t\t$display("%m: DP16KD mixed port widths are not modelled");
\tend
\tfunction integer lsb(input integer w);
\t\tlsb = (w == 1) ? 0 : (w == 2) ? 1 : (w == 4) ? 2 : (w == 9) ? 3 : 4;
\tendfunction
\tfunction [2:0] csdec(input [8*5-1:0] t);   // "0b101" -> 3'b101
\t\tcsdec = {t[23:16] == "1", t[15:8] == "1", t[7:0] == "1"};
\tendfunction''')
    for P in 'AB':
        di = '{' + ', '.join('DI%s%d_' % (P, i) for i in range(17, -1, -1)) + '}'
        ad = '{' + ', '.join('AD%s%d_' % (P, i) for i in range(13, -1, -1)) + '}'
        out.append('''
\twire [17:0] di{P} = {di};
\twire [13:0] ad{P} = {ad};
\twire sel{P} = CE{P}_ && ({{CS{P}2_, CS{P}1_, CS{P}0_}} == csdec(CSDECODE_{P}));
\tinteger base{P}, w{P}, i{P};
\treg [17:0] q{P} = 18'd0, r{P} = 18'd0;
\talways @(posedge CLK{P}_ or posedge RST{P}_) begin
\t\tif (RST{P}_ && (RESETMODE == "ASYNC")) q{P} <= 18'd0;
\t\telse if (CLK{P}_ === 1'b1) begin
\t\t\tw{P} = DATA_WIDTH_{P};
\t\t\tbase{P} = (ad{P} >> lsb(w{P})) * w{P};
\t\t\tif (RST{P}_) q{P} <= 18'd0;
\t\t\telse if (sel{P}) begin
\t\t\t\tif (!WE{P}_ || WRITEMODE_{P} == "READBEFOREWRITE")
\t\t\t\t\tfor (i{P} = 0; i{P} < 18; i{P} = i{P} + 1)
\t\t\t\t\t\tq{P}[i{P}] <= (i{P} < w{P}) ? mem[base{P} + i{P}] : 1'b0;
\t\t\t\telse if (WRITEMODE_{P} == "WRITETHROUGH")
\t\t\t\t\tq{P} <= di{P} & ((18'd1 << w{P}) - 1);
\t\t\t\tif (WE{P}_)
\t\t\t\t\tfor (i{P} = 0; i{P} < w{P}; i{P} = i{P} + 1)
\t\t\t\t\t\tif (w{P} != 18 || (i{P} < 9 ? ad{P}[0] : ad{P}[1]))
\t\t\t\t\t\t\tmem[base{P} + i{P}] <= di{P}[i{P}];
\t\t\tend
\t\tend
\tend
\talways @(posedge CLK{P}_) if (OCE{P}_) r{P} <= RST{P}_ ? 18'd0 : q{P};
\twire [17:0] do{P} = (REGMODE_{P} == "OUTREG") ? r{P} : q{P};
\tassign {{{dos}}} = do{P};'''.format(P=P, di=di, ad=ad,
            dos=', '.join('DO%s%d' % (P, i) for i in range(17, -1, -1))))
    out.append('\tspecify')
    for P in 'AB':
        for i in range(18):
            out.append('\t\t(CLK%s => DO%s%d) = 0;' % (P, P, i))
    out.append('\tendspecify')
    out.append('endmodule')
    return a, b, '\n'.join(out)


a, b, model = dp16kd()
s = s[:a] + '// DP16KD: see the end of this file (behavioural replacement)' + s[b:]
s += '\n\n// Added by tools/ecp5_sim_compat.py\n' + model + '''

// Added by tools/ecp5_sim_compat.py: global clock buffer with enable.
module DCCA(input CLKI, input CE, output CLKO);
\tassign CLKO = CLKI & (CE !== 1'b0);
\tspecify
\t\t(CLKI => CLKO) = 0;
\tendspecify
endmodule
'''
open(dst, 'w').write(s)
