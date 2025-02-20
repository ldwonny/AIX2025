//`define PRELOAD
//`define DEBUG
`define NUM_BRAMS   16
`define BRAM_WIDTH  128
`define BRAM_DELAY  3

// -------------------------------------------------------------
// Working with FPGA
//	1. Uncomment this line
//  2. Generate IPs 
//		+ DSP for multipliers(check mul.v)
//		+ Single-port RAM (spram_wrapper.v)
//		+ Double-port RAM (dpram_wrapper.v)
// -------------------------------------------------------------

// `define FPGA	1

// -------------------------------------------------------------
// For debuging 
// -------------------------------------------------------------
// IMPORTANT NOTE**: 
//      1. Correct the directories with your path
//      2. Use directories without blank space
//{{{
// Input Files
parameter IFM_WIDTH     = 256;
parameter IFM_HEIGHT    = 256;
parameter IFM_CHANNEL   = 3;
parameter IFM_DATA_SIZE     = IFM_HEIGHT*IFM_WIDTH*2;		// Layer 00
parameter IFM_WORD_SIZE     = 32/2;
parameter IFM_DATA_SIZE_32  = IFM_HEIGHT*IFM_WIDTH;		// Layer 00
parameter IFM_WORD_SIZE_32  = 32;
parameter Fx = 3, Fy = 3;
parameter Ni = 3, No = 16; 
parameter WGT_DATA_SIZE   = Fx*Fy*Ni*No;	// Layer 00
parameter WGT_WORD_SIZE   = 32;


parameter IFM_FILE_32 		 = "C:/yolohw/sim/inout_data_sw/log_feamap/CONV00_input_32b.hex"; 
parameter IFM_FILE   		 = "C:/yolohw/sim/inout_data_sw/log_feamap/CONV00_input_16b.hex"; 
parameter WGT_FILE   		 = "C:/yolohw/sim/inout_data_sw/log_param/CONV00_param_weight.hex"; 

// Output Files
parameter CONV_INPUT_IMG00   = "C:/yolohw/sim/inout_data_hw/CONV00_input_ch00.bmp"; 
parameter CONV_INPUT_IMG01   = "C:/yolohw/sim/inout_data_hw/CONV00_input_ch01.bmp"; 
parameter CONV_INPUT_IMG02   = "C:/yolohw/sim/inout_data_hw/CONV00_input_ch02.bmp"; 
parameter CONV_INPUT_IMG03   = "C:/yolohw/sim/inout_data_hw/CONV00_input_ch03.bmp"; 

parameter CONV_OUTPUT_IMG00  = "C:/yolohw/sim/inout_data_hw/CONV00_output_ch00.bmp"; 
parameter CONV_OUTPUT_IMG01  = "C:/yolohw/sim/inout_data_hw/CONV00_output_ch01.bmp"; 
parameter CONV_OUTPUT_IMG02  = "C:/yolohw/sim/inout_data_hw/CONV00_output_ch02.bmp"; 
parameter CONV_OUTPUT_IMG03  = "C:/yolohw/sim/inout_data_hw/CONV00_output_ch03.bmp"; 


// Uncomment to visualize the data from DMA write
//`define CHECK_DMA_WRITE 1

//}}}