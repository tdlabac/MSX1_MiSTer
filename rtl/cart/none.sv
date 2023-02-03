module cart_none
(
   input     [15:0] addr,
   input      [3:0] rom_offset,
   input            cs,
   output    [24:0] mem_addr,
   output           mem_oe
);

assign mem_addr  = addr - {rom_offset,12'd0};
assign mem_oe = cs;
endmodule