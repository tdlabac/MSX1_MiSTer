module msx
(
   input         reset,
   //Clock
   input         clk21m,
   input         ce_10m7_p,
   input         ce_3m58_p,
   input         ce_3m58_n,
   input         ce_10hz,
   //Video
   output  [7:0] R,
   output  [7:0] G,
   output  [7:0] B,
   output        DE,
   output        HS,
   output        VS,
   output        hblank,
   output        vblank,
   //I/O
   output [15:0] audio,
   input  [10:0] ps2_key,
   input   [5:0] joy0,
   input   [5:0] joy1,
   //CART SLOT interface
   output [15:0] cart_addr,
   output  [7:0] cart_d_from_cpu,
   input   [7:0] cart_d_to_cpu_A,
   input   [7:0] cart_d_to_cpu_B,
   input   [7:0] cart_d_to_cpu_FDC,
   output        cart_iorq_n,
   output        cart_mreq_n,
   output        cart_m1_n,
   output        cart_wr_n,
   output        cart_rd_n,
   output        cart_SLTSL1_n,
   output        cart_SLTSL2_n,
   output        en_FDC,
   input  [14:0] cart_sound_A,
   input  [14:0] cart_sound_B,
   //MEMORY 0-BIOS 1-EXT 2-RAM
   output [24:0] mem_addr[3],
   output  [7:0] mem_data[3],
   output  [2:0] mem_wren,
   output  [2:0] mem_rden,
   input   [7:0] mem_q[3],
   //Cassete
   output        cas_motor,
   input         cas_audio_in,
   //MSX config
   input  [64:0] rtc_time,
   input MSX::config_t MSXconf
);

//UNUSED signals
assign mem_data[0] = 'h00;
assign mem_data[1] = 'h00;
assign mem_wren[1:0] = 2'b00;
assign mem_rden[1:0] = 2'b00;


//  -----------------------------------------------------------------------------
//  -- Cartrige interface
//  -----------------------------------------------------------------------------
assign cart_addr       = a;
assign cart_d_from_cpu = d_from_cpu;
assign cart_wr_n       = wr_n;
assign cart_rd_n       = rd_n;
assign cart_iorq_n     = iorq_n;
assign cart_mreq_n     = mreq_n;
assign cart_m1_n       = m1_n;
assign cart_SLTSL1_n   = SLTSL_n[1];
assign cart_SLTSL2_n   = SLTSL_n[2];

//  -----------------------------------------------------------------------------
//  -- Audio MIX
//  -----------------------------------------------------------------------------
wire [15:0] sound_slots = {cart_sound_A[14],cart_sound_A} + {cart_sound_B[14],cart_sound_B};
wire  [9:0] audioPSG    = ay_ch_mix + {keybeep,5'b00000} + {(cas_audio_in & ~cas_motor),4'b0000};
wire [15:0] fm          = {2'b0, audioPSG, 4'b0000};
wire [16:0] audio_mix   = {sound_slots[15], sound_slots} + {fm[15], fm};
wire [15:0] compr[7:0]  = '{ {1'b1, audio_mix[13:0], 1'b0}, 16'h8000, 16'h8000, 16'h8000, 16'h7FFF, 16'h7FFF, 16'h7FFF,  {1'b0, audio_mix[13:0], 1'b0}};
assign audio            = compr[audio_mix[16:14]];

//  -----------------------------------------------------------------------------
//  -- T80 CPU
//  -----------------------------------------------------------------------------
wire [15:0] a;
wire [7:0] d_to_cpu, d_from_cpu;
wire mreq_n, wr_n, m1_n, iorq_n, rd_n, rfrsh_n;
t80pa #(.Mode(0)) T80
(
   .RESET_n(~reset),
   .CLK(clk21m),
   .CEN_p(ce_3m58_p),
   .CEN_n(ce_3m58_n),
   .WAIT_n(wait_n),
   .INT_n(vdp_int_n),
   .NMI_n(1),
   .BUSRQ_n(1),
   .M1_n(m1_n),
   .MREQ_n(mreq_n),
   .IORQ_n(iorq_n),
   .RD_n(rd_n),
   .WR_n(wr_n),
   .RFSH_n(rfrsh_n),
   .HALT_n(1),
   .BUSAK_n(),
   .A(a),
   .DI(d_to_cpu),
   .DO(d_from_cpu)
);

