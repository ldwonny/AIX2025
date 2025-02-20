//----------------------------------------------------------------+
// Project: Deep Learning Hardware Design Contest
// Module: yolo_engine
// Description:
//		Load parameters and input feature map from DRAM via AXI4
//
// 2023.04.05 by NXT (truongnx@capp.snu.ac.kr)
//----------------------------------------------------------------+
module yolo_engine #(
    parameter AXI_WIDTH_AD = 32,
    parameter AXI_WIDTH_ID = 4,
    parameter AXI_WIDTH_DA = 32,
    parameter AXI_WIDTH_DS = AXI_WIDTH_DA/8,
    parameter OUT_BITS_TRANS = 18,
    parameter WBUF_AW = 9,
    parameter WBUF_DW = 8*3*3*16,
    parameter WBUF_DS = WBUF_DW/8,
    parameter MEM_BASE_ADDR = 'h8000_0000,
    parameter MEM_DATA_BASE_ADDR = 4096
)
(
    input                          clk
    , input                          rstn

    , input [31:0] i_ctrl_reg0    // network_start, // {debug_big(1), debug_buf_select(16), debug_buf_addr(9)}
    , input [31:0] i_ctrl_reg1    // Read address base
    , input [31:0] i_ctrl_reg2    // Write address base
	, input [31:0] i_ctrl_reg3    // Write address base

    , output                         M_ARVALID
    , input                          M_ARREADY
    , output  [AXI_WIDTH_AD-1:0]     M_ARADDR
    , output  [AXI_WIDTH_ID-1:0]     M_ARID
    , output  [7:0]                  M_ARLEN
    , output  [2:0]                  M_ARSIZE
    , output  [1:0]                  M_ARBURST
    , output  [1:0]                  M_ARLOCK
    , output  [3:0]                  M_ARCACHE
    , output  [2:0]                  M_ARPROT
    , output  [3:0]                  M_ARQOS
    , output  [3:0]                  M_ARREGION
    , output  [3:0]                  M_ARUSER
    , input                          M_RVALID
    , output                         M_RREADY
    , input  [AXI_WIDTH_DA-1:0]      M_RDATA
    , input                          M_RLAST
    , input  [AXI_WIDTH_ID-1:0]      M_RID
    , input  [3:0]                   M_RUSER
    , input  [1:0]                   M_RRESP
       
    , output                         M_AWVALID
    , input                          M_AWREADY
    , output  [AXI_WIDTH_AD-1:0]     M_AWADDR
    , output  [AXI_WIDTH_ID-1:0]     M_AWID
    , output  [7:0]                  M_AWLEN
    , output  [2:0]                  M_AWSIZE
    , output  [1:0]                  M_AWBURST
    , output  [1:0]                  M_AWLOCK
    , output  [3:0]                  M_AWCACHE
    , output  [2:0]                  M_AWPROT
    , output  [3:0]                  M_AWQOS
    , output  [3:0]                  M_AWREGION
    , output  [3:0]                  M_AWUSER
    
    , output                         M_WVALID
    , input                          M_WREADY
    , output  [AXI_WIDTH_DA-1:0]     M_WDATA
    , output  [AXI_WIDTH_DS-1:0]     M_WSTRB
    , output                         M_WLAST
    , output  [AXI_WIDTH_ID-1:0]     M_WID
    , output  [3:0]                  M_WUSER
    
    , input                          M_BVALID
    , output                         M_BREADY
    , input  [1:0]                   M_BRESP
    , input  [AXI_WIDTH_ID-1:0]      M_BID
    , input                          M_BUSER
    
    , output network_done
    , output network_done_led   
);
`include "define.v"

parameter BUFF_DEPTH    = 256;
parameter BUFF_ADDR_W   = $clog2(BUFF_DEPTH);
localparam BIT_TRANS = BUFF_ADDR_W;

//CSR
reg ap_start;
reg ap_ready;
reg ap_done;
reg interrupt;

reg [31:0] dram_base_addr_rd;
reg [31:0] dram_base_addr_wr;
reg [31:0] reserved_register;

// Signals for dma read  
wire ctrl_read;
wire read_done;
wire [AXI_WIDTH_AD-1:0] read_addr;
wire [AXI_WIDTH_DA-1:0] read_data;
wire                    read_data_vld;
wire [BIT_TRANS   -1:0] read_data_cnt;

// Signals for dma write
wire ctrl_write_done;
wire ctrl_write;
wire write_done;
wire indata_req_wr;
wire [BIT_TRANS   -1:0] write_data_cnt;
wire [AXI_WIDTH_AD-1:0] write_addr;
wire [AXI_WIDTH_DA-1:0] write_data;

// FIX ME
wire[BIT_TRANS   -1:0] num_trans        = 16;           // BURST_LENGTH = 16
wire[            15:0] max_req_blk_idx  = (256*256)/16; // The number of blocks
//----------------------------------------------------------------
// Control signals
//----------------------------------------------------------------
always @ (*) begin
    ap_done     = ctrl_write_done;
    ap_ready    = 1;
end
assign network_done     = interrupt;
assign network_done_led = interrupt;


always @ (posedge clk, negedge rstn) begin
    if(~rstn) begin
        ap_start <= 0;
    end
    else begin 
        if(!ap_start && i_ctrl_reg0[0])
            ap_start <= 1;
        else if (ap_done)
            ap_start <= 0;    
    end 
end

always @(posedge clk, negedge rstn) begin
    if(~rstn) begin
        interrupt <= 0;
    end
    else begin        
        if(i_ctrl_reg0[0])
            interrupt <= 0;         
        else if (ap_done)
            interrupt <= 1;                   
    end
end

// Parse the control registers
always @ (posedge clk, negedge rstn) begin
    if(~rstn) begin
        dram_base_addr_rd <= 0;
        dram_base_addr_wr <= 0;
        reserved_register <= 0; // unused 
    end
    else begin 
        if(!ap_start && i_ctrl_reg0[0]) begin 
            dram_base_addr_rd <= i_ctrl_reg1; // Base Address for READ  (Input image, Model parameters)
            dram_base_addr_wr <= i_ctrl_reg2; // Base Address for WRITE (Intermediate feature maps, Outputs)
            reserved_register <= i_ctrl_reg3; // reserved
        end 
        else if (ap_done) begin 
            dram_base_addr_rd <= 0;
            dram_base_addr_wr <= 0;
            reserved_register <= 0; 
        end 
    end 
end
//----------------------------------------------------------------
// DUTs
//----------------------------------------------------------------
// DMA Controller
axi_dma_ctrl #(.BIT_TRANS(BIT_TRANS))
u_dma_ctrl(
    .clk              (clk              )
   ,.rstn             (rstn             )
   ,.i_start          (i_ctrl_reg0[0]   )
   ,.i_base_address_rd(dram_base_addr_rd)
   ,.i_base_address_wr(dram_base_addr_wr)
   ,.i_num_trans      (num_trans        )
   ,.i_max_req_blk_idx(max_req_blk_idx  )
   // DMA Read
   ,.i_read_done      (read_done        )
   ,.o_ctrl_read      (ctrl_read        )
   ,.o_read_addr      (read_addr        )
   // DMA Write
   ,.i_indata_req_wr  (indata_req_wr    )
   ,.i_write_done     (write_done       )
   ,.o_ctrl_write     (ctrl_write       )
   ,.o_write_addr     (write_addr       )
   ,.o_write_data_cnt (write_data_cnt   )
   ,.o_ctrl_write_done(ctrl_write_done  )
);


// DMA read module
axi_dma_rd #(
        .BITS_TRANS(BIT_TRANS),
        .OUT_BITS_TRANS(OUT_BITS_TRANS),    
        .AXI_WIDTH_USER(1),             // Master ID
        .AXI_WIDTH_ID(4),               // ID width in bits
        .AXI_WIDTH_AD(AXI_WIDTH_AD),    // address width
        .AXI_WIDTH_DA(AXI_WIDTH_DA),    // data width
        .AXI_WIDTH_DS(AXI_WIDTH_DS)     // data strobe width
    )
u_dma_read(
    //AXI Master Interface
    //Read address channel
    .M_ARVALID	(M_ARVALID	  ),  // address/control valid handshake
    .M_ARREADY	(M_ARREADY	  ),  // Read addr ready
    .M_ARADDR	(M_ARADDR	  ),  // Address Read 
    .M_ARID		(M_ARID		  ),  // Read addr ID
    .M_ARLEN	(M_ARLEN	  ),  // Transfer length
    .M_ARSIZE	(M_ARSIZE	  ),  // Transfer width
    .M_ARBURST	(M_ARBURST	  ),  // Burst type
    .M_ARLOCK	(M_ARLOCK	  ),  // Atomic access information
    .M_ARCACHE	(M_ARCACHE	  ),  // Cachable/bufferable infor
    .M_ARPROT	(M_ARPROT	  ),  // Protection info
    .M_ARQOS	(M_ARQOS	  ),  // Quality of Service
    .M_ARREGION	(M_ARREGION	  ),  // Region signaling
    .M_ARUSER	(M_ARUSER	  ),  // User defined signal
 
    //Read data channel
    .M_RVALID	(M_RVALID	  ),  // Read data valid 
    .M_RREADY	(M_RREADY	  ),  // Read data ready (to Slave)
    .M_RDATA	(M_RDATA	  ),  // Read data bus
    .M_RLAST	(M_RLAST	  ),  // Last beat of a burst transfer
    .M_RID		(M_RID		  ),  // Read ID
    .M_RUSER	(M_RUSER	  ),  // User defined signal
    .M_RRESP	(M_RRESP	  ),  // Read response
     
    //Functional Ports
    .start_dma	(ctrl_read    ),
    .num_trans	(num_trans    ), //Number of 128-bit words transferred
    .start_addr	(read_addr    ), //iteration_num * 4 * 16 + read_address_d	
    .data_o		(read_data    ),
    .data_vld_o	(read_data_vld),
    .data_cnt_o	(read_data_cnt),
    .done_o		(read_done    ),

    //Global signals
    .clk        (clk          ),
    .rstn       (rstn         )
);


// dpram_256x32 
dpram_wrapper #(
    .DEPTH  (BUFF_DEPTH     ),
    .AW     (BUFF_ADDR_W    ),
    .DW     (AXI_WIDTH_DA   ))
u_data_buffer(    
    .clk	(clk		    ),
    .ena	(1'd1		    ),
	.addra	(read_data_cnt  ),
	.wea	(read_data_vld  ),
	.dia	(read_data      ),
    .enb    (1'd1           ),  // Always Read       
    .addrb	(write_data_cnt ),
    .dob	(write_data     )
);

// DMA write module
axi_dma_wr #(
        .BITS_TRANS(BIT_TRANS),
        .OUT_BITS_TRANS(BIT_TRANS),    
        .AXI_WIDTH_USER(1),           // Master ID
        .AXI_WIDTH_ID(4),             // ID width in bits
        .AXI_WIDTH_AD(AXI_WIDTH_AD),  // address width
        .AXI_WIDTH_DA(AXI_WIDTH_DA),  // data width
        .AXI_WIDTH_DS(AXI_WIDTH_DS)   // data strobe width
    )
u_dma_write(
    .M_AWID		(M_AWID		),  // Address ID
    .M_AWADDR	(M_AWADDR	),  // Address Write
    .M_AWLEN	(M_AWLEN	),  // Transfer length
    .M_AWSIZE	(M_AWSIZE	),  // Transfer width
    .M_AWBURST	(M_AWBURST	),  // Burst type
    .M_AWLOCK	(M_AWLOCK	),  // Atomic access information
    .M_AWCACHE	(M_AWCACHE	),  // Cachable/bufferable infor
    .M_AWPROT	(M_AWPROT	),  // Protection info
    .M_AWREGION	(M_AWREGION	),
    .M_AWQOS	(M_AWQOS	),
    .M_AWVALID	(M_AWVALID	),  // address/control valid handshake
    .M_AWREADY	(M_AWREADY	),
    .M_AWUSER   (           ),
    //Write data channel
    .M_WID		(M_WID		),  // Write ID
    .M_WDATA	(M_WDATA	),  // Write Data bus
    .M_WSTRB	(M_WSTRB	),  // Write Data byte lane strobes
    .M_WLAST	(M_WLAST	),  // Last beat of a burst transfer
    .M_WVALID	(M_WVALID	),  // Write data valid
    .M_WREADY	(M_WREADY	),  // Write data ready
    .M_WUSER    (           ),
    .M_BUSER    (           ),    
    //Write response chaDnel
    .M_BID		(M_BID		),  // buffered response ID
    .M_BRESP	(M_BRESP	),  // Buffered write response
    .M_BVALID	(M_BVALID	),  // Response info valid
    .M_BREADY	(M_BREADY	),  // Response info ready (to slave)
    //Read address channDl
    //User interface
    .start_dma	(ctrl_write     ),
    .num_trans	(num_trans      ), //Number of words transferred
    .start_addr	(write_addr     ),
    .indata		(write_data     ),
    .indata_req_o(indata_req_wr ),
    .done_o		(write_done     ), //Blk transfer done
    .fail_check (               ),
    //User signals
    .clk        (clk            ),
    .rstn       (rstn           )
);

//--------------------------------------------------------------------
// DEBUGGING: Save the results in images
//--------------------------------------------------------------------
// synthesis_off
`ifdef CHECK_DMA_WRITE
	bmp_image_writer #(.OUTFILE(CONV_OUTPUT_IMG00),.WIDTH(IFM_WIDTH),.HEIGHT(IFM_HEIGHT))
	u_bmp_image_writer_00(
		./*input 			*/clk	(clk            ),
		./*input 			*/rstn	(rstn           ),
		./*input [WI-1:0]   */din	(i_WDATA[7:0]   ),
		./*input 			*/vld	(i_WVALID       ),
		./*output reg 		*/frame_done(           )
	);
	bmp_image_writer #(.OUTFILE(CONV_OUTPUT_IMG01),..WIDTH(IFM_WIDTH),.HEIGHT(IFM_HEIGHT))
	u_bmp_image_writer_01(
		./*input 			*/clk	(clk            ),
		./*input 			*/rstn	(rstn           ),
		./*input [WI-1:0]   */din	(i_WDATA[15:8]  ),
		./*input 			*/vld	(i_WVALID       ),
		./*output reg 		*/frame_done(           )
	);
	bmp_image_writer #(.OUTFILE(CONV_OUTPUT_IMG02),.WIDTH(IFM_WIDTH),.HEIGHT(IFM_HEIGHT))
	u_bmp_image_writer_02(
		./*input 			*/clk	(clk            ),
		./*input 			*/rstn	(rstn           ),
		./*input [WI-1:0]   */din	(i_WDATA[23:16] ),
		./*input 			*/vld	(i_WVALID       ),
		./*output reg 		*/frame_done(           )
	);
	bmp_image_writer #(.OUTFILE(CONV_OUTPUT_IMG03),.WIDTH(IFM_WIDTH),.HEIGHT(IFM_HEIGHT))
	u_bmp_image_writer_03(
		./*input 			*/clk	(clk            ),
		./*input 			*/rstn	(rstn           ),
		./*input [WI-1:0]   */din	(i_WDATA[31:24] ),
		./*input 			*/vld	(i_WVALID       ),
		./*output reg 		*/frame_done(           )
	);

