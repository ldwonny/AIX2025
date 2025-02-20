//------------------------------------------------------------+
//------------------------------------------------------------+
// Project: Deep Learning Hardware Design Contest
// Module: axi_lite_slave
// Description:
//		Dual-port RAM wrapper
//		FPGA = 1: Use the generated RAM 
//		Otherwise: Use a RAM modeling
//
// History: 2021.09.01 by NXT (truongnx@capp.snu.ac.kr)
//------------------------------------------------------------+

//`define FPGA 1
module dpram_wrapper (	
	clk,		// clock 
	ena,		// enable for write address
	addra,		// input address for write
	wea,		// input write enable
	enb,		// enable for read address
	addrb,		// input address for read
	dia,		// input write data
	dob			// output read-out data
);

//------------------------------------------------------------------------+
// Declare parameters
//------------------------------------------------------------------------+
// output parameters
parameter DW = 64;			// data bit-width per word
parameter AW = 8;			// address bit-width
parameter DEPTH = 256;		// depth, word length
parameter N_DELAY = 1;

//------------------------------------------------------------------------+
// Declare Input & Output signals
//------------------------------------------------------------------------+
// clock and reset
input							clk;
// input SRAM signals
input [AW-1			:	0]		addra;	// input address 
input							wea;	// input write enable
input							ena;	// input enable
input [DW-1			:	0]		dia;	// input write data
input [AW-1			:	0]		addrb;	// input address 
input							enb;	// input chip-select 
// output SRAM signal
output [DW-1		:	0]		dob;	// output read-out data
//------------------------------------------------------------------------+
// Declare internal signals
//------------------------------------------------------------------------+
reg	[DW-1			:	0]		rdata;

`ifdef FPGA
	//------------------------------------------------------------------------+
	// implement generate block ram
	//------------------------------------------------------------------------+
	generate
		if((DEPTH == 512) && (DW == 72)) begin: gen_dpram_512x72
			dpram_512x72 u_dpram_512x72 (
				// write ports
				.clka    (clk),
				.ena     (ena),
				.wea     (wea),
				.addra   (addra),
				.dina    (dia),
				// read ports 
				.clkb    (clk),
				.enb     (enb),
				.addrb   (addrb),
				.doutb   (dob)
			);
		end
		else if((DEPTH == 26) && (DW == 32)) begin: gen_dpram_26x32
			dpram_26x32 u_dpram_26x32 (
				// write ports
				.clka    (clk),
				.ena     (ena),
				.wea     (wea),
				.addra   (addra),
				.dina    (dia),
				// read ports 
				.clkb    (clk),
				.enb     (enb),
				.addrb   (addrb),
				.doutb   (dob)
			);
		end
		else if((DEPTH == 13) && (DW == 256)) begin: gen_dpram_13x256
			dpram_13x256 u_dpram_13x256 (
				// write ports
				.clka    (clk),
				.ena     (ena),
				.wea     (wea),
				.addra   (addra),
				.dina    (dia),
				// read ports 
				.clkb    (clk),
				.enb     (enb),
				.addrb   (addrb),
				.doutb   (dob)
			);
		end
		else if((DEPTH == 208) && (DW == 256)) begin: gen_dpram_208x256
			dpram_208x256 u_dpram_208x256 (
				// write ports
				.clka    (clk),
				.ena     (ena),
				.wea     (wea),
				.addra   (addra),
				.dina    (dia),
				// read ports 
				.clkb    (clk),
				.enb     (enb),
				.addrb   (addrb),
				.doutb   (dob)
			);
		end
		else if((DEPTH == 208) && (DW == 32)) begin: gen_dpram_208x32
			dpram_208x32 u_dpram_208x32 (
				// write ports
				.clka    (clk),
				.ena     (ena),
				.wea     (wea),
				.addra   (addra),
				.dina    (dia),
				// read ports 
				.clkb    (clk),
				.enb     (enb),
				.addrb   (addrb),
				.doutb   (dob)
			);
	    end
        else if((DEPTH == 16384) && (DW == 32)) begin: gen_dpram_16384x32
            dpram_16384x32 u_dpram_16384x32 (
				// write ports
				.clka    (clk),
				.ena     (ena),
				.wea     (wea),
				.addra   (addra),
				.dina    (dia),
				// read ports 
				.clkb    (clk),
				.enb     (enb),
				.addrb   (addrb),
				.doutb   (dob)
			);
		end
	endgenerate
`else
	//------------------------------------------------------------------------+
	// Memory modeling
	//------------------------------------------------------------------------+
	reg [DW-1			:	0]		ram[0:DEPTH-1];	// Memory cell
	// Write
	always @(posedge clk) begin
		if(ena) begin
			if(wea)			ram[addra] <= dia;
		end
	end	
	// Read
	generate 
	   if(N_DELAY == 1) begin: delay_1
		  reg [DW-1:0] rdata   ; //Primary Data Output
		  //Read port
		  always @(posedge clk)
		  begin: read
			 if(enb)
				rdata <= ram[addrb];
		  end
		  assign dob = rdata;
	   end
	   else begin: delay_n
		  reg [N_DELAY*DW-1:0] rdata_r;
		  always @(posedge clk)
		  begin: read
			 if(enb)
				rdata_r[0+:DW] <= ram[addrb];
		  end

		  always @(posedge clk) begin: delay
			 integer i;
			 for(i = 0; i < N_DELAY-1; i = i+1)
				if(enb)
				   rdata_r[(i+1)*DW+:DW] <= rdata_r[i*DW+:DW];
		  end
		  assign dob = rdata_r[(N_DELAY-1)*DW+:DW];
	   end
	endgenerate
`endif

endmodule


