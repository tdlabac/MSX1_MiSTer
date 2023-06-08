module scc_sound
(
   input                clk,
   input                clk_en,
   input                reset,
   input                cart_num,
   input                cs,
   input          [1:0] oe,
   input                cpu_wr,
   input                cpu_mreq,
   input          [7:0] cpu_addr,
   input          [7:0] din,
   output         [7:0] scc_dout,
   output signed [15:0] wave,
   input          [1:0] sccPlusChip,
   input          [1:0] sccPlusMode
);
/*verilator tracing_off*/
wire signed [14:0] wave_A, wave_B;

assign scc_dout = scc_dout_A & scc_dout_B;
assign wave = (oe[0] ? {wave_A[14],wave_A}   : 16'd0) +
              (oe[1] ? {wave_B[14],wave_B}   : 16'd0) ;


wire [7:0] scc_dout_A;
scc_wave scc_wave_A
(
   .clk(clk),
   .clkena(clk_en),
   .reset(reset),
   .req(~cart_num & cs),   
   .ack(),
   .wrt(cpu_wr & cpu_mreq),
   .adr(cpu_addr),
   .dbo(din),
   .dbi(scc_dout_A),
   .wave(wave_A),
   .sccPlusChip(sccPlusChip[0]),
   .sccPlusMode(sccPlusMode[0])
);

wire [7:0] scc_dout_B;
scc_wave scc_wave_B
(
   .clk(clk),
   .clkena(clk_en),
   .reset(reset),
   .req(cart_num & cs),   
   .ack(),
   .wrt(cpu_wr & cpu_mreq),
   .adr(cpu_addr),
   .dbo(din),
   .dbi(scc_dout_B),
   .wave(wave_B),
   .sccPlusChip(sccPlusChip[1]),
   .sccPlusMode(sccPlusMode[1])
);
endmodule