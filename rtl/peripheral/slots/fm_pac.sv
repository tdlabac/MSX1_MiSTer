module cart_fm_pac
(
   input                clk,
   input                reset,
   input         [15:0] addr,
   input          [7:0] d_from_cpu,
   output         [7:0] d_to_cpu,  
   input                cs,
   input                slot,
   input                wr,
   input                rd,
   input                mreq,
   output               cart_oe,  //Output data
   output               sram_we,
   output               sram_oe,  //Output sram
   output               mem_unmaped,
   output        [24:0] mem_addr,
   output         [1:0] opll_wr, 
   output         [1:0] opll_io_enable
);

    wire [24:0] mem_addr_A, mem_addr_B;
    wire  [7:0] d_to_cpu_A, d_to_cpu_B;
    wire        sram_we_A, sram_we_B;
    wire        sram_oe_A, sram_oe_B;
    wire        cart_oe_A, cart_oe_B;
    wire        opll_io_enable_A, opll_io_enable_B;

    assign d_to_cpu = slot ? d_to_cpu_B : d_to_cpu_A;
    assign mem_addr = slot ? mem_addr_B : mem_addr_A;
    assign sram_we  = slot ? sram_we_B  : sram_we_A;
    assign sram_oe  = slot ? sram_oe_B  : sram_oe_A;  
    assign cart_oe  = slot ? cart_oe_B  : cart_oe_A;
        
    assign mem_unmaped     = cs & ((addr < 16'h4000 | addr >= 16'h8000));
    assign opll_io_enable  = {opll_io_enable_B, opll_io_enable_A};

    fm_pac fm_pac_A
    (
        .d_to_cpu(d_to_cpu_A),
		  .cart_oe(cart_oe_A),
        .mem_addr(mem_addr_A),
        .sram_we(sram_we_A),
        .sram_oe(sram_oe_A),
        .cs(cs & ~slot),
        .opll_io_enable(opll_io_enable_A),
        .opll_wr(opll_wr[0]),
        .*
    );

    fm_pac fm_pac_B
    (
        .d_to_cpu(d_to_cpu_B),
		  .cart_oe(cart_oe_B),
        .mem_addr(mem_addr_B),
        .sram_we(sram_we_B),
        .sram_oe(sram_oe_B),
        .cs(cs & slot),
        .opll_io_enable(opll_io_enable_B),
        .opll_wr(opll_wr[1]),
        .*
    );

endmodule


module fm_pac
(
   input                clk,
   input                reset,
   input         [15:0] addr,
   input          [7:0] d_from_cpu,
   output         [7:0] d_to_cpu,  
   input                cs,
   input                wr,
   input                rd,
   input                mreq,
   output logic         opll_wr,
   output               opll_io_enable,
   output               cart_oe,  //Output data
   output               sram_we,
   output               sram_oe,  //Output sram
   output        [24:0] mem_addr
);

initial begin
   opll_wr        = 0;
end

logic [7:0] enable     = 8'h00;
logic [1:0] bank       = 2'b00;
logic [7:0] magicLo    = 8'h00;
logic [7:0] magicHi    = 8'h00;

wire   sramEnable = {magicHi,magicLo} == 16'h694D;

assign {cart_oe, d_to_cpu} = addr[13:0] == 14'h3FF6              ? {cs, enable}            :
                             addr[13:0] == 14'h3FF7              ? {cs, 6'b000000, bank}   :
                             addr[13:0] == 14'h1FFE & sramEnable ? {cs, magicLo}           :
                             addr[13:0] == 14'h1FFF & sramEnable ? {cs, magicHi}           :
                                                                   {1'b0, 8'hFF}           ;
assign opll_io_enable = enable[0];

always @(posedge reset, posedge clk) begin
   if (reset) begin
      enable  <= 8'h00;
      bank    <= 2'b00;
      magicLo <= 8'h00;
      magicHi <= 8'h00;
   end else begin
      opll_wr <= 1'b0;
      if (cs & wr & mreq) begin
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
            default: ;
         endcase
      end
   end
end

assign sram_oe    = cs & sramEnable & ~addr[13];
assign sram_we    = sram_oe & wr & mreq;
//assign sram_addr  = {2'b00,addr[12:0]};
//assign mem_addr   = {bank, addr[13:0]};
//assign mem_oe     = cs; //addr[15:14] == 2'b01;

assign mem_addr   = sram_oe ? 25'(addr[12:0]) : 25'({bank, addr[13:0]});

endmodule