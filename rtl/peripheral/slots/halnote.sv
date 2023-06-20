module mapper_halnote
(
   input               clk,
   input               reset,
   input        [15:0] cpu_addr,
   input         [7:0] din,
   input               cpu_mreq,
   input               cpu_wr,
   input               cs,
   output              mem_unmaped,
   output       [24:0] mem_addr
);

logic [7:0] subBank[2], bank[4];
logic       subMapperEnabled;
logic       sramEnabled;

wire  [1:0] bank_num = {cpu_addr[15],cpu_addr[13]};

always @(posedge clk) begin
   if (reset) begin
      subBank          <= '{default: '0};
      bank             <= '{default: '0};
      subMapperEnabled <= 1'b0;
      sramEnabled      <= 1'b0;
   end else begin
      if (cpu_addr[10:0] == 11'b111_1111_1111 & cpu_wr & cpu_mreq) begin
         if (cpu_addr[15:12] == 4'b0111) begin
            subBank[cpu_addr[13]] <= din;
         end else begin
            if (cpu_addr[12] ==  1'b0) begin
               bank[bank_num] <= din;
               if (bank_num == 2'd0) sramEnabled      <= din[7];
               if (bank_num == 2'd1) subMapperEnabled <= din[7];
            end
         end
      end
   end
end

assign mem_addr = subMapperEnabled & cpu_addr[15:12] == 4'h7 ? 25'h80000 + 25'({subBank[cpu_addr[11]],cpu_addr[10:0]}) :
                                                               25'({bank[bank_num],cpu_addr[12:0]})                                   ;
assign mem_unmaped = cs & ~^cpu_addr[15:14];

wire   sram_en     = cs & sramEnabled & cpu_addr[15:14] == 2'b00;

endmodule