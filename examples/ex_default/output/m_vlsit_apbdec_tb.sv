//--------------------------------------
//Project: APB Decoder Generator
//Module:  m_vlsit_apbdec
//Function: APB Decoder Testbench
//Author:  qtt\pc
//Script Author: Thang Luong (superzeldalink)
//Page:    VLSI Technology
//Generated: 2026-11-05 23:43:44
//--------------------------------------

`timescale 1ns/1ps

// ============================================================================
// Self-checking testbench of m_vlsit_apbdec
// Address width 24, data width 32, strobe 4, 8 slave(s), Address Rebase 1
// ============================================================================
module m_vlsit_apbdec_tb;

  localparam int ADDR_WIDTH = 24;
  localparam int DATA_WIDTH = 32;
  localparam int STRB_WIDTH = 4;
  localparam int NUM_SLAVES = 8;

  logic i_clk;
  logic i_rst_n;
  logic i_unmapped_err_en;

  // Requester side (master BFM drives, decoder answers)
  logic [ADDR_WIDTH-1:0] m_paddr;
  logic [DATA_WIDTH-1:0] m_pwdata;
  logic [DATA_WIDTH-1:0] m_prdata;
  logic                  m_pwrite;
  logic                  m_psel;
  logic                  m_penable;
  logic                  m_pready;
  logic                  m_pslverr;
  logic [STRB_WIDTH-1:0] m_pstrb;
  logic [2:0]            m_pprot;

  // Slave side
  logic        o_psel_uart;
  logic        o_penable_uart;
  logic        o_pwrite_uart;
  logic [7:0] o_paddr_uart;
  logic [DATA_WIDTH-1:0] o_pwdata_uart;
  logic [STRB_WIDTH-1:0] o_pstrb_uart;
  logic [2:0]  o_pprot_uart;
  logic        i_pready_uart;
  logic        i_pslverr_uart;
  logic [DATA_WIDTH-1:0] i_prdata_uart;
  logic        o_psel_i2c;
  logic        o_penable_i2c;
  logic        o_pwrite_i2c;
  logic [4:0] o_paddr_i2c;
  logic [DATA_WIDTH-1:0] o_pwdata_i2c;
  logic [STRB_WIDTH-1:0] o_pstrb_i2c;
  logic [2:0]  o_pprot_i2c;
  logic        i_pready_i2c;
  logic        i_pslverr_i2c;
  logic [DATA_WIDTH-1:0] i_prdata_i2c;
  logic        o_psel_spi;
  logic        o_penable_spi;
  logic        o_pwrite_spi;
  logic [11:0] o_paddr_spi;
  logic [DATA_WIDTH-1:0] o_pwdata_spi;
  logic [STRB_WIDTH-1:0] o_pstrb_spi;
  logic [2:0]  o_pprot_spi;
  logic        i_pready_spi;
  logic        i_pslverr_spi;
  logic [DATA_WIDTH-1:0] i_prdata_spi;
  logic        o_psel_can;
  logic        o_penable_can;
  logic        o_pwrite_can;
  logic [14:0] o_paddr_can;
  logic [DATA_WIDTH-1:0] o_pwdata_can;
  logic [STRB_WIDTH-1:0] o_pstrb_can;
  logic [2:0]  o_pprot_can;
  logic        i_pready_can;
  logic        i_pslverr_can;
  logic [DATA_WIDTH-1:0] i_prdata_can;
  logic        o_psel_pwm;
  logic        o_penable_pwm;
  logic        o_pwrite_pwm;
  logic [7:0] o_paddr_pwm;
  logic [DATA_WIDTH-1:0] o_pwdata_pwm;
  logic [STRB_WIDTH-1:0] o_pstrb_pwm;
  logic [2:0]  o_pprot_pwm;
  logic        i_pready_pwm;
  logic        i_pslverr_pwm;
  logic [DATA_WIDTH-1:0] i_prdata_pwm;
  logic        o_psel_gyro;
  logic        o_penable_gyro;
  logic        o_pwrite_gyro;
  logic [9:0] o_paddr_gyro;
  logic [DATA_WIDTH-1:0] o_pwdata_gyro;
  logic [STRB_WIDTH-1:0] o_pstrb_gyro;
  logic [2:0]  o_pprot_gyro;
  logic        i_pready_gyro;
  logic        i_pslverr_gyro;
  logic [DATA_WIDTH-1:0] i_prdata_gyro;
  logic        o_psel_sramcsr;
  logic        o_penable_sramcsr;
  logic        o_pwrite_sramcsr;
  logic [12:0] o_paddr_sramcsr;
  logic [DATA_WIDTH-1:0] o_pwdata_sramcsr;
  logic [STRB_WIDTH-1:0] o_pstrb_sramcsr;
  logic [2:0]  o_pprot_sramcsr;
  logic        i_pready_sramcsr;
  logic        i_pslverr_sramcsr;
  logic [DATA_WIDTH-1:0] i_prdata_sramcsr;
  logic        o_psel_romtab;
  logic        o_penable_romtab;
  logic        o_pwrite_romtab;
  logic [4:0] o_paddr_romtab;
  logic [DATA_WIDTH-1:0] o_pwdata_romtab;
  logic [STRB_WIDTH-1:0] o_pstrb_romtab;
  logic [2:0]  o_pprot_romtab;
  logic        i_pready_romtab;
  logic        i_pslverr_romtab;
  logic [DATA_WIDTH-1:0] i_prdata_romtab;

  integer n_chk;
  integer n_fail;

  // ---------------------------------------------------------------- DUT
  m_vlsit_apbdec u_m_vlsit_apbdec (
    .i_paddr(m_paddr),
    .i_pprot(m_pprot),
    .i_psel(m_psel),
    .i_penable(m_penable),
    .i_pwrite(m_pwrite),
    .i_pwdata(m_pwdata),
    .i_pstrb(m_pstrb),
    .o_pready(m_pready),
    .o_prdata(m_prdata),
    .o_pslverr(m_pslverr),
    .i_unmapped_err_en(i_unmapped_err_en),
    .o_psel_uart(o_psel_uart),
    .o_penable_uart(o_penable_uart),
    .o_pwrite_uart(o_pwrite_uart),
    .o_paddr_uart(o_paddr_uart),
    .o_pwdata_uart(o_pwdata_uart),
    .o_pstrb_uart(o_pstrb_uart),
    .o_pprot_uart(o_pprot_uart),
    .i_pready_uart(i_pready_uart),
    .i_pslverr_uart(i_pslverr_uart),
    .i_prdata_uart(i_prdata_uart),
    .o_psel_i2c(o_psel_i2c),
    .o_penable_i2c(o_penable_i2c),
    .o_pwrite_i2c(o_pwrite_i2c),
    .o_paddr_i2c(o_paddr_i2c),
    .o_pwdata_i2c(o_pwdata_i2c),
    .o_pstrb_i2c(o_pstrb_i2c),
    .o_pprot_i2c(o_pprot_i2c),
    .i_pready_i2c(i_pready_i2c),
    .i_pslverr_i2c(i_pslverr_i2c),
    .i_prdata_i2c(i_prdata_i2c),
    .o_psel_spi(o_psel_spi),
    .o_penable_spi(o_penable_spi),
    .o_pwrite_spi(o_pwrite_spi),
    .o_paddr_spi(o_paddr_spi),
    .o_pwdata_spi(o_pwdata_spi),
    .o_pstrb_spi(o_pstrb_spi),
    .o_pprot_spi(o_pprot_spi),
    .i_pready_spi(i_pready_spi),
    .i_pslverr_spi(i_pslverr_spi),
    .i_prdata_spi(i_prdata_spi),
    .o_psel_can(o_psel_can),
    .o_penable_can(o_penable_can),
    .o_pwrite_can(o_pwrite_can),
    .o_paddr_can(o_paddr_can),
    .o_pwdata_can(o_pwdata_can),
    .o_pstrb_can(o_pstrb_can),
    .o_pprot_can(o_pprot_can),
    .i_pready_can(i_pready_can),
    .i_pslverr_can(i_pslverr_can),
    .i_prdata_can(i_prdata_can),
    .o_psel_pwm(o_psel_pwm),
    .o_penable_pwm(o_penable_pwm),
    .o_pwrite_pwm(o_pwrite_pwm),
    .o_paddr_pwm(o_paddr_pwm),
    .o_pwdata_pwm(o_pwdata_pwm),
    .o_pstrb_pwm(o_pstrb_pwm),
    .o_pprot_pwm(o_pprot_pwm),
    .i_pready_pwm(i_pready_pwm),
    .i_pslverr_pwm(i_pslverr_pwm),
    .i_prdata_pwm(i_prdata_pwm),
    .o_psel_gyro(o_psel_gyro),
    .o_penable_gyro(o_penable_gyro),
    .o_pwrite_gyro(o_pwrite_gyro),
    .o_paddr_gyro(o_paddr_gyro),
    .o_pwdata_gyro(o_pwdata_gyro),
    .o_pstrb_gyro(o_pstrb_gyro),
    .o_pprot_gyro(o_pprot_gyro),
    .i_pready_gyro(i_pready_gyro),
    .i_pslverr_gyro(i_pslverr_gyro),
    .i_prdata_gyro(i_prdata_gyro),
    .o_psel_sramcsr(o_psel_sramcsr),
    .o_penable_sramcsr(o_penable_sramcsr),
    .o_pwrite_sramcsr(o_pwrite_sramcsr),
    .o_paddr_sramcsr(o_paddr_sramcsr),
    .o_pwdata_sramcsr(o_pwdata_sramcsr),
    .o_pstrb_sramcsr(o_pstrb_sramcsr),
    .o_pprot_sramcsr(o_pprot_sramcsr),
    .i_pready_sramcsr(i_pready_sramcsr),
    .i_pslverr_sramcsr(i_pslverr_sramcsr),
    .i_prdata_sramcsr(i_prdata_sramcsr),
    .o_psel_romtab(o_psel_romtab),
    .o_penable_romtab(o_penable_romtab),
    .o_pwrite_romtab(o_pwrite_romtab),
    .o_paddr_romtab(o_paddr_romtab),
    .o_pwdata_romtab(o_pwdata_romtab),
    .o_pstrb_romtab(o_pstrb_romtab),
    .o_pprot_romtab(o_pprot_romtab),
    .i_pready_romtab(i_pready_romtab),
    .i_pslverr_romtab(i_pslverr_romtab),
    .i_prdata_romtab(i_prdata_romtab)
  );

  // ---------------------------------------------------------------- clock and reset
  initial begin
    i_clk = 1'b0;
    forever #5 i_clk = ~i_clk;
  end

  initial begin
    i_rst_n = 1'b0;
    #50;
    i_rst_n = 1'b1;
  end

  // ---------------------------------------------------------------- BFMs
  apb_master_bfm #(
    .PARA_ADDR_WIDTH(ADDR_WIDTH),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_APB_WAIT_STATES(0)
  ) u_master_bfm (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .o_paddr(m_paddr),
    .o_pwdata(m_pwdata),
    .i_prdata(m_prdata),
    .o_pwrite(m_pwrite),
    .o_psel(m_psel),
    .o_penable(m_penable),
    .i_pready(m_pready),
    .i_pslverr(m_pslverr),
    .o_pstrb(m_pstrb),
    .o_pprot(m_pprot)
  );

  // Slave 0: UART
  apb_slave_bfm #(
    .PARA_ADDR_WIDTH(8),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_APB_WAIT_STATES(0),
    .PARA_MEM_WORDS(32),
    .PARA_MEM_ALIAS(0)
  ) u_uart_slave_bfm (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_paddr(o_paddr_uart),
    .i_pwdata(o_pwdata_uart),
    .o_prdata(i_prdata_uart),
    .i_pwrite(o_pwrite_uart),
    .i_psel(o_psel_uart),
    .i_penable(o_penable_uart),
    .o_pready(i_pready_uart),
    .o_pslverr(i_pslverr_uart),
    .i_pstrb(o_pstrb_uart),
    .i_pprot(o_pprot_uart)
  );

  // Slave 1: I2C
  apb_slave_bfm #(
    .PARA_ADDR_WIDTH(5),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_APB_WAIT_STATES(1),
    .PARA_MEM_WORDS(8),
    .PARA_MEM_ALIAS(1)
  ) u_i2c_slave_bfm (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_paddr(o_paddr_i2c),
    .i_pwdata(o_pwdata_i2c),
    .o_prdata(i_prdata_i2c),
    .i_pwrite(o_pwrite_i2c),
    .i_psel(o_psel_i2c),
    .i_penable(o_penable_i2c),
    .o_pready(i_pready_i2c),
    .o_pslverr(i_pslverr_i2c),
    .i_pstrb(o_pstrb_i2c),
    .i_pprot(o_pprot_i2c)
  );

  // Slave 2: SPI
  apb_slave_bfm #(
    .PARA_ADDR_WIDTH(12),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_APB_WAIT_STATES(2),
    .PARA_MEM_WORDS(1024),
    .PARA_MEM_ALIAS(1)
  ) u_spi_slave_bfm (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_paddr(o_paddr_spi),
    .i_pwdata(o_pwdata_spi),
    .o_prdata(i_prdata_spi),
    .i_pwrite(o_pwrite_spi),
    .i_psel(o_psel_spi),
    .i_penable(o_penable_spi),
    .o_pready(i_pready_spi),
    .o_pslverr(i_pslverr_spi),
    .i_pstrb(o_pstrb_spi),
    .i_pprot(o_pprot_spi)
  );

  // Slave 3: CAN
  apb_slave_bfm #(
    .PARA_ADDR_WIDTH(15),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_APB_WAIT_STATES(0),
    .PARA_MEM_WORDS(1024),
    .PARA_MEM_ALIAS(1)
  ) u_can_slave_bfm (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_paddr(o_paddr_can),
    .i_pwdata(o_pwdata_can),
    .o_prdata(i_prdata_can),
    .i_pwrite(o_pwrite_can),
    .i_psel(o_psel_can),
    .i_penable(o_penable_can),
    .o_pready(i_pready_can),
    .o_pslverr(i_pslverr_can),
    .i_pstrb(o_pstrb_can),
    .i_pprot(o_pprot_can)
  );

  // Slave 4: PWM
  apb_slave_bfm #(
    .PARA_ADDR_WIDTH(8),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_APB_WAIT_STATES(1),
    .PARA_MEM_WORDS(64),
    .PARA_MEM_ALIAS(1)
  ) u_pwm_slave_bfm (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_paddr(o_paddr_pwm),
    .i_pwdata(o_pwdata_pwm),
    .o_prdata(i_prdata_pwm),
    .i_pwrite(o_pwrite_pwm),
    .i_psel(o_psel_pwm),
    .i_penable(o_penable_pwm),
    .o_pready(i_pready_pwm),
    .o_pslverr(i_pslverr_pwm),
    .i_pstrb(o_pstrb_pwm),
    .i_pprot(o_pprot_pwm)
  );

  // Slave 5: GYRO
  apb_slave_bfm #(
    .PARA_ADDR_WIDTH(10),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_APB_WAIT_STATES(2),
    .PARA_MEM_WORDS(256),
    .PARA_MEM_ALIAS(1)
  ) u_gyro_slave_bfm (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_paddr(o_paddr_gyro),
    .i_pwdata(o_pwdata_gyro),
    .o_prdata(i_prdata_gyro),
    .i_pwrite(o_pwrite_gyro),
    .i_psel(o_psel_gyro),
    .i_penable(o_penable_gyro),
    .o_pready(i_pready_gyro),
    .o_pslverr(i_pslverr_gyro),
    .i_pstrb(o_pstrb_gyro),
    .i_pprot(o_pprot_gyro)
  );

  // Slave 6: SRAMCSR
  apb_slave_bfm #(
    .PARA_ADDR_WIDTH(13),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_APB_WAIT_STATES(0),
    .PARA_MEM_WORDS(1024),
    .PARA_MEM_ALIAS(1)
  ) u_sramcsr_slave_bfm (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_paddr(o_paddr_sramcsr),
    .i_pwdata(o_pwdata_sramcsr),
    .o_prdata(i_prdata_sramcsr),
    .i_pwrite(o_pwrite_sramcsr),
    .i_psel(o_psel_sramcsr),
    .i_penable(o_penable_sramcsr),
    .o_pready(i_pready_sramcsr),
    .o_pslverr(i_pslverr_sramcsr),
    .i_pstrb(o_pstrb_sramcsr),
    .i_pprot(o_pprot_sramcsr)
  );

  // Slave 7: ROMTAB
  apb_slave_bfm #(
    .PARA_ADDR_WIDTH(5),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_APB_WAIT_STATES(1),
    .PARA_MEM_WORDS(8),
    .PARA_MEM_ALIAS(1)
  ) u_romtab_slave_bfm (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_paddr(o_paddr_romtab),
    .i_pwdata(o_pwdata_romtab),
    .o_prdata(i_prdata_romtab),
    .i_pwrite(o_pwrite_romtab),
    .i_psel(o_psel_romtab),
    .i_penable(o_penable_romtab),
    .o_pready(i_pready_romtab),
    .o_pslverr(i_pslverr_romtab),
    .i_pstrb(o_pstrb_romtab),
    .i_pprot(o_pprot_romtab)
  );

  // ---------------------------------------------------------------- waveform dump
  initial begin
`ifdef VCS
    $fsdbDumpfile("wave.fsdb");
    $fsdbDumpvars(0, m_vlsit_apbdec_tb, "+mda");
