module upload_debug
(
   input                   clk,
   input                   reset,
   input MSX::block_t      memory_block[16],
   input MSX::rom_info_t   rom_info[2],
   input MSX::ioctl_rom_t  ioctl_rom[2],
   input MSX::msx_config_t msx_config[16],
   input MSX::fw_rom_t     fw_store[8],
   input MSX::sram_block_t sram_block[2],
   input MSX::msx_slots_t   msx_slots,

   //DDR3
   output           [27:0] ddr3_addr,
   output logic      [7:0] ddr3_din,
   output logic            ddr3_upload,
   output logic            ddr3_wr,
   input                   ddr3_ready
);
   
   logic [2:0] state;
   logic [10:0] addr;
   
   assign ddr3_addr = 28'h1400000 + addr;
   
   always @(posedge clk) begin
      if (reset) begin
         state       <= 3'd1;
         addr        <= 11'd0;
         ddr3_wr     <= 1'b0;
         ddr3_upload <= 1'b0;
      end else begin
         case(state) 
            3'd1: state <= 3'd2;
            3'd2: begin
               case(addr[10:8])
                  3'd0:
                     case (addr[7])
                        1'd0:
                           case (addr[0])
                              1'd0: ddr3_din <= {msx_slots.mem_block[addr[6:5]][addr[4:3]][addr[2:1]].typ,
                                                 msx_slots.mem_block[addr[6:5]][addr[4:3]][addr[2:1]].offset,
                                                 msx_slots.mem_block[addr[6:5]][addr[4:3]][addr[2:1]].init};
                              1'd1: ddr3_din <= {msx_slots.mem_block[addr[6:5]][addr[4:3]][addr[2:1]].block_id, 4'd0};
                           endcase
                        1'd1:
                           if (addr[6:2] == 5'd0) 
                              ddr3_din <= msx_slots.slot_typ[addr[1:0]];
                           else 
                              ddr3_din <= 8'd0;
                     endcase
                  3'd1:
                     case (addr[3:0])
                        4'd0:  ddr3_din <= 5'd0;
                        4'd1:  ddr3_din <= memory_block[addr[7:4]].block_count;
                        4'd2:  ddr3_din <= memory_block[addr[7:4]].mem_offset[23:16];
                        4'd3:  ddr3_din <= memory_block[addr[7:4]].mem_offset[15:8];
                        4'd4:  ddr3_din <= memory_block[addr[7:4]].mem_offset[7:0];
                        default: ddr3_din <= 8'd0;
                     endcase
                  3'd2:
                     case (addr[7:0])
                        8'd0:  ddr3_din <= rom_info[0].mapper;
                        8'd1:  ddr3_din <= rom_info[0].offset;
                        8'd2:  ddr3_din <= rom_info[0].size[23:16];
                        8'd3:  ddr3_din <= rom_info[0].size[15:8];
                        8'd4:  ddr3_din <= rom_info[0].size[7:0];
                        8'd5:  ddr3_din <= ioctl_rom[0].rom_size[23:16];
                        8'd6:  ddr3_din <= ioctl_rom[0].rom_size[15:8];
                        8'd7:  ddr3_din <= ioctl_rom[0].rom_size[7:0];
                        8'd8:  ddr3_din <= ioctl_rom[0].rom_mapper;
                        8'd9:  ddr3_din <= ioctl_rom[0].loaded;
                        8'd10: ddr3_din <= rom_info[1].mapper;
                        8'd11: ddr3_din <= rom_info[1].offset;
                        8'd12: ddr3_din <= rom_info[1].size[23:16];
                        8'd13: ddr3_din <= rom_info[1].size[15:8];
                        8'd14: ddr3_din <= rom_info[1].size[7:0];
                        8'd15: ddr3_din <= ioctl_rom[1].rom_size[23:16];
                        8'd16: ddr3_din <= ioctl_rom[1].rom_size[15:8];
                        8'd17: ddr3_din <= ioctl_rom[1].rom_size[7:0];
                        8'd18: ddr3_din <= ioctl_rom[1].rom_mapper;
                        8'd19: ddr3_din <= ioctl_rom[1].loaded;
                        ///SRAM
                        8'd20: ddr3_din <= sram_block[0].block_count[7:0];
                        8'd21: ddr3_din <= sram_block[0].mem_offset[23:16];
                        8'd22: ddr3_din <= sram_block[0].mem_offset[15:8];
                        8'd23: ddr3_din <= sram_block[0].mem_offset[7:0];
                        8'd24: ddr3_din <= sram_block[1].block_count[7:0];
                        8'd25: ddr3_din <= sram_block[1].mem_offset[23:16];
                        8'd26: ddr3_din <= sram_block[1].mem_offset[15:8];
                        8'd27: ddr3_din <= sram_block[1].mem_offset[7:0];
                        default: ddr3_din <= 8'd0;
                     endcase
                  3'd3:
                     case (addr[3:0])
                        4'd0:  ddr3_din <= msx_config[addr[7:4]].typ;
                        4'd1:  ddr3_din <= msx_config[addr[7:4]].reference;
                        4'd2:  ddr3_din <= msx_config[addr[7:4]].block_count;
                        4'd3:  ddr3_din <= msx_config[addr[7:4]].slot;
                        4'd4:  ddr3_din <= msx_config[addr[7:4]].sub_slot;
                        4'd5:  ddr3_din <= 8'd0;
                        4'd6:  ddr3_din <= msx_config[addr[7:4]].start_block;
                        4'd7:  ddr3_din <= msx_config[addr[7:4]].store_address[23:16];
                        4'd8:  ddr3_din <= msx_config[addr[7:4]].store_address[15:8];
                        4'd9:  ddr3_din <= msx_config[addr[7:4]].store_address[7:0];
                        default: ddr3_din <= 8'd0;
                     endcase
                  3'd4:
                     case (addr[2:0])
                        3'd0:  ddr3_din <= fw_store[addr[5:3]].block_count;
                        3'd1:  ddr3_din <= fw_store[addr[5:3]].store_address[23:16];
                        3'd2:  ddr3_din <= fw_store[addr[5:3]].store_address[15:8];
                        3'd3:  ddr3_din <= fw_store[addr[5:3]].store_address[7:0];
                        3'd4:  ddr3_din <= fw_store[addr[5:3]].sram_block_count;
                        default: ddr3_din <= 8'd0;
                     endcase
                  default:  ddr3_din <= 8'd0;
               endcase
               state       <= 3'd3; 
               ddr3_upload <= 1'b1;
            end
            3'd3: begin
               if (ddr3_ready) begin
                  ddr3_wr <= 1'b1; 
                  state   <= 3'd4; 
               end
            end
            3'd4: begin 
               ddr3_wr <= 1'b0;
               state   <= 3'd5; 
            end
            3'd5: begin
               if (addr == 11'h7FF) begin
                  state       <= 3'd0;
                  ddr3_upload <= 1'b0; 
               end else begin
                  addr  <= addr + 1'b1;
                  state <= 3'd2;
               end 
            end     
         endcase
      end
   end

endmodule