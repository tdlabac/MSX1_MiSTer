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
    input  mapper_typ_t selected_mapper[2]
);
/*verilator tracing_off*/
reg  [7:0] bank0[2], bank1[2];
wire [7:0] bank_base;

always @(posedge clk) begin
    if (reset) begin
        
        bank0 <= '{selected_mapper[0] == MAPPER_RTYPE ? 'h0F : 'h00 , selected_mapper[1] == MAPPER_RTYPE ? 'h0F : 'h00};
        bank1 <= '{'h00,'h00};
    end else begin
        if (cs & cpu_mreq & cpu_wr) begin
            if (selected_mapper[cart_num] == MAPPER_RTYPE) begin
               if (cpu_addr[15:12] == 4'b0111) begin
                  bank1[cart_num] <= din & (din[4] ? 8'h17 : 8'h1F);
               end
            end else begin
                case (cpu_addr[15:11])
                    5'b01100: // 6000-67ffh
                        bank0[cart_num] <= din;
                    5'b01110: // 7000-77ffh
                        bank1[cart_num] <= din;
                    default: ;
                endcase
            end
        end
    end
end

assign bank_base = cpu_addr[14] == 1'b1 ? bank0[cart_num] : bank1[cart_num];
assign mem_addr = 25'({bank_base, cpu_addr[13:0]});
assign mem_unmaped = cs & (mem_addr > rom_size | ~^cpu_addr[15:14]);

endmodule