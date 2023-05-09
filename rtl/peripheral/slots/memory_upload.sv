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

   typedef enum logic [2:0] {STATE_IDLE, STATE_CLEAN, STATE_READ_CONF, STATE_CHECK_CONFIG, STATE_FILL_RAM, STATE_STORE_CONFIG, STATE_FILL_1, STATE_ERROR} state_t;
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
   
   wire config_read_en    = ddr3_addr < 28'(ioctl_size[0]);
   wire config_read_fw_en = (ddr3_addr - 28'h100000) < 28'(ioctl_size[1]);

   always @(posedge clk) begin
      logic  [5:0] block_num;
      logic  [3:0] config_head_addr;
      logic [24:0] counter;
      logic  [3:0] ref_ram;
      logic        fw_find;
      mapper_typ_t mapper;
      device_typ_t device;

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
                  if (ddr3_ready) begin
                     state         <= STATE_READ_CONF;
                     ddr3_rd       <= config_read_en;
                     block_num     <= 0;
                  end
               end else begin
                  block_num  <= block_num + 1'd1;
               end
            end
            STATE_READ_CONF: begin
               config_head_addr <= config_head_addr + 1'd1;              
               ddr3_rd          <= config_read_en;
               conf[config_head_addr] <= ddr3_dout;         
               if (config_head_addr == 4'b1111) begin
                  state <= STATE_CHECK_CONFIG;
                  ddr3_rd          <= 1'd0;
                  config_head_addr <= 4'd0;
                  fw_find          <= 1'd0;
               end
            end
            STATE_CHECK_CONFIG: begin
               state <= STATE_IDLE;
               if ({conf[0],conf[1],conf[2]} == {"M","S","X"}) begin
                  state <= STATE_STORE_CONFIG;
                  mapper  <= mapper_typ_t'(conf[3][5:0]);
                  case (config_typ_t'(conf[4]))
                     CONFIG_FDC: device <= DEVICE_FDC;
                     default:    device <= DEVICE_NONE;
                  endcase
                  counter <= {conf[5][2:0], conf[6],14'h0} - 25'd1;
                  ddr3_rd <= config_read_en;                                     //Prefetch
                  if (conf[3][7]) begin                                          //Fill ?
                     lookup_RAM[ref_ram].addr <= ram_addr;
                     lookup_RAM[ref_ram].size <= {conf[5], conf[6]};
                     lookup_RAM[ref_ram].ro   <= conf[3][6];                     //RO
                     state                    <= STATE_FILL_RAM;
                     sdram_rq                 <= 1'b1;
                     pattern                  <= conf[3][6] ? 2'd0 : 2'd3;       //DRAM or RAM pattern;
                  end
                  if (config_typ_t'(conf[4]) == CONFIG_SLOT_A | config_typ_t'(conf[4]) == CONFIG_SLOT_B) begin
                     case (cart_conf[config_typ_t'(conf[4]) == CONFIG_SLOT_B].typ)
                        CART_TYP_FDC: begin
                           if (fw_find) begin
                              lookup_RAM[ref_ram].addr <= ram_addr;
                              lookup_RAM[ref_ram].size <= {fw_conf[5],fw_conf[6]};
                              lookup_RAM[ref_ram].ro   <= 1'd1;
                              counter                  <= (25'({fw_conf[5],fw_conf[6]}) << 14) - 25'd1;
                              state                    <= STATE_FILL_RAM;
                              sdram_rq                 <= 1;
                              mapper                   <= MAPPER_NONE;
                              pattern                  <= 2'd0;  
                              device                   <= DEVICE_FDC;
                              conf[7][7:6]             <= 2'd3; //Only device
                              conf[9][7:6]             <= 2'd2; //Standart
                              conf[11][7:6]            <= 2'd3; //Only device
                              conf[13][7:6]            <= 2'd3; //Only device
                           end else begin 
                              if (ioctl_size[1] > 0) begin
                                 save_addr <= ddr3_addr;                                                             //Backup addr
                                 ddr3_addr <= 28'h100000;                                                            //FW area
                                 ddr3_rd   <= 1'b1;                                                                  //Prefetch
                                 state     <= STATE_FILL_1;                                                          //seek fw
                                 device <= DEVICE_FDC;                                                               //search fw
                              end else begin
                                 state <= STATE_READ_CONF;  //NO FW ROM SKIP
                              end
                           end
                        end
                        CART_TYP_FM_PAC: begin
                           if (fw_find) begin
                              lookup_RAM[ref_ram].addr <= ram_addr;
                              lookup_RAM[ref_ram].size <= {fw_conf[5],fw_conf[6]};
                              lookup_RAM[ref_ram].ro   <= 1'd1;
                              counter                  <= (25'({fw_conf[5],fw_conf[6]}) << 14) - 25'd1;
                              state                    <= STATE_FILL_RAM;
                              sdram_rq                 <= 1;
                              mapper                   <= MAPPER_DEVICE;
                              pattern                  <= 2'd0;  
                              device                   <= DEVICE_FMPAC;
                              conf[7][7:6]             <= 2'd2; //Standart
                              conf[9][7:6]             <= 2'd2; //Standart
                              conf[11][7:6]            <= 2'd2; //Standart
                              conf[13][7:6]            <= 2'd2; //Standart
                           end else begin
                              if (ioctl_size[1] > 0) begin
                                 save_addr <= ddr3_addr;                                                             //Backup addr
                                 ddr3_addr <= 28'h100000;                                                            //FW area
                                 ddr3_rd   <= 1'b1;                                                                  //Prefetch
                                 state     <= STATE_FILL_1;                                                          //seek fw
                                 device <= DEVICE_FMPAC;                                                             //search fw
                              end else begin
                                 state <= STATE_READ_CONF;  //NO FW ROM SKIP
                              end
                           end
                        end
                        
                        CART_TYP_ROM: begin
                           if (ioctl_size[config_typ_t'(conf[4]) == CONFIG_SLOT_A ? 2 : 3] > 0) begin
                              lookup_RAM[ref_ram].addr <= ram_addr;
                              lookup_RAM[ref_ram].size <= 16'(ioctl_size[config_typ_t'(conf[4]) == CONFIG_SLOT_A ? 2 : 3] >> 14);
                              lookup_RAM[ref_ram].ro   <= 1'd1;
                              save_addr <= ddr3_addr;                                                             //Backup addr
                              ddr3_addr <= config_typ_t'(conf[4]) == CONFIG_SLOT_A ? 28'hA00000 : 28'hF00000 ;    //ROM Store
                              counter   <= ioctl_size[config_typ_t'(conf[4]) == CONFIG_SLOT_A ? 2 : 3][24:0] - 25'd1;
                              state                    <= STATE_FILL_RAM;
                              ddr3_rd                  <= 1'b1;
                              sdram_rq                 <= 1;
                              mapper                   <= cart_conf[config_typ_t'(conf[4]) == CONFIG_SLOT_B].mapper;
                              pattern                  <= 2'd0;                              
                           end else begin                // no ROM SKIP
                              state <= STATE_READ_CONF;
                           end
                        end
                        default: state <= STATE_READ_CONF;
                     endcase                   
                  end
               end
            end
            STATE_FILL_1: begin
               config_head_addr <= config_head_addr + 1'd1;              
               ddr3_rd          <= config_read_fw_en;
               fw_conf[config_head_addr[2:0]] <= ddr3_dout;         
               if (config_head_addr == 4'd7) begin
                  config_head_addr <= 4'd0;
                  if ({fw_conf[0],fw_conf[1],fw_conf[2]} == {"M","S","X"}) begin
                     if (device_typ_t'(fw_conf[4]) == device) begin  
                        ddr3_addr <= ddr3_addr + 8;
                        fw_find <= 1'd1;                 //Nalezeno pokracujeme
                        state <= STATE_CHECK_CONFIG;
                     end else begin          
                        if ((ddr3_addr - 28'h100000 + (28'({fw_conf[5],fw_conf[6]}) << 14) + 28'd8) >= 28'(ioctl_size[1])) begin
                           ddr3_addr <= save_addr;
                           ddr3_rd          <= config_read_en; //prefetch
                           state <= STATE_READ_CONF; //not find skip load
                        end else begin
                           ddr3_addr <= ddr3_addr + (28'({fw_conf[5],fw_conf[6]}) << 14) + 28'd8;
                           //not usable next header
                        end
                     end
                  end else begin
                     // Havarie. sem jsme se dostali chybou
                     state <= STATE_ERROR;
                  end
                     //TODO konec FW jak budeme resit 
               end
            end
            STATE_FILL_RAM: begin
               if (sdram_ready & ~ram_ce) begin
                  ddr3_rd  <= save_addr > 28'd0 ? 1'b1 : conf[3][6] & config_read_en;
                  counter  <= counter - 25'd1;
                  ram_ce   <= 1;
                  if (counter == 0) begin
                     state    <= STATE_STORE_CONFIG;
                     if (save_addr > 0) begin
                        ddr3_addr <= save_addr; //restore
                        save_addr <= 28'd0;
                        ddr3_rd  <= 1'd1;       //Prefetch
                     end
                  end
               end
            end
            STATE_STORE_CONFIG: begin
               state   <= STATE_READ_CONF;
               sdram_rq <= 0;
               case( config_typ_t'(conf[4]))
                  CONFIG_CONFIG: begin
                     bios_config.slot_expander_en <= conf[5][3:0];
                     bios_config.MSX_typ          <= MSX_typ_t'(conf[5][5:4]);
                     ddr3_rd <= config_read_en;
                  end
                  CONFIG_KBD_LAYOUT: begin
                     ddr3_addr <= ddr3_addr + 28'h1ff;
                     ddr3_rd   <= config_read_en;
                     ;
                  end            
                  CONFIG_NONE,
                  CONFIG_SLOT_A,
                  CONFIG_SLOT_B,
                  CONFIG_FDC: begin
                     ref_ram <= ref_ram + 1'd1;
                     case(conf[7][7:6])
                        2'b00: ;
                        2'b01: begin  //Reference RAM
                           slot_layout[conf[7][5:0]].ref_ram     <= slot_layout[conf[8][5:0]].ref_ram;
                           slot_layout[conf[7][5:0]].offset_ram  <= slot_layout[conf[8][5:0]].offset_ram;
                           slot_layout[conf[7][5:0]].mapper      <= slot_layout[conf[8][5:0]].mapper;
                           slot_layout[conf[7][5:0]].device      <= device;
                        end
                        2'b10: begin  //Filed RAM
                           slot_layout[conf[7][5:0]].ref_ram     <= ref_ram;
                           slot_layout[conf[7][5:0]].offset_ram  <= conf[8][1:0];
                           slot_layout[conf[7][5:0]].mapper      <= mapper == MAPPER_AUTO ? detect_mapper : mapper;
                           slot_layout[conf[7][5:0]].device      <= device;
                        end
                        2'b11:
                           slot_layout[conf[7][5:0]].device      <= device;
                     endcase
                     slot_layout[conf[7][5:0]].cart_num    <= config_typ_t'(conf[4]) == CONFIG_SLOT_B;
                     case(conf[9][7:6])
                        2'b00: ;
                        2'b01: begin  //Reference RAM
                           slot_layout[conf[9][5:0]].ref_ram     <= slot_layout[conf[10][5:0]].ref_ram;
                           slot_layout[conf[9][5:0]].offset_ram  <= slot_layout[conf[10][5:0]].offset_ram;
                           slot_layout[conf[9][5:0]].mapper      <= slot_layout[conf[10][5:0]].mapper;
                           slot_layout[conf[9][5:0]].device      <= device;
                        end
                        2'b10: begin  //Filed RAM
                           slot_layout[conf[9][5:0]].ref_ram     <= ref_ram;
                           slot_layout[conf[9][5:0]].offset_ram  <= conf[10][1:0];
                           slot_layout[conf[9][5:0]].mapper      <= mapper == MAPPER_AUTO ? detect_mapper : mapper;
                           slot_layout[conf[9][5:0]].device      <= device;
                        end
                        2'b11:
                           slot_layout[conf[9][5:0]].device      <= device;
                     endcase
                     slot_layout[conf[9][5:0]].cart_num    <= config_typ_t'(conf[4]) == CONFIG_SLOT_B;
                     case(conf[11][7:6])
                        2'b00: ;
                        2'b01: begin  //Reference RAM
                           slot_layout[conf[11][5:0]].ref_ram     <= slot_layout[conf[12][5:0]].ref_ram;
                           slot_layout[conf[11][5:0]].offset_ram  <= slot_layout[conf[12][5:0]].offset_ram;
                           slot_layout[conf[11][5:0]].mapper      <= slot_layout[conf[12][5:0]].mapper;
                           slot_layout[conf[11][5:0]].device      <= device;
                        end
                        2'b10: begin  //Filed RAM
                           slot_layout[conf[11][5:0]].ref_ram     <= ref_ram;
                           slot_layout[conf[11][5:0]].offset_ram  <= conf[12][1:0];
                           slot_layout[conf[11][5:0]].mapper      <= mapper == MAPPER_AUTO ? detect_mapper : mapper;
                           slot_layout[conf[11][5:0]].device      <= device;
                        end
                        2'b11:
                           slot_layout[conf[11][5:0]].device      <= device;
                     endcase
                     slot_layout[conf[11][5:0]].cart_num    <= config_typ_t'(conf[4]) == CONFIG_SLOT_B;
                     case(conf[13][7:6])
                        2'b00: ;
                        2'b01: begin  //Reference RAM
                           slot_layout[conf[13][5:0]].ref_ram     <= slot_layout[conf[14][5:0]].ref_ram;
                           slot_layout[conf[13][5:0]].offset_ram  <= slot_layout[conf[14][5:0]].offset_ram;
                           slot_layout[conf[13][5:0]].mapper      <= slot_layout[conf[14][5:0]].mapper;
                           slot_layout[conf[13][5:0]].device      <= device;
                        end
                        2'b10: begin  //Filed RAM
                           slot_layout[conf[13][5:0]].ref_ram     <= ref_ram;
                           slot_layout[conf[13][5:0]].offset_ram  <= conf[14][1:0];
                           slot_layout[conf[13][5:0]].mapper      <= mapper == MAPPER_AUTO ? detect_mapper : mapper;
                           slot_layout[conf[13][5:0]].device      <= device;
                        end
                        2'b11:
                           slot_layout[conf[13][5:0]].device      <= device;
                     endcase
                     slot_layout[conf[13][5:0]].cart_num    <= config_typ_t'(conf[4]) == CONFIG_SLOT_B;
                  end
                  default: state <= STATE_IDLE;
               endcase
               if (~config_read_en) state <= STATE_IDLE;
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