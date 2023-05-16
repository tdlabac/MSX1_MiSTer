module memory_upload
(
   input                       clk,
   output                      reset_rq,
   input                       ioctl_download,
   input                [15:0] ioctl_index,
   input                [26:0] ioctl_addr,
   input                       rom_eject,
   output logic         [27:0] ddr3_addr,
   output logic                ddr3_rd,
   output logic                ddr3_wr,
   output                [7:0] ddr3_din,
   input                 [7:0] ddr3_dout,
   input                       ddr3_ready,
   output                      ddr3_request,

   output logic         [26:0] ram_addr,
   output                [7:0] ram_din,
   input                 [7:0] ram_dout,
   output                      ram_ce,
   input                       sdram_ready,
   output                      sdram_rq,
   output                      bram_rq,
   output                      kbd_rq,
   input                 [1:0] sdram_size,
   output MSX::block_t         slot_layout[64],
   output MSX::lookup_RAM_t    lookup_RAM[16],
   output MSX::lookup_RAM_t    lookup_SRAM[4],
   output MSX::bios_config_t   bios_config,
   input  MSX::config_cart_t   cart_conf[2]
);

   logic [26:0] ioctl_size [4];
   logic        load;
   logic [27:0] save_addr;


   always @(posedge clk) begin
      logic ioctl_download_last;
      load <= 0;
      if (~ioctl_download & ioctl_download_last )  begin
         case(ioctl_index[5:0])
            6'd1: begin ioctl_size[0] <= ioctl_addr; load <= 1; end
            6'd2: begin ioctl_size[1] <= ioctl_addr; load <= 1; end
            6'd3: begin ioctl_size[2] <= ioctl_addr; load <= 1; end
            6'd4: begin ioctl_size[3] <= ioctl_addr; load <= 1; end
            default: ;
         endcase
      end
      if (rom_eject) begin
         ioctl_size[2] <= 0;
         ioctl_size[3] <= 0; 
         load <= 1;
      end
      ioctl_download_last <= ioctl_download;
   end 

   typedef enum logic [3:0] {STATE_IDLE, STATE_CLEAN, STATE_READ_CONF, STATE_READ_CONF2, STATE_CHECK_CONFIG, STATE_FILL_RAM, STATE_FILL_RAM2, STATE_STORE_SLOT_CONFIG, STATE_FIND_ROM, STATE_ERROR} state_t;
   state_t state;
   logic  [7:0] conf[16];
   logic  [7:0] fw_conf[8];
   logic  [1:0] pattern;
   logic  [1:0] subslot;   
   assign reset_rq = ! (state == STATE_IDLE | state == STATE_ERROR);
   assign ram_din = pattern == 2'd0 ? ddr3_dout :
                    pattern == 2'd1 ? 8'hFF     :
                    pattern == 2'd2 ? 8'h00     :
                    ram_addr[8]     ? ram_addr[1] ? 8'hff : 8'h00 :
                                      ram_addr[1] ? 8'h00 : 8'hff ; 
   
   always @(posedge clk) begin
      logic  [5:0] block_num;
      logic  [3:0] config_head_addr;
      logic [24:0] data_size;
      logic [24:0] sram_size;
      logic  [3:0] ref_ram;
      logic  [1:0] ref_sram;
      logic        rom_find;
      mapper_typ_t mapper;
      device_typ_t device;
      data_ID_t    data_id;
      logic [7:0]  mode;
      logic [7:0]  param;
      logic [3:0]  slotSubslot;
      logic        refAdd;
      logic [26:0] sram_addr;
      logic [26:0] save_ram_addr;
      logic  [3:0] cart_slot_expander_en;
      
      ddr3_wr <= 1'd0;
      
      if (ram_ce)               begin ram_ce  <= 1'b0; ram_addr  <= ram_addr + 1'd1; end
      if (ddr3_ready & ddr3_rd) begin ddr3_rd <= 1'b0; ddr3_addr <= ddr3_addr + 1'd1; end
      if (load) begin
         state <= STATE_CLEAN;
         ddr3_addr        <= 0;
         ram_addr         <= 27'd0;
         sram_addr        <= 27'd0;
         save_ram_addr    <= 27'd0;
         block_num        <= 6'd0;
         config_head_addr <= 4'd0;
         ref_ram          <= 4'd0;
         ddr3_rd          <= 1'd0;        
         save_addr        <= 0;
         refAdd           <= 1'b0;
         subslot          <= 2'd0; 
         cart_slot_expander_en <= 4'd0;        
      end
      if (ddr3_ready & ~ddr3_rd) begin
         case(state)
            STATE_ERROR,
            STATE_IDLE: begin
               ddr3_request     <= 1'd0;
            end
            STATE_CLEAN: begin
               ddr3_request  <= 1'd1;
               slot_layout[block_num].mapper <= MAPPER_UNUSED;
               slot_layout[block_num].device <= DEVICE_NONE;
               block_num                  <= block_num + 1'd1;
               if (block_num == 63) begin
                  state         <= STATE_READ_CONF;
                  block_num     <= 0;
               end else begin
                  block_num  <= block_num + 1'd1;
               end
            end
            STATE_READ_CONF: begin
               subslot <= 2'd0;         
               state   <= STATE_READ_CONF2;
               if (save_addr == 0) begin
                  if (ddr3_addr >= 28'(ioctl_size[0])) begin
                     state <= STATE_IDLE;      
                  end else begin
                     ddr3_rd       <= 1'b1;
                  end
               end else begin
                  ddr3_rd       <= 1'b1;
               end
            end
            STATE_READ_CONF2: begin
               config_head_addr <= config_head_addr + 4'd1;              
               ddr3_rd          <= 1'b1;
               conf[config_head_addr] <= ddr3_dout;         
               if (config_head_addr == 4'b1111) begin
                  state <= STATE_CHECK_CONFIG;
                  ddr3_rd          <= 1'd0;
                  config_head_addr <= 4'd0;
                  rom_find          <= 1'd0;
               end
            end
            STATE_CHECK_CONFIG: begin
               state <= STATE_IDLE;
               data_size <= 25'd0;
               sram_size <= 25'd0;
               if ({conf[0],conf[1],conf[2]} == {"M","S","X"}) begin
                  state <= STATE_FILL_RAM;
                  slotSubslot <= conf[3][3:0];
                  case(config_typ_t'(conf[3][7:4]))
                     CONFIG_SLOT_A,
                     CONFIG_SLOT_B: begin
                        if (cart_mapper != MAPPER_UNUSED | cart_mem_device != DEVICE_NONE ) begin
                           mapper      <= cart_mapper;;
                           device      <= cart_mem_device;
                           mode        <= cart_mode;
                           param       <= cart_param;
                           data_id     <= cart_rom_id;
                           sram_size   <= 25'({cart_sram_size, 10'd0});
                           ref_sram    <= config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_A ? 2'd2 : 2'd3;
                           slotSubslot <= {conf[3][3:2], subslot};
                           case(cart_rom_id)
                              ROM_NONE: ;                          
                              ROM_ROM: begin
                                 if (ioctl_size[config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_A ? 2 : 3] > 0) begin                           
                                    save_addr <= ddr3_addr;   
                                    ddr3_addr <= config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_A ? 28'hA00000 : 28'hF00000 ;    //ROM Store
                                    data_size <= ioctl_size[config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_A ? 2 : 3][24:0];
                                 end else begin
                                    state     <= STATE_READ_CONF;
                                 end
                              end
                              ROM_RAM: begin
                                 data_size <= 25'({cart_ram_size,14'h0});
                              end
                              default: begin
                                 save_addr <= ddr3_addr;   
                                 ddr3_addr <= 28'h100000;                                                            //FW Store
                                 ddr3_rd   <= 1'b1;                                                                  //Prefetch
                                 state     <= STATE_FIND_ROM;
                              end
                           endcase
                           if (subslot != 0) begin
                              cart_slot_expander_en <= cart_slot_expander_en | 4'b0001 << conf[3][3:2];
                           end
                        end else begin
                           if (subslot < 2'd3) begin
                              subslot <= subslot + 1'd1;
                              state <= STATE_CHECK_CONFIG;
                           end else begin
                              subslot <= 0;
                              state <= STATE_READ_CONF;
                           end
                        end
                     end
                     CONFIG_KBD_LAYOUT: begin
                         ddr3_addr <= ddr3_addr + 28'h200;
                         state     <= STATE_READ_CONF;
                     end
                     CONFIG_CONFIG: begin
                        bios_config.slot_expander_en <= conf[4][3:0] | cart_slot_expander_en;
                        bios_config.MSX_typ          <= MSX_typ_t'(conf[4][5:4]);
                        state                        <= STATE_READ_CONF;
                     end
                     CONFIG_SLOT_INTERNAL: begin
                        mapper      <= mapper_typ_t'(conf[8]);
                        device      <= device_typ_t'(conf[7]);
                        data_size   <= {conf[5][2:0], conf[6],14'h0};
                        sram_size   <= 25'd0;
                        data_id     <= data_ID_t'(conf[4]);
                        mode        <= conf[9];
                        param       <= conf[10];
                        if (data_ID_t'(conf[4]) != ROM_NONE) state <= STATE_FILL_RAM;
                     end
                     default: ;
                  endcase
               end
            end
            STATE_FIND_ROM: begin
               config_head_addr <= config_head_addr + 4'd1;              
               ddr3_rd          <= 1'd1;
               fw_conf[config_head_addr[2:0]] <= ddr3_dout;         
               if (config_head_addr == 4'd7) begin
                  config_head_addr <= 4'd0;
                  if ({fw_conf[0],fw_conf[1],fw_conf[2]} == {"M","S","X"}) begin
                     if (data_ID_t'(fw_conf[4]) == data_id) begin  
                        data_size <= {fw_conf[5][2:0], fw_conf[6],14'h0};
                        ddr3_addr <= ddr3_addr + 7;
                        state     <= STATE_FILL_RAM;
                     end else begin          
                        if ((ddr3_addr - 28'h100000 + (28'({fw_conf[5],fw_conf[6]}) << 14) + 28'd8) >= 28'(ioctl_size[1])) begin
                           ddr3_addr <= save_addr;
                           state <= STATE_READ_CONF;                                                           //not find skip load
                        end else begin
                           ddr3_addr <= ddr3_addr + (28'({fw_conf[5],fw_conf[6]}) << 14) + 28'd8;              //not usable next header
                        end
                     end
                  end else begin
                     // Havarie. sem jsme se dostali chybou
                     ddr3_addr <= save_addr;
                     state <= STATE_READ_CONF;
                  end
               end
            end
            STATE_FILL_RAM: begin
               if (~ram_ce) begin
                  state <= STATE_FILL_RAM2;
                  if (bram_rq) sram_addr <= ram_addr;
                  sdram_rq <= 0;
                  bram_rq  <= 0;
                  if (save_ram_addr != 27'd0) ram_addr <= save_ram_addr;
                  if (data_size != 25'd0) begin
                     refAdd                   <= 1'b1; // Add reference po ulozeni
                     lookup_RAM[ref_ram].addr <= ram_addr;
                     lookup_RAM[ref_ram].size <= 16'(data_size[24:14]);               
                     case(data_id)
                        ROM_RAM: begin
                           lookup_RAM[ref_ram].ro   <= 1'd0;
                           pattern                  <= 2'd3;       
                        end
                        default: begin
                           lookup_RAM[ref_ram].ro   <= 1'd1;
                           pattern                  <= 2'd0; 
                           ddr3_rd                  <= 1'd1;       //Prefetch
                        end
                     endcase
                     sdram_rq                 <= sdram_size != 0;
                     bram_rq                  <= sdram_size == 0;
                  end else 
                     if (sram_size != 25'd0) begin
                        lookup_SRAM[ref_sram].addr <= sram_addr;
                        lookup_SRAM[ref_sram].size <= 16'(sram_size[24:10]);
                        pattern       <= 2'd1; 
                        data_size     <= sram_size;
                        sram_size     <= 25'd0;
                        bram_rq       <= 1'b1;
                        data_id       <= ROM_RAM;
                        if (~bram_rq) ram_addr <= sram_addr;
                        if (sdram_size != 0) save_ram_addr <= ram_addr;
                     end else state <= STATE_STORE_SLOT_CONFIG;
               end
            end
            STATE_FILL_RAM2: begin
               if (sdram_ready & ~ram_ce) begin
                  data_size  <= data_size - 25'd1;
                  ram_ce     <= 1;
                  if (data_size == 25'd1) begin
                     state    <= STATE_FILL_RAM;
                     if (save_addr > 0) begin
                        ddr3_addr <= save_addr; //restore
                        save_addr <= 28'd0;
                        if (mapper == MAPPER_AUTO) mapper <= detect_mapper;
                     end
                  end else begin
                     if (data_id != ROM_RAM) ddr3_rd <= 1'b1;
                  end
               end
            end
            STATE_STORE_SLOT_CONFIG: begin
               if (mode[1:0] != 2'd0) begin
                  slot_layout[{slotSubslot,2'd0}].mapper      <= mode[1:0] == 2'd1 ? slot_layout[{slotSubslot,param[1:0]}].mapper  :
                                                                 mode[1:0] == 2'd2 ? mapper                                        :
                                                                                     MAPPER_UNUSED                                 ;

                  slot_layout[{slotSubslot,2'd0}].device      <= mode[1:0] == 2'd2 ? device                                        :
                                                                 mode[1:0] == 2'd3 ? device                                        :
                                                                                     DEVICE_NONE                                   ;

                  slot_layout[{slotSubslot,2'd0}].ref_ram     <= mode[1:0] == 2'd1 ? slot_layout[{slotSubslot,param[1:0]}].ref_ram : ref_ram;
                  slot_layout[{slotSubslot,2'd0}].offset_ram  <= mode[1:0] == 2'd1 ? slot_layout[{slotSubslot,param[1:0]}].offset_ram : param[1:0];
                  slot_layout[{slotSubslot,2'd0}].cart_num    <= config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_B;
               end
               if (mode[3:2] != 2'd0) begin
                  slot_layout[{slotSubslot,2'd1}].mapper      <= mode[3:2] == 2'd1 ? slot_layout[{slotSubslot,param[3:2]}].mapper  :
                                                                 mode[3:2] == 2'd2 ? mapper                                        :
                                                                                     MAPPER_UNUSED                                 ;

                  slot_layout[{slotSubslot,2'd1}].device      <= mode[3:2] == 2'd2 ? device                                        :
                                                                 mode[3:2] == 2'd3 ? device                                        :
                                                                                     DEVICE_NONE                                   ;

                  slot_layout[{slotSubslot,2'd1}].ref_ram     <= mode[3:2] == 2'd1 ? slot_layout[{slotSubslot,param[3:2]}].ref_ram : ref_ram;
                  slot_layout[{slotSubslot,2'd1}].offset_ram  <= mode[3:2] == 2'd1 ? slot_layout[{slotSubslot,param[3:2]}].offset_ram : param[3:2];
                  slot_layout[{slotSubslot,2'd1}].cart_num    <= config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_B;
               end
               if (mode[5:4] != 2'd0) begin
                  slot_layout[{slotSubslot,2'd2}].mapper      <= mode[5:4] == 2'd1 ? slot_layout[{slotSubslot,param[5:4]}].mapper  :
                                                                 mode[5:4] == 2'd2 ? mapper                                        :
                                                                                     MAPPER_UNUSED                                 ;

                  slot_layout[{slotSubslot,2'd2}].device      <= mode[5:4] == 2'd2 ? device                                        :
                                                                 mode[5:4] == 2'd3 ? device                                        :
                                                                                     DEVICE_NONE                                   ;

                  slot_layout[{slotSubslot,2'd2}].ref_ram     <= mode[5:4] == 2'd1 ? slot_layout[{slotSubslot,param[5:4]}].ref_ram : ref_ram;
                  slot_layout[{slotSubslot,2'd2}].offset_ram  <= mode[5:4] == 2'd1 ? slot_layout[{slotSubslot,param[5:4]}].offset_ram : param[5:4];
                  slot_layout[{slotSubslot,2'd2}].cart_num    <= config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_B;
               end
               if (mode[7:6] != 2'd0) begin
                  slot_layout[{slotSubslot,2'd3}].mapper      <= mode[7:6] == 2'd1 ? slot_layout[{slotSubslot,param[7:6]}].mapper  :
                                                                 mode[7:6] == 2'd2 ? mapper                                        :
                                                                                     MAPPER_UNUSED                                 ;

                  slot_layout[{slotSubslot,2'd3}].device      <= mode[7:6] == 2'd2 ? device                                        :
                                                                 mode[7:6] == 2'd3 ? device                                        :
                                                                                     DEVICE_NONE                                   ;

                  slot_layout[{slotSubslot,2'd3}].ref_ram     <= mode[7:6] == 2'd1 ? slot_layout[{slotSubslot,param[7:6]}].ref_ram : ref_ram;
                  slot_layout[{slotSubslot,2'd3}].offset_ram  <= mode[7:6] == 2'd1 ? slot_layout[{slotSubslot,param[7:6]}].offset_ram : param[7:6];
                  slot_layout[{slotSubslot,2'd3}].cart_num    <= config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_B;
               end
               state <= STATE_READ_CONF;
               ref_ram <= ref_ram + 4'(refAdd);
               refAdd  <= 1'b0;

               if (config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_A | config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_B) begin
                  if (subslot < 2'd3) begin
                     subslot <= subslot + 1'd1;
                     state <= STATE_CHECK_CONFIG;
                  end else begin
                     subslot <= 0;
                  end
             
               end              
            end
            default: ;
         endcase
      end
   end

mapper_typ_t detect_mapper;
mapper_detect mapper_detect 
(
   .clk(clk),
   .rst(state == STATE_READ_CONF),
   .data(ddr3_dout),
   .wr(ram_ce),
   .rom_size(ioctl_size[config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_A ? 2'd2 : 2'd3]),
   .mapper(detect_mapper),
   .offset()
);

mapper_typ_t cart_mapper;
device_typ_t cart_mem_device;
data_ID_t    cart_rom_id;
logic  [7:0] cart_sram_size, cart_mode, cart_param, cart_ram_size;

cart_confDecoder cart_decoder
(
   .typ(cart_conf[config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_B].typ),
   .selected_mapper(cart_conf[config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_B].selected_mapper),
   .selected_sram_size(cart_conf[config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_B].selected_sram_size),
   .subslot(subslot),
   .mapper(cart_mapper), 
   .mem_device(cart_mem_device),
   .rom_id(cart_rom_id),
   .sram_size(cart_sram_size),
   .ram_size(cart_ram_size),
   .mode(cart_mode),
   .param(cart_param)
);

endmodule

module cart_confDecoder
(
   input  cart_typ_t   typ,
   input  mapper_typ_t selected_mapper,
   input  logic  [7:0] selected_sram_size,
   input         [1:0] subslot,
   output mapper_typ_t mapper, 
   output device_typ_t mem_device,
   output data_ID_t    rom_id,
   output logic  [7:0] sram_size,
   output logic  [7:0] ram_size,
   output logic  [7:0] mode,
   output logic  [7:0] param
);

assign                                        {mapper          , mem_device  , rom_id    , mode  , param , sram_size          , ram_size } = 
   typ == CART_TYP_ROM    & subslot == 2'd0 ? {selected_mapper , DEVICE_NONE , ROM_ROM   , 8'hAA , 8'hE4 , selected_sram_size , 8'd0     } :
   typ == CART_TYP_SCC    & subslot == 2'd0 ? {MAPPER_UNUSED   , DEVICE_NONE , ROM_NONE  , 8'h00 , 8'h00 , 8'd0               , 8'd0     } :
   typ == CART_TYP_SCC2   & subslot == 2'd0 ? {MAPPER_UNUSED   , DEVICE_NONE , ROM_NONE  , 8'h00 , 8'h00 , 8'd0               , 8'd0     } :
   typ == CART_TYP_FM_PAC & subslot == 2'd0 ? {MAPPER_FMPAC    , DEVICE_NONE , ROM_FMPAC , 8'h08 , 8'h00 , 8'd8               , 8'd0     } : //4000 - 7FFF
   typ == CART_TYP_MFRSD  & subslot == 2'd0 ? {MAPPER_UNUSED   , DEVICE_NONE , ROM_NONE  , 8'h00 , 8'h00 , 8'd0               , 8'd0     } :
   typ == CART_TYP_MFRSD  & subslot == 2'd1 ? {MAPPER_UNUSED   , DEVICE_NONE , ROM_NONE  , 8'h00 , 8'h00 , 8'd0               , 8'd0     } :
   typ == CART_TYP_MFRSD  & subslot == 2'd2 ? {MAPPER_RAM      , DEVICE_NONE , ROM_RAM   , 8'hAA , 8'h00 , 8'd0               , 8'd32    } :
   typ == CART_TYP_MFRSD  & subslot == 2'd3 ? {MAPPER_UNUSED   , DEVICE_NONE , ROM_NONE  , 8'h00 , 8'h00 , 8'd0               , 8'd0     } :
   typ == CART_TYP_GM2    & subslot == 2'd0 ? {MAPPER_UNUSED   , DEVICE_NONE , ROM_NONE  , 8'h00 , 8'h00 , 8'd8               , 8'd0     } :
   typ == CART_TYP_FDC    & subslot == 2'd0 ? {MAPPER_NONE     , DEVICE_FDC  , ROM_FDC   , 8'h08 , 8'h00 , 8'd0               , 8'd0     } :
   /*typ == CART_TYP_EMPTY*/                  {MAPPER_UNUSED   , DEVICE_NONE , ROM_NONE  , 8'h00 , 8'h00 , 8'd0               , 8'd0     } ;

endmodule