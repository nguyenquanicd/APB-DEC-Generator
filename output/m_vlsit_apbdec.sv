//--------------------------------------
//Project: APB Decoder Generator
//Module:  m_vlsit_apbdec
//Function: APB Decoder
//Author:  desktop-419tv1e\lenovo
//Script Author: Thang Luong (superzeldalink)
//Page:    VLSI Technology
//--------------------------------------
//Generated: 2026-03-16 04:48:17
//--------------------------------------
//Address Width: 24
//Data Width: 32
//Write Strobe: 4
//Number of Slaves: 6
//--------------------------------------

`timescale 1ns/1ps

module m_vlsit_apbdec (
  // APB Master Interface
  input  logic [23:0]   i_paddr,
  input  logic [31:0]   i_pwdata,
  input  logic [ 3:0]   i_pstrb,
  input  logic          i_pwrite,
  input  logic          i_psel,
  input  logic          i_penable,
  output logic          o_pready,
  output logic          o_pslverr,
  output logic [31:0]   o_prdata,

  // APB Slave Interfaces
  // Slave 1: UART
  output logic [ 7:0]   o_paddr_uart,
  output logic [31:0]   o_pwdata_uart,
  output logic [ 3:0]   o_pstrb_uart,
  output logic          o_psel_uart,
  output logic          o_penable_uart,
  output logic          o_pwrite_uart,
  input  logic          i_pready_uart,
  input  logic          i_pslverr_uart,
  input  logic [31:0]   i_prdata_uart,
  // Slave 2: I2C
  output logic [ 3:0]   o_paddr_i2c,
  output logic [31:0]   o_pwdata_i2c,
  output logic [ 3:0]   o_pstrb_i2c,
  output logic          o_psel_i2c,
  output logic          o_penable_i2c,
  output logic          o_pwrite_i2c,
  input  logic          i_pready_i2c,
  input  logic          i_pslverr_i2c,
  input  logic [31:0]   i_prdata_i2c,
  // Slave 3: SPI
  output logic [11:0]   o_paddr_spi,
  output logic [31:0]   o_pwdata_spi,
  output logic [ 3:0]   o_pstrb_spi,
  output logic          o_psel_spi,
  output logic          o_penable_spi,
  output logic          o_pwrite_spi,
  input  logic          i_pready_spi,
  input  logic          i_pslverr_spi,
  input  logic [31:0]   i_prdata_spi,
  // Slave 4: CAN
  output logic [14:0]   o_paddr_can,
  output logic [31:0]   o_pwdata_can,
  output logic [ 3:0]   o_pstrb_can,
  output logic          o_psel_can,
  output logic          o_penable_can,
  output logic          o_pwrite_can,
  input  logic          i_pready_can,
  input  logic          i_pslverr_can,
  input  logic [31:0]   i_prdata_can,
  // Slave 5: PWM
  output logic [ 7:0]   o_paddr_pwm,
  output logic [31:0]   o_pwdata_pwm,
  output logic [ 3:0]   o_pstrb_pwm,
  output logic          o_psel_pwm,
  output logic          o_penable_pwm,
  output logic          o_pwrite_pwm,
  input  logic          i_pready_pwm,
  input  logic          i_pslverr_pwm,
  input  logic [31:0]   i_prdata_pwm,
  // Slave 6: GYRO
  output logic [ 9:0]   o_paddr_gyro,
  output logic [31:0]   o_pwdata_gyro,
  output logic [ 3:0]   o_pstrb_gyro,
  output logic          o_psel_gyro,
  output logic          o_penable_gyro,
  output logic          o_pwrite_gyro,
  input  logic          i_pready_gyro,
  input  logic          i_pslverr_gyro,
  input  logic [31:0]   i_prdata_gyro
);

  // Internal signals
  logic w_slave_uart_sel;
  logic w_slave_i2c_sel;
  logic w_slave_spi_sel;
  logic w_slave_can_sel;
  logic w_slave_pwm_sel;
  logic w_slave_gyro_sel;
  // ============================================================================
  // Address Decode Logic
  // ============================================================================
  assign w_slave_uart_sel = (i_paddr >= 24'h0000 & i_paddr <= 24'h0000FF);
  assign w_slave_i2c_sel = (i_paddr >= 24'h0100 & i_paddr <= 24'h00010F);
  assign w_slave_spi_sel = (i_paddr >= 24'h1000 & i_paddr <= 24'h001FFF);
  assign w_slave_can_sel = (i_paddr >= 24'h2000 & i_paddr <= 24'h009FFF);
  assign w_slave_pwm_sel = (i_paddr >= 24'hA000 & i_paddr <= 24'h00A0FF);
  assign w_slave_gyro_sel = (i_paddr >= 24'hB000 & i_paddr <= 24'h00B3FF);

  // ============================================================================
  // PREADY, PSLVERR and PRDATA Generation
  // ============================================================================
  always_comb begin
    casez ({
      w_slave_gyro_sel,
      w_slave_pwm_sel,
      w_slave_can_sel,
      w_slave_spi_sel,
      w_slave_i2c_sel,
      w_slave_uart_sel
    })
      6'b?????1: begin
        o_pready  = i_pready_uart;
        o_pslverr = i_pslverr_uart;
        o_prdata  = i_prdata_uart;
      end
      6'b????10: begin
        o_pready  = i_pready_i2c;
        o_pslverr = i_pslverr_i2c;
        o_prdata  = i_prdata_i2c;
      end
      6'b???100: begin
        o_pready  = i_pready_spi;
        o_pslverr = i_pslverr_spi;
        o_prdata  = i_prdata_spi;
      end
      6'b??1000: begin
        o_pready  = i_pready_can;
        o_pslverr = i_pslverr_can;
        o_prdata  = i_prdata_can;
      end
      6'b?10000: begin
        o_pready  = i_pready_pwm;
        o_pslverr = i_pslverr_pwm;
        o_prdata  = i_prdata_pwm;
      end
      6'b100000: begin
        o_pready  = i_pready_gyro;
        o_pslverr = i_pslverr_gyro;
        o_prdata  = i_prdata_gyro;
      end
      default: begin
        o_pready  = 1'b1;
        o_pslverr = 1'b1;
        o_prdata  = 32'd0;
      end
    endcase
  end

  // ============================================================================
  // Slave Select Generation
  // ============================================================================
  assign o_psel_uart    = w_slave_uart_sel & i_psel;
  assign o_penable_uart = i_penable;
  assign o_pwrite_uart  = i_pwrite;
  assign o_paddr_uart   = i_paddr[7:0];
  assign o_pwdata_uart  = i_pwdata;
  assign o_pstrb_uart   = i_pstrb;

  assign o_psel_i2c    = w_slave_i2c_sel & i_psel;
  assign o_penable_i2c = i_penable;
  assign o_pwrite_i2c  = i_pwrite;
  assign o_paddr_i2c   = i_paddr[3:0];
  assign o_pwdata_i2c  = i_pwdata;
  assign o_pstrb_i2c   = i_pstrb;

  assign o_psel_spi    = w_slave_spi_sel & i_psel;
  assign o_penable_spi = i_penable;
  assign o_pwrite_spi  = i_pwrite;
  assign o_paddr_spi   = i_paddr[11:0];
  assign o_pwdata_spi  = i_pwdata;
  assign o_pstrb_spi   = i_pstrb;

  assign o_psel_can    = w_slave_can_sel & i_psel;
  assign o_penable_can = i_penable;
  assign o_pwrite_can  = i_pwrite;
  assign o_paddr_can   = i_paddr[14:0];
  assign o_pwdata_can  = i_pwdata;
  assign o_pstrb_can   = i_pstrb;

  assign o_psel_pwm    = w_slave_pwm_sel & i_psel;
  assign o_penable_pwm = i_penable;
  assign o_pwrite_pwm  = i_pwrite;
  assign o_paddr_pwm   = i_paddr[7:0];
  assign o_pwdata_pwm  = i_pwdata;
  assign o_pstrb_pwm   = i_pstrb;

  assign o_psel_gyro    = w_slave_gyro_sel & i_psel;
  assign o_penable_gyro = i_penable;
  assign o_pwrite_gyro  = i_pwrite;
  assign o_paddr_gyro   = i_paddr[9:0];
  assign o_pwdata_gyro  = i_pwdata;
  assign o_pstrb_gyro   = i_pstrb;

endmodule
