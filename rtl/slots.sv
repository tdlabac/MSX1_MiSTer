module slots
(
    input            clk,
    input            clk_en,
    input            reset,
    input     [15:0] addr,
    input            wr_n,
    input            rd_n,
    input      [7:0] d_from_cpu,
    output     [7:0] d_to_cpu,
    input            CS1_n,
    input            CS01_n,
    input            CS12_n,
    input            CS2_n,
    input      [3:0] SLTSL_n,
    output    [15:0] sound,
    //IOCTL
    input            ioctl_wr,
    input     [24:0] ioctl_addr,
    input      [7:0] ioctl_dout,
    input            ioctl_isROMA,
    input            ioctl_isROMB,
    output           ioctl_wait,
    //SDRAM
    input      [7:0] sdram_dout,
    output     [7:0] sdram_din,
    output    [24:0] sdram_addr,
    output           sdram_we,
    output           sdram_rd,
    input            sdram_ready,
    input      [1:0] sdram_size,
    //image
    input            img_mounted,
    input     [31:0] img_size,
    input            img_wp,
    output    [31:0] sd_lba,
    output           sd_rd,
    output           sd_wr,
    input            sd_ack,
    input      [8:0] sd_buff_addr,
    input      [7:0] sd_buff_dout,
    output     [7:0] sd_buff_din,
    input            sd_buff_wr,
    input            sd_din_strobe,
    //User mode
    input      [3:0] slot_A,
    input      [3:0] slot_B,
    input      [1:0] rom_enabled,
    output     [2:0] mapper_info
);

assign sound = {sound_slot_A[14],sound_slot_A} + {sound_slot_B[14],sound_slot_B};
assign ioctl_wait = ioctl_wait_slot_A | ioctl_wait_slot_B;

assign d_to_cpu = ~(SLTSL_n[1]) ? (enableFDD_n ? d_from_slot_A : d_from_FDD) :
                  ~(SLTSL_n[2]) ? d_from_slot_B :
                  ~(SLTSL_n[3]) ? ram_q :
                                  8'hFF;
                                  

                                  
