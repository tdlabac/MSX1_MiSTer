module store_msx_config #(parameter MAX_CONFIG = 16)
(
   input                    clk,
   input                    ioctl_download,
   input             [15:0] ioctl_index,
   input             [26:0] ioctl_addr,
   input                    ddr3_ready,
   input              [7:0] ddr3_dout,
   output            [27:0] ddr3_addr,
   output logic             ddr3_rd,
   output                   ddr3_reqest,
   input                    update_ack,
   output logic             update_request,
   output logic       [1:0] msx_type,
   output MSX::msx_config_t msx_config[MAX_CONFIG]
);
   typedef enum logic [2:0] {STATE_SLEEP, STATE_PARSE, STATE_PARSE_BLOCK, STATE_BLOCK_NONE, STATE_PARSE_NEXT} state_t;
   
   initial begin
      update_request     = 1'b0;
      state              = STATE_SLEEP;
      msx_type           = 2'd0;
      ddr3_rd            = 1'b0;
   end

   state_t       state;
   logic   [3:0] head_addr;
   logic  [27:0] start_addr;
   logic  [23:0] addr;
   logic         last_ioctl_download;

   assign ddr3_addr   = start_addr + addr + head_addr;
   assign ddr3_reqest = state != STATE_SLEEP;

   always @(posedge clk) begin
      logic  [3:0] config_cnt;
      if (ddr3_ready) ddr3_rd        <= 1'b0;
      if (update_ack) update_request <= 1'b0;
      case(state)
         STATE_SLEEP: begin
            if (last_ioctl_download & ~ioctl_download & ioctl_index[5:0] == 6'd1) begin
               start_addr         <= 28'h000000;
               addr               <= 24'b0;
               config_cnt         <= 4'b0;
               state              <= STATE_PARSE;
            end
         end
         STATE_PARSE: begin
            if (ddr3_ready) begin
               state     <= STATE_PARSE_BLOCK;
               head_addr <= 4'd0;
               ddr3_rd   <= 1'b1;
            end
         end
         STATE_PARSE_BLOCK: begin
            if (addr + head_addr > ioctl_addr) begin
               state   <= STATE_BLOCK_NONE;
               ddr3_rd <= 1'd0;
            end
            if (ddr3_ready & ~ddr3_rd) begin
               head_addr <= head_addr + 1'b1;
               ddr3_rd   <= 1'd1;
               case(head_addr)
                  4'h0 : if (ddr3_dout != "M") state        <= STATE_BLOCK_NONE;
                  4'h1 : if (ddr3_dout != "S") state        <= STATE_BLOCK_NONE;
                  4'h2 : if (ddr3_dout != "X") state        <= STATE_BLOCK_NONE;
                  4'h3 : if (config_cnt == 0) msx_type      <= ddr3_dout[1:0];
                  4'h4 : msx_config[config_cnt].slot        <= ddr3_dout[1:0];
                  4'h5 : msx_config[config_cnt].sub_slot    <= ddr3_dout[1:0];                  
                  4'h6 : msx_config[config_cnt].start_block <= ddr3_dout[1:0];
                  4'h7 : msx_config[config_cnt].typ         <= config_typ_t'(ddr3_dout);
                  4'h8 : msx_config[config_cnt].reference   <= ddr3_dout[3:0];
                  4'h9 : begin                  
                     msx_config[config_cnt].block_count     <= ddr3_dout;
                     msx_config[config_cnt].store_address   <= start_addr + addr + 5'h10;
                     addr  <= addr + 5'h10 + (msx_config[config_cnt].typ == CONFIG_RAM        ? 1'd0    :
                                              msx_config[config_cnt].typ == CONFIG_RAM_MAPPER ? 1'd0    :
                                              msx_config[config_cnt].typ == CONFIG_ROM_MIRROR ? 1'd0    :
                                              msx_config[config_cnt].typ == CONFIG_IO_MIRROR  ? 1'd0    :
                                              msx_config[config_cnt].typ == CONFIG_MIRROR     ? 1'd0    :
                                              msx_config[config_cnt].typ == CONFIG_KBD_LAYOUT ? 10'h200 :
                                                                                                ddr3_dout << 14);
                     state <= STATE_PARSE_NEXT;
                  end
               endcase
            end
         end
         STATE_BLOCK_NONE: begin
            msx_config[config_cnt].typ <= CONFIG_NONE;
            state                      <= STATE_PARSE_NEXT;
         end
         STATE_PARSE_NEXT: begin
            if (config_cnt == MAX_CONFIG - 1) begin
               state          <= STATE_SLEEP;
               update_request <= 1'b1;
            end else begin
               config_cnt   <= config_cnt + 1'b1;
               state        <= STATE_PARSE;
            end
         end
      endcase
      last_ioctl_download <= ioctl_download;
   end

endmodule