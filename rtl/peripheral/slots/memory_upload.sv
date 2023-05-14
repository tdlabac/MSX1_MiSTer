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
      logic  [7:0] sram_size;
      logic  [3:0] ref_ram;
      logic        rom_find;
      mapper_typ_t mapper;
      device_typ_t device;
      data_ID_t    data_id;
      logic [7:0]  mode;
      logic [7:0]  param;
      logic [3:0]  slotSubslot;
      logic        refAdd;
      logic [26:0] sram_addr;
      
      ddr3_wr <= 1'd0;
      
      if (ram_ce)               begin ram_ce  <= 1'b0; ram_addr  <= ram_addr + 1'd1; end
      if (ddr3_ready & ddr3_rd) begin ddr3_rd <= 1'b0; ddr3_addr <= ddr3_addr + 1'd1; end
      if (load) begin
         state <= STATE_CLEAN;
         block_num        <= 6'd0;
         config_head_addr <= 4'd0;
         ram_addr         <= 27'd0;
         ref_ram          <= 4'd0;
         ddr3_rd          <= 1'd0;
         ddr3_addr        <= 0;
         save_addr        <= 0;
         refAdd           <= 1'b0;
         sram_addr        <= 27'd0;
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
               state <= STATE_READ_CONF2;
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
               if ({conf[0],conf[1],conf[2]} == {"M","S","X"}) begin
                  state <= STATE_STORE_SLOT_CONFIG;
                  slotSubslot <= conf[3][3:0];
                  case(config_typ_t'(conf[3][7:4]))
                     CONFIG_SLOT_A,
                     CONFIG_SLOT_B: begin
                        mapper      <= cart_conf[config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_B].mapper;
                        device      <= cart_conf[config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_B].mem_device;
                        mode        <= cart_conf[config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_B].mode;
                        param       <= cart_conf[config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_B].param;
                        data_id     <= cart_conf[config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_B].rom_id;
                        case(cart_conf[config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_B].rom_id)
                           ROM_NONE: ;                          
                           ROM_ROM: begin
                              if (ioctl_size[config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_A ? 2 : 3] > 0) begin                           
                                 save_addr <= ddr3_addr;   
                                 ddr3_addr <= config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_A ? 28'hA00000 : 28'hF00000 ;    //ROM Store
                                 data_size <= ioctl_size[config_typ_t'(conf[3][7:4]) == CONFIG_SLOT_A ? 2 : 3][24:0];
                                 state     <= STATE_FILL_RAM;
                              end else begin
                                 state     <= STATE_READ_CONF;
                              end
                           end
                           ROM_RAM: ;
                           default: begin
                              save_addr <= ddr3_addr;   
                              ddr3_addr <= 28'h100000;                                                            //FW Store
                              ddr3_rd   <= 1'b1;                                                                  //Prefetch
                              state     <= STATE_FIND_ROM;
                           end
                        endcase
                     end
                     CONFIG_KBD_LAYOUT: begin
                         ddr3_addr <= ddr3_addr + 28'h200;
                         state     <= STATE_READ_CONF;
                     end
                     CONFIG_CONFIG: begin
                        bios_config.slot_expander_en <= conf[4][3:0];
                        bios_config.MSX_typ          <= MSX_typ_t'(conf[4][5:4]);
                        state                        <= STATE_READ_CONF;
                     end
                     CONFIG_SLOT_INTERNAL: begin
                        mapper      <= mapper_typ_t'(conf[8]);
                        device      <= device_typ_t'(conf[7]);
                        data_size   <= {conf[5][2:0], conf[6],14'h0};
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
               refAdd                   <= 1'b1; // Add reference po ulozeni
               lookup_RAM[ref_ram].addr <= ram_addr;
               lookup_RAM[ref_ram].size <= 16'(data_size >> 14);               
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
               state                    <= STATE_FILL_RAM2;
               sdram_rq                 <= sdram_size != 0;
               bram_rq                  <= sdram_size == 0;
            end
            STATE_FILL_RAM2: begin
               if (sdram_ready & ~ram_ce) begin
                  data_size  <= data_size - 25'd1;
                  ram_ce     <= 1;
                  if (data_size == 25'd1) begin
                     state    <= STATE_STORE_SLOT_CONFIG;
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
               if (bram_rq) sram_addr <= ram_addr;
               sdram_rq <= 0;
               bram_rq  <= 0;

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
   .rom_size(ioctl_size[2]),
   .mapper(detect_mapper),
   .offset()
);

endmodule