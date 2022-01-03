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

endmodule
