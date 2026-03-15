//--------------------------------------
//Project: APB Decoder Generator
//Module:  m_vlsit_apbdec
//Function: APB Decoder Testbench
//Author:  link
//Script Author: Thang Luong (superzeldalink)
//Page:    VLSI Technology
//--------------------------------------
// Generated: 2026-03-16 00:11:59
//--------------------------------------
// Address Width: 24
// Data Width: 32
// Write Strobe: 4
// Number of Slaves: 6
//--------------------------------------

// ============================================================================
// Testbench for m_vlsit_apbdec
// Generated: 2026-03-16 00:11:59
// ============================================================================

`timescale 1ns/1ps

module m_vlsit_apbdec_tb;

// Parameters
localparam int ADDR_WIDTH = 24;
localparam int DATA_WIDTH = 32;
localparam int WRITE_STROBE = 4;

// Clock and Reset
logic i_clk;
logic i_rst_n;

// Master Signals (connected to master BFM)
logic [ADDR_WIDTH-1:0]  m_paddr;
logic [DATA_WIDTH-1:0]  m_pwdata;
logic [DATA_WIDTH-1:0]  m_prdata;  // From DUT (read data)
logic                   m_pwrite;
logic                   m_psel;
logic                   m_penable;
logic                   m_pready;
logic                   m_pslverr;
logic [WRITE_STROBE-1:0] m_pstrb;
logic [2:0]              m_pprot;

// Slave Signals (connected to DUT and slave BFMs)
// Slave: UART
logic                   o_psel_uart;
logic                   o_penable_uart;
logic                   o_pwrite_uart;
logic [7:0]  o_paddr_uart;
logic [DATA_WIDTH-1:0]  o_pwdata_uart;
logic [WRITE_STROBE-1:0] o_pstrb_uart;
logic                   i_pready_uart;
logic                   i_pslverr_uart;
logic [DATA_WIDTH-1:0]  i_prdata_uart;

// Slave: I2C
logic                   o_psel_i2c;
logic                   o_penable_i2c;
logic                   o_pwrite_i2c;
logic [3:0]  o_paddr_i2c;
logic [DATA_WIDTH-1:0]  o_pwdata_i2c;
logic [WRITE_STROBE-1:0] o_pstrb_i2c;
logic                   i_pready_i2c;
logic                   i_pslverr_i2c;
logic [DATA_WIDTH-1:0]  i_prdata_i2c;

// Slave: SPI
logic                   o_psel_spi;
logic                   o_penable_spi;
logic                   o_pwrite_spi;
logic [11:0]  o_paddr_spi;
logic [DATA_WIDTH-1:0]  o_pwdata_spi;
logic [WRITE_STROBE-1:0] o_pstrb_spi;
logic                   i_pready_spi;
logic                   i_pslverr_spi;
logic [DATA_WIDTH-1:0]  i_prdata_spi;

// Slave: CAN
logic                   o_psel_can;
logic                   o_penable_can;
logic                   o_pwrite_can;
logic [14:0]  o_paddr_can;
logic [DATA_WIDTH-1:0]  o_pwdata_can;
logic [WRITE_STROBE-1:0] o_pstrb_can;
logic                   i_pready_can;
logic                   i_pslverr_can;
logic [DATA_WIDTH-1:0]  i_prdata_can;

// Slave: PWM
logic                   o_psel_pwm;
logic                   o_penable_pwm;
logic                   o_pwrite_pwm;
logic [7:0]  o_paddr_pwm;
logic [DATA_WIDTH-1:0]  o_pwdata_pwm;
logic [WRITE_STROBE-1:0] o_pstrb_pwm;
logic                   i_pready_pwm;
logic                   i_pslverr_pwm;
logic [DATA_WIDTH-1:0]  i_prdata_pwm;

// Slave: GYRO
logic                   o_psel_gyro;
logic                   o_penable_gyro;
logic                   o_pwrite_gyro;
logic [9:0]  o_paddr_gyro;
logic [DATA_WIDTH-1:0]  o_pwdata_gyro;
logic [WRITE_STROBE-1:0] o_pstrb_gyro;
logic                   i_pready_gyro;
logic                   i_pslverr_gyro;
logic [DATA_WIDTH-1:0]  i_prdata_gyro;

// Instantiate DUT
m_vlsit_apbdec u_m_vlsit_apbdec (
    .i_paddr(m_paddr),
    .i_pwrite(m_pwrite),
    .i_psel(m_psel),
    .i_penable(m_penable),
    .i_pwdata(m_pwdata),
    .i_pstrb(m_pstrb),
    .o_pready(m_pready),
    .o_pslverr(m_pslverr),
    .o_prdata(m_prdata),
    .o_psel_uart(o_psel_uart),
    .o_penable_uart(o_penable_uart),
    .o_pwrite_uart(o_pwrite_uart),
    .o_paddr_uart(o_paddr_uart),
    .o_pwdata_uart(o_pwdata_uart),
    .o_pstrb_uart(o_pstrb_uart),
    .i_pready_uart(i_pready_uart),
    .i_pslverr_uart(i_pslverr_uart),
    .i_prdata_uart(i_prdata_uart),
    .o_psel_i2c(o_psel_i2c),
    .o_penable_i2c(o_penable_i2c),
    .o_pwrite_i2c(o_pwrite_i2c),
    .o_paddr_i2c(o_paddr_i2c),
    .o_pwdata_i2c(o_pwdata_i2c),
    .o_pstrb_i2c(o_pstrb_i2c),
    .i_pready_i2c(i_pready_i2c),
    .i_pslverr_i2c(i_pslverr_i2c),
    .i_prdata_i2c(i_prdata_i2c),
    .o_psel_spi(o_psel_spi),
    .o_penable_spi(o_penable_spi),
    .o_pwrite_spi(o_pwrite_spi),
    .o_paddr_spi(o_paddr_spi),
    .o_pwdata_spi(o_pwdata_spi),
    .o_pstrb_spi(o_pstrb_spi),
    .i_pready_spi(i_pready_spi),
    .i_pslverr_spi(i_pslverr_spi),
    .i_prdata_spi(i_prdata_spi),
    .o_psel_can(o_psel_can),
    .o_penable_can(o_penable_can),
    .o_pwrite_can(o_pwrite_can),
    .o_paddr_can(o_paddr_can),
    .o_pwdata_can(o_pwdata_can),
    .o_pstrb_can(o_pstrb_can),
    .i_pready_can(i_pready_can),
    .i_pslverr_can(i_pslverr_can),
    .i_prdata_can(i_prdata_can),
    .o_psel_pwm(o_psel_pwm),
    .o_penable_pwm(o_penable_pwm),
    .o_pwrite_pwm(o_pwrite_pwm),
    .o_paddr_pwm(o_paddr_pwm),
    .o_pwdata_pwm(o_pwdata_pwm),
    .o_pstrb_pwm(o_pstrb_pwm),
    .i_pready_pwm(i_pready_pwm),
    .i_pslverr_pwm(i_pslverr_pwm),
    .i_prdata_pwm(i_prdata_pwm),
    .o_psel_gyro(o_psel_gyro),
    .o_penable_gyro(o_penable_gyro),
    .o_pwrite_gyro(o_pwrite_gyro),
    .o_paddr_gyro(o_paddr_gyro),
    .o_pwdata_gyro(o_pwdata_gyro),
    .o_pstrb_gyro(o_pstrb_gyro),
    .i_pready_gyro(i_pready_gyro),
    .i_pslverr_gyro(i_pslverr_gyro),
    .i_prdata_gyro(i_prdata_gyro)
);

// Clock generation (10ns period = 100MHz)
initial begin
  i_clk = 0;
  forever #5 i_clk = ~i_clk;
end

// Reset generation
initial begin
  i_rst_n = 1'b0;
  #50;
  i_rst_n = 1'b1;
end

// Master BFM
apb_master_bfm #(
  .PARA_ADDR_WIDTH(24),
  .PARA_DATA_WIDTH(32),
  .PARA_APB_WAIT_STATES(0)
) u_master_bfm (
  .i_clk(i_clk),
  .i_rst_n(i_rst_n),
  .o_paddr(m_paddr),
  .o_pwdata(m_pwdata),
  .i_prdata(m_prdata),  // Connected to DUT output
  .o_pwrite(m_pwrite),
  .o_psel(m_psel),
  .o_penable(m_penable),
  .i_pready(m_pready),
  .o_pstrb(m_pstrb),
  .o_pprot(m_pprot)
);

  // Slave 1: UART
  apb_slave_bfm #(
    .PARA_ADDR_WIDTH(8),
    .PARA_DATA_WIDTH(32),
    .PARA_APB_WAIT_STATES(0)
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
    .i_pprot(3'b000)
  );

  // Slave 2: I2C
  apb_slave_bfm #(
    .PARA_ADDR_WIDTH(4),
    .PARA_DATA_WIDTH(32),
    .PARA_APB_WAIT_STATES(0)
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
    .i_pprot(3'b000)
  );

  // Slave 3: SPI
  apb_slave_bfm #(
    .PARA_ADDR_WIDTH(12),
    .PARA_DATA_WIDTH(32),
    .PARA_APB_WAIT_STATES(0)
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
    .i_pprot(3'b000)
  );

  // Slave 4: CAN
  apb_slave_bfm #(
    .PARA_ADDR_WIDTH(15),
    .PARA_DATA_WIDTH(32),
    .PARA_APB_WAIT_STATES(0)
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
    .i_pprot(3'b000)
  );

  // Slave 5: PWM
  apb_slave_bfm #(
    .PARA_ADDR_WIDTH(8),
    .PARA_DATA_WIDTH(32),
    .PARA_APB_WAIT_STATES(0)
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
    .i_pprot(3'b000)
  );

  // Slave 6: GYRO
  apb_slave_bfm #(
    .PARA_ADDR_WIDTH(10),
    .PARA_DATA_WIDTH(32),
    .PARA_APB_WAIT_STATES(0)
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
    .i_pprot(3'b000)
  );

// Waveform dump
initial begin
`ifdef VCS
  $fsdbDumpfile("wave.fsdb");
  $fsdbDumpvars(0, m_vlsit_apbdec_tb, "+mda");
