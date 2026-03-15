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
    parameter integer PARA_APB_WAIT_STATES = 0
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
    output logic [3:0]              o_pstrb,
    output logic [2:0]              o_pprot
);

  typedef enum logic [1:0] {
    IDLE,
    SETUP,
    ACCESS
  } apb_state_t;

  apb_state_t state, next_state;

  logic        trans_done;
  logic [PARA_ADDR_WIDTH-1:0] req_addr;
  logic [PARA_DATA_WIDTH-1:0] req_wdata;
  logic        req_write;
  logic [3:0]  req_strb;
  logic [2:0]  req_prot;
  logic        req_valid = 1'b0;
  logic [PARA_DATA_WIDTH-1:0] read_data;
  integer      wait_cnt;

  // APB4 protection signal encoding:
  // pprot[0]: 0=Secure, 1=Non-secure
  // pprot[1]: 0=Privileged, 1=Unprivileged
  // pprot[2]: 0=Data access, 1=Instruction access

  // APB state machine
  always_ff @(posedge i_clk or negedge i_rst_n) begin : apb_master_seq
    if (~i_rst_n) begin
      state      <= IDLE;
      o_psel     <= 1'b0;
      o_penable  <= 1'b0;
      o_pwrite   <= 1'b0;
      o_paddr    <= {PARA_ADDR_WIDTH{1'b0}};
      o_pwdata   <= {PARA_DATA_WIDTH{1'b0}};
      o_pstrb    <= 4'h0;
      o_pprot    <= 3'h0;
      wait_cnt   <= 0;
      trans_done <= 1'b0;
    end else begin
      trans_done <= 1'b0;
      state <= next_state;

      case (state)
        IDLE: begin
          o_psel    <= 1'b0;
          o_penable <= 1'b0;
        end

        SETUP: begin
          o_psel     <= 1'b1;
          o_penable  <= 1'b0;
          o_pwrite   <= req_write;
          o_paddr    <= req_addr;
          o_pwdata   <= req_wdata;
          o_pstrb    <= req_strb;
          o_pprot    <= req_prot;
          wait_cnt   <= PARA_APB_WAIT_STATES;
        end

        ACCESS: begin
          o_psel    <= 1'b1;
          o_penable <= 1'b1;
          if (wait_cnt > 0) begin
            wait_cnt <= wait_cnt - 1;
          end else if (i_pready) begin
            if (!req_write) begin
              read_data <= i_prdata;
            end
            trans_done <= 1'b1;
          end
        end

        default: begin
          o_psel     <= 1'b0;
          o_penable  <= 1'b0;
        end
      endcase
    end
  end

  always_comb begin : apb_master_next_state
    next_state = state;
    case (state)
      IDLE: begin
        if (req_valid) begin
          next_state = SETUP;
        end
      end

      SETUP: begin
        next_state = ACCESS;
      end

      ACCESS: begin
        if (wait_cnt > 0) begin
          next_state = ACCESS;
        end else if (i_pready) begin
          next_state = IDLE;
        end else begin
          next_state = ACCESS;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
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
    req_strb  = 4'hF;  // All bytes enabled
    req_prot  = prot;
    req_valid = 1'b1;
    wait (trans_done);
    req_valid = 1'b0;
  endtask

  // Task: APB4 write (byte lane controlled)
  task automatic write_strb(
    input logic [PARA_ADDR_WIDTH-1:0] addr,
    input logic [PARA_DATA_WIDTH-1:0] wdata,
    input logic [3:0]  strb,
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
    req_strb  = 4'h0;
    req_prot  = prot;
    req_valid = 1'b1;
    wait (trans_done);
    req_valid = 1'b0;
    rdata = read_data;
  endtask

endmodule
