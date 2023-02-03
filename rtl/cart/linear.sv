module cart_linear
(
   input     [15:0] addr,
   input            cs,
   input     [24:0] rom_size,
   output    [24:0] mem_addr,
   output           mem_oe
);

assign mem_addr  = addr & (rom_size - 1'b1);
assign mem_oe = cs;
endmodule