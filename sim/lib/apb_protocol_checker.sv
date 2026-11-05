`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// Module: apb_protocol_checker
// Description:
//   Passive APB4 protocol checker for one bus (the requester side of a decoder, or one slave side).
//   Rules (AMBA APB Protocol Specification IHI 0024D, sections 3 and 4.1):
//     R1  PENABLE is never high without PSEL.
//     R2  A transfer starts with PSEL high and PENABLE low (setup phase).
//     R3  The setup phase lasts exactly one cycle: PENABLE is high in the next cycle.
//     R4  PSEL and PENABLE stay high until PREADY is high (the access phase is not aborted).
//     R5  After the cycle where PREADY ends the access, PENABLE is low (idle or a new setup).
//     R6  PADDR, PWRITE, PPROT, PSTRB and, for a write, PWDATA do not change during a transfer.
//     R7  PSLVERR is high only in the last cycle of a transfer (PSEL, PENABLE and PREADY high).
//   o_err_cnt counts the violations; each one prints a message with the rule number.
//------------------------------------------------------------------------------
module apb_protocol_checker #(
    parameter integer PARA_ADDR_WIDTH = 32,
    parameter integer PARA_DATA_WIDTH = 32,
    parameter integer PARA_STRB_WIDTH = PARA_DATA_WIDTH / 8,
    parameter integer PARA_ID = 0
) (
    input  logic                       i_clk,
    input  logic                       i_rst_n,
    input  logic [PARA_ADDR_WIDTH-1:0] i_paddr,
    input  logic [                2:0] i_pprot,
    input  logic                       i_psel,
    input  logic                       i_penable,
    input  logic                       i_pwrite,
    input  logic [PARA_DATA_WIDTH-1:0] i_pwdata,
    input  logic [PARA_STRB_WIDTH-1:0] i_pstrb,
    input  logic                       i_pready,
    input  logic                       i_pslverr,
    output integer                     o_err_cnt
);

  logic                       prev_valid;
  logic                       prev_psel;
  logic                       prev_penable;
  logic                       prev_pready;
  logic [PARA_ADDR_WIDTH-1:0] prev_paddr;
  logic [                2:0] prev_pprot;
  logic                       prev_pwrite;
  logic [PARA_DATA_WIDTH-1:0] prev_pwdata;
  logic [PARA_STRB_WIDTH-1:0] prev_pstrb;
  logic                       in_transfer;

  initial o_err_cnt = 0;

  task automatic fail(input string rule);
    o_err_cnt = o_err_cnt + 1;
    $display("[APB-CHK %0d] FAIL @%0t: %s", PARA_ID, $time, rule);
  endtask

  always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      prev_valid   <= 1'b0;
      prev_psel    <= 1'b0;
      prev_penable <= 1'b0;
      prev_pready  <= 1'b0;
    end else begin
      // R1
      if (i_penable === 1'b1 && i_psel !== 1'b1) fail("R1 PENABLE without PSEL");
      // R7
      if (i_pslverr === 1'b1 && !(i_psel === 1'b1 && i_penable === 1'b1 && i_pready === 1'b1))
        fail("R7 PSLVERR outside the last cycle of a transfer");
      if (prev_valid) begin
        in_transfer = prev_psel && !(prev_penable && prev_pready);
        // R2
        if (i_psel === 1'b1 && !prev_psel && i_penable === 1'b1)
          fail("R2 transfer does not start with a setup phase");
        // R3
        if (prev_psel && !prev_penable && !(i_psel === 1'b1 && i_penable === 1'b1))
          fail("R3 setup phase is not followed by the access phase");
        // R4
        if (prev_psel && prev_penable && !prev_pready && !(i_psel === 1'b1 && i_penable === 1'b1))
          fail("R4 access phase ended before PREADY");
        // R5
        if (prev_psel && prev_penable && prev_pready && i_penable === 1'b1)
          fail("R5 PENABLE still high after the end of the access phase");
        // R6
        if (in_transfer && i_psel === 1'b1) begin
          if (i_paddr !== prev_paddr) fail("R6 PADDR changed during the transfer");
          if (i_pwrite !== prev_pwrite) fail("R6 PWRITE changed during the transfer");
          if (i_pprot !== prev_pprot) fail("R6 PPROT changed during the transfer");
          if (i_pstrb !== prev_pstrb) fail("R6 PSTRB changed during the transfer");
          if (prev_pwrite && i_pwdata !== prev_pwdata) fail("R6 PWDATA changed during the transfer");
        end
      end
      prev_valid   <= 1'b1;
      prev_psel    <= (i_psel === 1'b1);
      prev_penable <= (i_penable === 1'b1);
      prev_pready  <= (i_pready === 1'b1);
      prev_paddr   <= i_paddr;
      prev_pprot   <= i_pprot;
      prev_pwrite  <= i_pwrite;
      prev_pwdata  <= i_pwdata;
      prev_pstrb   <= i_pstrb;
    end
  end

endmodule
