module download_msx #(parameter MAX_CONFIG = 16, MAX_MEM_BLOCK = 16, MAX_FW_ROM = 8)
(
   input                     clk,
   input                     ddr3_ready,
   input               [7:0] ddr3_dout,
   output             [27:0] ddr3_addr,
   output logic              ddr3_rd,
   output                    ddr3_reqest,
   output logic       [24:0] sdram_addr,
   output logic        [7:0] sdram_din,
   output logic              sdram_we,
   input                     sdram_ready,
   output                    sdram_request,
   input               [1:0] sdram_size,
   output logic       [24:0] bram_addr, 
   output logic        [7:0] bram_din,
   output logic              bram_we,
   output                    bram_request,
   input               [1:0] MSXtype,
   input                     update_request,
   output logic              update_ack,
   output                    need_reset,
   input  MSX::config_cart_t cart_conf[2],
   input  MSX::msx_config_t  msx_config[MAX_CONFIG],
   input  MSX::ioctl_rom_t   ioctl_rom[2],
   input  MSX::fw_rom_t      fw_store[MAX_FW_ROM],
   output MSX::rom_info_t    rom_info[2],
   output MSX::slot_t        msx_slot[4],
   output MSX::block_t       memory_block[MAX_MEM_BLOCK],
   output MSX::sram_block_t  sram_block[2]
   
);
   typedef enum logic [2:0] {STATE_WAIT, STATE_INIT_SLOT, STATE_FILL_SLOT, STATE_UPLOAD_RAM, STATE_FILL_NEXT, STATE_INIT_SRAM} state_t;
   
   initial begin
      update_ack     = 1'b0;
      state          = STATE_WAIT;
      ddr3_rd        = 1'b0;
      sdram_we       = 1'b0;
      need_reset     = 1'b0;
   end
   
   assign ddr3_addr     = start_addr + addr;
   assign ddr3_reqest   = state != STATE_WAIT;
   assign sdram_request = ddr3_reqest;
   assign bram_request  = ddr3_reqest;
   
   config_typ_t act_config_typ;
   slot_typ_t   act_slot_typ;
   logic [23:0] addr;
   logic [27:0] start_addr;
   state_t      state;
   state_t      next_state;
   logic        last_sdram_we;
   logic        last_bram_we;
   logic        do_we;
   logic  [3:0] config_cnt;   

   wire   [1:0] act_slot        = msx_config[config_cnt].slot;
   wire   [1:0] act_block       = msx_config[config_cnt].start_block;
   wire   [1:0] act_subslot     = msx_config[config_cnt].sub_slot;
   wire   [3:0] act_block_id    = msx_config[config_cnt].block_id;
   wire   [7:0] act_block_count = msx_config[config_cnt].block_count;
   assign       act_config_typ  = msx_config[config_cnt].typ;
   assign       act_slot_typ    = act_config_typ == CONFIG_BIOS  ? SLOT_TYP_ROM      :
                                  act_config_typ == CONFIG_FDC   ? SLOT_TYP_ROM      :
                                  MSXtype == 0                   ? SLOT_TYP_RAM      :
                                                                   SLOT_TYP_MSX2_RAM ;
   
   always @(posedge clk) begin 
      logic  [5:0] init;
      logic  [3:0] share_fw_id;
      sdram_we <= 1'd0;
      bram_we  <= 1'd0;
      if (ddr3_ready) ddr3_rd <= 1'b0;
      case(state)
            STATE_WAIT:
               begin
                  if (update_request) begin
                     init                      <= 6'd0;
                     state                     <= STATE_INIT_SLOT;
                     config_cnt                <= 4'd0;
                     sdram_addr                <= 25'd0;
                     bram_addr                 <= 25'd0;
                     update_ack                <= 1'b1;
                     need_reset                <= 1'b1;
                     share_fw_id               <= 4'd0;
                     sram_block[0].block_count <= 8'd0;
                     sram_block[1].block_count <= 8'd0;
                  end  else begin
                     update_ack    <= 1'b0;
                     need_reset    <= 1'b0;
                  end             
               end
            STATE_INIT_SLOT:
               begin
                  if (&init) state <= STATE_FILL_SLOT;
                  msx_slot[init[5:4]].subslot[init[3:2]].block[init[1:0]].init <= 1'b0;
                  msx_slot[init[5:4]].typ <= SLOT_TYP_EMPTY;
                  init <= init + 1'b1;
               end
            STATE_FILL_SLOT:
               begin
                  case (act_config_typ)
                     CONFIG_RAM,
                     CONFIG_FDC,
                     CONFIG_BIOS:
                        begin
                           if (ddr3_ready) begin
                              
                              if (msx_config[config_cnt].slot_internal_mapper) msx_slot[act_slot].typ <= SLOT_TYP_MAPPER;
                              else                                             msx_slot[act_slot].typ <= act_slot_typ;

                              if (msx_config[config_cnt].slot_internal_mapper) msx_slot[act_slot].subslot[act_subslot].typ <= act_slot_typ;
                              msx_slot[act_slot].subslot[act_subslot].block[act_block].block_id <= act_block_id;
                              msx_slot[act_slot].subslot[act_subslot].block[act_block].offset <= 2'd0;
                              msx_slot[act_slot].subslot[act_subslot].block[act_block].init <= 1'b1;
                              if (act_block_count >= 8'd2 & act_block < 2'd3) begin
                                 if (msx_config[config_cnt].slot_internal_mapper) msx_slot[act_slot].subslot[act_subslot + 2'd1].typ <= act_slot_typ;
                                 msx_slot[act_slot].subslot[act_subslot].block[act_block + 2'd1].block_id <= act_block_id;
                                 msx_slot[act_slot].subslot[act_subslot].block[act_block + 2'd1].offset <= 2'd1;
                                 msx_slot[act_slot].subslot[act_subslot].block[act_block + 2'd1].init <= 1'b1;
                              end
                              if (act_block_count >= 8'd3 & act_block < 2'd2) begin
                                 if (msx_config[config_cnt].slot_internal_mapper) msx_slot[act_slot].subslot[act_subslot + 2'd2].typ <= act_slot_typ;
                                 msx_slot[act_slot].subslot[act_subslot].block[act_block + 2'd2].block_id <= act_block_id;
                                 msx_slot[act_slot].subslot[act_subslot].block[act_block + 2'd2].offset <= 2'd2;
                                 msx_slot[act_slot].subslot[act_subslot].block[act_block + 2'd2].init <= 1'b1;
                              end
                              if (act_block_count >= 8'd4 & act_block < 2'd1) begin
                                 if (msx_config[config_cnt].slot_internal_mapper) msx_slot[act_slot].subslot[act_subslot + 2'd3].typ <= act_slot_typ;
                                 msx_slot[act_slot].subslot[act_subslot].block[act_block + 2'd3].block_id <= act_block_id;
                                 msx_slot[act_slot].subslot[act_subslot].block[act_block + 2'd3].offset <= 2'd3;
                                 msx_slot[act_slot].subslot[act_subslot].block[act_block + 2'd3].init <= 1'b1;
                              end
                              memory_block[act_block_id].block_count <= act_block_count;
                              memory_block[act_block_id].mem_offset <= sdram_addr;
                              start_addr  <= msx_config[config_cnt].store_address;   //Odkud
                              addr   <= 24'd0;                                       //offset
                              case (act_config_typ)
                                 CONFIG_RAM:
                                    begin
                                       memory_block[act_block_id].typ <= BLOCK_TYP_RAM;
                                    end
                                 CONFIG_FDC:
                                    begin
                                       memory_block[act_block_id].typ <= BLOCK_TYP_FDC;
                                       ddr3_rd <= 1'b1;
                                    end
                                 default:
                                    begin
                                       memory_block[act_block_id].typ <= BLOCK_TYP_ROM;
                                       ddr3_rd <= 1'b1;
                                    end
                              endcase 
                              state <= STATE_UPLOAD_RAM;
                           end
                        end
                     CONFIG_CART_A,
                     CONFIG_CART_B:
                        begin                          
                           state <= STATE_FILL_NEXT;   
                           case(cart_conf[act_config_typ == CONFIG_CART_B].typ)
                              CART_TYP_EMPTY: begin 
                                 //None
                              end
                              CART_TYP_ROM: begin
                                 if (ioctl_rom[act_config_typ == CONFIG_CART_B].loaded) begin
                                    msx_slot[act_slot].typ <= act_config_typ == CONFIG_CART_A ? SLOT_TYP_CART_A : SLOT_TYP_CART_B;
                                    msx_slot[act_slot].subslot[act_subslot].block[act_block].block_id <= act_block_id;
                                    msx_slot[act_slot].subslot[act_subslot].block[act_block].offset <= 2'd0;
                                    msx_slot[act_slot].subslot[act_subslot].block[act_block].init <= 1'b1;
                                    start_addr  <= act_config_typ == CONFIG_CART_A ? 28'hA00000 : 28'hF00000;
                                    memory_block[act_block_id].block_count <= ioctl_rom[act_config_typ == CONFIG_CART_B].rom_size >> 14;
                                    memory_block[act_block_id].mem_offset <= sdram_addr;
                                    memory_block[act_block_id].typ <= BLOCK_TYP_ROM;
                                    ddr3_rd <= 1'b1;                     
                                    addr <= 24'd0;
                                    state <= STATE_UPLOAD_RAM;
                                 end
                              end
                              CART_TYP_SCC2: begin
                                 sram_block[act_config_typ == CONFIG_CART_B].mem_offset  <= bram_addr;
                                 sram_block[act_config_typ == CONFIG_CART_B].block_count <= 8'd8;
                                 state <= STATE_INIT_SRAM;
                                 next_state <= STATE_FILL_NEXT;
                                 bram_din <= 8'hFF;
                                 addr <= 24'd0;
                              end

                              default:
                                          //Nasli jsme cart a vime kam mapovat.
                                          //Rozhodnout se co se nahraje do RAM
                                          //Nastavit slot na spravne chovani
                                          //Doresit SRAM jak pro ROM tak i pro FW
                                 begin
                                    next_state <= STATE_FILL_NEXT;
                                    if (fw_store[cart_conf[act_config_typ == CONFIG_CART_B].typ].block_count > 8'd0) begin
                                       if (cart_conf[act_config_typ == CONFIG_CART_A] == cart_conf[act_config_typ == CONFIG_CART_B] & share_fw_id > 0) begin //Shodne a inicializovane
                                          msx_slot[act_slot].subslot[act_subslot].block[act_block].block_id <= share_fw_id;
                                          state <= STATE_FILL_NEXT;
                                       end else begin                                          
                                          msx_slot[act_slot].subslot[act_subslot].block[act_block].block_id <= act_block_id;
                                          msx_slot[act_slot].subslot[act_subslot].block[act_block].offset <= 2'd0;
                                          msx_slot[act_slot].subslot[act_subslot].block[act_block].init <= 1'b1;
                                          start_addr  <= fw_store[cart_conf[act_config_typ == CONFIG_CART_B].typ].store_address;   //Odkud
                                          memory_block[act_block_id].block_count <= fw_store[cart_conf[act_config_typ == CONFIG_CART_B].typ].block_count;
                                          memory_block[act_block_id].mem_offset <= sdram_addr;
                                          memory_block[act_block_id].typ <= BLOCK_TYP_ROM;
                                          share_fw_id <= act_block_id;
                                          ddr3_rd <= 1'b1;                     
                                          addr <= 24'd0;
                                          state <= STATE_UPLOAD_RAM;
                                          next_state <= STATE_UPLOAD_RAM;
                                       end
                                       msx_slot[act_slot].typ <= act_config_typ == CONFIG_CART_A ? SLOT_TYP_CART_A : SLOT_TYP_CART_B;
                                       msx_slot[act_slot].subslot[act_subslot].block[act_block].offset <= 2'd0;
                                       msx_slot[act_slot].subslot[act_subslot].block[act_block].init <= 1'b1;
                                    end
                                    
                                    if (fw_store[cart_conf[act_config_typ == CONFIG_CART_B].typ].sram_block_count > 8'd0) begin // Je potreba SRAM
                                       sram_block[act_config_typ == CONFIG_CART_B].mem_offset  <= bram_addr;
                                       sram_block[act_config_typ == CONFIG_CART_B].block_count <= fw_store[cart_conf[act_config_typ == CONFIG_CART_B].typ].sram_block_count;
                                       state <= STATE_INIT_SRAM;
                                       bram_din <= 8'hFF;
                                       addr <= 24'd0;
                                    end
                                 end
                           endcase
                        end
                     default:
                     begin
                        state <= STATE_FILL_NEXT;
                     end
                  endcase
               end
            STATE_INIT_SRAM:
               begin
                  if (~last_bram_we & bram_we) begin
                     bram_addr <= bram_addr + 1'b1;
                     if (sdram_size == 2'd0) sdram_addr <= sdram_addr + 1'b1;            //Pokud neni SDRAM zapisujeme do BRAM
                  end
                  if (~bram_we) begin                                                    //Muzeme psat do BRAM
                     if (addr[21:0] > {sram_block[act_config_typ == CONFIG_CART_B].block_count - 1'b1, 14'h3FFF} ) begin
                        state <= next_state;
                        addr <= 24'd0;
                     end else begin
                        bram_we <= 1'b1;
                        addr <= addr + 1'b1;
                     end
                  end
               end
            STATE_UPLOAD_RAM:
               begin
                  if (~last_sdram_we & sdram_we) begin
                     sdram_addr <= sdram_addr + 1'b1;                                        //Po zapisu zvedni adresu
                     if (sdram_size == 2'd0) bram_addr <= bram_addr + 1'b1;                  //Pokud neni SDRAM zapisujeme do BRAM
                  end
                  if (ddr3_ready & ~ddr3_rd) begin                                                  //Read Done
                     if (sdram_ready & ~sdram_we) begin                                             //Muzeme psat do SDRAM
                        if (addr[21:0] > {memory_block[act_block_id].block_count - 1'b1, 14'h3FFF} ) begin
                           if (act_config_typ == CONFIG_CART_A | act_config_typ == CONFIG_CART_B) begin
                              rom_info[act_config_typ == CONFIG_CART_B].offset <= detect_offset;
                              rom_info[act_config_typ == CONFIG_CART_B].size   <= detect_rom_size;
                              rom_info[act_config_typ == CONFIG_CART_B].mapper <= ioctl_rom[act_config_typ == CONFIG_CART_B].rom_mapper == 6'd0 ? detect_mapper : 
                                                                                  ioctl_rom[act_config_typ == CONFIG_CART_B].rom_mapper;
                           end
                           state <= STATE_FILL_NEXT;
                        end else begin
                           sdram_din <= memory_block[act_block_id].typ != BLOCK_TYP_RAM ? ddr3_dout : 8'hFF;                                                        
                           do_we <= 1'b1;
                           if (do_we) begin
                              sdram_we <= 1'b1;                                                                  //Write to RAM
                              do_we <= 1'b0;
                              addr <= addr + 1'b1;                                                               //Next addr
                              if (memory_block[act_block_id].typ != BLOCK_TYP_RAM) begin
                                 ddr3_rd <= 1'b1;                                                                //Read
                              end
                           end
                        end
                     end
                  end
               end
            STATE_FILL_NEXT:
               begin
                  if (config_cnt == MAX_CONFIG - 1) begin
                     state <= STATE_WAIT;
                  end else begin
                     config_cnt <= config_cnt + 1'b1;
                     state <= STATE_FILL_SLOT;
                  end
               end
      endcase
      last_sdram_we <= sdram_we;
		last_bram_we <=  bram_we;
   end

   wire  [5:0] detect_mapper;
   wire  [3:0] detect_offset;
   wire [24:0] detect_rom_size;
   rom_detect rom_detect
   (
      .clk(clk),
      .ioctl_addr(addr),
      .ioctl_dout(sdram_din),
      .ioctl_wr(sdram_we),
      .mapper(detect_mapper),
      .offset(detect_offset),
      .rom_size(detect_rom_size)
   );

endmodule