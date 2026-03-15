`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// Module: apb_slave_bfm
// Description:
//   APB4 slave BFM with internal word-addressed data memory.
//   Supports byte strobe (PSTRB), protection (PPROT), and error response (PSLVERR).
//------------------------------------------------------------------------------
module apb_slave_bfm #(
    parameter integer PARA_ADDR_WIDTH = 32,
    parameter integer PARA_DATA_WIDTH = 32,
    parameter integer PARA_APB_WAIT_STATES = 0
) (
    input  logic                       i_clk,
    input  logic                       i_rst_n,
    input  logic [PARA_ADDR_WIDTH-1:0] i_paddr,
    input  logic [PARA_DATA_WIDTH-1:0] i_pwdata,
    output logic [PARA_DATA_WIDTH-1:0] o_prdata,
    input  logic                       i_pwrite,
    input  logic                       i_psel,
    input  logic                       i_penable,
    output logic                       o_pready,
    output logic                       o_pslverr,
    input  logic [                3:0] i_pstrb,
    input  logic [                2:0] i_pprot
);

  localparam integer PARA_MEM_DEPTH = (2 ** PARA_ADDR_WIDTH);
  localparam integer PARA_DMEM_ADDR_W = $clog2(PARA_MEM_DEPTH);
  // Use minimum of address width and memory depth for indexing
  localparam integer PARA_IDX_W = (PARA_ADDR_WIDTH > PARA_DMEM_ADDR_W) ? PARA_DMEM_ADDR_W : PARA_ADDR_WIDTH;
  localparam logic [PARA_ADDR_WIDTH:0] PARA_MEM_DEPTH_U = {1'b1, {PARA_ADDR_WIDTH{1'b0}}};
  logic   [PARA_DATA_WIDTH-1:0] dmem              [0:PARA_MEM_DEPTH-1];

  integer                       apb_wait_cnt;
  logic                         apb_req_valid;
  logic                         apb_req_write;
  logic   [PARA_ADDR_WIDTH-1:0] apb_req_addr;
  logic   [PARA_DATA_WIDTH-1:0] apb_req_wdata;
  logic   [                3:0] apb_req_strb;
  logic   [                2:0] apb_req_prot;
  logic   [PARA_ADDR_WIDTH-1:0] apb_req_word_addr;
  logic   [     PARA_IDX_W-1:0] apb_req_word_idx;
  logic                         apb_addr_in_range;
  logic   [PARA_DATA_WIDTH-1:0] apb_read_data;

  // Word-align address (divide by 4 for byte-to-word conversion)
  assign apb_req_word_addr = (apb_req_addr >> 2);
  assign apb_req_word_idx = apb_req_word_addr;
  assign apb_addr_in_range = ({1'b0, apb_req_word_addr} < PARA_MEM_DEPTH_U);
  assign apb_read_data = apb_addr_in_range ? dmem[apb_req_word_idx] : {PARA_DATA_WIDTH{1'b0}};

  // APB4 protection signal encoding:
  // pprot[0]: 0=Secure, 1=Non-secure
  // pprot[1]: 0=Privileged, 1=Unprivileged
  // pprot[2]: 0=Data access, 1=Instruction access

  // APB4 slave BFM:
  // - Captures requests during SETUP (PSEL=1, PENABLE=0)
  // - Completes requests in ACCESS (PSEL=1, PENABLE=1) after wait states
  // - Holds PREADY low while inserting wait states
  // - Supports byte-lane writes via PSTRB
  // - Returns 0 and asserts PSLVERR on out-of-range accesses
  always_ff @(posedge i_clk or negedge i_rst_n) begin : apb_slave_seq
    integer i;
    if (~i_rst_n) begin
      apb_req_valid <= 1'b0;
      apb_req_write <= 1'b0;
      apb_req_addr  <= {PARA_ADDR_WIDTH{1'b0}};
      apb_req_wdata <= {PARA_DATA_WIDTH{1'b0}};
      apb_req_strb  <= 4'h0;
      apb_req_prot  <= 3'h0;
      apb_wait_cnt  <= 0;
      o_prdata      <= {PARA_DATA_WIDTH{1'b0}};
      o_pready      <= 1'b0;
      o_pslverr     <= 1'b0;
      for (i = 0; i < PARA_MEM_DEPTH; i = i + 1) begin
        dmem[i] <= {PARA_DATA_WIDTH{1'b0}};
      end
    end else begin
      o_pready  <= 1'b0;
      o_pslverr <= 1'b0;

      // Setup phase capture
      if (i_psel && !i_penable) begin
        apb_req_valid <= 1'b1;
        apb_req_write <= i_pwrite;
        apb_req_addr  <= i_paddr;
        apb_req_wdata <= i_pwdata;
        apb_req_strb  <= i_pstrb;
        apb_req_prot  <= i_pprot;
        apb_wait_cnt  <= PARA_APB_WAIT_STATES;
      end

      // Access phase response/handshake
      if (apb_req_valid && i_psel && i_penable) begin
        if (apb_wait_cnt > 0) begin
          apb_wait_cnt <= apb_wait_cnt - 1;
        end else begin
          o_pready  <= 1'b1;
          o_prdata  <= apb_read_data;
          o_pslverr <= ~apb_addr_in_range;

          if (apb_req_write && apb_addr_in_range) begin
            // Byte-lane write based on PSTRB
            if (apb_req_strb[0]) dmem[apb_req_word_idx][7:0] <= apb_req_wdata[7:0];
            if (apb_req_strb[1]) dmem[apb_req_word_idx][15:8] <= apb_req_wdata[15:8];
            if (apb_req_strb[2]) dmem[apb_req_word_idx][23:16] <= apb_req_wdata[23:16];
            if (apb_req_strb[3]) dmem[apb_req_word_idx][31:24] <= apb_req_wdata[31:24];
          end

          apb_req_valid <= 1'b0;
        end
      end
    end
  end

endmodule
