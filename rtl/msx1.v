module msx1
(
	input         clk,
	input         ce_10m7,
	input         reset
);


//  -----------------------------------------------------------------------------
//  -- Clock generation
//  -----------------------------------------------------------------------------
wire clk_en_3m58_p, clk_en_3m58_n;
cv_clock clock
(
	.clk_i(clk),
	.clk_en_10m7_i(ce_10m7),
	.reset_n_i(~reset),
	.clk_en_3m58_p_o(clk_en_3m58_p),
	.clk_en_3m58_n_o(clk_en_3m58_n)
);

//  -----------------------------------------------------------------------------
//  -- T80 CPU
//  -----------------------------------------------------------------------------
wire [15:0] a;
wire [7:0] d_to_cpu, d_from_cpu;
wire mreq_n, wr_n, m1_n, iorq_n, rd_n, rfrsh_n, wait_n = 1; 
t80pa #(.Mode(0)) T80
(
	.RESET_n(~reset),
	.CLK(clk),
	.CEN_p(clk_en_3m58_p),
	.CEN_n(clk_en_3m58_n),
	.WAIT_n(wait_n),
	.INT_n(1),
	.NMI_n(1),
	.BUSRQ_n(1),
	.M1_n(m1_n),
	.MREQ_n(mreq_n),
	.IORQ_n(iorq_n),
	.RD_n(rd_n),
	.WR_n(wr_n),
	.RFSH_n(rfrsh_n),
	.HALT_n(1),
	.BUSAK_n(),
	.A(a),
	.DI(d_to_cpu),
	.DO(d_from_cpu)
);

endmodule