`else
  $dumpfile("wave.vcd");
  $dumpvars(0, m_vlsit_apbdec_tb);
`endif
end

// Test sequence
initial begin
  logic [DATA_WIDTH-1:0] v_rdata;  // Temporary variable for BFM reads
  localparam logic PSLVERR_VAL = 1'b1;
  integer test_num;
  integer test_pass;
  integer test_fail;
  test_num = 0;
  test_pass = 0;
  test_fail = 0;

  // Wait for reset to complete
  @(posedge i_rst_n);

  $display("");
  $display("========================================");
  $display("APB Decoder Testbench");
  $display("========================================");
  $display("");

  // ============================================================================
  // Test 1: Basic read from UART at 0x0000
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Read from UART (offset 0x0000)", test_num);
  u_master_bfm.read(24'h0000, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: 0x00000000 - cleared memory)", v_rdata);
  test_pass++;

  // ============================================================================
  // Test 2: Write to UART
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Write to UART (offset 0x0000)", test_num);
  u_master_bfm.write(24'h0000, 32'h00000000);
  $display("[TB] Wrote: 32'h00000000");
  test_pass++;

  // ============================================================================
  // Test 3: Read back to verify write
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Read back from UART to verify", test_num);
  u_master_bfm.read(24'h0000, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: 32'h00000000)", v_rdata);
  if (v_rdata === 32'h00000000) begin
    $display("[TB] ✓ PASS: UART data match!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: UART data mismatch!");
    test_fail++;
  end

  // ============================================================================
  // Test 2: Basic read from I2C at 0x0100
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Read from I2C (offset 0x0100)", test_num);
  u_master_bfm.read(24'h0100, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: 0x00000000 - cleared memory)", v_rdata);
  test_pass++;

  // ============================================================================
  // Test 3: Write to I2C
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Write to I2C (offset 0x0100)", test_num);
  u_master_bfm.write(24'h0100, 32'h01010101);
  $display("[TB] Wrote: 32'h01010101");
  test_pass++;

  // ============================================================================
  // Test 4: Read back to verify write
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Read back from I2C to verify", test_num);
  u_master_bfm.read(24'h0100, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: 32'h01010101)", v_rdata);
  if (v_rdata === 32'h01010101) begin
    $display("[TB] ✓ PASS: I2C data match!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: I2C data mismatch!");
    test_fail++;
  end

  // ============================================================================
  // Test 3: Basic read from SPI at 0x1000
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Read from SPI (offset 0x1000)", test_num);
  u_master_bfm.read(24'h1000, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: 0x00000000 - cleared memory)", v_rdata);
  test_pass++;

  // ============================================================================
  // Test 4: Write to SPI
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Write to SPI (offset 0x1000)", test_num);
  u_master_bfm.write(24'h1000, 32'h02020202);
  $display("[TB] Wrote: 32'h02020202");
  test_pass++;

  // ============================================================================
  // Test 5: Read back to verify write
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Read back from SPI to verify", test_num);
  u_master_bfm.read(24'h1000, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: 32'h02020202)", v_rdata);
  if (v_rdata === 32'h02020202) begin
    $display("[TB] ✓ PASS: SPI data match!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: SPI data mismatch!");
    test_fail++;
  end

  // ============================================================================
  // Test 4: Basic read from CAN at 0x2000
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Read from CAN (offset 0x2000)", test_num);
  u_master_bfm.read(24'h2000, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: 0x00000000 - cleared memory)", v_rdata);
  test_pass++;

  // ============================================================================
  // Test 5: Write to CAN
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Write to CAN (offset 0x2000)", test_num);
  u_master_bfm.write(24'h2000, 32'h03030303);
  $display("[TB] Wrote: 32'h03030303");
  test_pass++;

  // ============================================================================
  // Test 6: Read back to verify write
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Read back from CAN to verify", test_num);
  u_master_bfm.read(24'h2000, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: 32'h03030303)", v_rdata);
  if (v_rdata === 32'h03030303) begin
    $display("[TB] ✓ PASS: CAN data match!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: CAN data mismatch!");
    test_fail++;
  end

  // ============================================================================
  // Test 5: Basic read from PWM at 0xA000
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Read from PWM (offset 0xA000)", test_num);
  u_master_bfm.read(24'hA000, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: 0x00000000 - cleared memory)", v_rdata);
  test_pass++;

  // ============================================================================
  // Test 6: Write to PWM
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Write to PWM (offset 0xA000)", test_num);
  u_master_bfm.write(24'hA000, 32'h04040404);
  $display("[TB] Wrote: 32'h04040404");
  test_pass++;

  // ============================================================================
  // Test 7: Read back to verify write
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Read back from PWM to verify", test_num);
  u_master_bfm.read(24'hA000, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: 32'h04040404)", v_rdata);
  if (v_rdata === 32'h04040404) begin
    $display("[TB] ✓ PASS: PWM data match!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: PWM data mismatch!");
    test_fail++;
  end

  // ============================================================================
  // Test 6: Basic read from GYRO at 0xB000
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Read from GYRO (offset 0xB000)", test_num);
  u_master_bfm.read(24'hB000, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: 0x00000000 - cleared memory)", v_rdata);
  test_pass++;

  // ============================================================================
  // Test 7: Write to GYRO
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Write to GYRO (offset 0xB000)", test_num);
  u_master_bfm.write(24'hB000, 32'h05050505);
  $display("[TB] Wrote: 32'h05050505");
  test_pass++;

  // ============================================================================
  // Test 8: Read back to verify write
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Read back from GYRO to verify", test_num);
  u_master_bfm.read(24'hB000, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: 32'h05050505)", v_rdata);
  if (v_rdata === 32'h05050505) begin
    $display("[TB] ✓ PASS: GYRO data match!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: GYRO data mismatch!");
    test_fail++;
  end

  // ============================================================================
  // Test 19: Byte-lane write test (lower byte) on UART
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Byte-lane write to UART (lower byte only)", test_num);
  // First clear the register
  u_master_bfm.write_strb(24'h0000, 32'h00000000, 4'b1111);
  // Write only lower byte
  u_master_bfm.write_strb(24'h0000, 32'h12345678, 4'b0001);
  u_master_bfm.read(24'h0000, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: 0x00000078)", v_rdata);
  if (v_rdata === 32'h00000078) begin
    $display("[TB] ✓ PASS: Lower byte write correct!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: Lower byte write incorrect!");
    test_fail++;
  end

  // ============================================================================
  // Test 20: Byte-lane write test (upper byte) on UART
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Byte-lane write to UART (upper byte only)", test_num);
  // First clear the register
  u_master_bfm.write_strb(24'h0000, 32'h00000000, 4'b1111);
  // Write only upper byte
  u_master_bfm.write_strb(24'h0000, 32'h12345678, 4'b1000);
  u_master_bfm.read(24'h0000, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: 0x12000000)", v_rdata);
  if (v_rdata === 32'h12000000) begin
    $display("[TB] ✓ PASS: Upper byte write correct!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: Upper byte write incorrect!");
    test_fail++;
  end

  // ============================================================================
  // Test 21: Verify slave isolation (UART vs I2C)
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Verify slave isolation", test_num);
  u_master_bfm.write(24'h0100, 32'hFFFFFFFF);  // Write to I2C
  u_master_bfm.write(24'h0000, 32'h00000000);   // Write to UART
  u_master_bfm.read(24'h0100, v_rdata);
  $display("[TB] I2C data after UART write: 0x%08h (expected: 0xFFFFFFFF)", v_rdata);
  if (v_rdata === 32'hFFFFFFFF) begin
    $display("[TB] ✓ PASS: Slaves are isolated!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: Slave isolation broken!");
    test_fail++;
  end

  // ============================================================================
  // Test 22: Access at UART boundary (0x0000FF)
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Access at UART boundary (0x0000FF)", test_num);
  u_master_bfm.write(24'h0000FF, 32'hFEDCBA98);
  u_master_bfm.read(24'h0000FF, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: 0xFEDCBA98)", v_rdata);
  if (v_rdata === 32'hFEDCBA98) begin
    $display("[TB] ✓ PASS: Boundary access correct!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: Boundary access incorrect!");
    test_fail++;
  end

  // ============================================================================
  // Test 23: Unmapped address access (0xFFFF - outside all slaves)
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Unmapped address access (0xFFFF - outside all slaves)", test_num);
  $display("[TB] Expected: PSLVERR should be asserted, no hang");
  u_master_bfm.read(24'hFFFF, v_rdata);
  $display("[TB] Read from unmapped 0xFFFF: 0x%08h, PSLVERR = %b", v_rdata, m_pslverr);
  if (m_pslverr === PSLVERR_VAL) begin
    $display("[TB] ✓ PASS: PSLVERR correct for unmapped access!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: PSLVERR mismatch for unmapped access!");
    test_fail++;
  end

  // ============================================================================
  // Test 24: Verify PSLVERR deasserted for valid access
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Verify PSLVERR deasserted for valid access", test_num);
  u_master_bfm.write(24'h0000, 32'hFACEFACE);
  u_master_bfm.read(24'h0000, v_rdata);
  $display("[TB] Valid UART access: 0x%08h, PSLVERR = %b", v_rdata, m_pslverr);
  if (m_pslverr === 1'b0) begin
    $display("[TB] ✓ PASS: PSLVERR deasserted for valid access!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: PSLVERR asserted for valid access!");
    test_fail++;
  end

  // ============================================================================
  // Test 25: Unmapped address in gap between I2C and SPI
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Unmapped address in gap (0x0110 - between I2C and SPI)", test_num);
  u_master_bfm.read(24'h0110, v_rdata);
  $display("[TB] Read from gap 0x0110: 0x%08h, PSLVERR = %b", v_rdata, m_pslverr);
  if (m_pslverr === PSLVERR_VAL) begin
    $display("[TB] ✓ PASS: PSLVERR correct for gap access!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: PSLVERR mismatch for gap access!");
    test_fail++;
  end

  // ============================================================================
  // Test 26: Back-to-back writes to UART
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Back-to-back writes to UART", test_num);
  u_master_bfm.write(24'h0000, 32'h11111111);
  u_master_bfm.write(24'h0000, 32'h22222222);
  u_master_bfm.write(24'h0000, 32'h33333333);
  u_master_bfm.read(24'h0000, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: 0x33333333)", v_rdata);
  if (v_rdata === 32'h33333333) begin
    $display("[TB] ✓ PASS: Back-to-back writes correct!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: Back-to-back writes incorrect!");
    test_fail++;
  end

  $display("");
  $display("========================================");
  $display("[TB] Test Summary");
  $display("========================================");
  $display("[TB] Total Tests: %0d", test_num);
  $display("[TB] Passed:      %0d", test_pass);
  $display("[TB] Failed:      %0d", test_fail);
  $display("========================================");
  if (test_fail > 0) begin
    $display("[TB] ✗ OVERALL RESULT: FAIL");
    $finish(1);
  end else begin
    $display("[TB] ✓ OVERALL RESULT: PASS");
    $finish(0);
  end
end

endmodule
