//----------------------------------------------------------------+
//----------------------------------------------------------------+
// Project: Deep Learning Hardware Design Contest
// Module: axi_dma_wr
// Description:
//		Write the final output feature map to DRAM by AXI4
//
// 2021.09.01 by NXT (truongnx@capp.snu.ac.kr)
//----------------------------------------------------------------+
`timescale 1ns/1ps

module axi_dma_wr(
    //AXI Master Interface
    //Write address channel
    M_AWVALID,    // address/control valid handshake
    M_AWADDR,     // Address Write
    M_AWREADY,
    M_AWID,       // Address ID
    M_AWLEN,      // Transfer length
    M_AWSIZE,     // Transfer width
    M_AWBURST,    // Burst type
    M_AWLOCK,     // Atomic access information
    M_AWCACHE,    // Cachable/bufferable infor
    M_AWPROT,     // Protection info
    M_AWQOS,
    M_AWREGION,
    M_AWUSER,

    //Write data channel
    M_WVALID,     // Write data valid
    M_WREADY,     // Write data ready
    M_WDATA,      // Write Data bus
    M_WSTRB,      // Write Data byte lane strobes
    M_WLAST,      // Last beat of a burst transfer
    M_WID,        // Write ID
    M_WUSER,

    //Write response channel
    M_BVALID,     // Response info valid
    M_BREADY,     // Response info ready (to slave)
    M_BRESP,      // Buffered write response
    M_BID,        // buffered response ID
    M_BUSER,

    //User interface
    start_dma,		
    done_o,			
    num_trans,
    start_addr,
    //buff_start_addr,
    indata,
    indata_req_o,
    //buff_valid,
    fail_check,
    //User signals
    clk, 
    rstn
);
	// Parameters
	parameter BITS_TRANS = 18;
	parameter OUT_BITS_TRANS = 13;

	parameter AXI_WIDTH_USER = 1;              // Master ID
	parameter AXI_WIDTH_ID   = 4;              // ID width in bits
	parameter AXI_WIDTH_AD   = 32;             // address width
	parameter AXI_WIDTH_DA   = 32;            // data width
	parameter AXI_WIDTH_DS = (AXI_WIDTH_DA/8); // data strobe width
    //AXI Master Interface
    //Write address channel
    output                     M_AWVALID;   // address/control valid handshake
    input                      M_AWREADY;
    output [AXI_WIDTH_AD-1:0]  M_AWADDR;    // Address Write
    output [AXI_WIDTH_ID-1:0]  M_AWID;      // Address ID
    output [7:0]               M_AWLEN;     // Transfer length
    output [2:0]               M_AWSIZE;    // Transfer width
    output [1:0]               M_AWBURST;   // Burst type
    output [1:0]               M_AWLOCK;    // Atomic access information
    output [3:0]               M_AWCACHE;   // Cachable/bufferable infor
    output [2:0]               M_AWPROT;    // Protection info
    output [3:0]               M_AWQOS;
    output [3:0]               M_AWREGION;
    output [3:0]               M_AWUSER;
                               
    //Write data channel       
    output                     M_WVALID;    // Write data valid
    input                      M_WREADY;    // Write data ready
    output [AXI_WIDTH_DA-1:0]  M_WDATA;     // Write Data bus
    output [AXI_WIDTH_DS-1:0]  M_WSTRB;     // Write Data byte lane strobes
    output                     M_WLAST;     // Last beat of a burst transfer
    output [AXI_WIDTH_ID-1:0]  M_WID;       // Write ID
    output [3:0]               M_WUSER;

    //Write response channel
    input                       M_BVALID;    // Response info valid
    output                      M_BREADY;    // Response info ready (to slave)
    input [1:0]                 M_BRESP;     // Buffered write response
    input [AXI_WIDTH_ID-1:0]    M_BID;       // buffered response ID
    input                       M_BUSER;

    //User interface
    input                       start_dma;
    output reg                  done_o;
    input [OUT_BITS_TRANS-1:0]  num_trans;
    input [AXI_WIDTH_DA-1:0]    start_addr;
    input [AXI_WIDTH_DA-1:0]    indata;
    output reg                  indata_req_o;
    //input [MAX_BUFF_W-1:0]      buff_start_addr;
    //input           buff_valid;
    output reg      fail_check;	// For debugging
    //User signals
    input clk;
    input rstn;
//---------------------------------------------------------------------
// parameter definitions 
//---------------------------------------------------------------------
   localparam FIXED_BURST_SIZE = 256;//It can be ~256
   localparam DEFAULT_ID = 0;
   //AXI data width: number of bytes
   localparam  SIZE_1B     = 3'b000;
   localparam  SIZE_2B     = 3'b001;
   localparam  SIZE_4B     = 3'b010;
   localparam  SIZE_8B     = 3'b011;
   localparam  SIZE_16B    = 3'b100;      // not supported    
   localparam  SIZE_32B    = 3'b101;      // not supported
   localparam  SIZE_64B    = 3'b110;      // not supported
   localparam  SIZE_128B   = 3'b111;      // not supported
   
   localparam  RESP_OKAY   = 2'b00;
   localparam  RESP_EXOKAY = 2'b01;
   localparam  RESP_SLVERR = 2'b10;
   localparam  RESP_DECERR = 2'b11;
   localparam LOG_BURST_SIZE = $clog2(FIXED_BURST_SIZE);
//---------------------------------------------------------------------
// Internal signals 
//---------------------------------------------------------------------
  reg  [AXI_WIDTH_AD-1:0] ext_awaddr ;
  reg  [7:0]              ext_awlen  ;
  reg  [2:0]              ext_awsize ;
  reg                     ext_awvalid;
  wire                    ext_awready;
  reg  [AXI_WIDTH_DA-1:0] ext_wdata  ;
  reg  [AXI_WIDTH_DS-1:0] ext_wstrb  ;
  reg                  ext_wlast  ;
  reg                  ext_wvalid ;
  wire                 ext_wready ;
  wire [AXI_WIDTH_ID-1:0]    ext_bid;
  wire [1:0]           ext_bresp  ;
  wire                 ext_bvalid ;
  reg                  ext_bready ;
//reg  [1:0]                 ext_awburst;

   assign M_AWID = DEFAULT_ID;
   assign M_WID = DEFAULT_ID;
   assign M_AWBURST = 2'b01;//Increase mode
   assign M_AWLOCK = 2'b00;
   assign M_AWCACHE = 4'b0000;
   assign M_AWPROT = 3'b000;
   assign M_AWQOS = 4'b1111;
   assign M_AWREGION = 4'b0000;
   assign M_AWUSER = 4'b0000;
   assign M_WUSER = 4'b0000;

   assign  M_AWVALID = ext_awvalid;
   assign  M_AWADDR  = ext_awaddr;
   assign  M_AWLEN   = ext_awlen;
   assign  M_AWSIZE  = ext_awsize;
   assign  ext_awready = M_AWREADY;
               
   assign  M_WVALID  = ext_wvalid;
   assign  M_WDATA   = ext_wdata;
   assign  M_WSTRB   = ext_wstrb;
   assign  M_WLAST   = ext_wlast;
   assign  ext_wready = M_WREADY;
               
   assign  ext_bid     = M_BID;
   assign  ext_bresp   = M_BRESP;
   assign  ext_bvalid  = M_BVALID;
   assign  M_BREADY    = ext_bready;

   reg [OUT_BITS_TRANS-1:0] num_trans_d;
   reg [7:0] d_beat_cnt_wr, q_beat_cnt_wr;
   reg [OUT_BITS_TRANS-1:0] d_burst_cnt_wr, q_burst_cnt_wr;
   reg [7:0] q_burst_size_wr;
   reg [8:0] q_burst_size_wr_1;   //added 1 to q_burst_size_wr
   reg [AXI_WIDTH_AD-1:0] q_ext_addr_wr; //current AXI address for Write

   //FSM for Write to axi
  reg [2:0] st_wr2axi, next_st_wr2axi;
   localparam  WR_IDLE = 0,
               WR_PRE = 1,
               WR_START = 2,
               WR_BUFF_WAIT =3,	// Reserved
               WR_SEQ = 4,
               WR_WAIT = 5;
//---------------------------------------------------------------------
// Module designs 
//---------------------------------------------------------------------
   //---------------------------------------------------------------
   // FSM for Write data to AXI Interface 
   //---------------------------------------------------------------
   always @(posedge clk or negedge rstn) begin
      if(!rstn) num_trans_d <= 'h0;
      else if(start_dma) num_trans_d <= num_trans;
   end
   always @(posedge clk or negedge rstn) begin
      if(!rstn) begin
         q_beat_cnt_wr <= 0;
         q_burst_cnt_wr <= 0;
      end
      else begin
         q_beat_cnt_wr <= d_beat_cnt_wr;
         q_burst_cnt_wr <= d_burst_cnt_wr;
      end
   end
   
   always @(posedge clk or negedge rstn)
   begin
      if(!rstn) begin
         q_burst_size_wr <= 0; 
         q_burst_size_wr_1 <= 0; 
      end
      else if(q_burst_cnt_wr + FIXED_BURST_SIZE > num_trans_d)
      begin
         q_burst_size_wr <= num_trans_d[LOG_BURST_SIZE-1:0] - 1;
         q_burst_size_wr_1 <= num_trans_d[LOG_BURST_SIZE-1:0];
      end
      else begin
         q_burst_size_wr <= FIXED_BURST_SIZE-1;
         q_burst_size_wr_1 <= FIXED_BURST_SIZE;
      end
   end
   always @(posedge clk or negedge rstn) begin
      if(!rstn) 
         q_ext_addr_wr <= 0;
      else if(start_dma)
         q_ext_addr_wr <= start_addr;
      else if((st_wr2axi == WR_WAIT) && (next_st_wr2axi == WR_PRE) && (ext_bresp == RESP_OKAY))
         q_ext_addr_wr <= q_ext_addr_wr + {q_burst_size_wr_1, {2'b00}}; //4 Byte
   end

  //assign data_last_o = (st_wr2axi == WR_PRE)&&(q_burst_cnt_wr == num_trans_d);

   always @(posedge clk or negedge rstn)
      if(!rstn)  st_wr2axi <= WR_IDLE;
      else       st_wr2axi <= next_st_wr2axi;

   always @* begin
      next_st_wr2axi = st_wr2axi;
      d_beat_cnt_wr = q_beat_cnt_wr;
      d_burst_cnt_wr = q_burst_cnt_wr;
      
      indata_req_o = 1'b0;
      //AXI signals for write
      ext_awvalid = 1'b0;
      ext_awaddr = 0;
      ext_awlen = 0;
      ext_awsize = 0;
      ext_wvalid = 1'b0;
      ext_wdata = 0;
      ext_wstrb = 0;
      ext_wlast = 1'b0;
      ext_bready = 1'b0;
      done_o = 1'b0;
      fail_check = 1'b0;
      case(st_wr2axi)
         default: next_st_wr2axi = WR_IDLE;
         WR_IDLE: begin
            if(start_dma)
               next_st_wr2axi = WR_PRE;
         end
         WR_PRE: begin
            if(q_burst_cnt_wr == num_trans_d) begin   //end of blk transfer
               d_burst_cnt_wr = 0;
               next_st_wr2axi = WR_IDLE;
               done_o = 1'b1;
            end
            else
               next_st_wr2axi = WR_START;
         end
         WR_START: begin   //start burst transfer
               ext_awvalid = 1'b1; //start write cmd
               ext_awaddr = q_ext_addr_wr;
               ext_awlen = q_burst_size_wr;
               //ext_awburst = 2'b01;
               ext_awsize = SIZE_4B;      //data width is 32bit
            if(ext_awready) begin //valid data and axiwr is ready
               indata_req_o = 1'b1;
               //next_st_wr2axi = WR_BUFF_WAIT;
			   next_st_wr2axi = WR_SEQ;
            end
         end
         //WR_BUFF_WAIT : begin
         // if(buff_valid) begin 
         //   next_st_wr2axi = WR_SEQ;
         // end
         //end
         WR_SEQ: begin
            if(ext_wready) begin
               ext_wvalid = 1'b1;   //start output data
               ext_wdata = indata;
               ext_wstrb = {AXI_WIDTH_DS{1'b1}};  //no support for narrow transfer

               if(q_burst_size_wr == q_beat_cnt_wr) begin //last beat of burst
                  d_beat_cnt_wr = 'h0;
                  ext_wlast = 1'b1;
                  next_st_wr2axi = WR_WAIT;
               end
               else begin
                  indata_req_o = 1'b1;
                  d_beat_cnt_wr = q_beat_cnt_wr + 1'b1;
               end
            end
         end
         WR_WAIT: begin //wait bresp from AXI
            ext_bready = 1'b1;
            if(ext_bvalid) begin
               //if((ext_bid == ext_wid) && (ext_bresp == RESP_OKAY)) begin
               if((ext_bresp == RESP_OKAY)) begin //TODO: to compatible with AXI IC
                  d_burst_cnt_wr = q_burst_cnt_wr + q_burst_size_wr_1;
                  d_beat_cnt_wr = 0;
                  next_st_wr2axi = WR_PRE;   
               end//when bresp is wrong, back to start state and repeat recent burst 
               else begin 
                  d_beat_cnt_wr = 0;
                  next_st_wr2axi = WR_PRE;
                  fail_check = 1'b1;
               end            
            end
         end
      endcase
   end
endmodule