assign sdram_addr    = ioctl_isROMA ? {3'b001,ram_addr_A[21:0]} :
                       ioctl_isROMB ? {3'b000,ram_addr_B[21:0]} :
                       ~SLTSL_n[1]  ? enableFDD_n ? {3'b001,ram_addr_A[21:0]} : 'd0 :
                       ~SLTSL_n[2]  ? {3'b000,ram_addr_B[21:0]} :                                  
                                      'd0;
assign bram_addr     = ram_addr_B;                       
assign sdram_din     = ioctl_dout;
assign bram_din      = ioctl_dout;
assign sdram_we      = ioctl_isROMA  ? ram_we_A :
                       ioctl_isROMB  ? ram_we_B :
                                       0;

assign bram_we       = sdram_size == 0 & ioctl_isROMB & ioctl_wr;
assign sdram_rd      = ~SLTSL_n[1] ?  enableFDD_n ? ram_rd_A : 0 :
                       ~SLTSL_n[2] ?  ram_rd_B :
                                      0;                                      

assign ram_dout_A   = sdram_size == 0 ? 8'hFF     : sdram_dout;
assign ram_dout_B   = sdram_size == 0 ? bram_dout : sdram_dout;

assign ram_ready_A  = sdram_size == 0 ? 1'b1 : sdram_ready;
assign ram_ready_B  = sdram_size == 0 ? 1'b1 : sdram_ready;
                                 
//MapperInfo
reg    last_loadRom;
always @(posedge ioctl_isROMA, posedge ioctl_isROMB) begin
   if (ioctl_isROMA) last_loadRom <= 0;
   if (ioctl_isROMB) last_loadRom <= 1;
end

assign mapper_info = last_loadRom ?  rom_enabled[1] ? detected_mapper_B : 3'h0 :
                                     rom_enabled[0] ? detected_mapper_A : 3'h0 ;
                                  
//SLOT A
wire enableFDD_n = SLTSL_n[1] | ~((|sdram_size &  slot_A == 9) | (sdram_size == 0 & slot_A == 1));
wire enableROM_n = SLTSL_n[1] | ~enableFDD_n;

wire [7:0]  d_from_slot_A;
wire [14:0] sound_slot_A;
wire        ioctl_wait_slot_A;

wire [7:0]  ram_dout_A;
wire [7:0]  ram_din_A;
wire [24:0] ram_addr_A;
wire        ram_we_A;
wire        ram_rd_A;
wire        ram_ready_A;
wire  [2:0] detected_mapper_A;
cart_rom ROM_slot_A
(
	.clk(clk),
	.clk_en(clk_en),
	.reset(reset),
	.addr(addr),
	.wr(~wr_n),
	.rd(~rd_n),
	.CS1_n(CS1_n),    
	.CS2_n(CS2_n),
	.CS12_n(CS12_n),
	.SLTSL_n(enableROM_n),
	.d_from_cpu(d_from_cpu),
	.d_to_cpu(d_from_slot_A),
	.sound(sound_slot_A),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_isROM(ioctl_isROMA),
	.ioctl_wait(ioctl_wait_slot_A),
   .ram_dout(ram_dout_A),
   .ram_din(ram_din_A),
   .ram_addr(ram_addr_A),
   .ram_we(ram_we_A),
   .ram_rd(ram_rd_A),
   .ram_ready(ram_ready_A),
   .user_mapper(slot_A),
   .detected_mapper(detected_mapper_A),
   .rom_enabled(rom_enabled[0])
);

wire [7:0]  d_from_FDD;
vy0010 FDD
(
	.clk(clk),
	.clk_en(clk_en),
	.reset(reset),
	.addr(addr),
	.d_to_cpu(d_from_FDD),
	.d_from_cpu(d_from_cpu),
	.wr_n(wr_n),
	.rd_n(rd_n),
	.CS1_n(CS1_n),
	.stlsl_n(enableFDD_n),
	.img_mounted(img_mounted),
	.img_size(img_size),
	.img_wp(img_wp),
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	.sd_din_strobe(sd_din_strobe)
);

//SLOT B
wire [7:0]  d_from_slot_B;
wire [14:0] sound_slot_B;
wire ioctl_wait_slot_B;

wire [7:0]  ram_dout_B;
wire [7:0]  ram_din_B;
wire [24:0] ram_addr_B;
wire        ram_we_B;
wire        ram_rd_B;
wire        ram_ready_B;
wire  [2:0] detected_mapper_B;
cart_rom ROM_slot_B
(
	.clk(clk),
	.clk_en(clk_en),
	.reset(reset),
	.addr(addr),
	.wr(~wr_n),
	.rd(~rd_n),
	.CS1_n(CS1_n),    
	.CS2_n(CS2_n),
	.CS12_n(CS12_n),
	.SLTSL_n(SLTSL_n[2]),
	.d_from_cpu(d_from_cpu),
	.d_to_cpu(d_from_slot_B),
	.sound(sound_slot_B),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_isROM(ioctl_isROMB),
	.ioctl_wait(ioctl_wait_slot_B),
   .ram_dout(ram_dout_B),
   .ram_din(ram_din_B),
   .ram_addr(ram_addr_B),
   .ram_we(ram_we_B),
   .ram_rd(ram_rd_B),
   .ram_ready(ram_ready_B),
	.user_mapper(slot_B),
   .detected_mapper(detected_mapper_B),
   .rom_enabled(rom_enabled[1])
);                                  

//SLOT C - RAM 64kB
wire [7:0] ram_q;
spram #(.addr_width(16), .mem_name("RAM")) ram
(   
	.clock(clk),
	.address (addr[15:0]),
	.q(ram_q),
	.data(d_from_cpu),
	.wren(~(SLTSL_n[3] | wr_n ))
);

//BRAM
wire [7:0] bram_dout;
wire [7:0] bram_din;
wire [24:0] bram_addr;
wire bram_we;
spram #(.addr_width(18),.mem_name("SLOTROM")) rom_cart
(
    .clock(clk),
    .address(bram_addr),
    .wren(bram_we & bram_addr < 24'h20000),
    .q(bram_dout),
    .data(bram_din)
);

endmodule
