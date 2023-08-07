`timescale 10ns / 1ns

module tb;

// ---------------------------------------------------------------------
reg clock;
reg reset_n;

always #0.5 clock = ~clock;     // 100 Mhz

initial begin reset_n = 1'b0; clock = 1'b1; #1.5 reset_n = 1; #2000 $finish; end
initial begin $dumpfile("tb.vcd"); $dumpvars(0, tb); end
initial begin $readmemh("tb.hex", ram, 0); end
// ---------------------------------------------------------------------

reg  [ 7:0] ram[65536];
wire [15:0] address;
reg  [ 7:0] in;
wire [ 7:0] out;
wire        we;
wire        rd;

always @(negedge clock) begin in <= ram[address]; if (we) begin in <= out; ram[address] <= out; end end

// ---------------------------------------------------------------------

c6502 CPU
(
    .clock      (clock),
    .ce         (1'b1),
    .reset_n    (reset_n),
    .address    (address),
    .in         (in),
    .out        (out),
    .rd         (rd),
    .we         (we)
);

endmodule
