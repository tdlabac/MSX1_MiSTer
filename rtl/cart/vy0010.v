module vy0010
(
    input            clk,
	 input     [15:0] addr,
	 output     [7:0] d_to_cpu
);

assign d_to_cpu = addr[15:14] == 2'b01 ? d_from_rom : 8'hFF;

wire [7:0] d_from_rom;

spram #(.addr_width(14), .mem_init_file("rtl/rom/vy0010.mif"), .mem_name("VY0010ROM")) vy0010_rom
(
   .clock(clk),
   .address(addr[13:0]),
   .wren(0),
   .q(d_from_rom)
);

endmodule
