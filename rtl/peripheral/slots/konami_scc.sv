//sccChip = 0 Only ROM mapper and SCC chip management 
//sccChip = 1 RAM mapper and SCC+ 

module cart_konami_scc
(
   input            clk,
   input            reset,
   input     [24:0] mem_size,
   input     [15:0] addr,
   input      [7:0] d_from_cpu,
   input            wr,
   input            rd,
   input            cs,
   input            slot,
   input            sccDevice,     // 0-SCC 1-SCC+
   output           mem_unmaped,
   output    [20:0] mem_addr,
   output           scc_req,
   output    [1:0]  scc_mode
   //output logic [1:0] sccPlusChip
);
   /*verilator tracing_off*/
   logic [7:0] sccMode[2];
   logic [7:0] bank[2][4];
   logic [1:0] sccEnable;
   always @(posedge clk) begin
      if (reset) begin
         bank        <= '{'{'h00, 'h01, 'h02, 'h03},'{'h00, 'h01, 'h02, 'h03}};
         sccMode     <= '{'h00,'h00};
         //sccPlusChip <= 2'b00;
         sccEnable   <= 2'b00;
      end else begin
         if (cs && wr) begin
           // if (sccTyp) sccPlusChip[slot] <= sccTyp;
            case (addr[15:11])
               5'b01010: // 5000-57ffh
                     bank[slot][2'd0] <= d_from_cpu;
               5'b01110: // 7000-77ffh
                     bank[slot][2'd1] <= d_from_cpu;
               5'b10010: // 9000-97ffh
                     bank[slot][2'd2] <= d_from_cpu;
               5'b10110: // b000-b7ffh
                     bank[slot][2'd3] <= d_from_cpu;
               default: ;
            endcase
            if ({addr[15:1],1'b0} == 16'hBFFE & sccDevice)  sccMode[slot] <= d_from_cpu;
            if (addr[15:11]       == 5'b10010 & ~sccDevice) sccEnable[slot] <= d_from_cpu[5:0] == 6'h3F;
         end
      end
   end

   assign scc_mode = { sccDevice & sccMode[1][5] & bank[1][3][7], sccDevice & sccMode[0][5] & bank[0][3][7]};
   assign scc_req  = (rd | wr) &&
                     ((sccMode[slot][5] && bank[slot][3][7] && addr[15:8] == 8'hB8)                    ||   //SCC+
                     (~sccMode[slot][5] && bank[slot][2][5:0] == 6'b111111 && addr[15:11] == 5'b10011) ||   //SCC+ mode SCC
                     (~sccDevice && sccEnable[slot] && addr[15:11] == 5'b10011));                           //SCC

   wire maped, en_ram;
   wire [7:0] bank_base;
   assign {maped, en_ram, bank_base} = addr[15:13] == 3'b010 ? {1'b1,(sccMode[slot][4] | sccMode[slot][0]                     ),bank[slot][0]} :   //4000 - 5FFF
                                       addr[15:13] == 3'b011 ? {1'b1,(sccMode[slot][4] | sccMode[slot][1]                     ),bank[slot][1]} :   //6000 - 7FFF
                                       addr[15:13] == 3'b100 ? {1'b1,(sccMode[slot][4] | (sccMode[slot][5] & sccMode[slot][2])),bank[slot][2]} :   //8000 - 9FFF
                                       addr[15:13] == 3'b101 ? {1'b1,(sccMode[slot][4]                                        ),bank[slot][3]} :   //A000 - BFFF
                                                               10'd0 ;    

   assign mem_unmaped = cs & (scc_req  | ~maped | (wr & ~en_ram));
   assign mem_addr = {bank_base, addr[12:0]};


endmodule
       