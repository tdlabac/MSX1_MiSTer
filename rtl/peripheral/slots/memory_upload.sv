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
   output MSX::bios_config_t   bios_config
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

   typedef enum logic [2:0] {STATE_IDLE, STATE_CLEAN, STATE_READ_CONF, STATE_CHECK_CONFIG, STATE_FILL_RAM, STATE_STORE_CONFIG} state_t;
   state_t state;
   logic  [7:0] conf[16];
   
   assign reset_rq = state != STATE_IDLE;
   assign ram_din = save_addr > 28'd0 ? ddr3_dout                   :  
                    conf[3][6]        ? ddr3_dout                   :
                    ram_addr[8]       ? ram_addr[1] ? 8'hff : 8'h00 :
                                        ram_addr[1] ? 8'h00 : 8'hff ; 
   
   wire config_read_en = ddr3_addr < 28'(ioctl_size[0]);
   always @(posedge clk) begin
      logic  [5:0] block_num;
      logic  [3:0] config_head_addr;
      logic [24:0] counter;
      logic  [3:0] ref_ram;
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
         STATE_IDLE: begin
            ddr3_request     <= 1'd0;
         end
         STATE_CLEAN: begin
            ddr3_request  <= 1'd1;
            slot_layout[block_num].mapper <= MAPPER_UNUSED;
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
                     sdram_rq                 <= 1;
                  end
                  if (config_typ_t'(conf[4][$bits(config_typ_t)-1:0]) == CONFIG_SLOT_A /*| config_typ_t'(conf[3][$bits(config_typ_t)-1:0]) == CONFIG_CART_B*/) begin
                     //TADY zjistime co je nastavene pro DANY SLOT a PRIPADNE TO POSLEME DO RAM
                     //BACHA NA READ EN
                     //30A00000 je addr ROM A
                     if (ioctl_size[2] > 0) begin
                        save_addr <= ddr3_addr; //Backup addr
                        ddr3_addr <= 28'hA00000;  //ROM A addr
                        counter   <= ioctl_size[2][24:0] - 25'd1;
                        state                    <= STATE_FILL_RAM;
                        ddr3_rd                  <= 1'b1;
                        sdram_rq                 <= 1;
                        mapper                   <= MAPPER_OFFSET;
                        lookup_RAM[ref_ram].addr <= ram_addr;
                        lookup_RAM[ref_ram].size <= 16'(ioctl_size[2] >> 14);
                        lookup_RAM[ref_ram].ro   <= 1'd1;
                     end else begin                // no ROM SKIP
                         state <= STATE_READ_CONF;
                     end
                  end
               end
            end
            STATE_FILL_RAM: begin
               if (sdram_ready & ~ram_ce) begin
                  ddr3_rd  <= save_addr > 1'b0 ? 1'b1 : conf[3][6] & config_read_en;
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
               //case( config_typ_t'(conf[3][$bits(config_typ_t)-1:0]))
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
                  CONFIG_SLOT_B: begin
                     ;
                     //ddr3_rd <= config_read_en;
                  end               
                  CONFIG_NONE,
                  CONFIG_SLOT_A,
                  CONFIG_FDC: begin
                     ref_ram <= ref_ram + 1'd1;
                     if (conf[7][7:6] > 2'd0) begin                       
                        if (conf[7][7]) begin
                           slot_layout[conf[7][5:0]].ref_ram     <= ref_ram;
                           slot_layout[conf[7][5:0]].offset_ram  <= conf[8][1:0];
                        end else begin
                           slot_layout[conf[7][5:0]].ref_ram     <= slot_layout[conf[8][5:0]].ref_ram;
                           slot_layout[conf[7][5:0]].offset_ram  <= slot_layout[conf[8][5:0]].offset_ram;
                        end
                        slot_layout[conf[7][5:0]].mapper      <= mapper;
                        slot_layout[conf[7][5:0]].device      <= device;
                     end
                     if (conf[9][7:6] > 2'd0) begin                       
                        if (conf[9][7]) begin
                           slot_layout[conf[9][5:0]].ref_ram     <= ref_ram;
                           slot_layout[conf[9][5:0]].offset_ram  <= conf[10][1:0];
                        end else begin
                           slot_layout[conf[9][5:0]].ref_ram     <= slot_layout[conf[10][5:0]].ref_ram;
                           slot_layout[conf[9][5:0]].offset_ram  <= slot_layout[conf[10][5:0]].offset_ram;
                        end
                        slot_layout[conf[9][5:0]].mapper      <= mapper;
                        slot_layout[conf[9][5:0]].device      <= device;
                     end
                     if (conf[11][7:6] > 2'd0) begin                       
                        if (conf[11][7]) begin
                           slot_layout[conf[11][5:0]].ref_ram    <= ref_ram;
                           slot_layout[conf[11][5:0]].offset_ram <= conf[12][1:0];
                        end else begin
                           slot_layout[conf[11][5:0]].ref_ram     <= slot_layout[conf[12][5:0]].ref_ram;
                           slot_layout[conf[11][5:0]].offset_ram  <= slot_layout[conf[12][5:0]].offset_ram;
                        end
                        slot_layout[conf[11][5:0]].mapper     <= mapper;
                        slot_layout[conf[11][5:0]].device     <= device;
                     end
                     if (conf[13][7:6] > 2'd0) begin                       
                        if (conf[13][7]) begin
                           slot_layout[conf[13][5:0]].ref_ram    <= ref_ram;
                           slot_layout[conf[13][5:0]].offset_ram <= conf[14][1:0];
                        end else begin
                           slot_layout[conf[13][5:0]].ref_ram     <= slot_layout[conf[14][5:0]].ref_ram;
                           slot_layout[conf[13][5:0]].offset_ram  <= slot_layout[conf[14][5:0]].offset_ram;
                        end
                        slot_layout[conf[13][5:0]].mapper     <= mapper;
                        slot_layout[conf[13][5:0]].device     <= device;
                     end
                  end
                  default: state <= STATE_IDLE;
               endcase
               if (~config_read_en) state <= STATE_IDLE;
            end
            default: ;
         endcase
      end
   end

mapper_detect mapper_detect 
(
   .clk(clk),
   .rst(state == STATE_READ_CONF),
   .data(ddr3_dout),
   .wr(ram_ce),
   .rom_size(ioctl_size[2]),
   .mapper(),
   .offset()
);


endmodule