//------------------------------------------------------------+
//------------------------------------------------------------+
// Project: Deep Learning Hardware Design Contest
// Module: spram_wrapper
// Description:
//		Single-port RAM wrapper
//		FPGA = 1: Use the generated RAM 
//		Otherwise: Use a RAM modeling
//
// History: 2021.09.01 by NXT (truongnx@capp.snu.ac.kr)
//------------------------------------------------------------+

//`define FPGA 1
module spram_wrapper (
	clk,					// clock 
	addr,					// input address 
	we,						// input write enable
	cs,						// input chip-select 
	wdata,					// input write data
	rdata					// output read-out data
);
`include "define.v"
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
input [AW-1			:	0]		addr;	// input address 
input							we;		// input write enable
input							cs;		// input chip-select 
input [DW-1			:	0]		wdata;	// input write data
// output SRAM signal
output [DW-1		:	0]		rdata;	// output read-out data

//------------------------------------------------------------------------+
// Declare internal signals
//------------------------------------------------------------------------+
reg	[DW-1			:	0]		rdata_o;


`ifdef FPGA
	//------------------------------------------------------------------------+
	// Implement generate block ram
	//------------------------------------------------------------------------+
	generate
		if((DEPTH == 512) && (DW == 72)) begin: gen_spram_512x72
			spram_512x72 u_spram_512x72( 
				// write
				.clka(clk),
				.ena(cs),
				.wea(we),
				.addra(addr),
				.dina(wdata),
				// read-out
				.douta(rdata)
			 );
		end
		else if((DEPTH == 832) && (DW == 32)) begin: gen_spram_832x32
			spram_832x32 u_spram_832x32( 
				// write
				.clka(clk),
				.ena(cs),
				.wea(we),
				.addra(addr),
				.dina(wdata),
				// read-out
				.douta(rdata)
			 );
		end
		else if((DEPTH == 256) && (DW == 64)) begin: gen_spram_256x64
			spram_256x64 u_spram_256x64( 
				// write
				.clka(clk),
				.ena(cs),
				.wea(we),
				.addra(addr),
				.dina(wdata),
				// read-out
				.douta(rdata)
			 );
		end
		else if((DEPTH == 208) && (DW == 256)) begin: gen_spram_208x256
			spram_208x256 u_spram_208x256( 
				// write
				.clka(clk),
				.ena(cs),
				.wea(we),
				.addra(addr),
				.dina(wdata),
				// read-out
				.douta(rdata)
			 );
		end
		else if((DEPTH == 6240) && (DW == 32)) begin: gen_spram_6240x32
			spram_6240x32 u_spram_6240x32( 
				// write
				.clka(clk),
				.ena(cs),
				.wea(we),
				.addra(addr),
				.dina(wdata),
				// read-out
				.douta(rdata)
			 );
		end
	endgenerate

`else 
	//------------------------------------------------------------------------+
	// Memory modeling
	//------------------------------------------------------------------------+
	reg [DW-1			:	0]		mem[0:DEPTH-1];	// Memory cell
	// Write
	always @(posedge clk) begin
		if(cs && we)			mem[addr] <= wdata;
	end
	// Read
	generate
	   if(N_DELAY == 1) begin: gen_delay_1
		  always @(posedge clk)
			 if (cs && !(|we)) rdata_o <= mem[addr];

		  assign rdata = rdata_o;
	   end
	   else begin: gen_delay_n
		  reg [N_DELAY*DW-1:0] rdata_r;

		  always @(posedge clk)
			 if (cs && !(|we)) rdata_r[0*DW+:DW] <= mem[addr];

		  always @(posedge clk) begin: delay
			 integer i;
			 for(i = 0; i < N_DELAY-1; i = i+1)
				if(cs && !(|we))
				   rdata_r[(i+1)*DW+:DW] <= rdata_r[i*DW+:DW];
		  end
		  assign rdata = rdata_r[(N_DELAY-1)*DW+:DW];
	   end
	endgenerate

`endif


endmodule




