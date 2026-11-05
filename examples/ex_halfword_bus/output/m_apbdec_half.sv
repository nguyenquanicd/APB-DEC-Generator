/*
 * Project      : APB Decoder Generator
 * Author       : qtt\pc (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-05
 * Description  : APB4 decoder with 3 slave(s): window match, local address, response.
 */
`timescale 1ns/1ps

module m_apbdec_half #(
  // Window of every slave (first and last byte, inclusive) and port width
  localparam logic [31:0] LPARA_TIMER_START = 32'h00000010,
  localparam logic [31:0] LPARA_TIMER_END = 32'h0000005F,
  localparam logic [31:0] LPARA_TIMER_W = 7,
  localparam logic [31:0] LPARA_GPIO_START = 32'h00000100,
  localparam logic [31:0] LPARA_GPIO_END = 32'h000001FF,
  localparam logic [31:0] LPARA_GPIO_W = 8,
  localparam logic [31:0] LPARA_WDOG_START = 32'h00000300,
  localparam logic [31:0] LPARA_WDOG_END = 32'h0000030B,
  localparam logic [31:0] LPARA_WDOG_W = 4
) (
  // APB4 requester side
  input  wire  [11:0] i_paddr,
  input  wire  [2:0]  i_pprot,
  input  wire         i_psel,
  input  wire         i_penable,
  input  wire         i_pwrite,
  input  wire  [15:0] i_pwdata,
  input  wire  [1:0]  i_pstrb,
  output logic        o_pready,
  output logic [15:0] o_prdata,
  output logic        o_pslverr,

  // Response to an address that belongs to no slave: 1 = error, 0 = ready only
  input  wire         i_unmapped_err_en,

  // Slave 0: TIMER 0x10 to 0x5F (odd start and size)
  output logic        o_psel_timer,
  output logic        o_penable_timer,
  output logic        o_pwrite_timer,
  output logic [6:0]  o_paddr_timer,
  output logic [15:0] o_pwdata_timer,
  output logic [1:0]  o_pstrb_timer,
  output logic [2:0]  o_pprot_timer,
  input  wire         i_pready_timer,
  input  wire         i_pslverr_timer,
  input  wire  [15:0] i_prdata_timer,

  // Slave 1: GPIO 0x100 to 0x1FF (256 B)
  output logic        o_psel_gpio,
  output logic        o_penable_gpio,
  output logic        o_pwrite_gpio,
  output logic [7:0]  o_paddr_gpio,
  output logic [15:0] o_pwdata_gpio,
  output logic [1:0]  o_pstrb_gpio,
  output logic [2:0]  o_pprot_gpio,
  input  wire         i_pready_gpio,
  input  wire         i_pslverr_gpio,
  input  wire  [15:0] i_prdata_gpio,

  // Slave 2: WDOG 0x300 to 0x30B (12 B)
  output logic        o_psel_wdog,
  output logic        o_penable_wdog,
  output logic        o_pwrite_wdog,
  output logic [3:0]  o_paddr_wdog,
  output logic [15:0] o_pwdata_wdog,
  output logic [1:0]  o_pstrb_wdog,
  output logic [2:0]  o_pprot_wdog,
  input  wire         i_pready_wdog,
  input  wire         i_pslverr_wdog,
  input  wire  [15:0] i_prdata_wdog
);

  logic [2:0] w_sel;
  logic [2:0] w_psel;
  logic w_unmapped;
  logic w_pready_sel;
  logic w_pslverr_sel;
  logic [15:0] w_prdata_sel;

  // Window match: the address is inside [START, END] of the slave, all address bits compared.
  assign w_sel[0] = (i_paddr >= LPARA_TIMER_START[11:0]) &
                  (i_paddr <= LPARA_TIMER_END[11:0]);
  assign w_sel[1] = (i_paddr >= LPARA_GPIO_START[11:0]) &
                  (i_paddr <= LPARA_GPIO_END[11:0]);
  assign w_sel[2] = (i_paddr >= LPARA_WDOG_START[11:0]) &
                  (i_paddr <= LPARA_WDOG_END[11:0]);

  // PSEL of a slave is the window match gated with the requester select.
  assign w_psel = w_sel & {3{i_psel}};

  // No window matches the address: the decoder answers the transfer itself.
  assign w_unmapped = ~(|w_sel);

  // Response of the selected slave. The select is one-hot, so one branch matches; no match is the
  // unmapped case: ready at once and no data.
  always_comb begin : p_com_resp_sel
    w_pready_sel  = 1'b1;
    w_pslverr_sel = 1'b0;
    w_prdata_sel  = 16'd0;
    casez (w_sel)
      3'b??1: begin
        w_pready_sel  = i_pready_timer;
        w_pslverr_sel = i_pslverr_timer;
        w_prdata_sel  = i_prdata_timer;
      end
      3'b?10: begin
        w_pready_sel  = i_pready_gpio;
        w_pslverr_sel = i_pslverr_gpio;
        w_prdata_sel  = i_prdata_gpio;
      end
      3'b100: begin
        w_pready_sel  = i_pready_wdog;
        w_pslverr_sel = i_pslverr_wdog;
        w_prdata_sel  = i_prdata_wdog;
      end
      default: begin
        w_pready_sel  = 1'b1;
        w_pslverr_sel = 1'b0;
        w_prdata_sel  = 16'd0;
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
  assign o_paddr_timer = i_paddr[LPARA_TIMER_W-1:0] -
                         LPARA_TIMER_START[LPARA_TIMER_W-1:0];
  assign o_paddr_gpio = i_paddr[LPARA_GPIO_W-1:0] -
                         LPARA_GPIO_START[LPARA_GPIO_W-1:0];
  assign o_paddr_wdog = i_paddr[LPARA_WDOG_W-1:0] -
                         LPARA_WDOG_START[LPARA_WDOG_W-1:0];

  // Select of every slave; the other attributes reach every slave unchanged.
  assign o_psel_timer = w_psel[0];
  assign o_penable_timer = i_penable & w_psel[0];
  assign o_pwrite_timer = i_pwrite;
  assign o_pwdata_timer = i_pwdata;
  assign o_pstrb_timer = i_pstrb;
  assign o_pprot_timer = i_pprot;
  assign o_psel_gpio = w_psel[1];
  assign o_penable_gpio = i_penable & w_psel[1];
  assign o_pwrite_gpio = i_pwrite;
  assign o_pwdata_gpio = i_pwdata;
  assign o_pstrb_gpio = i_pstrb;
  assign o_pprot_gpio = i_pprot;
  assign o_psel_wdog = w_psel[2];
  assign o_penable_wdog = i_penable & w_psel[2];
  assign o_pwrite_wdog = i_pwrite;
  assign o_pwdata_wdog = i_pwdata;
  assign o_pstrb_wdog = i_pstrb;
  assign o_pprot_wdog = i_pprot;

endmodule
