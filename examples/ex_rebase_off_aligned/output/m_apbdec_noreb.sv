/*
 * Project      : APB Decoder Generator
 * Author       : qtt\pc (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-05
 * Description  : APB4 decoder with 8 slave(s): window match, local address, response.
 */
`timescale 1ns/1ps

module m_apbdec_noreb #(
  // Window of every slave (first and last byte, inclusive) and port width
  localparam logic [31:0] LPARA_UART_END = 32'h000000FF,
  localparam logic [31:0] LPARA_UART_W = 8,
  localparam logic [31:0] LPARA_I2C_START = 32'h00000100,
  localparam logic [31:0] LPARA_I2C_END = 32'h0000011F,
  localparam logic [31:0] LPARA_I2C_W = 5,
  localparam logic [31:0] LPARA_SPI_START = 32'h00001000,
  localparam logic [31:0] LPARA_SPI_END = 32'h00001FFF,
  localparam logic [31:0] LPARA_SPI_W = 12,
  localparam logic [31:0] LPARA_CAN_START = 32'h00008000,
  localparam logic [31:0] LPARA_CAN_END = 32'h0000FFFF,
  localparam logic [31:0] LPARA_CAN_W = 15,
  localparam logic [31:0] LPARA_PWM_START = 32'h00010000,
  localparam logic [31:0] LPARA_PWM_END = 32'h000100FF,
  localparam logic [31:0] LPARA_PWM_W = 8,
  localparam logic [31:0] LPARA_GYRO_START = 32'h00011000,
  localparam logic [31:0] LPARA_GYRO_END = 32'h000113FF,
  localparam logic [31:0] LPARA_GYRO_W = 10,
  localparam logic [31:0] LPARA_SRAMCSR_START = 32'h00014000,
  localparam logic [31:0] LPARA_SRAMCSR_END = 32'h00015FFF,
  localparam logic [31:0] LPARA_SRAMCSR_W = 13,
  localparam logic [31:0] LPARA_ROMTAB_START = 32'h00020000,
  localparam logic [31:0] LPARA_ROMTAB_END = 32'h0002001F,
  localparam logic [31:0] LPARA_ROMTAB_W = 5
) (
  // APB4 requester side
  input  wire  [23:0] i_paddr,
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

  // Slave 0: UART 0x0 to 0xFF (256 B at 0x0000)
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

  // Slave 1: I2C 0x100 to 0x11F (32 B at a multiple of 32)
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

  // Slave 2: SPI 0x1000 to 0x1FFF (4 KB at a multiple of 4 KB)
  output logic        o_psel_spi,
  output logic        o_penable_spi,
  output logic        o_pwrite_spi,
  output logic [11:0] o_paddr_spi,
  output logic [31:0] o_pwdata_spi,
  output logic [3:0]  o_pstrb_spi,
  output logic [2:0]  o_pprot_spi,
  input  wire         i_pready_spi,
  input  wire         i_pslverr_spi,
  input  wire  [31:0] i_prdata_spi,

  // Slave 3: CAN 0x8000 to 0xFFFF (32 KB at a multiple of 32 KB)
  output logic        o_psel_can,
  output logic        o_penable_can,
  output logic        o_pwrite_can,
  output logic [14:0] o_paddr_can,
  output logic [31:0] o_pwdata_can,
  output logic [3:0]  o_pstrb_can,
  output logic [2:0]  o_pprot_can,
  input  wire         i_pready_can,
  input  wire         i_pslverr_can,
  input  wire  [31:0] i_prdata_can,

  // Slave 4: PWM 0x10000 to 0x100FF (256 B)
  output logic        o_psel_pwm,
  output logic        o_penable_pwm,
  output logic        o_pwrite_pwm,
  output logic [7:0]  o_paddr_pwm,
  output logic [31:0] o_pwdata_pwm,
  output logic [3:0]  o_pstrb_pwm,
  output logic [2:0]  o_pprot_pwm,
  input  wire         i_pready_pwm,
  input  wire         i_pslverr_pwm,
  input  wire  [31:0] i_prdata_pwm,

  // Slave 5: GYRO 0x11000 to 0x113FF (1 KB)
  output logic        o_psel_gyro,
  output logic        o_penable_gyro,
  output logic        o_pwrite_gyro,
  output logic [9:0]  o_paddr_gyro,
  output logic [31:0] o_pwdata_gyro,
  output logic [3:0]  o_pstrb_gyro,
  output logic [2:0]  o_pprot_gyro,
  input  wire         i_pready_gyro,
  input  wire         i_pslverr_gyro,
  input  wire  [31:0] i_prdata_gyro,

  // Slave 6: SRAMCSR 0x14000 to 0x15FFF (8 KB)
  output logic        o_psel_sramcsr,
  output logic        o_penable_sramcsr,
  output logic        o_pwrite_sramcsr,
  output logic [12:0] o_paddr_sramcsr,
  output logic [31:0] o_pwdata_sramcsr,
  output logic [3:0]  o_pstrb_sramcsr,
  output logic [2:0]  o_pprot_sramcsr,
  input  wire         i_pready_sramcsr,
  input  wire         i_pslverr_sramcsr,
  input  wire  [31:0] i_prdata_sramcsr,

  // Slave 7: ROMTAB 0x20000 to 0x2001F (32 B)
  output logic        o_psel_romtab,
  output logic        o_penable_romtab,
  output logic        o_pwrite_romtab,
  output logic [4:0]  o_paddr_romtab,
  output logic [31:0] o_pwdata_romtab,
  output logic [3:0]  o_pstrb_romtab,
  output logic [2:0]  o_pprot_romtab,
  input  wire         i_pready_romtab,
  input  wire         i_pslverr_romtab,
  input  wire  [31:0] i_prdata_romtab
);

  logic [7:0] w_sel;
  logic [7:0] w_psel;
  logic w_unmapped;
  logic w_pready_sel;
  logic w_pslverr_sel;
  logic [31:0] w_prdata_sel;

  // Window match: the address is inside [START, END] of the slave, all address bits compared.
  assign w_sel[0] = (i_paddr <= LPARA_UART_END[23:0]);
  assign w_sel[1] = (i_paddr >= LPARA_I2C_START[23:0]) &
                  (i_paddr <= LPARA_I2C_END[23:0]);
  assign w_sel[2] = (i_paddr >= LPARA_SPI_START[23:0]) &
                  (i_paddr <= LPARA_SPI_END[23:0]);
  assign w_sel[3] = (i_paddr >= LPARA_CAN_START[23:0]) &
                  (i_paddr <= LPARA_CAN_END[23:0]);
  assign w_sel[4] = (i_paddr >= LPARA_PWM_START[23:0]) &
                  (i_paddr <= LPARA_PWM_END[23:0]);
  assign w_sel[5] = (i_paddr >= LPARA_GYRO_START[23:0]) &
                  (i_paddr <= LPARA_GYRO_END[23:0]);
  assign w_sel[6] = (i_paddr >= LPARA_SRAMCSR_START[23:0]) &
                  (i_paddr <= LPARA_SRAMCSR_END[23:0]);
  assign w_sel[7] = (i_paddr >= LPARA_ROMTAB_START[23:0]) &
                  (i_paddr <= LPARA_ROMTAB_END[23:0]);

  // PSEL of a slave is the window match gated with the requester select.
  assign w_psel = w_sel & {8{i_psel}};

  // No window matches the address: the decoder answers the transfer itself.
  assign w_unmapped = ~(|w_sel);

  // Response of the selected slave. The select is one-hot, so one branch matches; no match is the
  // unmapped case: ready at once and no data.
  always_comb begin : p_com_resp_sel
    w_pready_sel  = 1'b1;
    w_pslverr_sel = 1'b0;
    w_prdata_sel  = 32'd0;
    casez (w_sel)
      8'b???????1: begin
        w_pready_sel  = i_pready_uart;
        w_pslverr_sel = i_pslverr_uart;
        w_prdata_sel  = i_prdata_uart;
      end
      8'b??????10: begin
        w_pready_sel  = i_pready_i2c;
        w_pslverr_sel = i_pslverr_i2c;
        w_prdata_sel  = i_prdata_i2c;
      end
      8'b?????100: begin
        w_pready_sel  = i_pready_spi;
        w_pslverr_sel = i_pslverr_spi;
        w_prdata_sel  = i_prdata_spi;
      end
      8'b????1000: begin
        w_pready_sel  = i_pready_can;
        w_pslverr_sel = i_pslverr_can;
        w_prdata_sel  = i_prdata_can;
      end
      8'b???10000: begin
        w_pready_sel  = i_pready_pwm;
        w_pslverr_sel = i_pslverr_pwm;
        w_prdata_sel  = i_prdata_pwm;
      end
      8'b??100000: begin
        w_pready_sel  = i_pready_gyro;
        w_pslverr_sel = i_pslverr_gyro;
        w_prdata_sel  = i_prdata_gyro;
      end
      8'b?1000000: begin
        w_pready_sel  = i_pready_sramcsr;
        w_pslverr_sel = i_pslverr_sramcsr;
        w_prdata_sel  = i_prdata_sramcsr;
      end
      8'b10000000: begin
        w_pready_sel  = i_pready_romtab;
        w_pslverr_sel = i_pslverr_romtab;
        w_prdata_sel  = i_prdata_romtab;
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
  // Address Rebase = 0: the slave sees the raw low address bits.
  assign o_paddr_uart = i_paddr[LPARA_UART_W-1:0];
  assign o_paddr_i2c = i_paddr[LPARA_I2C_W-1:0];
  assign o_paddr_spi = i_paddr[LPARA_SPI_W-1:0];
  assign o_paddr_can = i_paddr[LPARA_CAN_W-1:0];
  assign o_paddr_pwm = i_paddr[LPARA_PWM_W-1:0];
  assign o_paddr_gyro = i_paddr[LPARA_GYRO_W-1:0];
  assign o_paddr_sramcsr = i_paddr[LPARA_SRAMCSR_W-1:0];
  assign o_paddr_romtab = i_paddr[LPARA_ROMTAB_W-1:0];

  // Select of every slave; the other attributes reach every slave unchanged.
  assign o_psel_uart = w_psel[0];
  assign o_penable_uart = i_penable & w_psel[0];
  assign o_pwrite_uart = i_pwrite;
  assign o_pwdata_uart = i_pwdata;
  assign o_pstrb_uart = i_pstrb;
  assign o_pprot_uart = i_pprot;
  assign o_psel_i2c = w_psel[1];
  assign o_penable_i2c = i_penable & w_psel[1];
  assign o_pwrite_i2c = i_pwrite;
  assign o_pwdata_i2c = i_pwdata;
  assign o_pstrb_i2c = i_pstrb;
  assign o_pprot_i2c = i_pprot;
  assign o_psel_spi = w_psel[2];
  assign o_penable_spi = i_penable & w_psel[2];
  assign o_pwrite_spi = i_pwrite;
  assign o_pwdata_spi = i_pwdata;
  assign o_pstrb_spi = i_pstrb;
  assign o_pprot_spi = i_pprot;
  assign o_psel_can = w_psel[3];
  assign o_penable_can = i_penable & w_psel[3];
  assign o_pwrite_can = i_pwrite;
  assign o_pwdata_can = i_pwdata;
  assign o_pstrb_can = i_pstrb;
  assign o_pprot_can = i_pprot;
  assign o_psel_pwm = w_psel[4];
  assign o_penable_pwm = i_penable & w_psel[4];
  assign o_pwrite_pwm = i_pwrite;
  assign o_pwdata_pwm = i_pwdata;
  assign o_pstrb_pwm = i_pstrb;
  assign o_pprot_pwm = i_pprot;
  assign o_psel_gyro = w_psel[5];
  assign o_penable_gyro = i_penable & w_psel[5];
  assign o_pwrite_gyro = i_pwrite;
  assign o_pwdata_gyro = i_pwdata;
  assign o_pstrb_gyro = i_pstrb;
  assign o_pprot_gyro = i_pprot;
  assign o_psel_sramcsr = w_psel[6];
  assign o_penable_sramcsr = i_penable & w_psel[6];
  assign o_pwrite_sramcsr = i_pwrite;
  assign o_pwdata_sramcsr = i_pwdata;
  assign o_pstrb_sramcsr = i_pstrb;
  assign o_pprot_sramcsr = i_pprot;
  assign o_psel_romtab = w_psel[7];
  assign o_penable_romtab = i_penable & w_psel[7];
  assign o_pwrite_romtab = i_pwrite;
  assign o_pwdata_romtab = i_pwdata;
  assign o_pstrb_romtab = i_pstrb;
  assign o_pprot_romtab = i_pprot;

endmodule
