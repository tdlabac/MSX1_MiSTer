module io_decoder
(
	input  [7:0] addr,
	input	       iorq_n,
	input	       m1_n,
	output       vdp_n,
	output       psg_n,
	output       ppi_n,
	output       cen_n
);

wire io_en = ~iorq_n & m1_n;

assign cen_n = ~((addr[7:3] == 5'b10010) & io_en);
assign vdp_n = ~((addr[7:3] == 5'b10011) & io_en);
assign psg_n = ~((addr[7:3] == 5'b10100) & io_en);
assign ppi_n = ~((addr[7:3] == 5'b10101) & io_en);

endmodule