`else   // Check DMA_READ 
	bmp_image_writer #(.OUTFILE(CONV_INPUT_IMG00),.WIDTH(IFM_WIDTH),.HEIGHT(IFM_HEIGHT))
	u_bmp_image_writer_00(
		./*input 			*/clk	(clk             ),
		./*input 			*/rstn	(rstn            ),
		./*input [WI-1:0]   */din	(read_data[7:0]  ),
		./*input 			*/vld	(read_data_vld   ),
		./*output reg 		*/frame_done(            )
	);
	bmp_image_writer #(.OUTFILE(CONV_INPUT_IMG01),.WIDTH(IFM_WIDTH),.HEIGHT(IFM_HEIGHT))
	u_bmp_image_writer_01(
		./*input 			*/clk	(clk             ),
		./*input 			*/rstn	(rstn            ),
		./*input [WI-1:0]   */din	(read_data[15:8] ),
		./*input 			*/vld	(read_data_vld   ),
		./*output reg 		*/frame_done(            )
	);
	bmp_image_writer #(.OUTFILE(CONV_INPUT_IMG02),.WIDTH(IFM_WIDTH),.HEIGHT(IFM_HEIGHT))
	u_bmp_image_writer_02(
		./*input 			*/clk	(clk             ),
		./*input 			*/rstn	(rstn            ),
		./*input [WI-1:0]   */din	(read_data[23:16]),
		./*input 			*/vld	(read_data_vld   ),
		./*output reg 		*/frame_done(            )
	);
	bmp_image_writer #(.OUTFILE(CONV_INPUT_IMG03),.WIDTH(IFM_WIDTH),.HEIGHT(IFM_HEIGHT))
	u_bmp_image_writer_03(
		./*input 			*/clk	(clk             ),
		./*input 			*/rstn	(rstn            ),
		./*input [WI-1:0]   */din	(read_data[31:24]),
		./*input 			*/vld	(read_data_vld   ),
		./*output reg 		*/frame_done(            )
	);
`endif    
// synthesis_on

endmodule
