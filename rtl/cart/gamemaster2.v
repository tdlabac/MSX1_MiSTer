module cart_gamemaster2
(
   input            clk,
   input            reset,
   input     [15:0] addr,
   input      [7:0] d_from_cpu,
   input            wr,
   input            cs,
   output    [24:0] mem_addr,
   output           mem_oe,
   output    [14:0] sram_addr,
   output           sram_we,
   output           sram_oe
);
reg  [5:0] bank1, bank2, bank3;

always @(posedge reset, posedge clk) begin
   if (reset) begin
      bank1 <= 5'h01;
      bank2 <= 5'h02;
      bank3 <= 5'h03;
   end else begin
      if (cs && wr) begin
         case (addr[15:12])
            4'h6: bank1 <= d_from_cpu[5:0];
            4'h8: bank2 <= d_from_cpu[5:0];
            4'hA: bank3 <= d_from_cpu[5:0];
         endcase
      end
   end
end

wire [7:0] bank_base = addr[15:13] == 3'b010 ? 8'h00 :
                       addr[15:13] == 3'b011 ? bank1 :
                       addr[15:13] == 3'b100 ? bank2 : bank3;

assign mem_addr  = {3'h0, (bank_base[3:0]), addr[12:0]};
assign mem_oe    = cs & ~bank_base[4];                      
assign sram_addr = {2'b00,bank_base[5], addr[11:0]};
assign sram_oe   = cs & bank_base[4];
assign sram_we   = cs & bank_base[4] & addr[15:12] == 4'hB & wr;

endmodule