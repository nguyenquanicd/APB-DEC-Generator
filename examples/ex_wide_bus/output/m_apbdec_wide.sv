/*
 * Project      : APB Decoder Generator
 * Author       : qtt\pc (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-05
 * Description  : APB4 decoder with 3 slave(s): window match, local address, response.
 */
`timescale 1ns/1ps

module m_apbdec_wide #(
  // Window of every slave (first and last byte, inclusive) and port width
  localparam logic [31:0] LPARA_LOWMEM_END = 32'h0000FFFF,
  localparam logic [31:0] LPARA_LOWMEM_W = 16,
  localparam logic [31:0] LPARA_MIDDLE_START = 32'h12345678,
  localparam logic [31:0] LPARA_MIDDLE_END = 32'h123456FF,
  localparam logic [31:0] LPARA_MIDDLE_W = 8,
  localparam logic [31:0] LPARA_TOPREG_START = 32'hFFFFFF00,
  localparam logic [31:0] LPARA_TOPREG_W = 8
) (
  // APB4 requester side
  input  wire  [31:0] i_paddr,
  input  wire  [2:0]  i_pprot,
  input  wire         i_psel,
  input  wire         i_penable,
  input  wire         i_pwrite,
  input  wire  [31:0] i_pwdata,
  input  wire  [3:0]  i_pstrb,
  output logic        o_pready,
  output logic [31:0] o_prdata,
  output logic        o_pslverr,

  // Response to an address that belongs to no slave: 1 = error, 0 = ready only
  input  wire         i_unmapped_err_en,

  // Slave 0: LOWMEM 0x0 to 0xFFFF (64 KB at the bottom)
  output logic        o_psel_lowmem,
  output logic        o_penable_lowmem,
  output logic        o_pwrite_lowmem,
  output logic [15:0] o_paddr_lowmem,
  output logic [31:0] o_pwdata_lowmem,
  output logic [3:0]  o_pstrb_lowmem,
  output logic [2:0]  o_pprot_lowmem,
  input  wire         i_pready_lowmem,
  input  wire         i_pslverr_lowmem,
  input  wire  [31:0] i_prdata_lowmem,

  // Slave 1: MIDDLE 0x12345678 to 0x123456FF (unaligned 136 B)
  output logic        o_psel_middle,
  output logic        o_penable_middle,
  output logic        o_pwrite_middle,
  output logic [7:0]  o_paddr_middle,
  output logic [31:0] o_pwdata_middle,
  output logic [3:0]  o_pstrb_middle,
  output logic [2:0]  o_pprot_middle,
  input  wire         i_pready_middle,
  input  wire         i_pslverr_middle,
  input  wire  [31:0] i_prdata_middle,

  // Slave 2: TOPREG 0xFFFFFF00 to 0xFFFFFFFF (last 256 bytes of the space)
  output logic        o_psel_topreg,
  output logic        o_penable_topreg,
  output logic        o_pwrite_topreg,
  output logic [7:0]  o_paddr_topreg,
  output logic [31:0] o_pwdata_topreg,
  output logic [3:0]  o_pstrb_topreg,
  output logic [2:0]  o_pprot_topreg,
  input  wire         i_pready_topreg,
  input  wire         i_pslverr_topreg,
  input  wire  [31:0] i_prdata_topreg
);

  logic [2:0] w_sel;
  logic [2:0] w_psel;
  logic w_unmapped;
  logic w_pready_sel;
  logic w_pslverr_sel;
  logic [31:0] w_prdata_sel;

  // Window match: the address is inside [START, END] of the slave, all address bits compared.
  assign w_sel[0] = (i_paddr <= LPARA_LOWMEM_END[31:0]);
  assign w_sel[1] = (i_paddr >= LPARA_MIDDLE_START[31:0]) &
                  (i_paddr <= LPARA_MIDDLE_END[31:0]);
  assign w_sel[2] = (i_paddr >= LPARA_TOPREG_START[31:0]);

  // PSEL of a slave is the window match gated with the requester select.
  assign w_psel = w_sel & {3{i_psel}};

  // No window matches the address: the decoder answers the transfer itself.
  assign w_unmapped = ~(|w_sel);

  // Response of the selected slave. The select is one-hot, so one branch matches; no match is the
  // unmapped case: ready at once and no data.
  always_comb begin : p_com_resp_sel
    w_pready_sel  = 1'b1;
    w_pslverr_sel = 1'b0;
    w_prdata_sel  = 32'd0;
    casez (w_sel)
      3'b??1: begin
        w_pready_sel  = i_pready_lowmem;
        w_pslverr_sel = i_pslverr_lowmem;
        w_prdata_sel  = i_prdata_lowmem;
      end
      3'b?10: begin
        w_pready_sel  = i_pready_middle;
        w_pslverr_sel = i_pslverr_middle;
        w_prdata_sel  = i_prdata_middle;
      end
      3'b100: begin
        w_pready_sel  = i_pready_topreg;
        w_pslverr_sel = i_pslverr_topreg;
        w_prdata_sel  = i_prdata_topreg;
      end
      default: begin
        w_pready_sel  = 1'b1;
        w_pslverr_sel = 1'b0;
        w_prdata_sel  = 32'd0;
      end
    endcase
  end

  // Ready and read data of the requester side are those of the selected slave.
  assign o_pready = w_pready_sel;
  assign o_prdata = w_prdata_sel;

  // PSLVERR is valid only in the last cycle of a transfer (PSEL, PENABLE and PREADY high). An
  // unmapped address takes the value of the pin; a mapped address takes the slave error.
  assign o_pslverr = i_psel & i_penable & w_pready_sel &
                     (w_unmapped ? i_unmapped_err_en : w_pslverr_sel);

  // Local address of every slave.
  // Address Rebase = 1: the slave sees the offset inside its window. The subtraction is
  // done modulo 2^W, which gives the low W bits of (i_paddr - START).
  assign o_paddr_lowmem = i_paddr[LPARA_LOWMEM_W-1:0];
  assign o_paddr_middle = i_paddr[LPARA_MIDDLE_W-1:0] -
                         LPARA_MIDDLE_START[LPARA_MIDDLE_W-1:0];
  assign o_paddr_topreg = i_paddr[LPARA_TOPREG_W-1:0] -
                         LPARA_TOPREG_START[LPARA_TOPREG_W-1:0];

  // Select of every slave; the other attributes reach every slave unchanged.
  assign o_psel_lowmem = w_psel[0];
  assign o_penable_lowmem = i_penable & w_psel[0];
  assign o_pwrite_lowmem = i_pwrite;
  assign o_pwdata_lowmem = i_pwdata;
  assign o_pstrb_lowmem = i_pstrb;
  assign o_pprot_lowmem = i_pprot;
  assign o_psel_middle = w_psel[1];
  assign o_penable_middle = i_penable & w_psel[1];
  assign o_pwrite_middle = i_pwrite;
  assign o_pwdata_middle = i_pwdata;
  assign o_pstrb_middle = i_pstrb;
  assign o_pprot_middle = i_pprot;
  assign o_psel_topreg = w_psel[2];
  assign o_penable_topreg = i_penable & w_psel[2];
  assign o_pwrite_topreg = i_pwrite;
  assign o_pwdata_topreg = i_pwdata;
  assign o_pstrb_topreg = i_pstrb;
  assign o_pprot_topreg = i_pprot;

endmodule
