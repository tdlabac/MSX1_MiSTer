module store_fw_config #(parameter MAX_FW_ROM = 8)
(
   input                clk,
   input                ioctl_download,
   input         [15:0] ioctl_index,
   input         [26:0] ioctl_addr,
   input                ddr3_ready,
   input          [7:0] ddr3_dout,
   output        [27:0] ddr3_addr,
   output logic         ddr3_rd,
   output               ddr3_reqest,
   input                update_ack,
   output logic         update_request,
   output MSX::fw_rom_t fw_store[MAX_FW_ROM]
);
   typedef enum logic [1:0] {STATE_SLEEP, STATE_CLEAN, STATE_PARSE, STATE_PARSE_BLOCK} state_t;
   
   initial begin
      update_request = 1'b0;
      state          = STATE_SLEEP;
      ddr3_rd        = 1'b0;
   end

   state_t       state;
   logic   [3:0] head_addr;
   logic  [27:0] start_addr;
   logic  [23:0] addr;
   logic         last_ioctl_download;

   assign ddr3_addr   = start_addr + addr + head_addr;
   assign ddr3_reqest = state != STATE_SLEEP;

   always @(posedge clk) begin
      logic  [2:0] fw_store_id;
      if (ddr3_ready) ddr3_rd <= 1'b0;
      case(state)
         STATE_SLEEP: begin
            if (last_ioctl_download & ~ioctl_download & ioctl_index[5:0] == 6'd2) begin
               start_addr  <= 28'h500000;
               addr        <= 24'b0;
               fw_store_id <= 3'd0;
               state       <= STATE_CLEAN;
            end
         end
         STATE_CLEAN: begin
            fw_store[fw_store_id].block_count   <= 8'd0;
            fw_store[fw_store_id].store_address <= 28'd0;
            fw_store_id                         <= fw_store_id + 1'd1;
            if (fw_store_id == MAX_FW_ROM - 1)
               state <= STATE_PARSE;
         end
         STATE_PARSE: begin
            if (ddr3_ready & ~ddr3_rd) begin
               state     <= STATE_PARSE_BLOCK; 
               head_addr <= 4'd0;
               ddr3_rd   <= 1'b1;
            end
         end
         STATE_PARSE_BLOCK: begin
            if (addr + head_addr > ioctl_addr) begin
               state   <= STATE_SLEEP;
               ddr3_rd <= 1'd0;
            end
            if (ddr3_ready & ~ddr3_rd) begin
               head_addr <= head_addr + 1'b1;
               ddr3_rd   <= 1'd1;
               case(head_addr)
                  4'h0 : if (ddr3_dout != "M") state       <= STATE_SLEEP;
                  4'h1 : if (ddr3_dout != "S") state       <= STATE_SLEEP;
                  4'h2 : if (ddr3_dout != "X") state       <= STATE_SLEEP;
                  4'h4 : fw_store_id                       <= ddr3_dout[2:0];
                  4'h6 : begin
                     fw_store[fw_store_id].block_count <= ddr3_dout;
                     fw_store[fw_store_id].sram_block_count <= fw_store_id == CART_TYP_FM_PAC ? 8'd2 :
                                                               fw_store_id == CART_TYP_GM2    ? 8'd4 :
                                                                                                8'd0 ;
                     fw_store[fw_store_id].store_address    <= start_addr + addr + 5'h10;
                     addr                                   <= addr + 5'h10 + (ddr3_dout << 14);
                     state                                  <= STATE_PARSE;
                  end
               endcase
            end
         end
      endcase
      last_ioctl_download <= ioctl_download;
   end
   
endmodule