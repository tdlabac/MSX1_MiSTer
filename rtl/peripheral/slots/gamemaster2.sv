module cart_gamemaster2
(
   input            clk,
   input            reset,
   input     [15:0] cpu_addr,
   input      [7:0] din,
   input            cpu_mreq,
   input            cpu_wr,
   input            cs,
   output    [24:0] mem_addr,
   output           sram_we,
   output           sram_cs
);
/*verilator tracing_off*/
logic [5:0] bank1, bank2, bank3;

always @(posedge reset, posedge clk) begin
   if (reset) begin
      bank1 <= 6'h01;
      bank2 <= 6'h02;
      bank3 <= 6'h03;
   end else begin
      if (cs & cpu_mreq & cpu_wr) begin
         case (cpu_addr[15:12])
            4'h6: bank1 <= din[5:0];
            4'h8: bank2 <= din[5:0];
            4'hA: bank3 <= din[5:0];
            default : ;
         endcase
      end
   end
end

wire [7:0] bank_base = cpu_addr[15:13] == 3'b010 ? 8'h00     :
                       cpu_addr[15:13] == 3'b011 ? 8'(bank1) :
                       cpu_addr[15:13] == 3'b100 ? 8'(bank2) : 
                                                   8'(bank3) ;

assign sram_cs   = cs & bank_base[4];
assign mem_addr  = sram_cs ? 25'({bank_base[5], cpu_addr[11:0]}) : 25'({bank_base[3:0], cpu_addr[12:0]});
assign sram_we   = cs & bank_base[4] & cpu_addr[15:12] == 4'hB & cpu_mreq & cpu_wr;

endmodule