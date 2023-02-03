//WIZARDY      SIZE 0x0800  2kB  sramPages 0x30 sramEnableBit 0x80
//KOEI 32      SIZE 0x8000 32kB  sramPages 0x34 sramEnableBit = romSize/0x2000
//KOEI 8       SIZE 0x2000  8kB  sramPages 0x34 sramEnableBit = romSize/0x2000
//ASCII8 32    SIZE 0x8000 32kB  sramPages 0x30 sramEnableBit = romSize/0x2000
//ASCII8 8     SIZE 0x2000  8kB  sramPages 0x30 sramEnableBit = romSize/0x2000
//ASCII8 2     SIZE 0x0800  2kB  sramPages 0x30 sramEnableBit = romSize/0x2000

module cart_ascii8
(
    input            clk,
    input            reset,
    input     [24:0] rom_size,
    input     [15:0] addr,
    input      [7:0] d_from_cpu,
    input            wr,
    input            cs,
    input            koei,
    input            wizardry,
    input     [1:0]  sramSize,  // 00-0x800 01-0x2000 02-0x8000
    output    [24:0] mem_addr,
    output           mem_oe,
    output    [14:0] sram_addr,
    output           sram_we,
    output           sram_oe
);

reg  [7:0] bank[0:3];
reg  [7:0] sramBank[0:7];
reg  [7:0] sramEnable;

wire [7:0] mask          = rom_size[20:13] - 1'd1;
wire [7:0] sram_mask     = rom_size[20:13];
wire [7:0] sramEnableBit = wizardry ? 8'h80 : rom_size[20:13];

wire [1:0] region        = addr[12:11];
always @(posedge reset, posedge clk) begin
    if (reset) begin
        bank        <='{default: '0};
        sramBank    <='{default: '0};
        sramEnable  <= 8'h00;
    end else begin
        if (cs & wr & addr[15:13] == 3'b011) begin //6000-7ffff 
            if (|(d_from_cpu & sramEnableBit)) begin
                sramEnable <= sramEnable | ((8'b00000100 << region) & (koei ? 8'h34 : 8'h30));
                sramBank[region] <= d_from_cpu & sram_mask;
            end else begin
                sramEnable <= sramEnable & ~(8'b00000100 << region);
                bank[region] = d_from_cpu;
            end
        end
    end 
end

wire [1:0] bank_num            = {addr[15] ^ addr[14] ? addr[15] : ~addr[15], addr[13]};
wire [7:0] bank_base           = bank[bank_num];

assign     mem_addr            = {4'h0, (bank_base & mask), addr[12:0]};
assign     mem_oe              = cs;
//SRAM 
wire       sram_en             = |((8'b00000001 << addr[15:13]) & sramEnable);
assign     sram_oe             = cs & sram_en;
assign     sram_we             = sram_oe & wr;
wire [7:0] sram_bank_base      = sramBank[addr[15:13]];
assign     sram_addr           = {sram_bank_base[1:0],addr[12:0]};

endmodule
