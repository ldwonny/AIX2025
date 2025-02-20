`timescale 1ns/1ps

module axi_dma_ctrl #(
   parameter AXI_WIDTH_AD  = 32,
   parameter BIT_TRANS     = 18)(
input                   clk, 
input                   rstn,
input                   i_start,
input [31:0]            i_base_address_rd,
input [31:0]            i_base_address_wr,
input [BIT_TRANS-1:0]   i_num_trans,
input [15:0]            i_max_req_blk_idx,
// DMA Read
input                   i_read_done,
output                  o_ctrl_read,
output [31:0]           o_read_addr,
// DMA Write
input                   i_write_done,
input                   i_indata_req_wr,
output                  o_ctrl_write,
output [31:0]           o_write_addr,
output [BIT_TRANS-1:0]  o_write_data_cnt,
output                  o_ctrl_write_done   
);

// Internal Signals
// FSM
localparam ST_IDLE         = 0;
localparam ST_DMA          = 1;
localparam ST_DMA_WAIT     = 2;
localparam ST_DMA_SYNC     = 3;
localparam ST_DMA_DONE     = 4;

reg [2:0] cstate_rd, nstate_rd;
reg [2:0] cstate_wr, nstate_wr;

// dma read
reg ctrl_read;
reg ctrl_read_wait;
reg ctrl_read_sync;
reg ctrl_read_done;
wire[AXI_WIDTH_AD-1:0] read_addr;
//reg [BIT_TRANS   -1:0] read_data_cnt;
reg [15:0]  req_blk_idx_rd;

// dma write
reg ctrl_write;
reg ctrl_write_wait;
reg ctrl_write_sync;
reg ctrl_write_done;
wire[AXI_WIDTH_AD-1:0] write_addr;
reg [BIT_TRANS   -1:0] write_data_cnt;
reg [15:0]  req_blk_idx_wr;

wire [BIT_TRANS-1:0] num_trans      = i_num_trans;
wire [15:0] max_req_blk_idx         = i_max_req_blk_idx;
wire [31:0] dram_base_addr_rd       = i_base_address_rd;
wire [31:0] dram_base_addr_wr       = i_base_address_wr;
wire read_done                      = i_read_done;
wire write_done                     = i_write_done;
wire indata_req_wr                  = i_indata_req_wr;

assign o_write_data_cnt     = write_data_cnt;
assign o_ctrl_write         = ctrl_write;
assign o_ctrl_read          = ctrl_read;
assign o_read_addr          = read_addr;
assign o_write_addr         = write_addr;
assign o_ctrl_write_done    = ctrl_write_done;
//----------------------------------------------------------------
// FSM for DMA Read
//----------------------------------------------------------------
always @(posedge clk, negedge rstn) begin
    if(~rstn) begin
        cstate_rd <= ST_IDLE;
    end
    else begin
        cstate_rd <= nstate_rd;
    end
end

always @(*) begin
    ctrl_read = 0;
    ctrl_read_wait = 0;
    ctrl_read_sync = 0;
    ctrl_read_done = 0;
    nstate_rd = cstate_rd;
    case(cstate_rd)
        ST_IDLE: begin
            if(i_start) 
                nstate_rd = ST_DMA;
            else 
                nstate_rd = ST_IDLE;
        end
        ST_DMA: begin
            nstate_rd = ST_DMA_WAIT;
            ctrl_read = 1;
        end
        ST_DMA_WAIT: begin
            ctrl_read_wait = 1;
            if(read_done) begin 
                if (req_blk_idx_rd == max_req_blk_idx - 1)
                    nstate_rd = ST_DMA_DONE;
                else                 
                    nstate_rd = ST_DMA_SYNC;
            end 
        end 
        ST_DMA_SYNC: begin 
            ctrl_read_sync = 1;
            if(write_done) begin    // FIX ME
                    nstate_rd = ST_DMA;
            end                 
        end 
        ST_DMA_DONE: begin
            ctrl_read_done = 1;
            nstate_rd = ST_IDLE;
        end 
    endcase 
end 

always @(posedge clk, negedge rstn) begin
    if(~rstn) begin
        req_blk_idx_rd <= 0;
    end
    else begin
        if(read_done) begin 
           if(req_blk_idx_rd == max_req_blk_idx - 1)
                req_blk_idx_rd <= 0;                // Reset the counter
            else 
                req_blk_idx_rd <= req_blk_idx_rd + 1;   // Up-Counter    
        end 
    end
end

assign read_addr = dram_base_addr_rd + {req_blk_idx_rd,6'b0}; 

//----------------------------------------------------------------
// FSM for DMA Write
//----------------------------------------------------------------
always @(posedge clk, negedge rstn) begin
    if(~rstn) begin
        cstate_wr <= ST_IDLE;
    end
    else begin
        cstate_wr <= nstate_wr;
    end
end

always @(*) begin
    ctrl_write = 0;
    ctrl_write_wait = 0;
    ctrl_write_sync = 0;
    ctrl_write_done = 0;
    nstate_wr = cstate_wr;
    case(cstate_wr)
        ST_IDLE: begin
            if(read_done)   // FIX ME
                nstate_wr = ST_DMA;
            else 
                nstate_wr = ST_IDLE;
        end
        ST_DMA: begin
            nstate_wr = ST_DMA_WAIT;
            ctrl_write = 1;
        end
        ST_DMA_WAIT: begin
            ctrl_write_wait = 1;
            if(write_done) begin 
                if (req_blk_idx_wr == max_req_blk_idx - 1)
                    nstate_wr = ST_DMA_DONE;
                else 
                    nstate_wr = ST_DMA_SYNC;
            end 
        end
        ST_DMA_SYNC: begin 
            ctrl_write_sync = 1;
            if(read_done) begin     // FIX ME
                    nstate_wr = ST_DMA;
            end 
        end 
        ST_DMA_DONE: begin
            ctrl_write_done = 1;
            nstate_wr = ST_IDLE;
        end         
    endcase 
end 

always @(posedge clk, negedge rstn) begin
    if(~rstn) begin
        req_blk_idx_wr <= 0;
    end
    else begin
        if(write_done) begin 
           if(req_blk_idx_wr == max_req_blk_idx - 1)
                req_blk_idx_wr <= 0;                // Reset the counter
            else 
                req_blk_idx_wr <= req_blk_idx_wr + 1;   // Up-Counter    
        end 
    end
end

always @(posedge clk, negedge rstn) begin
    if(~rstn) begin
        write_data_cnt <= 0;
    end
    else begin
        if(ctrl_write)
            write_data_cnt <= 0;
        else if (indata_req_wr) begin 
            if(write_data_cnt == num_trans - 1)
                write_data_cnt <= 0;
            else 
                write_data_cnt <= write_data_cnt + 1;
        end 
    end
end

assign write_addr = dram_base_addr_wr + {req_blk_idx_wr,6'b0} + {write_data_cnt,2'b0}; 
endmodule