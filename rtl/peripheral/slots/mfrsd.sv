module mapper_mfrsd0
(
   input               clk,
   input               reset,
   input               cs,
   input               cart_num,
   input        [15:0] cpu_addr,
   input        [26:0] base_ram,
   output logic [26:0] mfrsd_base_ram[2],
   output       [22:0] flash_addr,
   output              flash_rq
);
/*verilator tracing_off*/
always @(posedge clk) begin
   if (reset) begin
      mfrsd_base_ram <= '{27'd0,27'd0};
   end else begin
      if (cs) mfrsd_base_ram[cart_num] <= base_ram;
   end

end

assign flash_addr = 23'(cpu_addr[13:0]);
assign flash_rq   = cs;

endmodule

module mapper_mfrsd1
(
   input               clk,
   input               reset, 
   input               cs,
   input         [1:0] slot, 
   input        [15:0] cpu_addr,
   input         [7:0] din,
   input               cpu_mreq,
   input               cpu_wr,
   input               cpu_rd,
   input        [26:0] mfrsd_base_ram,
   output logic  [7:0] configReg,
   output logic  [3:0] mapper_mask,
   output       [26:0] mem_addr,
   output              mem_unmaped,
   output       [22:0] flash_addr,
   output              flash_rq, 
   output              scc_req,
   output              scc_mode
);
/*verilator tracing_off*/
logic [7:0] mapperReg, sccMode;
logic [9:0] offsetReg;

assign mem_unmaped = cs & (~flashAddrValid | scc_req);

