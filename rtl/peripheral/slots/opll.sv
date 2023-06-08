module opll
(
   input clk,
   input cen,
   input rst,
   input [7:0] din,
   input addr,
   input [2:0] wr,
   input [2:0] cs,
   output signed [15:0] sound
);

/*verilator tracing_off*/

assign sound = (cs[0] ? sound_OPL_A   : 16'd0) +
               (cs[1] ? sound_OPL_B   : 16'd0) +
               (cs[2] ? sound_OPL_int : 16'd0) ;

wire signed [15:0] sound_OPL_int, sound_OPL_A, sound_OPL_B;
jt2413 opll_int
(
   .rst(rst),
   .clk(clk),
   .cen(cen),
   .din(din),
   .addr(addr),
   .cs_n(~cs[2]),
   .wr_n(~wr[2]),
   .snd(sound_OPL_int),
   .sample()
);

jt2413 opll_A
(
   .rst(rst),
   .clk(clk),
   .cen(cen),
   .din(din),
   .addr(addr),
   .cs_n(~cs[0]),
   .wr_n(~wr[0]),
   .snd(sound_OPL_A),
   .sample()
);

jt2413 opll_B
(
   .rst(rst),
   .clk(clk),
   .cen(cen),
   .din(din),
   .addr(addr),
   .cs_n(~cs[1]),
   .wr_n(~wr[1]),
   .snd(sound_OPL_B),
   .sample()
);

endmodule