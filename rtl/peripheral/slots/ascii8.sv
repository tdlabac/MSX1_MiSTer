module cart_ascii8
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

//reg  [7:0] bank0[2], bank1[2], bank2[2], bank3[2];
logic  [7:0] bank[2][4];
//reg  [7:0] sramBank[0:7];
//reg  [7:0] sramEnable;
wire [7:0] bank_base;

wire [1:0] region  = cpu_addr[12:11];
always @(posedge clk) begin
    if (reset) begin
        bank <= '{'{default: '0},'{default: '0}};
        //bank0 <= '{'h00,'h00};
        //bank1 <= '{'h00,'h00};
        //bank2 <= '{'h00,'h00};
        //bank3 <= '{'h00,'h00};
    end else begin
        if (cs & cpu_mreq & cpu_wr) begin
            case (cpu_addr[15:11])
                5'b01100: // 6000-67ffh
                    bank[cart_num][0] <= din;
                5'b01101: // 6800-6fffh
                    bank[cart_num][1] <= din;
                5'b01110: // 7000-77ffh
                    bank[cart_num][2] <= din;
                5'b01111: // 7800-7fffh
                    bank[cart_num][3] <= din;
                default: ;
            endcase
        end
    end
end

assign bank_base = cpu_addr[14:13] == 2'b00 ? bank[cart_num][2] : 
                   cpu_addr[14:13] == 2'b01 ? bank[cart_num][3] : 
                   cpu_addr[14:13] == 2'b10 ? bank[cart_num][0] : 
                                          bank[cart_num][1] ;

assign mem_addr = 25'({bank_base, cpu_addr[12:0]});
assign mem_unmaped = cs & ((mem_addr > rom_size) | ~^cpu_addr[15:14]);

endmodule