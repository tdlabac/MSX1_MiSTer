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
    end else begin
        if (cs & cpu_mreq & cpu_wr & cpu_addr[15:13] == 3'b011) begin
            bank[cart_num][cpu_addr[12:11]] <= din;     
        end
    end
end

assign bank_base = bank[cart_num][{cpu_addr[15],cpu_addr[13]}];                  

assign mem_addr = 25'({bank_base, cpu_addr[12:0]});
assign mem_unmaped = cs & ((mem_addr > rom_size) | ~^cpu_addr[15:14]);

endmodule