/*
 * Project      : APB Decoder Generator
 * Author       : qtt\pc (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-05
 * Description  : APB4 decoder with 1 slave(s): window match, local address, response.
 */
`timescale 1ns/1ps

module m_apbdec_full #(
  // Window of every slave (first and last byte, inclusive) and port width
  localparam logic [31:0] LPARA_ALL_W = 8
) (
  // APB4 requester side
  input  wire  [7:0]  i_paddr,
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

  // Slave 0: ALL 0x0 to 0xFF (one slave owns the whole 8-bit space: no hole)
  output logic        o_psel_all,
  output logic        o_penable_all,
  output logic        o_pwrite_all,
  output logic [7:0]  o_paddr_all,
  output logic [31:0] o_pwdata_all,
  output logic [3:0]  o_pstrb_all,
  output logic [2:0]  o_pprot_all,
  input  wire         i_pready_all,
  input  wire         i_pslverr_all,
  input  wire  [31:0] i_prdata_all
);

  logic  w_sel;
  logic  w_psel;
  logic w_unmapped;
  logic w_pready_sel;
  logic w_pslverr_sel;
  logic [31:0] w_prdata_sel;

  // Window match: the address is inside [START, END] of the slave, all address bits compared.
  assign w_sel = 1'b1;

  // PSEL of a slave is the window match gated with the requester select.
  assign w_psel = w_sel & {1{i_psel}};

  // No window matches the address: the decoder answers the transfer itself.
  assign w_unmapped = ~(|w_sel);

  // Response of the selected slave. The select is one-hot, so one branch matches; no match is the
  // unmapped case: ready at once and no data.
  always_comb begin : p_com_resp_sel
    w_pready_sel  = 1'b1;
    w_pslverr_sel = 1'b0;
    w_prdata_sel  = 32'd0;
    casez (w_sel)
      1'b1: begin
        w_pready_sel  = i_pready_all;
        w_pslverr_sel = i_pslverr_all;
        w_prdata_sel  = i_prdata_all;
      end
      // The windows cover the whole address space: this branch cannot be reached and
      // stays only to give the case a default (excluded from the coverage count).
      // verilator coverage_off
      default: begin
        w_pready_sel  = 1'b1;
        w_pslverr_sel = 1'b0;
        w_prdata_sel  = 32'd0;
      end
      // verilator coverage_on
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
  assign o_paddr_all = i_paddr[LPARA_ALL_W-1:0];

  // Select of every slave; the other attributes reach every slave unchanged.
  assign o_psel_all = w_psel;
  assign o_penable_all = i_penable & w_psel;
  assign o_pwrite_all = i_pwrite;
  assign o_pwdata_all = i_pwdata;
  assign o_pstrb_all = i_pstrb;
  assign o_pprot_all = i_pprot;

endmodule
