module cart_ascii16
(
    input               clk,
    input               reset,
    input        [24:0] rom_size,
    input        [15:0] cpu_addr,
    input         [7:0] din,
    input               cpu_mreq,
    input               cpu_wr,
    input               cs,
    input               cart_num,
    output              mem_unmaped,
    output       [24:0] mem_addr,
    input        [15:0] size_sram,
    output              sram_we,
    output              sram_cs,
    input  mapper_typ_t selected_mapper[2]
);
/*verilator tracing_off*/
logic [7:0] bank0[2], bank1[2];
logic [1:0] sramEnable[2];

wire sram_exist = size_sram > 0;

always @(posedge clk) begin
    if (reset) begin
        
        bank0      <= '{selected_mapper[0] == MAPPER_RTYPE ? 'h0F : 'h00 , selected_mapper[1] == MAPPER_RTYPE ? 'h0F : 'h00};
        bank1      <= '{'h00,'h00};
        sramEnable <= '{2'd0, 2'd0};
    end else begin
        if (cs & cpu_mreq & cpu_wr) begin
            if (selected_mapper[cart_num] == MAPPER_RTYPE) begin
               if (cpu_addr[15:12] == 4'b0111) begin
                  bank1[cart_num] <= din & (din[4] ? 8'h17 : 8'h1F);
               end
            end else begin
                case (cpu_addr[15:11])
                    5'b01100: // 6000-67ffh
                        if (din == 8'h10 && sram_exist) 
                            sramEnable[cart_num][0] <= 1'b1;
                        else begin
                            sramEnable[cart_num][0] <= 1'b0;
                            bank0[cart_num] <= din;
                        end
                    5'b01110: // 7000-77ffh
                        if (din == 8'h10 && sram_exist) 
                            sramEnable[cart_num][1] <= 1'b1;
                        else begin
                            sramEnable[cart_num][1] <= 1'b0;
                            bank1[cart_num] <= din;
                        end
                    default: ;
                endcase
            end
        end
    end
end

wire  [7:0] bank_base = cpu_addr[15] ? bank1[cart_num] : bank0[cart_num];
wire        sram_en   = sramEnable[cart_num][cpu_addr[15]];
wire [24:0] sram_addr = size_sram > 16'd2 ? 25'(cpu_addr[12:0]) : 25'(cpu_addr[10:0]);
wire [24:0] ram_addr  = 25'({bank_base, cpu_addr[13:0]});

assign mem_addr       = sram_en ? sram_addr : ram_addr;
assign sram_cs        = cs & sram_en;
assign sram_we        = sram_cs & & cpu_wr & cpu_mreq & cpu_addr[15];
assign mem_unmaped    = cs & ((mem_addr > rom_size & ~sram_en) | ~^cpu_addr[15:14]);

endmodule