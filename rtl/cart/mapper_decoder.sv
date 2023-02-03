module cart_mapper_decoder
(
   input            en,
   input      [5:0] mapper,
   input      [2:0] cart_type,
   output           en_konami,
   output           en_konami_scc,
   output           en_ascii8,
   output           en_ascii16,
   output           en_gm2,
   output           en_linear,
   output           en_fmPAC,
   output           en_scc,
   output           en_scc2,
   output           en_none,
   output           subtype_r_type,
   output           subtype_koei,
   output           subtype_wizardy
);

assign subtype_r_type  = mapper == MAPPER_R_TYPE;
assign subtype_koei    = mapper == MAPPER_KOEI;
assign subtype_wizardy = mapper == MAPPER_WIZARDRY;
assign en_konami       = en & cart_type == CART_TYPE_ROM & (mapper == MAPPER_KONAMI);
assign en_konami_scc   = en & cart_type == CART_TYPE_ROM & (mapper == MAPPER_KONAMI_SCC);
assign en_ascii8       = en & cart_type == CART_TYPE_ROM & (mapper == MAPPER_ASCII8  | subtype_koei | subtype_wizardy);
assign en_ascii16      = en & cart_type == CART_TYPE_ROM & (mapper == MAPPER_ASCII16 | subtype_r_type);
assign en_linear       = en & cart_type == CART_TYPE_ROM & (mapper == MAPPER_LINEAR);
assign en_fmPAC        = en & cart_type == CART_TYPE_FM_PAC;
assign en_gm2          = en & cart_type == CART_TYPE_GM2;
assign en_scc          = en & cart_type == CART_TYPE_SCC;
assign en_scc2         = en & cart_type == CART_TYPE_SCC2;
assign en_none         = en & cart_type == MAPPER_NO_UNKNOWN;
endmodule