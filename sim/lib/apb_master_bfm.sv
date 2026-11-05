`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// Module: apb_master_bfm
// Description:
//   APB4 master BFM with task-based interface for read/write operations.
//   Supports byte strobe (PSTRB) and protection (PPROT) signals.
//------------------------------------------------------------------------------
module apb_master_bfm #(
    parameter integer PARA_ADDR_WIDTH = 32,
    parameter integer PARA_DATA_WIDTH = 32,
    parameter integer PARA_APB_WAIT_STATES = 0,
    // Bonus fix (found while fixing BUG_REPORT.md): PSTRB was hardcoded to
    // [3:0] regardless of PARA_DATA_WIDTH, even though the generator's own
    // "Write Strobe" config field is independently settable. A DUT built for
    // any data width other than 32 bit would get a port-width mismatch on
    // o_pstrb when connected through this BFM. Default keeps the previous
    // 32-bit/4-lane behaviour unchanged.
    parameter integer PARA_STRB_WIDTH = PARA_DATA_WIDTH / 8
) (
    input  logic                    i_clk,
    input  logic                    i_rst_n,
    output logic [PARA_ADDR_WIDTH-1:0] o_paddr,
    output logic [PARA_DATA_WIDTH-1:0] o_pwdata,
    input  logic [PARA_DATA_WIDTH-1:0] i_prdata,
    output logic                    o_pwrite,
    output logic                    o_psel,
    output logic                    o_penable,
    input  logic                    i_pready,
    input  logic                    i_pslverr,
    output logic [PARA_STRB_WIDTH-1:0] o_pstrb,
    output logic [2:0]              o_pprot
);

  typedef enum logic [1:0] {
    IDLE,
    SETUP,
    ACCESS
  } apb_state_t;

  apb_state_t state;

  logic        trans_done;
  logic [PARA_ADDR_WIDTH-1:0] req_addr;
  logic [PARA_DATA_WIDTH-1:0] req_wdata;
  logic        req_write;
  logic [PARA_STRB_WIDTH-1:0] req_strb;
  logic [2:0]  req_prot;
  logic        req_valid = 1'b0;
  logic [PARA_DATA_WIDTH-1:0] read_data;
  // PSLVERR of the last completed transfer (captured in the cycle where PREADY is high)
  logic        last_pslverr = 1'b0;
  integer      wait_cnt;

  // APB4 protection signal encoding:
  // pprot[0]: 0=Secure, 1=Non-secure
  // pprot[1]: 0=Privileged, 1=Unprivileged
  // pprot[2]: 0=Data access, 1=Instruction access

  // APB state machine (IEEE: APB4 operating states, one transfer at a time):
  //   IDLE   : bus idle; a pending request drives PSEL, PADDR, PWRITE, PWDATA, PSTRB, PPROT
  //   SETUP  : PSEL = 1, PENABLE = 0 on the bus; the next edge raises PENABLE
  //   ACCESS : PSEL = 1, PENABLE = 1 on the bus; the transfer ends at the edge where PREADY = 1
  //            (after the optional master wait states), and PSEL and PENABLE fall at that edge
  always_ff @(posedge i_clk or negedge i_rst_n) begin : apb_master_seq
    if (~i_rst_n) begin
      state      <= IDLE;
      o_psel     <= 1'b0;
      o_penable  <= 1'b0;
      o_pwrite   <= 1'b0;
      o_paddr    <= {PARA_ADDR_WIDTH{1'b0}};
      o_pwdata   <= {PARA_DATA_WIDTH{1'b0}};
      o_pstrb    <= {PARA_STRB_WIDTH{1'b0}};
      o_pprot    <= 3'h0;
      wait_cnt   <= 0;
      trans_done <= 1'b0;
    end else begin
      trans_done <= 1'b0;

      case (state)
        IDLE: begin
          if (req_valid) begin
            o_psel    <= 1'b1;
            o_penable <= 1'b0;
            o_pwrite  <= req_write;
            o_paddr   <= req_addr;
            o_pwdata  <= req_wdata;
            o_pstrb   <= req_strb;
            o_pprot   <= req_prot;
            wait_cnt  <= PARA_APB_WAIT_STATES;
            state     <= SETUP;
          end
        end

        SETUP: begin
          o_penable <= 1'b1;
          state     <= ACCESS;
        end

        ACCESS: begin
          if (wait_cnt > 0) begin
            wait_cnt <= wait_cnt - 1;
          end else if (i_pready) begin
            if (!req_write) begin
              read_data <= i_prdata;
            end
            last_pslverr <= i_pslverr;
            trans_done   <= 1'b1;
            o_psel       <= 1'b0;
            o_penable    <= 1'b0;
            state        <= IDLE;
          end
        end

        default: begin
          o_psel    <= 1'b0;
          o_penable <= 1'b0;
          state     <= IDLE;
        end
      endcase
    end
  end

  // Task: APB4 write (full word)
  task automatic write(
    input logic [PARA_ADDR_WIDTH-1:0] addr,
    input logic [PARA_DATA_WIDTH-1:0] wdata,
    input logic [2:0]  prot = 3'b000
  );
    wait ((state == IDLE) && !req_valid);
    wait (!trans_done);
    req_addr  = addr;
    req_wdata = wdata;
    req_write = 1'b1;
    req_strb  = {PARA_STRB_WIDTH{1'b1}};  // All bytes enabled
    req_prot  = prot;
    req_valid = 1'b1;
    wait (trans_done);
    req_valid = 1'b0;
  endtask

  // Task: APB4 write (byte lane controlled)
  task automatic write_strb(
    input logic [PARA_ADDR_WIDTH-1:0] addr,
    input logic [PARA_DATA_WIDTH-1:0] wdata,
    input logic [PARA_STRB_WIDTH-1:0]  strb,
    input logic [2:0]  prot = 3'b000
  );
    wait ((state == IDLE) && !req_valid);
    wait (!trans_done);
    req_addr  = addr;
    req_wdata = wdata;
    req_write = 1'b1;
    req_strb  = strb;
    req_prot  = prot;
    req_valid = 1'b1;
    wait (trans_done);
    req_valid = 1'b0;
  endtask

  // Task: APB4 read
  task automatic read(
    input  logic [PARA_ADDR_WIDTH-1:0] addr,
    output logic [PARA_DATA_WIDTH-1:0] rdata,
    input  logic [2:0]  prot = 3'b000
  );
    wait ((state == IDLE) && !req_valid);
    wait (!trans_done);
    req_addr  = addr;
    req_wdata = {PARA_DATA_WIDTH{1'b0}};
    req_write = 1'b0;
    req_strb  = {PARA_STRB_WIDTH{1'b0}};
    req_prot  = prot;
    req_valid = 1'b1;
    wait (trans_done);
    req_valid = 1'b0;
    rdata = read_data;
  endtask

endmodule
