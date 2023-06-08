module cart_konami_scc
(
   input            clk,
   input            reset,
   input     [24:0] mem_size,
   input     [15:0] cpu_addr,
   input      [7:0] din,
   input            cpu_mreq,
   input            cpu_wr,
   input            cpu_rd,
   input            cs,
   input            cart_num,
   input            sccDevice,     // 0-SCC 1-SCC+
   output           mem_unmaped,
   output    [20:0] mem_addr,
   output           scc_req,
   output    [1:0]  scc_mode
);
   /*verilator tracing_off*/
   logic [7:0] sccMode[2];
   logic [7:0] bank[2][4];
   logic [1:0] sccEnable;
   always @(posedge clk) begin
      if (reset) begin
         bank        <= '{'{'h00, 'h01, 'h02, 'h03},'{'h00, 'h01, 'h02, 'h03}};
         sccMode     <= '{'h00,'h00};
         sccEnable   <= 2'b00;
      end else begin
         if (cs & cpu_mreq & cpu_wr) begin

            case (cpu_addr[15:11])
               5'b01010: // 5000-57ffh
                     bank[cart_num][2'd0] <= din;
               5'b01110: // 7000-77ffh
                     bank[cart_num][2'd1] <= din;
               5'b10010: // 9000-97ffh
                     bank[cart_num][2'd2] <= din;
               5'b10110: // b000-b7ffh
                     bank[cart_num][2'd3] <= din;
               default: ;
            endcase
            if ({cpu_addr[15:1],1'b0} == 16'hBFFE & sccDevice)  sccMode[cart_num] <= din;
            if (cpu_addr[15:11]       == 5'b10010 & ~sccDevice) sccEnable[cart_num] <= din[5:0] == 6'h3F;
         end
      end
   end

   assign scc_mode = { sccDevice & sccMode[1][5] & bank[1][3][7], sccDevice & sccMode[0][5] & bank[0][3][7]};
   assign scc_req  = cpu_mreq & (cpu_rd | cpu_wr) &
                     ((sccMode[cart_num][5] & bank[cart_num][3][7] & cpu_addr[15:8] == 8'hB8)                    ||   //SCC+
                     (~sccMode[cart_num][5] & bank[cart_num][2][5:0] == 6'b111111 & cpu_addr[15:11] == 5'b10011) ||   //SCC+ mode SCC
                     (~sccDevice && sccEnable[cart_num] & cpu_addr[15:11] == 5'b10011));                              //SCC

   wire maped, en_ram;
   wire [7:0] bank_base;
   assign {maped, en_ram, bank_base} = cpu_addr[15:13] == 3'b010 ? {1'b1,(sccMode[cart_num][4] | sccMode[cart_num][0]                         ),bank[cart_num][0]} :   //4000 - 5FFF
                                       cpu_addr[15:13] == 3'b011 ? {1'b1,(sccMode[cart_num][4] | sccMode[cart_num][1]                         ),bank[cart_num][1]} :   //6000 - 7FFF
                                       cpu_addr[15:13] == 3'b100 ? {1'b1,(sccMode[cart_num][4] | (sccMode[cart_num][5] & sccMode[cart_num][2])),bank[cart_num][2]} :   //8000 - 9FFF
                                       cpu_addr[15:13] == 3'b101 ? {1'b1,(sccMode[cart_num][4]                                                ),bank[cart_num][3]} :   //A000 - BFFF
                                                               10'd0 ;    

   assign mem_unmaped = cs & (scc_req  | ~maped | (cpu_wr & cpu_mreq & ~en_ram));
   assign mem_addr = {bank_base, cpu_addr[12:0]};

endmodule
       