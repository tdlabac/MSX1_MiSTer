module cart_ascii16
(
    input            clk,
    input            reset,
    input     [24:0] rom_size,
    input     [15:0] addr,
    input      [7:0] d_from_cpu,
    input            wr,
    input            cs,
    input            slot,
    input            r_type,
    output    [24:0] mem_addr,
    output           sram_we,
    output           sram_oe
);

   wire [24:0] mem_addr_A, mem_addr_B;
   wire        sram_we_A, sram_we_B;
   wire        sram_oe_A, sram_oe_B;

   assign mem_addr = slot ? mem_addr_B : mem_addr_A;
   assign sram_we  = slot ? sram_we_B  : sram_we_A;
   assign sram_oe  = slot ? sram_oe_B  : sram_oe_A; 

   ascii16 ascii16_A
   (
      .mem_addr(mem_addr_A),
      .sram_we(sram_we_A),
      .sram_oe(sram_oe_A),
      .cs(cs & ~slot),
      .*
   );

   ascii16 ascii16_B
   (
      .mem_addr(mem_addr_B),
      .sram_we(sram_we_B),
      .sram_oe(sram_oe_B),
      .cs(cs & slot),
      .*
   );

endmodule


module ascii16
(
    input            clk,
    input            reset,
    input     [24:0] rom_size,
    input     [15:0] addr,
    input      [7:0] d_from_cpu,
    input            wr,
    input            cs,
    input            r_type,
    output    [24:0] mem_addr,
    output           sram_we,
    output           sram_oe
);
   reg  [7:0] bank0, bank1;
   wire [7:0] mask = rom_size[20:13] - 1'd1;
   wire [7:0] sram_mask = rom_size[20:13] > 8'h10 ? rom_size[20:13] : 8'h10;

   initial bank0 = 8'h00;
   initial bank1 = 8'h00;

   always @(posedge clk) begin
      if (reset) begin
         bank0 <= r_type ? 8'h0f : 8'h00;
         bank1 <= 8'h00;
      end else begin
         if (cs && wr) begin
            if (r_type) begin
               if (addr[15:12] == 4'b0111) begin
                  bank1 <= d_from_cpu[4] ? {5'b00010,d_from_cpu[2:0]} : {3'b000,d_from_cpu[4:0]};
               end
            end else begin
               case (addr[15:11])
                  5'b01100: // 6000-67ffh
                     bank0 <= d_from_cpu;
                  5'b01110: // 7000-77ffh
                     bank1 <= d_from_cpu;
               endcase
            end
         end
      end
   end

   wire [7:0] bank_base = addr[15] == 0 ? bank0 : bank1; 

   assign sram_we   = cs & |(bank1 & sram_mask) & addr[15:14] == 2'b10 & wr;
   assign sram_oe   = cs & |(bank_base & sram_mask);

   assign mem_addr  = sram_oe ? addr[12:0] : {(bank_base & mask), addr[13:0]};

endmodule
