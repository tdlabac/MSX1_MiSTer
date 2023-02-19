module msx_download_debug
(
   input                   clk,
   input                   reset,
   input MSX::block_t      memory_block[16],
   input MSX::slot_t       msx_slot[4],
   input MSX::rom_info_t   rom_info[2],
   input MSX::ioctl_rom_t  ioctl_rom[2],
   input MSX::msx_config_t msx_config[16],
   input MSX::fw_rom_t     fw_store[8],

   //DDR3
   output           [27:0] ddr3_addr,
   output logic      [7:0] ddr3_din,
   output logic            ddr3_upload,
   output logic            ddr3_wr,
   input                   ddr3_ready
);
   assign ddr3_addr = 28'h1400000 + addr;

   logic [2:0] state;
   logic [10:0] addr;

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
                     case (addr[3:0])
                        4'd0:  ddr3_din <= {6'd0,addr[7:6]};
                        4'd1:  ddr3_din <= msx_slot[addr[7:6]].typ;
                        4'd2:  ddr3_din <= {6'd0,addr[5:4]};
                        4'd3:  ddr3_din <= msx_slot[addr[7:6]].subslot[addr[5:4]].block[0].init;
                        4'd4:  ddr3_din <= msx_slot[addr[7:6]].subslot[addr[5:4]].block[0].block_id;
                        4'd5:  ddr3_din <= msx_slot[addr[7:6]].subslot[addr[5:4]].block[0].offset;
                        4'd6:  ddr3_din <= msx_slot[addr[7:6]].subslot[addr[5:4]].block[1].init;
                        4'd7:  ddr3_din <= msx_slot[addr[7:6]].subslot[addr[5:4]].block[1].block_id;
                        4'd8:  ddr3_din <= msx_slot[addr[7:6]].subslot[addr[5:4]].block[1].offset;
                        4'd9:  ddr3_din <= msx_slot[addr[7:6]].subslot[addr[5:4]].block[2].init;
                        4'd10: ddr3_din <= msx_slot[addr[7:6]].subslot[addr[5:4]].block[2].block_id;
                        4'd11: ddr3_din <= msx_slot[addr[7:6]].subslot[addr[5:4]].block[2].offset;
                        4'd12: ddr3_din <= msx_slot[addr[7:6]].subslot[addr[5:4]].block[3].init;
                        4'd13: ddr3_din <= msx_slot[addr[7:6]].subslot[addr[5:4]].block[3].block_id;
                        4'd14: ddr3_din <= msx_slot[addr[7:6]].subslot[addr[5:4]].block[3].offset;
                        4'd15: ddr3_din <= 8'd0;
                     endcase
                  3'd1:
                     case (addr[3:0])
                        4'd0:  ddr3_din <= memory_block[addr[7:4]].typ;
                        4'd1:  ddr3_din <= memory_block[addr[7:4]].block_count;
                        4'd2:  ddr3_din <= memory_block[addr[7:4]].mem_offset[24:16];
                        4'd3:  ddr3_din <= memory_block[addr[7:4]].mem_offset[15:8];
                        4'd4:  ddr3_din <= memory_block[addr[7:4]].mem_offset[7:0];
                        default: ddr3_din <= 8'd0;
                     endcase
                  3'd2:
                     case (addr[7:0])
                        8'd0:  ddr3_din <= rom_info[0].mapper;
                        8'd1:  ddr3_din <= rom_info[0].offset;
                        8'd2:  ddr3_din <= rom_info[0].size[24:16];
                        8'd3:  ddr3_din <= rom_info[0].size[15:8];
                        8'd4:  ddr3_din <= rom_info[0].size[7:0];
                        8'd5:  ddr3_din <= ioctl_rom[0].rom_size[24:16];
                        8'd6:  ddr3_din <= ioctl_rom[0].rom_size[15:8];
                        8'd7:  ddr3_din <= ioctl_rom[0].rom_size[7:0];
                        8'd8:  ddr3_din <= ioctl_rom[0].rom_mapper;
                        8'd9:  ddr3_din <= ioctl_rom[0].loaded;
                        8'd10: ddr3_din <= rom_info[1].mapper;
                        8'd11: ddr3_din <= rom_info[1].offset;
                        8'd12: ddr3_din <= rom_info[1].size[24:16];
                        8'd13: ddr3_din <= rom_info[1].size[15:8];
                        8'd14: ddr3_din <= rom_info[1].size[7:0];
                        8'd15: ddr3_din <= ioctl_rom[1].rom_size[24:16];
                        8'd16: ddr3_din <= ioctl_rom[1].rom_size[15:8];
                        8'd17: ddr3_din <= ioctl_rom[1].rom_size[7:0];
                        8'd18: ddr3_din <= ioctl_rom[1].rom_mapper;
                        8'd19: ddr3_din <= ioctl_rom[1].loaded;
                        default: ddr3_din <= 8'd0;
                     endcase
                  3'd3:
                     case (addr[3:0])
                        4'd0:  ddr3_din <= msx_config[addr[7:4]].typ;
                        4'd1:  ddr3_din <= msx_config[addr[7:4]].block_id;
                        4'd2:  ddr3_din <= msx_config[addr[7:4]].block_count;
                        4'd3:  ddr3_din <= msx_config[addr[7:4]].slot;
                        4'd4:  ddr3_din <= msx_config[addr[7:4]].sub_slot;
                        4'd5:  ddr3_din <= msx_config[addr[7:4]].slot_internal_mapper;
                        4'd6:  ddr3_din <= msx_config[addr[7:4]].start_block;
                        4'd7:  ddr3_din <= msx_config[addr[7:4]].store_address[24:16];
                        4'd8:  ddr3_din <= msx_config[addr[7:4]].store_address[15:8];
                        4'd9:  ddr3_din <= msx_config[addr[7:4]].store_address[7:0];
                        default: ddr3_din <= 8'd0;
                     endcase
                  3'd4:
                     case (addr[1:0])
                        4'd0:  ddr3_din <= fw_store[addr[4:2]].block_count;
                        4'd1:  ddr3_din <= fw_store[addr[4:2]].store_address[24:16];
                        4'd2:  ddr3_din <= fw_store[addr[4:2]].store_address[15:8];
                        4'd3:  ddr3_din <= fw_store[addr[4:2]].store_address[7:0];
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