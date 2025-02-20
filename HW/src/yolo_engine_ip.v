
`timescale 1 ns / 1 ps

	module yolo_engine_ip #
	(
		// Users to add parameters here
        parameter integer MEM_ADDRW = 22,
        parameter integer MEM_DW = 16,
        parameter integer A = 32,
        parameter integer D = 32,
        parameter integer I = 4,
        parameter integer L = 8,
        parameter integer M = D/8,
        parameter integer AXI_WIDTH_AD = A,	// Address Bit Width
		parameter integer AXI_WIDTH_ID = 4, 
		parameter integer AXI_WIDTH_DA = D, // Data Bit Width
		parameter integer AXI_WIDTH_DS = M, // Data Strobe Bit Width
		// User parameters ends
		// Do not modify the parameters beyond this line
		
		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 4		
	)
	(
		// Users to add ports here
          output                         M_ARVALID
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
        , input                          M_BUSER,
		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready
	);
	
    wire [31:0] ctrl_reg0;	
	wire [31:0] ctrl_reg1;
	wire [31:0] ctrl_reg2;
	wire [31:0] ctrl_reg3;
	wire        network_done;
	wire        network_done_led;
	
// Instantiation of Axi Bus Interface S00_AXI
	yolo_engine_axi # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) u_yolo_engine_axi (
        .ctrl_reg0 (ctrl_reg0), // network_start // {debug_big(1), debug_buf_select(16), debug_buf_addr(9)}
        .ctrl_reg1 (ctrl_reg1), // Read_address (INPUT)
        .ctrl_reg2 (ctrl_reg2), // Write_address
        .ctrl_reg3 (ctrl_reg3), // Reserved
        .network_done(network_done),
        .network_done_led(network_done_led),
		
		.S_AXI_ACLK    (s00_axi_aclk   ),
		.S_AXI_ARESETN (s00_axi_aresetn),
		.S_AXI_AWADDR  (s00_axi_awaddr ),
		.S_AXI_AWPROT  (s00_axi_awprot ),
		.S_AXI_AWVALID (s00_axi_awvalid),
		.S_AXI_AWREADY (s00_axi_awready),
		.S_AXI_WDATA   (s00_axi_wdata  ),
		.S_AXI_WSTRB   (s00_axi_wstrb  ),
		.S_AXI_WVALID  (s00_axi_wvalid ),
		.S_AXI_WREADY  (s00_axi_wready ),
		.S_AXI_BRESP   (s00_axi_bresp  ),
		.S_AXI_BVALID  (s00_axi_bvalid ),
		.S_AXI_BREADY  (s00_axi_bready ),
		.S_AXI_ARADDR  (s00_axi_araddr ),
		.S_AXI_ARPROT  (s00_axi_arprot ),
		.S_AXI_ARVALID (s00_axi_arvalid),
		.S_AXI_ARREADY (s00_axi_arready),
		.S_AXI_RDATA   (s00_axi_rdata  ),
		.S_AXI_RRESP   (s00_axi_rresp  ),
		.S_AXI_RVALID  (s00_axi_rvalid ),
		.S_AXI_RREADY  (s00_axi_rready )
	);

	// Add user logic here
    yolo_engine #(
        .AXI_WIDTH_AD(A),
        .AXI_WIDTH_ID(4),
        .AXI_WIDTH_DA(D),
        .AXI_WIDTH_DS(M),
        .MEM_BASE_ADDR(2048),
        .MEM_DATA_BASE_ADDR(2048)
    )
    u_yolo_engine
    (
        .clk(clk),
        .rstn(rstn),
           
        .i_ctrl_reg0(ctrl_reg0), // network_start // {debug_big(1), debug_buf_select(16), debug_buf_addr(9)}
        .i_ctrl_reg1(ctrl_reg1), // Read_address (INPUT)
        .i_ctrl_reg2(ctrl_reg2), // Write_address
        .i_ctrl_reg3(ctrl_reg3), // Reserved
    
        .M_ARADDR	(M_ARADDR        ),
		.M_ARPROT	(M_ARPROT        ),
		.M_ARVALID	(M_ARVALID       ),
        .M_ARREADY	(M_ARREADY       ),
        
        .M_ARID		(M_ARID	         ),
        .M_ARLEN	(M_ARLEN         ),
        .M_ARSIZE	(M_ARSIZE        ),
        .M_ARBURST	(M_ARBURST       ),
        .M_ARLOCK	(M_ARLOCK        ),
        .M_ARCACHE	(M_ARCACHE       ),
        
        .M_ARQOS	(		         ),
        .M_ARREGION (		         ),
        .M_ARUSER	(		         ),
		
        .M_RVALID	(M_RVALID        ),
        .M_RREADY	(M_RREADY        ),
        .M_RDATA	(M_RDATA         ),
        .M_RLAST	(M_RLAST         ),
        .M_RID		(M_RID	         ),
        .M_RUSER	(		         ),
        .M_RRESP	(M_RRESP         ),
        
        .M_AWVALID	(M_AWVALID       ),
        .M_AWREADY	(M_AWREADY       ),
        .M_AWADDR	(M_AWADDR        ),
        .M_AWID		(M_AWID	         ),
        .M_AWLEN	(M_AWLEN         ),
        .M_AWSIZE	(M_AWSIZE        ),
        .M_AWBURST	(M_AWBURST       ),
        .M_AWLOCK	(M_AWLOCK        ),
        .M_AWCACHE	(M_AWCACHE       ),
        .M_AWPROT	(M_AWPROT        ),
        .M_AWQOS	(	             ),
        .M_AWREGION (	             ),
        .M_AWUSER	(	             ),
        
        .M_WVALID	(M_WVALID        ),
        .M_WREADY	(M_WREADY        ),
        .M_WDATA	(M_WDATA         ),
        .M_WSTRB	(M_WSTRB         ),
        .M_WLAST	(M_WLAST         ),
        .M_WID		(M_WID	         ),
        .M_WUSER	(		         ),
        
        .M_BVALID	(M_BVALID        ),
        .M_BREADY	(M_BREADY        ),
        .M_BRESP	(M_BRESP         ),
        .M_BID		(M_BID	         ),
        .M_BUSER	(		         ),
        
        .network_done(network_done),
        .network_done_led(network_done_led)
    );

	// User logic ends

	endmodule