always @(posedge clk) begin
   if (reset) begin
      configReg   <= 8'd3;
      mapperReg   <= 8'd0;
      offsetReg   <= 10'd0;
      mapper_mask <= 4'b1111;
      sccMode     <= 8'd0;
   end else begin
      if (cs & cpu_mreq & cpu_wr) begin
         case(cpu_addr)
            16'h7FFC: begin
               if (~configReg[7]) begin
                  configReg <= din;
                  mapper_mask[slot] <= ~din[2];
               end
            end
            16'h7FFD : begin
               if (~mapperReg[1]) begin
                  offsetReg[7:0] <= din;
               end
            end
            16'h7FFE : begin
               if (~mapperReg[1]) begin
                  offsetReg[9:8] <= din[1:0];
               end
            end
            16'h7FFF : begin
               if (~mapperReg[2]) begin
                  mapperReg <= din;
               end
            end
            16'hBFFE,
            16'hBFFF: begin
               if (mapperReg[7:5] == 3'd0) begin
                  sccMode <= din;
               end
            end
            default:;
         endcase
      end
   end
end

wire EN_SCCPLUS     = sccMode[5] & sccBanks[3][7] & cpu_addr[15:8] == 8'hB8;
wire EN_SCC         = ~sccMode[5] & sccBanks[2][5:0] == 6'b111111 & cpu_addr[15:11] == 5'b10011;
wire isRamSegment2  = (sccMode[5] & sccMode[2]) | sccMode[4];
wire isRamSegment3  = sccMode[4];
assign scc_req      = cs & cpu_mreq & (cpu_rd | cpu_wr) & ((cpu_wr & ((EN_SCC & ~isRamSegment2) | (EN_SCCPLUS & ~isRamSegment3))) | (cpu_rd & (EN_SCC | EN_SCCPLUS)));
assign scc_mode     = EN_SCCPLUS;

wire [2:0] page8kB  = cpu_addr[15:13] - 3'd2;
logic [7:0] bank[4], sccBanks[4];
always @(posedge clk) begin
   if (reset) begin
      bank <= '{8'd0,8'd1,8'd2,8'd3};
      sccBanks <= '{8'd0,8'd1,8'd2,8'd3};
   end else begin
      if (cs & cpu_mreq & cpu_wr) begin
         if (~mapperReg[1] & page8kB < 3'd4) begin
            case(mapperReg[7:5])
            3'b000: begin //KONAMI-SCC
               if (cpu_addr[12:11] == 2'b10) begin
                  sccBanks[page8kB[1:0]] <= din;
                  bank[page8kB[1:0]]    <= mapperReg[0] ? din & 8'h3F : din;
               end
            end
            3'b001: begin //Konami
               if (~(mapperReg[3] & (cpu_addr < 16'h6000))) begin
                  if (cpu_addr[15:11] == 5'b01010 /*5000-57ff*/ | cpu_addr[15:13] >= 3'b011 /*6000 - ffff*/) begin
                     bank[page8kB[1:0]] <= mapperReg[0] ? din & 8'h1F : din;
                  end
               end
            end
            
            3'b010,
            3'b011: begin//64kB
               bank[page8kB[1:0]] <= din;
            end
            
            3'b100,
            3'b101: begin //Ascii8
               if (cpu_addr[15:13] == 3'b011 /*6000 - 7fff*/) begin
                  bank[cpu_addr[13:12]] <= din;
               end
            end
            
            3'b110,
            3'b111: begin //Acii16
               if (cpu_addr[15:11] == 5'b01100) begin
                  bank[0] <= {din[6:0],1'b0};
                  bank[1] <= {din[6:0],1'b1};
               end
               if (cpu_addr[15:11] == 5'b01110) begin
                  bank[2] <= {din[6:0],1'b0};
                  bank[3] <= {din[6:0],1'b1};
               end
            end
            default: ;
            endcase
         end
      end
   end
end

wire  [2:0] page      =  mapperReg[7:6] == 2'b01 ? 3'(cpu_addr[15:14]) : cpu_addr[15:13] - 3'd2;
wire [15:0] bankValue = configReg[4] & page[1:0] == 2'b00 & bank[page[1:0]] == 8'd0 ? 16'h3FA :
                        configReg[4] & page[1:0] == 2'b01 & bank[page[1:0]] == 8'd1 ? 16'h3FB :
                                                                                      16'(bank[page[1:0]]) + 16'(offsetReg);
wire flashAddrValid   = page < 3'd4;
assign flash_addr     = 23'h010000 + 23'(mapperReg[7:6] == 2'b01 ? {bankValue, cpu_addr[13:0]} : {1'b0,bankValue, cpu_addr[12:0]});
assign flash_rq       = cs & flashAddrValid;
assign mem_addr       = mfrsd_base_ram + 27'(flash_addr);

endmodule

module mapper_mfrsd2
(
   input              clk,
   input              reset, 
   input       [15:0] cpu_addr,
   input        [7:0] cpu_dout,
   output       [7:0] mapper_dout,
   input              cpu_wr,
   input              cpu_rd,
   input              cpu_iorq,
   input              cpu_m1,
   input              en,
   output      [21:0] mem_addr
);
/*verilator tracing_off*/
msx2_ram_mapper ram_mapper
(
    .mapper_dout(mapper_dout),
    .mapper_addr(mem_addr),
    .ram_block_count(8'd32),
    .*
);

endmodule

module mapper_mfrsd3
(
   input              clk,
   input              reset, 
   input              cs,
   input       [15:0] cpu_addr,
   input        [7:0] din,
   output       [7:0] mapper_dout,
   input              cpu_mreq,
   input              cpu_wr,
   input              cpu_rd,
   input       [26:0] mfrsd_base_ram,
   input        [7:0] configReg,
   output      [26:0] mem_addr,
   output      [22:0] flash_addr,
   output             mem_unmaped,
   output       logic sd_rx,
   output       logic sd_tx,
   input        [7:0] d_from_sd,
   output             flash_rq,
   output             debug_sd_card
);
/*verilator tracing_off*/
assign debug_sd_card = sd_card_data_en;

logic [7:0] bank[4];

always @(posedge clk) begin
   if (reset) begin
      bank <= '{8'd0, 8'd1, 8'd0, 8'd0};
   end else begin
      if (cs & cpu_mreq & cpu_wr & cpu_addr[15:13] == 3'd3) begin // 6000 - 7fff
         if (bank[cpu_addr[12:11]] != din) begin
            bank[cpu_addr[12:11]] <= din;
         end
      end
   end
end


wire  [1:0] page       = {cpu_addr[15] ^ cpu_addr[14] ? cpu_addr[15] : ~cpu_addr[15], cpu_addr[13]};

assign flash_addr      = 23'h700000 + 23'({bank[page][6:0],13'd0}) + 23'(cpu_addr[12:0]);
assign mem_addr        = mfrsd_base_ram + 27'(flash_addr);
wire   mem_valid       = (cpu_addr[15:14] == 2'b01 | cpu_addr[15:14] == 2'b10);
wire   sd_card_en      = cs & bank[0][7:6] == 2'b01 & cpu_addr[15:13] == 3'b010; // 4000 - 5FFF
wire   sd_card_data_en = sd_card_en & cpu_mreq & cpu_rd;
assign mem_unmaped     = cs & (~mem_valid | sd_card_data_en);

assign mapper_dout = sd_card_data_en & ~cpu_addr[12] ? d_from_sd  : 8'hFF;
assign flash_rq    =  cs & mem_valid & configReg[0];

always @(posedge clk) begin
   logic old_wr, old_rd, select_sd;
   sd_rx <= 1'b0;
   sd_tx <= 1'b0;
   if (~old_rd & cs & cpu_mreq & cpu_rd & sd_card_en) sd_rx <= ~select_sd & ~cpu_addr[12];
   if (~old_wr & cs & cpu_mreq & cpu_wr & sd_card_en) begin
      if (cpu_addr[15:11] == 5'b01011) // >= 5800
         select_sd <= din[0];
      else
         sd_tx <= ~select_sd & ~cpu_addr[12];
   end
   old_rd <= cpu_rd & cpu_mreq;
   old_wr <= cpu_wr & cpu_mreq;
end

endmodule