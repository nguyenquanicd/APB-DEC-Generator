/*
 * Project      : APB Decoder Generator
 * Author       : qtt\pc (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-05
 * Description  : APB4 decoder with 4 slave(s): window match, local address, response.
 */
`timescale 1ns/1ps

module m_apbdec_byte #(
  // Window of every slave (first and last byte, inclusive) and port width
  localparam logic [31:0] LPARA_REGA_END = 32'h00000002,
  localparam logic [31:0] LPARA_REGA_W = 2,
  localparam logic [31:0] LPARA_REGB_START = 32'h00000003,
  localparam logic [31:0] LPARA_REGB_END = 32'h00000003,
  localparam logic [31:0] LPARA_REGB_W = 1,
  localparam logic [31:0] LPARA_REGC_START = 32'h00000010,
  localparam logic [31:0] LPARA_REGC_END = 32'h0000001F,
  localparam logic [31:0] LPARA_REGC_W = 4,
  localparam logic [31:0] LPARA_REGD_START = 32'h00008000,
  localparam logic [31:0] LPARA_REGD_END = 32'h0000BFFF,
  localparam logic [31:0] LPARA_REGD_W = 14
) (
  // APB4 requester side
  input  wire  [15:0] i_paddr,
  input  wire  [2:0]  i_pprot,
  input  wire         i_psel,
  input  wire         i_penable,
  input  wire         i_pwrite,
  input  wire  [7:0]  i_pwdata,
  input  wire         i_pstrb,
  output logic        o_pready,
  output logic [7:0]  o_prdata,
  output logic        o_pslverr,

  // Response to an address that belongs to no slave: 1 = error, 0 = ready only
  input  wire         i_unmapped_err_en,

  // Slave 0: REGA 0x0 to 0x2 (three bytes)
  output logic        o_psel_rega,
  output logic        o_penable_rega,
  output logic        o_pwrite_rega,
  output logic [1:0]  o_paddr_rega,
  output logic [7:0]  o_pwdata_rega,
  output logic        o_pstrb_rega,
  output logic [2:0]  o_pprot_rega,
  input  wire         i_pready_rega,
  input  wire         i_pslverr_rega,
  input  wire  [7:0]  i_prdata_rega,

  // Slave 1: REGB 0x3 to 0x3 (one byte)
  output logic        o_psel_regb,
  output logic        o_penable_regb,
  output logic        o_pwrite_regb,
  output logic        o_paddr_regb,
  output logic [7:0]  o_pwdata_regb,
  output logic        o_pstrb_regb,
  output logic [2:0]  o_pprot_regb,
  input  wire         i_pready_regb,
  input  wire         i_pslverr_regb,
  input  wire  [7:0]  i_prdata_regb,

  // Slave 2: REGC 0x10 to 0x1F (16 bytes)
  output logic        o_psel_regc,
  output logic        o_penable_regc,
  output logic        o_pwrite_regc,
  output logic [3:0]  o_paddr_regc,
  output logic [7:0]  o_pwdata_regc,
  output logic        o_pstrb_regc,
  output logic [2:0]  o_pprot_regc,
  input  wire         i_pready_regc,
  input  wire         i_pslverr_regc,
  input  wire  [7:0]  i_prdata_regc,

  // Slave 3: REGD 0x8000 to 0xBFFF (16 KB)
  output logic        o_psel_regd,
  output logic        o_penable_regd,
  output logic        o_pwrite_regd,
  output logic [13:0] o_paddr_regd,
  output logic [7:0]  o_pwdata_regd,
  output logic        o_pstrb_regd,
  output logic [2:0]  o_pprot_regd,
  input  wire         i_pready_regd,
  input  wire         i_pslverr_regd,
  input  wire  [7:0]  i_prdata_regd
);

  logic [3:0] w_sel;
  logic [3:0] w_psel;
  logic w_unmapped;
  logic w_pready_sel;
  logic w_pslverr_sel;
  logic [7:0] w_prdata_sel;

  // Window match: the address is inside [START, END] of the slave, all address bits compared.
  assign w_sel[0] = (i_paddr <= LPARA_REGA_END[15:0]);
  assign w_sel[1] = (i_paddr >= LPARA_REGB_START[15:0]) &
                  (i_paddr <= LPARA_REGB_END[15:0]);
  assign w_sel[2] = (i_paddr >= LPARA_REGC_START[15:0]) &
                  (i_paddr <= LPARA_REGC_END[15:0]);
  assign w_sel[3] = (i_paddr >= LPARA_REGD_START[15:0]) &
                  (i_paddr <= LPARA_REGD_END[15:0]);

  // PSEL of a slave is the window match gated with the requester select.
  assign w_psel = w_sel & {4{i_psel}};

  // No window matches the address: the decoder answers the transfer itself.
  assign w_unmapped = ~(|w_sel);

  // Response of the selected slave. The select is one-hot, so one branch matches; no match is the
  // unmapped case: ready at once and no data.
  always_comb begin : p_com_resp_sel
    w_pready_sel  = 1'b1;
    w_pslverr_sel = 1'b0;
    w_prdata_sel  = 8'd0;
    casez (w_sel)
      4'b???1: begin
        w_pready_sel  = i_pready_rega;
        w_pslverr_sel = i_pslverr_rega;
        w_prdata_sel  = i_prdata_rega;
      end
      4'b??10: begin
        w_pready_sel  = i_pready_regb;
        w_pslverr_sel = i_pslverr_regb;
        w_prdata_sel  = i_prdata_regb;
      end
      4'b?100: begin
        w_pready_sel  = i_pready_regc;
        w_pslverr_sel = i_pslverr_regc;
        w_prdata_sel  = i_prdata_regc;
      end
      4'b1000: begin
        w_pready_sel  = i_pready_regd;
        w_pslverr_sel = i_pslverr_regd;
        w_prdata_sel  = i_prdata_regd;
      end
      default: begin
        w_pready_sel  = 1'b1;
        w_pslverr_sel = 1'b0;
        w_prdata_sel  = 8'd0;
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
  assign o_paddr_rega = i_paddr[LPARA_REGA_W-1:0];
  assign o_paddr_regb = i_paddr[LPARA_REGB_W-1:0] -
                         LPARA_REGB_START[LPARA_REGB_W-1:0];
  assign o_paddr_regc = i_paddr[LPARA_REGC_W-1:0] -
                         LPARA_REGC_START[LPARA_REGC_W-1:0];
  assign o_paddr_regd = i_paddr[LPARA_REGD_W-1:0] -
                         LPARA_REGD_START[LPARA_REGD_W-1:0];

  // Select of every slave; the other attributes reach every slave unchanged.
  assign o_psel_rega = w_psel[0];
  assign o_penable_rega = i_penable & w_psel[0];
  assign o_pwrite_rega = i_pwrite;
  assign o_pwdata_rega = i_pwdata;
  assign o_pstrb_rega = i_pstrb;
  assign o_pprot_rega = i_pprot;
  assign o_psel_regb = w_psel[1];
  assign o_penable_regb = i_penable & w_psel[1];
  assign o_pwrite_regb = i_pwrite;
  assign o_pwdata_regb = i_pwdata;
  assign o_pstrb_regb = i_pstrb;
  assign o_pprot_regb = i_pprot;
  assign o_psel_regc = w_psel[2];
  assign o_penable_regc = i_penable & w_psel[2];
  assign o_pwrite_regc = i_pwrite;
  assign o_pwdata_regc = i_pwdata;
  assign o_pstrb_regc = i_pstrb;
  assign o_pprot_regc = i_pprot;
  assign o_psel_regd = w_psel[3];
  assign o_penable_regd = i_penable & w_psel[3];
  assign o_pwrite_regd = i_pwrite;
  assign o_pwdata_regd = i_pwdata;
  assign o_pstrb_regd = i_pstrb;
  assign o_pprot_regd = i_pprot;

endmodule
