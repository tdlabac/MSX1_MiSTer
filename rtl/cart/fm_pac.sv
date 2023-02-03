module cart_fm_pac
(
   input            clk,
   input            clk_en,
   input            reset,
   input     [15:0] addr,
   input      [7:0] d_from_cpu,
   output     [7:0] d_to_cpu,  
   input            cs,
   input            wr,
   input            rd,
   input            iorq,
   input            m1,
   output signed [15:0] sound,
   output           cart_oe,  //Output data
   output           sram_we,
   output           sram_oe,  //Output sram
   output    [14:0] sram_addr,
   output    [24:0] mem_addr,
   output           mem_oe
);

logic [7:0] enable     = 8'h00;
logic [1:0] bank       = 2'b00;
logic [7:0] magicLo    = 8'h00;
logic [7:0] magicHi    = 8'h00;

//wire fm = addr[7:1] == 7'b0111110 & iorq & ~m1;
wire   sramEnable = {magicHi,magicLo} == 16'h694D;

assign {cart_oe, d_to_cpu} = addr[13:0] == 14'h3FF6              ? {cs, enable}            :
                             addr[13:0] == 14'h3FF7              ? {cs, 6'b000000, bank}   :
                             addr[13:0] == 14'h1FFE & sramEnable ? {cs, magicLo}           :
                             addr[13:0] == 14'h1FFF & sramEnable ? {cs, magicHi}           :
                                                                   {1'b0, 8'hFF}           ;
reg opll_wr = 0;
wire io_wr  = wr & addr[7:1] == 7'b0111110 & iorq & ~m1;

always @(posedge reset, posedge clk) begin
   if (reset) begin
      enable  <= 8'h00;
      bank    <= 2'b00;
      magicLo <= 8'h00;
      magicHi <= 8'h00;
   end else begin
      opll_wr <= 1'b0;
      if (cs & wr) begin
         case (addr[13:0]) 
            14'h1FFE:
               if (~enable[4]) 
                  magicLo   <= d_from_cpu;
            14'h1FFF:
               if (~enable[4]) 
                  magicHi   <= d_from_cpu;
            14'h3FF4,
            14'h3FF5: begin
               opll_wr <= 1'b1;
            end
            14'h3FF6: begin
               enable <= d_from_cpu & 8'h11;
               if (enable[4]) begin
                  magicLo <= 0;
                  magicHi <= 0;
               end
            end
            14'h3FF7: begin
               bank <=d_from_cpu[1:0];
            end
         endcase
      end
   end
end

assign sram_oe    = cs & sramEnable & ~addr[13];
assign sram_we    = sram_oe & wr;
assign sram_addr  = {2'b00,addr[12:0]};
assign mem_addr   = {bank, addr[13:0]};
assign mem_oe     = cs; //addr[15:14] == 2'b01;

jt2413 opll
(
   .rst(reset),
   .clk(clk),
   .cen(clk_en),
   .din(d_from_cpu),
   .addr(addr[0]),
   .cs_n(1'b0),
   .wr_n(~(io_wr | opll_wr)),
   .snd(sound)
);

endmodule