module store_rom_config
(
   input                   clk,
   input                   ioctl_download,
   input            [15:0] ioctl_index,
   input            [26:0] ioctl_addr,
   input                   update_ack,
   input                   rom_eject,
   output logic            update_request,
   output MSX::ioctl_rom_t ioctl_rom[2]
);

   always @(posedge clk) begin
      logic last_ioctl_download;

      if (update_ack) update_request <= 1'b0;
      if (rom_eject) begin
         ioctl_rom[0].loaded <= 1'b0;
         ioctl_rom[1].loaded <= 1'b0;
         update_request      <= 1'b1;
      end
      if (last_ioctl_download & ~ioctl_download & ioctl_index[5:0] == 6'd3) begin
         ioctl_rom[0].loaded     <= 1'b1;
         ioctl_rom[0].rom_mapper <= ioctl_index[15] ? ioctl_index[10:6] : 6'd0;
         ioctl_rom[0].rom_size   <= ioctl_addr[24:0];
         update_request          <= 1'b1;
      end
      if (last_ioctl_download & ~ioctl_download & ioctl_index[5:0] == 6'd4) begin
         ioctl_rom[1].loaded     <= 1'b1;
         ioctl_rom[1].rom_mapper <= ioctl_index[15] ? ioctl_index[10:6] : 6'd0;
         ioctl_rom[1].rom_size   <= ioctl_addr[24:0];
         update_request          <= 1'b1;
      end
      last_ioctl_download <= ioctl_download;
   end
endmodule