//  -----------------------------------------------------------------------------
//  -- WAIT CPU
//  -----------------------------------------------------------------------------
wire exwait_n = 1;

reg wait_n = 1'b0;
always @(posedge clk21m, negedge exwait_n, negedge u1_2_q) begin
   if (~exwait_n)
      wait_n <= 1'b0;
   else if (~u1_2_q)
      wait_n <= 1'b1;
   else if (ce_3m58_p)
      wait_n <= m1_n;
end

reg u1_2_q = 1'b0;
always @(posedge clk21m, negedge exwait_n) begin
   if (~exwait_n)
      u1_2_q <= 1'b1;
   else if (ce_3m58_p)
      u1_2_q <= wait_n;
end

//  -----------------------------------------------------------------------------
//  -- RAM ROMs
//  -----------------------------------------------------------------------------
assign mem_addr[MEM_BIOS] = a[14:0];
assign mem_addr[MEM_EXT]  = a[13:0];
assign mem_addr[MEM_RAM]  = {ram_bank[5:0],a[13:0]};
assign mem_data[MEM_RAM]  = d_from_cpu;
assign mem_wren[MEM_RAM]  = ~(wr_n | SLT3_n[2]);
assign mem_rden[MEM_RAM]  = ~(rd_n | SLT3_n[2]);

//  -----------------------------------------------------------------------------
//  -- MSX1 / MSX2 handler
//  -----------------------------------------------------------------------------
wire [7:0] d_from_msx, ram_bank;
wire dataBusRQ_msx;
wire vdp_int_n;
wire CS0_n, CS1_n, CS01_n, CS12_n, CS2_n;
wire [3:0] SLTSL_n, SLT3_n;

reg map_valid = 0;
wire ppi_en = ~ppi_n;
always @(posedge reset, posedge clk21m) begin
    if (reset)
        map_valid = 0;
    else if (ppi_en)
        map_valid = 1;
end

msx_select msx_select (
   .MSXconf(MSXconf),
   .clk21m(clk21m),
   .ce_10m7_p(ce_10m7_p),
   .ce_10hz(ce_10hz),
   .reset(reset),
   .addr(a),
   .d_from_cpu,
   .d_to_cpu(d_from_msx),
   .dataBusRQ(dataBusRQ_msx),
   .wr_n(wr_n),
   .rd_n(rd_n),
   .iorq_n(iorq_n),
   .mreq_n(mreq_n),
   .m1_n(m1_n),
   .rfrsh_n(rfrsh_n),
   //.vdp_pal(vdp_pal),
   //.border(border),
   .R(R),
   .G(G),
   .B(B),
   .HS(HS),
   .VS(VS),
   .DE(DE),
   .vdp_int_n(vdp_int_n),
   .hblank(hblank),
   .vblank(vblank),
   .rtc_time(rtc_time),
   .ram_bank(ram_bank),
   .addr_map(ppi_out_a),
   .map_valid(map_valid),
   .CS1_n(CS1_n),
   .CS01_n(CS01_n),
   .CS12_n(CS12_n),
   .CS2_n(CS2_n),
   .CS0_n(CS0_n),      
   .SLTSL_n(SLTSL_n),
   .SLT3_n(SLT3_n),
   .en_FDC(en_FDC)
);