`else
    $dumpfile("wave.vcd");
    $dumpvars(0, m_vlsit_apbdec_tb);
`endif
  end

  // ---------------------------------------------------------------- check helper
  task automatic chk(input bit cond, input string what);
    n_chk = n_chk + 1;
    if (!cond) begin
      n_fail = n_fail + 1;
      $display("[TB] FAIL @%0t: %s", $time, what);
    end
  endtask

  // ---------------------------------------------------------------- reference model
  // Owner of an address: slave index, or -1 when no window contains it.
  function automatic integer owner_of(input logic [ADDR_WIDTH-1:0] a);
    owner_of = -1;
    if (a >= 24'h0 && a <= 24'hFF) owner_of = 0;
    if (a >= 24'h100 && a <= 24'h117) owner_of = 1;
    if (a >= 24'h1000 && a <= 24'h1FFF) owner_of = 2;
    if (a >= 24'h2000 && a <= 24'h9FFF) owner_of = 3;
    if (a >= 24'hA000 && a <= 24'hA0FF) owner_of = 4;
    if (a >= 24'hB000 && a <= 24'hB3FF) owner_of = 5;
    if (a >= 24'hC000 && a <= 24'hD7FF) owner_of = 6;
    if (a >= 24'hE010 && a <= 24'hE02F) owner_of = 7;
  endfunction

  // Expected local address of slave k for the requester address a.
  function automatic logic [31:0] exp_local(input integer k, input logic [ADDR_WIDTH-1:0] a);
    exp_local = 32'd0;
    case (k)
      0: exp_local = (32'(a) - 32'h0) & 32'hFF;
      1: exp_local = (32'(a) - 32'h100) & 32'h1F;
      2: exp_local = (32'(a) - 32'h1000) & 32'hFFF;
      3: exp_local = (32'(a) - 32'h2000) & 32'h7FFF;
      4: exp_local = (32'(a) - 32'hA000) & 32'hFF;
      5: exp_local = (32'(a) - 32'hB000) & 32'h3FF;
      6: exp_local = (32'(a) - 32'hC000) & 32'h1FFF;
      7: exp_local = (32'(a) - 32'hE010) & 32'h1F;
      default: exp_local = 32'd0;
    endcase
  endfunction

  // Local address that slave k actually sees.
  function automatic logic [31:0] act_local(input integer k);
    act_local = 32'd0;
    case (k)
      0: act_local = 32'(o_paddr_uart);
      1: act_local = 32'(o_paddr_i2c);
      2: act_local = 32'(o_paddr_spi);
      3: act_local = 32'(o_paddr_can);
      4: act_local = 32'(o_paddr_pwm);
      5: act_local = 32'(o_paddr_gyro);
      6: act_local = 32'(o_paddr_sramcsr);
      7: act_local = 32'(o_paddr_romtab);
      default: act_local = 32'd0;
    endcase
  endfunction

  function automatic logic sl_pready(input integer k);
    sl_pready = 1'b0;
    case (k)
      0: sl_pready = i_pready_uart;
      1: sl_pready = i_pready_i2c;
      2: sl_pready = i_pready_spi;
      3: sl_pready = i_pready_can;
      4: sl_pready = i_pready_pwm;
      5: sl_pready = i_pready_gyro;
      6: sl_pready = i_pready_sramcsr;
      7: sl_pready = i_pready_romtab;
      default: sl_pready = 1'b0;
    endcase
  endfunction

  function automatic logic sl_pslverr(input integer k);
    sl_pslverr = 1'b0;
    case (k)
      0: sl_pslverr = i_pslverr_uart;
      1: sl_pslverr = i_pslverr_i2c;
      2: sl_pslverr = i_pslverr_spi;
      3: sl_pslverr = i_pslverr_can;
      4: sl_pslverr = i_pslverr_pwm;
      5: sl_pslverr = i_pslverr_gyro;
      6: sl_pslverr = i_pslverr_sramcsr;
      7: sl_pslverr = i_pslverr_romtab;
      default: sl_pslverr = 1'b0;
    endcase
  endfunction

  function automatic logic [DATA_WIDTH-1:0] sl_prdata(input integer k);
    sl_prdata = {DATA_WIDTH{1'b0}};
    case (k)
      0: sl_prdata = i_prdata_uart;
      1: sl_prdata = i_prdata_i2c;
      2: sl_prdata = i_prdata_spi;
      3: sl_prdata = i_prdata_can;
      4: sl_prdata = i_prdata_pwm;
      5: sl_prdata = i_prdata_gyro;
      6: sl_prdata = i_prdata_sramcsr;
      7: sl_prdata = i_prdata_romtab;
      default: sl_prdata = {DATA_WIDTH{1'b0}};
    endcase
  endfunction

  // Slave error that the slave BFM answers for the local address (slave 0 only, see slave_ram).
  function automatic logic exp_slverr(input integer k, input logic [31:0] local_addr);
    exp_slverr = 1'b0;
    case (k)
      0: exp_slverr = ((local_addr >> 2) >= 32);
      default: exp_slverr = 1'b0;
    endcase
  endfunction


  // ---------------------------------------------------------------- transaction scoreboard
  // One requester transfer must give exactly one slave access at the owner of the address (none
  // for a hole), with the attributes and the local address of the reference model, and the
  // response of the requester side must be the response of that slave (or of the hole).
  logic [NUM_SLAVES-1:0] w_psel_vec;
  logic [NUM_SLAVES-1:0] w_dn_done_vec;
  assign w_psel_vec = {o_psel_romtab, o_psel_sramcsr, o_psel_gyro, o_psel_pwm, o_psel_can, o_psel_spi, o_psel_i2c, o_psel_uart};
  assign w_dn_done_vec = {(o_psel_romtab & o_penable_romtab & i_pready_romtab), (o_psel_sramcsr & o_penable_sramcsr & i_pready_sramcsr), (o_psel_gyro & o_penable_gyro & i_pready_gyro), (o_psel_pwm & o_penable_pwm & i_pready_pwm), (o_psel_can & o_penable_can & i_pready_can), (o_psel_spi & o_penable_spi & i_pready_spi), (o_psel_i2c & o_penable_i2c & i_pready_i2c), (o_psel_uart & o_penable_uart & i_pready_uart)};

  function automatic logic dn_pwrite(input integer k);
    dn_pwrite = 1'b0;
    case (k)
      0: dn_pwrite = o_pwrite_uart;
      1: dn_pwrite = o_pwrite_i2c;
      2: dn_pwrite = o_pwrite_spi;
      3: dn_pwrite = o_pwrite_can;
      4: dn_pwrite = o_pwrite_pwm;
      5: dn_pwrite = o_pwrite_gyro;
      6: dn_pwrite = o_pwrite_sramcsr;
      7: dn_pwrite = o_pwrite_romtab;
      default: dn_pwrite = 1'b0;
    endcase
  endfunction

  function automatic logic [DATA_WIDTH-1:0] dn_pwdata(input integer k);
    dn_pwdata = {DATA_WIDTH{1'b0}};
    case (k)
      0: dn_pwdata = o_pwdata_uart;
      1: dn_pwdata = o_pwdata_i2c;
      2: dn_pwdata = o_pwdata_spi;
      3: dn_pwdata = o_pwdata_can;
      4: dn_pwdata = o_pwdata_pwm;
      5: dn_pwdata = o_pwdata_gyro;
      6: dn_pwdata = o_pwdata_sramcsr;
      7: dn_pwdata = o_pwdata_romtab;
      default: dn_pwdata = {DATA_WIDTH{1'b0}};
    endcase
  endfunction

  function automatic logic [STRB_WIDTH-1:0] dn_pstrb(input integer k);
    dn_pstrb = {STRB_WIDTH{1'b0}};
    case (k)
      0: dn_pstrb = o_pstrb_uart;
      1: dn_pstrb = o_pstrb_i2c;
      2: dn_pstrb = o_pstrb_spi;
      3: dn_pstrb = o_pstrb_can;
      4: dn_pstrb = o_pstrb_pwm;
      5: dn_pstrb = o_pstrb_gyro;
      6: dn_pstrb = o_pstrb_sramcsr;
      7: dn_pstrb = o_pstrb_romtab;
      default: dn_pstrb = {STRB_WIDTH{1'b0}};
    endcase
  endfunction

  function automatic logic [2:0] dn_pprot(input integer k);
    dn_pprot = 3'd0;
    case (k)
      0: dn_pprot = o_pprot_uart;
      1: dn_pprot = o_pprot_i2c;
      2: dn_pprot = o_pprot_spi;
      3: dn_pprot = o_pprot_can;
      4: dn_pprot = o_pprot_pwm;
      5: dn_pprot = o_pprot_gyro;
      6: dn_pprot = o_pprot_sramcsr;
      7: dn_pprot = o_pprot_romtab;
      default: dn_pprot = 3'd0;
    endcase
  endfunction

  logic                  sb_open;
  integer                sb_owner;
  integer                sb_cnt;
  integer                sb_txn;
  integer                sb_age;
  integer                sb_k;
  logic [ADDR_WIDTH-1:0] sb_addr;
  logic                  sb_write;
  logic [DATA_WIDTH-1:0] sb_wdata;
  logic [STRB_WIDTH-1:0] sb_strb;
  logic [2:0]            sb_prot;
  logic [31:0]           sb_dn_local;
  logic                  sb_dn_write;
  logic [DATA_WIDTH-1:0] sb_dn_wdata;
  logic [STRB_WIDTH-1:0] sb_dn_strb;
  logic [2:0]            sb_dn_prot;
  logic [DATA_WIDTH-1:0] sb_dn_rdata;
  logic                  sb_dn_err;

  initial begin
    sb_open = 1'b0;
    sb_owner = -1;
    sb_cnt = 0;
    sb_txn = 0;
    sb_age = 0;
  end

  always @(posedge i_clk) begin
    if (i_rst_n === 1'b1) begin
      chk($onehot0(w_psel_vec), "at most one slave select");
      if (sb_open)
        sb_age = sb_age + 1;
      // the requester setup phase opens a transaction
      if (m_psel && !m_penable && !sb_open) begin
        sb_open  = 1'b1;
        sb_owner = owner_of(m_paddr);
        sb_addr  = m_paddr;
        sb_write = m_pwrite;
        sb_wdata = m_pwdata;
        sb_strb  = m_pstrb;
        sb_prot  = m_pprot;
        sb_cnt   = 0;
        sb_age   = 0;
      end
      if (!sb_open)
        chk(w_psel_vec === {NUM_SLAVES{1'b0}}, "no slave select without a requester transfer");
      // end of an access phase at a slave
      for (sb_k = 0; sb_k < NUM_SLAVES; sb_k = sb_k + 1) begin
        if (w_dn_done_vec[sb_k]) begin
          chk(sb_open && sb_k == sb_owner, "an access ends only at the owner of the address");
          if (sb_open && sb_k == sb_owner) begin
            sb_cnt      = sb_cnt + 1;
            sb_dn_local = act_local(sb_k);
            sb_dn_write = dn_pwrite(sb_k);
            sb_dn_wdata = dn_pwdata(sb_k);
            sb_dn_strb  = dn_pstrb(sb_k);
            sb_dn_prot  = dn_pprot(sb_k);
            sb_dn_rdata = sl_prdata(sb_k);
            sb_dn_err   = sl_pslverr(sb_k);
          end
        end
      end
      // end of the requester transfer
      if (sb_open && m_psel && m_penable && m_pready) begin
        chk(sb_cnt == ((sb_owner >= 0) ? 1 : 0), "one slave access for a mapped address, none for a hole");
        if (sb_owner >= 0 && sb_cnt == 1) begin
          chk(sb_dn_local === exp_local(sb_owner, sb_addr), "local address seen by the slave");
          chk(sb_dn_write === sb_write, "PWRITE seen by the slave");
          chk(sb_dn_strb === sb_strb, "PSTRB seen by the slave");
          chk(sb_dn_prot === sb_prot, "PPROT seen by the slave");
          if (sb_write)
            chk(sb_dn_wdata === sb_wdata, "PWDATA seen by the slave");
          else
            chk(m_prdata === sb_dn_rdata, "PRDATA returned to the requester");
          chk(m_pslverr === sb_dn_err, "PSLVERR returned to the requester");
        end else if (sb_owner < 0) begin
          if (!sb_write)
            chk(m_prdata === {DATA_WIDTH{1'b0}}, "hole: PRDATA zero");
          chk(m_pslverr === i_unmapped_err_en, "hole: PSLVERR follows the pin");
          chk(sb_age == 1, "hole: cycles from the setup to the end of the transfer");
        end
        sb_open = 1'b0;
        sb_txn  = sb_txn + 1;
      end
    end
  end

  // ---------------------------------------------------------------- monitor
  // Compares the decoder with the reference model in every cycle after reset.
  integer      mon_owner;
  logic [NUM_SLAVES-1:0] mon_exp_vec;

  always @(posedge i_clk) begin
    if (i_rst_n === 1'b1) begin
      mon_owner = owner_of(m_paddr);
      mon_exp_vec = {NUM_SLAVES{1'b0}};
      if (m_psel && mon_owner >= 0)
        mon_exp_vec[mon_owner] = 1'b1;
      chk(w_psel_vec === mon_exp_vec, "select vector (one-hot owner, none for a hole)");
      chk($onehot0(w_psel_vec), "at most one slave select");
      chk(o_penable_uart === (m_penable & o_psel_uart) && o_pwrite_uart === m_pwrite &&
          o_pwdata_uart === m_pwdata && o_pstrb_uart === m_pstrb &&
          o_pprot_uart === m_pprot, "forwarded attributes of uart");
      chk(o_penable_i2c === (m_penable & o_psel_i2c) && o_pwrite_i2c === m_pwrite &&
          o_pwdata_i2c === m_pwdata && o_pstrb_i2c === m_pstrb &&
          o_pprot_i2c === m_pprot, "forwarded attributes of i2c");
      chk(o_penable_spi === (m_penable & o_psel_spi) && o_pwrite_spi === m_pwrite &&
          o_pwdata_spi === m_pwdata && o_pstrb_spi === m_pstrb &&
          o_pprot_spi === m_pprot, "forwarded attributes of spi");
      chk(o_penable_can === (m_penable & o_psel_can) && o_pwrite_can === m_pwrite &&
          o_pwdata_can === m_pwdata && o_pstrb_can === m_pstrb &&
          o_pprot_can === m_pprot, "forwarded attributes of can");
      chk(o_penable_pwm === (m_penable & o_psel_pwm) && o_pwrite_pwm === m_pwrite &&
          o_pwdata_pwm === m_pwdata && o_pstrb_pwm === m_pstrb &&
          o_pprot_pwm === m_pprot, "forwarded attributes of pwm");
      chk(o_penable_gyro === (m_penable & o_psel_gyro) && o_pwrite_gyro === m_pwrite &&
          o_pwdata_gyro === m_pwdata && o_pstrb_gyro === m_pstrb &&
          o_pprot_gyro === m_pprot, "forwarded attributes of gyro");
      chk(o_penable_sramcsr === (m_penable & o_psel_sramcsr) && o_pwrite_sramcsr === m_pwrite &&
          o_pwdata_sramcsr === m_pwdata && o_pstrb_sramcsr === m_pstrb &&
          o_pprot_sramcsr === m_pprot, "forwarded attributes of sramcsr");
      chk(o_penable_romtab === (m_penable & o_psel_romtab) && o_pwrite_romtab === m_pwrite &&
          o_pwdata_romtab === m_pwdata && o_pstrb_romtab === m_pstrb &&
          o_pprot_romtab === m_pprot, "forwarded attributes of romtab");
      if (m_psel && mon_owner >= 0) begin
        chk(act_local(mon_owner) === exp_local(mon_owner, m_paddr), "local address of the owner");
      end
      if (!m_psel || !m_penable)
        chk(m_pslverr === 1'b0, "PSLVERR low when PSEL or PENABLE is low");
      if (m_psel && m_penable) begin
        if (mon_owner < 0) begin
          chk(m_pready === 1'b1, "unmapped address: PREADY high");
          chk(m_prdata === {DATA_WIDTH{1'b0}}, "unmapped address: PRDATA zero");
          chk(m_pslverr === i_unmapped_err_en, "unmapped address: PSLVERR follows the pin");
        end else begin
          chk(m_pready === sl_pready(mon_owner), "PREADY of the selected slave");
          chk(m_prdata === sl_prdata(mon_owner), "PRDATA of the selected slave");
          chk(m_pslverr === (m_pready & sl_pslverr(mon_owner)), "PSLVERR of the selected slave");
        end
      end
    end
  end

  // ---------------------------------------------------------------- protocol checkers
  integer w_chk_cnt_req;
  apb_protocol_checker #(
    .PARA_ADDR_WIDTH(ADDR_WIDTH),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_ID(0)
  ) u_chk_req (
    .i_clk(i_clk), .i_rst_n(i_rst_n), .i_paddr(m_paddr), .i_pprot(m_pprot), .i_psel(m_psel),
    .i_penable(m_penable), .i_pwrite(m_pwrite), .i_pwdata(m_pwdata), .i_pstrb(m_pstrb),
    .i_pready(m_pready), .i_pslverr(m_pslverr), .o_err_cnt(w_chk_cnt_req)
  );

  integer w_chk_cnt_uart;
  apb_protocol_checker #(
    .PARA_ADDR_WIDTH(8),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_ID(1)
  ) u_chk_uart (
    .i_clk(i_clk), .i_rst_n(i_rst_n), .i_paddr(o_paddr_uart), .i_pprot(o_pprot_uart),
    .i_psel(o_psel_uart), .i_penable(o_penable_uart), .i_pwrite(o_pwrite_uart),
    .i_pwdata(o_pwdata_uart), .i_pstrb(o_pstrb_uart), .i_pready(i_pready_uart),
    .i_pslverr(i_pslverr_uart), .o_err_cnt(w_chk_cnt_uart)
  );

  integer w_chk_cnt_i2c;
  apb_protocol_checker #(
    .PARA_ADDR_WIDTH(5),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_ID(2)
  ) u_chk_i2c (
    .i_clk(i_clk), .i_rst_n(i_rst_n), .i_paddr(o_paddr_i2c), .i_pprot(o_pprot_i2c),
    .i_psel(o_psel_i2c), .i_penable(o_penable_i2c), .i_pwrite(o_pwrite_i2c),
    .i_pwdata(o_pwdata_i2c), .i_pstrb(o_pstrb_i2c), .i_pready(i_pready_i2c),
    .i_pslverr(i_pslverr_i2c), .o_err_cnt(w_chk_cnt_i2c)
  );

  integer w_chk_cnt_spi;
  apb_protocol_checker #(
    .PARA_ADDR_WIDTH(12),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_ID(3)
  ) u_chk_spi (
    .i_clk(i_clk), .i_rst_n(i_rst_n), .i_paddr(o_paddr_spi), .i_pprot(o_pprot_spi),
    .i_psel(o_psel_spi), .i_penable(o_penable_spi), .i_pwrite(o_pwrite_spi),
    .i_pwdata(o_pwdata_spi), .i_pstrb(o_pstrb_spi), .i_pready(i_pready_spi),
    .i_pslverr(i_pslverr_spi), .o_err_cnt(w_chk_cnt_spi)
  );

  integer w_chk_cnt_can;
  apb_protocol_checker #(
    .PARA_ADDR_WIDTH(15),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_ID(4)
  ) u_chk_can (
    .i_clk(i_clk), .i_rst_n(i_rst_n), .i_paddr(o_paddr_can), .i_pprot(o_pprot_can),
    .i_psel(o_psel_can), .i_penable(o_penable_can), .i_pwrite(o_pwrite_can),
    .i_pwdata(o_pwdata_can), .i_pstrb(o_pstrb_can), .i_pready(i_pready_can),
    .i_pslverr(i_pslverr_can), .o_err_cnt(w_chk_cnt_can)
  );

  integer w_chk_cnt_pwm;
  apb_protocol_checker #(
    .PARA_ADDR_WIDTH(8),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_ID(5)
  ) u_chk_pwm (
    .i_clk(i_clk), .i_rst_n(i_rst_n), .i_paddr(o_paddr_pwm), .i_pprot(o_pprot_pwm),
    .i_psel(o_psel_pwm), .i_penable(o_penable_pwm), .i_pwrite(o_pwrite_pwm),
    .i_pwdata(o_pwdata_pwm), .i_pstrb(o_pstrb_pwm), .i_pready(i_pready_pwm),
    .i_pslverr(i_pslverr_pwm), .o_err_cnt(w_chk_cnt_pwm)
  );

  integer w_chk_cnt_gyro;
  apb_protocol_checker #(
    .PARA_ADDR_WIDTH(10),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_ID(6)
  ) u_chk_gyro (
    .i_clk(i_clk), .i_rst_n(i_rst_n), .i_paddr(o_paddr_gyro), .i_pprot(o_pprot_gyro),
    .i_psel(o_psel_gyro), .i_penable(o_penable_gyro), .i_pwrite(o_pwrite_gyro),
    .i_pwdata(o_pwdata_gyro), .i_pstrb(o_pstrb_gyro), .i_pready(i_pready_gyro),
    .i_pslverr(i_pslverr_gyro), .o_err_cnt(w_chk_cnt_gyro)
  );

  integer w_chk_cnt_sramcsr;
  apb_protocol_checker #(
    .PARA_ADDR_WIDTH(13),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_ID(7)
  ) u_chk_sramcsr (
    .i_clk(i_clk), .i_rst_n(i_rst_n), .i_paddr(o_paddr_sramcsr), .i_pprot(o_pprot_sramcsr),
    .i_psel(o_psel_sramcsr), .i_penable(o_penable_sramcsr), .i_pwrite(o_pwrite_sramcsr),
    .i_pwdata(o_pwdata_sramcsr), .i_pstrb(o_pstrb_sramcsr), .i_pready(i_pready_sramcsr),
    .i_pslverr(i_pslverr_sramcsr), .o_err_cnt(w_chk_cnt_sramcsr)
  );

  integer w_chk_cnt_romtab;
  apb_protocol_checker #(
    .PARA_ADDR_WIDTH(5),
    .PARA_DATA_WIDTH(DATA_WIDTH),
    .PARA_STRB_WIDTH(STRB_WIDTH),
    .PARA_ID(8)
  ) u_chk_romtab (
    .i_clk(i_clk), .i_rst_n(i_rst_n), .i_paddr(o_paddr_romtab), .i_pprot(o_pprot_romtab),
    .i_psel(o_psel_romtab), .i_penable(o_penable_romtab), .i_pwrite(o_pwrite_romtab),
    .i_pwdata(o_pwdata_romtab), .i_pstrb(o_pstrb_romtab), .i_pready(i_pready_romtab),
    .i_pslverr(i_pslverr_romtab), .o_err_cnt(w_chk_cnt_romtab)
  );

  // ---------------------------------------------------------------- directed helpers
  function automatic logic [DATA_WIDTH-1:0] pat(input logic [31:0] seed);
    pat = DATA_WIDTH'(seed * 32'h9E3779B1 + 32'h1234567);
  endfunction

  // Let the bus return to idle before the pin changes (the pin is stable while PSEL is high).
  task automatic tick_idle;
    repeat (3) @(posedge i_clk);
  endtask

  task automatic set_pin(input logic v);
    tick_idle();
    i_unmapped_err_en = v;
    tick_idle();
  endtask

  logic [DATA_WIDTH-1:0] v_rdata;
  logic                  lane_e;

  // Read: the response must follow the model.
  task automatic rd_chk(input logic [ADDR_WIDTH-1:0] a);
    integer k;
    logic [31:0] la;
    k = owner_of(a);
    u_master_bfm.read(a, v_rdata);
    if (k < 0) begin
      chk(u_master_bfm.last_pslverr === i_unmapped_err_en, "read of a hole: PSLVERR is the pin");
      chk(v_rdata === {DATA_WIDTH{1'b0}}, "read of a hole: data zero");
    end else begin
      la = exp_local(k, a);
      chk(u_master_bfm.last_pslverr === exp_slverr(k, la), "read of a mapped address: PSLVERR");
      chk(act_local(k) === la, "local address after a read");
    end
  endtask

  // Write: the response must follow the model.
  task automatic wr_chk(input logic [ADDR_WIDTH-1:0] a, input logic [DATA_WIDTH-1:0] d);
    integer k;
    k = owner_of(a);
    u_master_bfm.write(a, d);
    if (k < 0)
      chk(u_master_bfm.last_pslverr === i_unmapped_err_en, "write to a hole: PSLVERR is the pin");
    else
      chk(u_master_bfm.last_pslverr === exp_slverr(k, exp_local(k, a)),
          "write to a mapped address: PSLVERR");
  endtask

  // Write then read back a mapped address.
  task automatic wr_rd_chk(input logic [ADDR_WIDTH-1:0] a, input logic [DATA_WIDTH-1:0] d);
    integer k;
    logic        e;
    k = owner_of(a);
    chk(k >= 0, "wr_rd_chk address belongs to a slave");
    e = exp_slverr(k, exp_local(k, a));
    wr_chk(a, d);
    u_master_bfm.read(a, v_rdata);
    chk(u_master_bfm.last_pslverr === e, "read back: PSLVERR");
    chk(v_rdata === (e ? {DATA_WIDTH{1'b0}} : d), "read back: data");
    chk(act_local(k) === exp_local(k, a), "local address after read back");
  endtask

  // Random traffic: window and random addresses, reads and writes, protection and strobe.
  task automatic random_traffic(input integer count);
    integer j, k;
    logic [ADDR_WIDTH-1:0] a;
    logic [31:0] r;
    for (j = 0; j < count; j = j + 1) begin
      r = $urandom;
      k = r % (NUM_SLAVES + 2);
      a = $urandom;
      case (k)
        0: a = 24'h0 + (24'($urandom) % 24'd256);
        1: a = 24'h100 + (24'($urandom) % 24'd24);
        2: a = 24'h1000 + (24'($urandom) % 24'd4096);
        3: a = 24'h2000 + (24'($urandom) % 24'd32768);
        4: a = 24'hA000 + (24'($urandom) % 24'd256);
        5: a = 24'hB000 + (24'($urandom) % 24'd1024);
        6: a = 24'hC000 + (24'($urandom) % 24'd6144);
        7: a = 24'hE010 + (24'($urandom) % 24'd32);
        default: a = $urandom;
      endcase
      if (j % 7 == 0)
        set_pin(~i_unmapped_err_en);
      u_master_bfm.write_strb(a, $urandom, $urandom, $urandom);
      chk(u_master_bfm.last_pslverr === (owner_of(a) < 0 ? i_unmapped_err_en :
          exp_slverr(owner_of(a), exp_local(owner_of(a), a))), "random write PSLVERR");
      u_master_bfm.read(a, v_rdata, $urandom);
      chk(u_master_bfm.last_pslverr === (owner_of(a) < 0 ? i_unmapped_err_en :
          exp_slverr(owner_of(a), exp_local(owner_of(a), a))), "random read PSLVERR");
    end
  endtask

  // ---------------------------------------------------------------- test sequence
  initial begin
    n_chk = 0;
    n_fail = 0;
    i_unmapped_err_en = 1'b1;
    v_rdata = {DATA_WIDTH{1'b0}};

    @(posedge i_rst_n);
    tick_idle();

    $display("");
    $display("========================================");
    $display("APB Decoder Testbench: m_vlsit_apbdec");
    $display("========================================");

    // Mapped windows: edges, middle, neighbors, write and read back
    for (int pn = 0; pn < 2; pn++) begin
      set_pin(pn == 0);

  // ---- Slave 0: UART 0x0 to 0xFF (256 B)
  wr_rd_chk(24'h0, pat(32'd1));
  wr_rd_chk(24'hFF, pat(32'd2));
  wr_rd_chk(24'h80, pat(32'd3));
  rd_chk(24'h100);

  // ---- Slave 1: I2C 0x100 to 0x117 (24 B)
  wr_rd_chk(24'h100, pat(32'd11));
  wr_rd_chk(24'h117, pat(32'd12));
  wr_rd_chk(24'h10C, pat(32'd13));
  rd_chk(24'hFF);
  rd_chk(24'h118);

  // ---- Slave 2: SPI 0x1000 to 0x1FFF (4 KB)
  wr_rd_chk(24'h1000, pat(32'd21));
  wr_rd_chk(24'h1FFF, pat(32'd22));
  wr_rd_chk(24'h1800, pat(32'd23));
  rd_chk(24'hFFF);
  rd_chk(24'h2000);

  // ---- Slave 3: CAN 0x2000 to 0x9FFF (32 KB)
  wr_rd_chk(24'h2000, pat(32'd31));
  wr_rd_chk(24'h9FFF, pat(32'd32));
  wr_rd_chk(24'h6000, pat(32'd33));
  rd_chk(24'h1FFF);
  rd_chk(24'hA000);

  // ---- Slave 4: PWM 0xA000 to 0xA0FF (256 B)
  wr_rd_chk(24'hA000, pat(32'd41));
  wr_rd_chk(24'hA0FF, pat(32'd42));
  wr_rd_chk(24'hA080, pat(32'd43));
  rd_chk(24'h9FFF);
  rd_chk(24'hA100);

  // ---- Slave 5: GYRO 0xB000 to 0xB3FF (1 KB)
  wr_rd_chk(24'hB000, pat(32'd51));
  wr_rd_chk(24'hB3FF, pat(32'd52));
  wr_rd_chk(24'hB200, pat(32'd53));
  rd_chk(24'hAFFF);
  rd_chk(24'hB400);

  // ---- Slave 6: SRAMCSR 0xC000 to 0xD7FF (6 KB)
  wr_rd_chk(24'hC000, pat(32'd61));
  wr_rd_chk(24'hD7FF, pat(32'd62));
  wr_rd_chk(24'hCC00, pat(32'd63));
  rd_chk(24'hBFFF);
  rd_chk(24'hD800);

  // ---- Slave 7: ROMTAB 0xE010 to 0xE02F (32 B)
  wr_rd_chk(24'hE010, pat(32'd71));
  wr_rd_chk(24'hE02F, pat(32'd72));
  wr_rd_chk(24'hE020, pat(32'd73));
  rd_chk(24'hE00F);
  rd_chk(24'hE030);
    end

    // Unmapped holes with the pin at 1 (error) and at 0 (ready only)
    for (int pn = 0; pn < 2; pn++) begin
      set_pin(pn == 0);
  rd_chk(24'h118);
  wr_chk(24'h118, pat(32'd280));
  rd_chk(24'hFFF);
  wr_chk(24'hFFF, pat(32'd4095));
  rd_chk(24'h88B);
  wr_chk(24'h88B, pat(32'd2187));
  rd_chk(24'hA100);
  wr_chk(24'hA100, pat(32'd41216));
  rd_chk(24'hAFFF);
  wr_chk(24'hAFFF, pat(32'd45055));
  rd_chk(24'hA87F);
  wr_chk(24'hA87F, pat(32'd43135));
  rd_chk(24'hB400);
  wr_chk(24'hB400, pat(32'd46080));
  rd_chk(24'hBFFF);
  wr_chk(24'hBFFF, pat(32'd49151));
  rd_chk(24'hB9FF);
  wr_chk(24'hB9FF, pat(32'd47615));
  rd_chk(24'hD800);
  wr_chk(24'hD800, pat(32'd55296));
  rd_chk(24'hE00F);
  wr_chk(24'hE00F, pat(32'd57359));
  rd_chk(24'hDC07);
  wr_chk(24'hDC07, pat(32'd56327));
    end

  // ---- Byte lanes: only the enabled lane changes (slave 0)
  tick_idle();
  lane_e = exp_slverr(0, exp_local(0, 24'h0));
  u_master_bfm.write(24'h0, 32'd0);
  u_master_bfm.write_strb(24'h0, ~32'd0, 4'd1);
  u_master_bfm.read(24'h0, v_rdata);
  chk(u_master_bfm.last_pslverr === lane_e, "byte lane read PSLVERR");
  if (!lane_e)
    chk(v_rdata === 32'hFF, "only lane 0 written");

    // Random traffic with the pin changing between transfers
    random_traffic(300);

    tick_idle();
    chk((w_chk_cnt_req + w_chk_cnt_uart + w_chk_cnt_i2c + w_chk_cnt_spi + w_chk_cnt_can + w_chk_cnt_pwm + w_chk_cnt_gyro + w_chk_cnt_sramcsr + w_chk_cnt_romtab) == 0, "the APB protocol checkers report no violation");
    chk(sb_txn > 0, "the scoreboard saw transfers");
    $display("");
    $display("========================================");
    $display("[TB] Test Summary");
    $display("[TB] Transactions: %0d", sb_txn);
    $display("========================================");
    $display("[TB] Checks: %0d", n_chk);
    $display("[TB] Failed: %0d", n_fail);
    $display("========================================");
    if (n_fail > 0 || n_chk == 0) begin
      $display("[TB] OVERALL RESULT: FAIL");
      $fatal(1, "APB decoder testbench failed");
    end else begin
      $display("[TB] OVERALL RESULT: PASS");
      $finish;
    end
  end

  // Watchdog: the run must end by itself (the longest configuration needs about 0.1 ms)
  initial begin
    #5000000;
    $display("[TB] OVERALL RESULT: FAIL (timeout)");
    $fatal(1, "APB decoder testbench timeout");
  end

endmodule
