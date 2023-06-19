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
    input        [15:0] size_sram,
    output              sram_we,
    output              sram_cs,
    input  mapper_typ_t selected_mapper[2]
);

logic [7:0] bank[2][4];
logic [7:0] sramBank[2][4];
logic [7:0] sramEnable[2];

wire        sram_exists    = size_sram > 0;
wire  [7:0] sram_mask      = size_sram[10:3] > 0 ? size_sram[10:3] - 8'd1 : 8'd0;
wire  [7:0] sramEnableBit  = selected_mapper[cart_num] == MAPPER_WIZARDY ? 8'h80 : rom_size[20:13];
wire  [7:0] sramPages      = selected_mapper[cart_num] == MAPPER_KOEI    ? 8'h34 : 8'h30;
wire  [1:0] region         = cpu_addr[12:11];
wire  [7:0] bank_base      = bank[cart_num][{cpu_addr[15],cpu_addr[13]}]; 
wire  [7:0] sram_bank_base = sramBank[cart_num][{cpu_addr[15],cpu_addr[13]}];                 

always @(posedge clk) begin
    if (reset) begin
        bank       <= '{'{default: '0},'{default: '0}};
        sramBank   <= '{'{default: '0},'{default: '0}};
        sramEnable <= '{default: '0}; 
    end else begin
        if (cs & cpu_mreq & cpu_wr & cpu_addr[15:13] == 3'b011) begin //WR 6000-7ffff
            if (|(din & sramEnableBit) & sram_exists) begin
                sramEnable[cart_num]       <= sramEnable[cart_num] | ((8'b00000100 << region) & sramPages);
                $display("Enable SRAM %x sram pages mask %x",((8'b00000100 << region) & sramPages),sramPages);
                sramBank[cart_num][region] <= din & sram_mask;
                $display("Write SRAM bank region %d banka %x",region, din & sram_mask);
            end else begin
                sramEnable[cart_num] <= sramEnable[cart_num] & ~(8'b00000100 << region);
                $display("Disable SRAM %x sram pages mask %x",((8'b00000100 << region) & sramPages),sramPages);
                bank[cart_num][region] <= din;     
            end
        end
    end
end

wire        sram_en     = |((8'b00000001 << cpu_addr[15:13]) & sramEnable[cart_num]);
wire [24:0] ram_addr    = 25'({bank_base, cpu_addr[12:0]});
wire [24:0] sram_addr   = 25'({sram_bank_base,cpu_addr[12:0]});
assign      sram_cs     = cs & sram_en;
assign      sram_we     = sram_cs & cpu_wr & cpu_mreq;
assign      mem_addr    = sram_en ? sram_addr : ram_addr;
assign      mem_unmaped = cs & ((mem_addr > rom_size & ~sram_en) | ~^cpu_addr[15:14]);

endmodule