/*
 * Project      : APB Decoder Generator
 * Author       : qtt\pc (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-05
 * Description  : APB4 decoder with 3 slave(s) and output flops.
 */
`timescale 1ns/1ps

module m_apbdec_regout #(
  // Window of every slave (first and last byte, inclusive) and port width
  localparam logic [31:0] LPARA_UART_END = 32'h000000FF,
  localparam logic [31:0] LPARA_UART_W = 8,
  localparam logic [31:0] LPARA_I2C_START = 32'h00000100,
  localparam logic [31:0] LPARA_I2C_END = 32'h00000117,
  localparam logic [31:0] LPARA_I2C_W = 5,
  localparam logic [31:0] LPARA_SPI_START = 32'h00001000,
  localparam logic [31:0] LPARA_SPI_END = 32'h00001FFF,
  localparam logic [31:0] LPARA_SPI_W = 12
) (
  // Clock and reset (the register options of the generator are on)
  input  wire         i_clk_apb,
  input  wire         i_rst_n_apb,

  // APB4 requester side
  input  wire  [15:0] i_paddr,
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

  // Slave 0: UART 0x0 to 0xFF (UART, 256 B)
  output logic        o_psel_uart,
  output logic        o_penable_uart,
  output logic        o_pwrite_uart,
  output logic [7:0]  o_paddr_uart,
  output logic [31:0] o_pwdata_uart,
  output logic [3:0]  o_pstrb_uart,
  output logic [2:0]  o_pprot_uart,
  input  wire         i_pready_uart,
  input  wire         i_pslverr_uart,
  input  wire  [31:0] i_prdata_uart,

  // Slave 1: I2C 0x100 to 0x117 (I2C, 24 B)
  output logic        o_psel_i2c,
  output logic        o_penable_i2c,
  output logic        o_pwrite_i2c,
  output logic [4:0]  o_paddr_i2c,
  output logic [31:0] o_pwdata_i2c,
  output logic [3:0]  o_pstrb_i2c,
  output logic [2:0]  o_pprot_i2c,
  input  wire         i_pready_i2c,
  input  wire         i_pslverr_i2c,
  input  wire  [31:0] i_prdata_i2c,

  // Slave 2: SPI 0x1000 to 0x1FFF (SPI, 4 KB)
  output logic        o_psel_spi,
  output logic        o_penable_spi,
  output logic        o_pwrite_spi,
  output logic [11:0] o_paddr_spi,
  output logic [31:0] o_pwdata_spi,
  output logic [3:0]  o_pstrb_spi,
  output logic [2:0]  o_pprot_spi,
  input  wire         i_pready_spi,
  input  wire         i_pslverr_spi,
  input  wire  [31:0] i_prdata_spi
);

  // Requester signals seen by the decoder: the input pins.
  logic [15:0] w_req_paddr;
  logic [2:0] w_req_pprot;
  logic w_req_psel;
  logic w_req_penable;
  logic w_req_pwrite;
  logic [31:0] w_req_pwdata;
  logic [3:0] w_req_pstrb;

  logic [2:0] w_sel;
  logic w_unmapped;
  logic w_slv_ready;
  logic w_trigger;
  logic w_done;
  logic w_pulse;
  logic w_pslverr_sel;
  logic [31:0] w_prdata_sel;
  logic w_rerr;
  logic reg_acc;
  logic reg_setup;
  logic reg_o_pready;
  logic reg_o_pslverr;
  logic [31:0] reg_o_prdata;
  logic reg_psel_uart;
  logic reg_penable_uart;
  logic reg_pwrite_uart;
  logic [7:0] reg_paddr_uart;
  logic [31:0] reg_pwdata_uart;
  logic [3:0] reg_pstrb_uart;
  logic [2:0] reg_pprot_uart;
  logic reg_psel_i2c;
  logic reg_penable_i2c;
  logic reg_pwrite_i2c;
  logic [4:0] reg_paddr_i2c;
  logic [31:0] reg_pwdata_i2c;
  logic [3:0] reg_pstrb_i2c;
  logic [2:0] reg_pprot_i2c;
  logic reg_psel_spi;
  logic reg_penable_spi;
  logic reg_pwrite_spi;
  logic [11:0] reg_paddr_spi;
  logic [31:0] reg_pwdata_spi;
  logic [3:0] reg_pstrb_spi;
  logic [2:0] reg_pprot_spi;

  assign w_req_psel = i_psel;
  assign w_req_penable = i_penable;
  assign w_req_pwrite = i_pwrite;
  assign w_req_paddr = i_paddr;
  assign w_req_pprot = i_pprot;
  assign w_req_pwdata = i_pwdata;
  assign w_req_pstrb = i_pstrb;

  // Window match: the address is inside [START, END] of the slave, all address bits compared.
  assign w_sel[0] = (w_req_paddr <= LPARA_UART_END[15:0]);
  assign w_sel[1] = (w_req_paddr >= LPARA_I2C_START[15:0]) &
                  (w_req_paddr <= LPARA_I2C_END[15:0]);
  assign w_sel[2] = (w_req_paddr >= LPARA_SPI_START[15:0]) &
                  (w_req_paddr <= LPARA_SPI_END[15:0]);

  // No window matches the address: the decoder answers the transfer itself.
  assign w_unmapped = ~(|w_sel);

  // PREADY of the selected slave, taken from the pins. An address that no slave owns is ready
  // at once.
  always_comb begin : p_com_slv_ready
    w_slv_ready = 1'b1;
    casez (w_sel)
      3'b??1: w_slv_ready = i_pready_uart;
      3'b?10: w_slv_ready = i_pready_i2c;
      3'b100: w_slv_ready = i_pready_spi;
      default: w_slv_ready = 1'b1;
    endcase
  end

  // A new transfer starts when the requester setup phase is seen and the decoder is idle.
  assign w_trigger = w_req_psel & ~w_req_penable & ~reg_acc & ~reg_setup;

  // The access phase of the slave side ends in the cycle where the slave asserts PREADY.
  assign w_done = reg_acc & w_slv_ready;

  // Phase state (registered outputs): setup, then access until the slave PREADY.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_phase
    if (!i_rst_n_apb) begin
      reg_setup <= 1'b0;
      reg_acc   <= 1'b0;
    end else begin
      reg_setup <= w_trigger;
      reg_acc   <= reg_setup | (reg_acc & ~w_slv_ready);
    end
  end

  // Output stage: every output of the decoder is registered.
  // The select of a slave is high in the setup and access cycles.
  logic w_bus_nxt;
  logic w_acc_nxt;
  assign w_acc_nxt = reg_setup | (reg_acc & ~w_slv_ready);
  assign w_bus_nxt = w_trigger | w_acc_nxt;

  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_slave_out
    if (!i_rst_n_apb) begin
      reg_psel_uart    <= 1'b0;
      reg_penable_uart <= 1'b0;
      reg_pwrite_uart  <= 1'b0;
      reg_paddr_uart   <= 8'd0;
      reg_pwdata_uart  <= 32'd0;
      reg_pstrb_uart   <= 4'd0;
      reg_pprot_uart   <= 3'd0;
      reg_psel_i2c    <= 1'b0;
      reg_penable_i2c <= 1'b0;
      reg_pwrite_i2c  <= 1'b0;
      reg_paddr_i2c   <= 5'd0;
      reg_pwdata_i2c  <= 32'd0;
      reg_pstrb_i2c   <= 4'd0;
      reg_pprot_i2c   <= 3'd0;
      reg_psel_spi    <= 1'b0;
      reg_penable_spi <= 1'b0;
      reg_pwrite_spi  <= 1'b0;
      reg_paddr_spi   <= 12'd0;
      reg_pwdata_spi  <= 32'd0;
      reg_pstrb_spi   <= 4'd0;
      reg_pprot_spi   <= 3'd0;
    end else begin
      reg_psel_uart    <= w_bus_nxt & w_sel[0];
      reg_penable_uart <= w_acc_nxt & w_sel[0];
      reg_pwrite_uart  <= w_req_pwrite;
      reg_paddr_uart   <= w_req_paddr[LPARA_UART_W-1:0];
      reg_pwdata_uart  <= w_req_pwdata;
      reg_pstrb_uart   <= w_req_pstrb;
      reg_pprot_uart   <= w_req_pprot;
      reg_psel_i2c    <= w_bus_nxt & w_sel[1];
      reg_penable_i2c <= w_acc_nxt & w_sel[1];
      reg_pwrite_i2c  <= w_req_pwrite;
      reg_paddr_i2c   <= w_req_paddr[LPARA_I2C_W-1:0] - LPARA_I2C_START[LPARA_I2C_W-1:0];
      reg_pwdata_i2c  <= w_req_pwdata;
      reg_pstrb_i2c   <= w_req_pstrb;
      reg_pprot_i2c   <= w_req_pprot;
      reg_psel_spi    <= w_bus_nxt & w_sel[2];
      reg_penable_spi <= w_acc_nxt & w_sel[2];
      reg_pwrite_spi  <= w_req_pwrite;
      reg_paddr_spi   <= w_req_paddr[LPARA_SPI_W-1:0] - LPARA_SPI_START[LPARA_SPI_W-1:0];
      reg_pwdata_spi  <= w_req_pwdata;
      reg_pstrb_spi   <= w_req_pstrb;
      reg_pprot_spi   <= w_req_pprot;
    end
  end

  assign o_psel_uart = reg_psel_uart;
  assign o_penable_uart = reg_penable_uart;
  assign o_pwrite_uart = reg_pwrite_uart;
  assign o_paddr_uart = reg_paddr_uart;
  assign o_pwdata_uart = reg_pwdata_uart;
  assign o_pstrb_uart = reg_pstrb_uart;
  assign o_pprot_uart = reg_pprot_uart;
  assign o_psel_i2c = reg_psel_i2c;
  assign o_penable_i2c = reg_penable_i2c;
  assign o_pwrite_i2c = reg_pwrite_i2c;
  assign o_paddr_i2c = reg_paddr_i2c;
  assign o_pwdata_i2c = reg_pwdata_i2c;
  assign o_pstrb_i2c = reg_pstrb_i2c;
  assign o_pprot_i2c = reg_pprot_i2c;
  assign o_psel_spi = reg_psel_spi;
  assign o_penable_spi = reg_penable_spi;
  assign o_pwrite_spi = reg_pwrite_spi;
  assign o_paddr_spi = reg_paddr_spi;
  assign o_pwdata_spi = reg_pwdata_spi;
  assign o_pstrb_spi = reg_pstrb_spi;
  assign o_pprot_spi = reg_pprot_spi;

  // Response data and error of the selected slave (pins).
  always_comb begin : p_com_resp_sel
    w_pslverr_sel = 1'b0;
    w_prdata_sel  = 32'd0;
    casez (w_sel)
      3'b??1: begin
        w_pslverr_sel = i_pslverr_uart;
        w_prdata_sel  = i_prdata_uart;
      end
      3'b?10: begin
        w_pslverr_sel = i_pslverr_i2c;
        w_prdata_sel  = i_prdata_i2c;
      end
      3'b100: begin
        w_pslverr_sel = i_pslverr_spi;
        w_prdata_sel  = i_prdata_spi;
      end
      default: begin
        w_pslverr_sel = 1'b0;
        w_prdata_sel  = 32'd0;
      end
    endcase
  end

  // An unmapped address takes the value of the pin; a mapped address takes the slave error.
  assign w_rerr = w_unmapped ? i_unmapped_err_en : w_pslverr_sel;

  // One response pulse per transfer: the cycle of the end of the access.
  assign w_pulse = w_done;

  // Output stage of the requester side: PREADY is the registered pulse, PSLVERR is valid only
  // together with it.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_resp_out
    if (!i_rst_n_apb) begin
      reg_o_pready  <= 1'b0;
      reg_o_prdata  <= 32'd0;
      reg_o_pslverr <= 1'b0;
    end else begin
      reg_o_pready  <= w_pulse;
      reg_o_prdata  <= w_prdata_sel;
      reg_o_pslverr <= w_pulse & w_rerr;
    end
  end

  assign o_pready  = reg_o_pready;
  assign o_prdata  = reg_o_prdata;
  assign o_pslverr = reg_o_pslverr;

endmodule