//  -----------------------------------------------------------------------------
//  -- IO Decoder
//  -----------------------------------------------------------------------------
wire psg_n = ~((a[7:3] == 5'b10100) & ~iorq_n & m1_n);
wire ppi_n = ~((a[7:3] == 5'b10101) & ~iorq_n & m1_n);

//  -----------------------------------------------------------------------------
//  -- 82C55 PPI
//  -----------------------------------------------------------------------------
wire [7:0] d_from_8255;
wire [7:0] ppi_out_a, ppi_out_c;
wire keybeep = ppi_out_c[7];
assign cas_motor =  ppi_out_c[4];
jt8255 PPI
(
   .rst(reset),
   .clk(clk21m),
   .addr(a[1:0]),
   .din(d_from_cpu),
   .dout(d_from_8255),
   .rdn(rd_n),
   .wrn(wr_n),
   .csn(ppi_n),
   .porta_din(8'h0),
   .portb_din(d_from_kb),
   .portc_din(8'h0),
   .porta_dout(ppi_out_a),
   .portb_dout(),
   .portc_dout(ppi_out_c)
 );

//  -----------------------------------------------------------------------------
//  -- CPU data multiplex
//  -----------------------------------------------------------------------------
assign d_to_cpu = rd_n                                      ? 8'hFF           :
                  dataBusRQ_msx                             ? d_from_msx      :
                  ~(SLT3_n[2]                             ) ? mem_q[MEM_RAM] :
                  ~(CS01_n    | SLTSL_n[0]                ) ? mem_q[MEM_BIOS] :
                  ~(CS2_n     | SLTSL_n[0] | ~MSXconf.typ) ? mem_q[MEM_EXT]  :
                  ~(CS0_n     | SLT3_n[0]  |  MSXconf.typ) ? mem_q[MEM_EXT]  :
                  ~(psg_n                                 ) ? d_from_psg      :
                  ~(ppi_n                                 ) ? d_from_8255     :
                  ~(SLT3_n[3] | MSXconf.typ              ) ? cart_d_to_cpu_FDC :
                  ~(SLTSL_n[1]                            ) ? cart_d_to_cpu_A :
                  ~(SLTSL_n[2]                            ) ? cart_d_to_cpu_B :
                                                              8'hFF;

//  -----------------------------------------------------------------------------
//  -- Keyboard decoder
//  -----------------------------------------------------------------------------
wire [7:0] d_from_kb;
keyboard msx_key
(
   .reset_n_i(~reset),
   .clk_i(clk21m),
   .ps2_code_i(ps2_key),
   .kb_addr_i(ppi_out_c[3:0]),
   .kb_data_o(d_from_kb)
);

//  -----------------------------------------------------------------------------
//  -- Sound AY-3-8910
//  -----------------------------------------------------------------------------
wire [7:0] d_from_psg, psg_ioa, psg_iob;
wire [5:0] joy_a = psg_iob[4] ? 6'b111111 : {~joy0[5], ~joy0[4], ~joy0[0], ~joy0[1], ~joy0[2], ~joy0[3]};
wire [5:0] joy_b = psg_iob[5] ? 6'b111111 : {~joy1[5], ~joy1[4], ~joy1[0], ~joy1[1], ~joy1[2], ~joy1[3]};
wire [5:0] joyA = joy_a & {psg_iob[0], psg_iob[1], 4'b1111};
wire [5:0] joyB = joy_b & {psg_iob[2], psg_iob[3], 4'b1111};
assign psg_ioa = {cas_audio_in,1'b0, psg_iob[6] ? joyB : joyA};
wire [9:0] ay_ch_mix;

reg u21_1_q = 1'b0;
always @(posedge clk21m,  posedge psg_n) begin
   if (psg_n)
      u21_1_q <= 1'b0;
   else if (ce_3m58_p)
      u21_1_q <= ~psg_n;
end

reg u21_2_q = 1'b0;
always @(posedge clk21m, posedge psg_n) begin
   if (psg_n)
      u21_2_q <= 1'b0;
   else if (ce_3m58_p)
      u21_2_q <= u21_1_q;
end

wire psg_e = !(!u21_2_q | ce_3m58_p) | psg_n;
wire psg_bc   = !(a[0] | psg_e);
wire psg_bdir = !(a[1] | psg_e);
jt49_bus PSG
(
   .rst_n(~reset),
   .clk(clk21m),
   .clk_en(ce_3m58_n),
   .bdir(psg_bdir),
   .bc1(psg_bc),
   .din(d_from_cpu),
   .sel(0),
   .dout(d_from_psg),
   .sound(ay_ch_mix),
   .A(),
   .B(),
   .C(),
   .IOA_in(psg_ioa),
   .IOA_out(),
   .IOB_in(8'hFF),
   .IOB_out(psg_iob)
);

endmodule