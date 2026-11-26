// tb_gate.v - replay the RTL testbench's port trace into videl_synth_top.
//
// The VHDL testbench (tb/tb_videl_core.vhd, generic TRACE) records, once per
// bus_clk cycle, the 107 input bits the core latches and the 71 output bits
// it drives. This bench drives the same inputs into the synthesis wrapper
// (syn/videl_synth_top.vhd) and checks its outputs cycle by cycle, either
//   * against the pre-route netlist (zero delay: checks the trace alignment
//     and that synthesis preserved behaviour), or
//   * against the routed netlist with nextpnr's SDF delays (timing sim).
//
// The wrapper adds one register on every input and output, so with clock
// edges numbered from 1:
//   pins after edge m      = trace_in[m]       (core latches it at m+2)
//   outputs before edge m+1 = trace_out[m-2]   (core drove it after m-1)
// Inputs change HOLD ps after each rising edge; outputs are sampled SAMPLE ps
// before the next rising edge. Expected bits that are x (uninitialised RAM
// in the RTL run) are not checked.
//
// Single clock: bus_clk and pix_clk are the same net, period PERIOD ps.
//
// SPDX-License-Identifier: GPL-2.0-or-later

`timescale 1ps/1ps

// nextpnr renames the routed top level to "top": compile with -DDUT=top.
`ifndef DUT
`define DUT videl_synth_top
`endif

module tb_gate;
  parameter PERIOD = 20000;
  // Inputs change at the falling edge by default. A fixed 1 ns after the
  // rising edge raced the clock tree once the decode was pipelined: the
  // inputs reached the input registers before the clock did.
  parameter HOLD   = PERIOD / 2;
  parameter SAMPLE = 100;
  parameter MAXCYC = 100000;
  // Power-up: VHDL integer signals start at 0, Verilog regs in the pre-route
  // netlist start at x and only become known once reset has passed through
  // the input registers, the core and the output registers (43 cycles for
  // the current trace). Outputs are not checked before trace cycle WARMUP.
  parameter WARMUP = 50;
  parameter SHOW   = 10;     // mismatches printed

  reg  clk = 0;
  reg  [106:0] tin [0:MAXCYC-1];
  reg  [70:0]  tout[0:MAXCYC-1];
  reg  [106:0] pins = 0;
  wire [70:0]  outs;
  integer n, m, errors, checked, first_err, vcdcyc;
  reg  [70:0] want, mask;
  reg  [1023:0] in_file, out_file, sdf_file;

  `DUT dut (
    .bus_clk(clk), .pix_clk(clk),
    .rst(pins[106]), .monitor(pins[105:104]), .wr(pins[103]),
    .addr(pins[102:81]), .be(pins[80:77]), .wdata(pins[76:45]),
    .line_start(pins[44]), .line_y(pins[43:33]), .line_bank(pins[32]),
    .mem_ack(pins[31]), .mem_valid(pins[30]), .mem_data(pins[29:14]),
    .in_valid(pins[13]), .in_border(pins[12]), .in_bank(pins[11]),
    .in_x(pins[10:0]),
    .geom_fold(outs[70:63]), .line_done(outs[62]), .mem_req(outs[61]),
    .mem_addr(outs[60:37]), .mem_words(outs[36:26]), .mem_ready(outs[25]),
    .out_valid(outs[24]), .out_rgb(outs[23:0]));

  always #(PERIOD/2) clk = ~clk;

  initial begin
    if (!$value$plusargs("in=%s", in_file))   in_file  = "trace_in.txt";
    if (!$value$plusargs("out=%s", out_file)) out_file = "trace_out.txt";
    for (n = 0; n < MAXCYC; n = n + 1) tin[n] = {107{1'bz}};
    $readmemb(in_file, tin);
    $readmemb(out_file, tout);
    for (n = 0; n < MAXCYC && tin[n][0] !== 1'bz; n = n + 1) ;
    if (n == 0) begin $display("no trace in %0s", in_file); $finish; end
    if ($value$plusargs("sdf=%s", sdf_file)) begin
      $display("annotating %0s", sdf_file);
      $sdf_annotate(sdf_file, dut);
    end
    // debug: +vcd=N dumps the DUT's top-level nets (all nets of a flat
    // netlist) to gate.vcd for the first N cycles
    if (!$value$plusargs("vcd=%d", vcdcyc)) vcdcyc = 0;
    if (vcdcyc > 0) begin
      $dumpfile("gate.vcd");
      $dumpvars(1, dut);
    end
    $display("%0d cycles, period %0d ps", n, PERIOD);
    errors = 0; checked = 0; first_err = -1;
    pins = tin[0];
    for (m = 1; m < n; m = m + 1) begin
      @(posedge clk);
      if (m == vcdcyc) $dumpoff;
      #(HOLD) pins = tin[m];
      #(PERIOD - HOLD - SAMPLE);
      if (m >= 2 + WARMUP) begin
        want = tout[m - 2];
        mask = ~(want ^ want);            // 1 where the expected bit is 0/1
        // out_rgb means something only with out_valid. Otherwise it is the
        // free-running palette RAM output, and a palette write in the same
        // cycle as that read (a two-clock RAM collision) may give either
        // value at gate level.
        if (want[24] !== 1'b1) mask[23:0] = 24'd0;
        checked = checked + 1;
        if (((outs ^ want) & mask) !== 71'd0) begin
          errors = errors + 1;
          if (errors <= SHOW)
            $display("cycle %0d: got %b\n          want %b", m - 2, outs, want);
          if (first_err < 0) first_err = m - 2;
        end
      end
    end
    $display("%0d cycles checked, %0d mismatches", checked, errors);
    if (errors == 0) $display("PASSED"); else $display("FAILED (first at trace cycle %0d)", first_err);
    $finish;
  end
endmodule
