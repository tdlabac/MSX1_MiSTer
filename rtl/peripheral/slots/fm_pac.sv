module cart_fm_pac
(
   input                clk,
   input                reset,
   input         [15:0] cpu_addr,
   input          [7:0] din,
   output         [7:0] mapper_dout,  
   input                cs,
   input                cart_num,
   input                cpu_wr,
   input                cpu_rd,
   input                cpu_mreq,
   output               sram_we,
   output               sram_cs,
   output               mem_unmaped,
   output        [24:0] mem_addr,
   output         [1:0] opll_wr, 
   output         [1:0] opll_io_enable
);
   /*verilator tracing_off*/
    wire [24:0] mem_addr_A, mem_addr_B;
    wire  [7:0] d_to_cpu_A, d_to_cpu_B;
    wire        sram_we_A, sram_we_B;
    wire        sram_cs_A, sram_cs_B;
    wire        cart_oe_A, cart_oe_B;
    wire        mem_unmaped_A, mem_unmaped_B;
    wire        opll_io_enable_A, opll_io_enable_B;

    assign mem_addr = cart_num ? mem_addr_B : mem_addr_A;
    assign sram_we  = cart_num ? sram_we_B  : sram_we_A;
    assign sram_cs  = cart_num ? sram_cs_B  : sram_cs_A;  
            
    assign mem_unmaped     =  mem_unmaped_A | mem_unmaped_B;
    assign mapper_dout     = d_to_cpu_A & d_to_cpu_B;
    assign opll_io_enable  = {opll_io_enable_B, opll_io_enable_A};

    fm_pac fm_pac_A
    (
        .d_to_cpu(d_to_cpu_A),
		  .cart_oe(cart_oe_A),
        .mem_addr(mem_addr_A),
        .sram_we(sram_we_A),
        .sram_cs(sram_cs_A),
        .cs(cs & ~cart_num),
        .opll_io_enable(opll_io_enable_A),
        .opll_wr(opll_wr[0]),
        .mem_unmaped(mem_unmaped_A),
        .*
    );

    fm_pac fm_pac_B
    (
        .d_to_cpu(d_to_cpu_B),
		  .cart_oe(cart_oe_B),
        .mem_addr(mem_addr_B),
        .sram_we(sram_we_B),
        .sram_cs(sram_cs_B),
        .cs(cs & cart_num),
        .opll_io_enable(opll_io_enable_B),
        .opll_wr(opll_wr[1]),
        .mem_unmaped(mem_unmaped_B),
        .*
    );

endmodule


module fm_pac
(
   input                clk,
   input                reset,
   input         [15:0] cpu_addr,
   input          [7:0] din,
   output         [7:0] d_to_cpu,  
   input                cs,
   input                cpu_wr,
   input                cpu_rd,
   input                cpu_mreq,
   output logic         opll_wr,
   output               opll_io_enable,
   output               cart_oe,
   output               sram_we,
   output               sram_cs,
   output        [24:0] mem_addr,
   output               mem_unmaped
);
/*verilator tracing_off*/
initial begin
   opll_wr        = 0;
end

logic [7:0] enable     = 8'h00;
logic [1:0] bank       = 2'b00;
logic [7:0] magicLo    = 8'h00;
logic [7:0] magicHi    = 8'h00;
logic       last_mreq;

wire   sramEnable = {magicHi,magicLo} == 16'h694D;

assign mem_unmaped     = cs & ((cpu_addr < 16'h4000 | cpu_addr >= 16'h8000)) & cart_oe;

assign {cart_oe, d_to_cpu} = ~cs                                     ? {cs, 8'hFF}             :
                             cpu_addr[13:0] == 14'h3FF6              ? {cs, enable}            :
                             cpu_addr[13:0] == 14'h3FF7              ? {cs, 6'b000000, bank}   :
                             cpu_addr[13:0] == 14'h1FFE & sramEnable ? {cs, magicLo}           :
                             cpu_addr[13:0] == 14'h1FFF & sramEnable ? {cs, magicHi}           :
                                                                       {cs, 8'hFF}             ;
assign opll_io_enable = enable[0];

always @(posedge clk) begin
   if (reset) begin
      enable  <= 8'h00;
      bank    <= 2'b00;
      magicLo <= 8'h00;
      magicHi <= 8'h00;
   end else begin
      opll_wr <= 1'b0;
      if (cs & cpu_wr & cpu_mreq) begin
         case (cpu_addr[13:0]) 
            14'h1FFE:
               if (~enable[4]) 
                  magicLo   <= din;
            14'h1FFF:
               if (~enable[4]) 
                  magicHi   <= din;
            14'h3FF4,
            14'h3FF5: begin
               opll_wr <= 1'b1;
            end
            14'h3FF6: begin
               enable <= din & 8'h11;
               if (enable[4]) begin
                  magicLo <= 0;
                  magicHi <= 0;
               end
            end
            14'h3FF7: begin
               bank <=din[1:0];
            end
            default: ;
         endcase
      end
   end
   last_mreq <= cpu_mreq & (cpu_rd | cpu_wr);
end

assign sram_cs    = cs & sramEnable & ~cpu_addr[13] & ((~last_mreq & cpu_wr) | cpu_mreq & cpu_rd);
assign sram_we    = sram_cs & cpu_wr & cpu_mreq;
assign mem_addr   = sram_cs ? 25'(cpu_addr[12:0]) : 25'({bank, cpu_addr[13:0]});

endmodule