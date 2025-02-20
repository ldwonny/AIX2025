1. Code structure
+ Top level
    /src    Source code
    /sim    Testbench and data for simulation
    /arxiv  Screen-captured results
+ Simulation
    /sim/inout_data_sw/log_feamap       Feature maps from SW simulation (Hex format)
    /sim/inout_data_sw/log_param        Weight maps from SW simulation (Hex format)
    /sim/inout_data_hw                  Output for HW simulation
	/sim/sim_dram_model					A simple external memory model and a memory controller

2. Test bench
    //--------------------------------------------------------------------
    // conv_kern_tb.v
    //--------------------------------------------------------------------
    sim/conv_kern_tb.v
        IMPORTANT NOTE**: Assume the HW code are in C:/yolohw

    a. Code flow        
        Step 1: 
            + in_img: Load images from  /sim/inout_data_sw/log_feamap
            + filter: Load filters  from  /sim/inout_data_sw/log_param
        
        Step 2: 
                // Show the filter			
            #(100*CLK_PERIOD) 
                    @(posedge clk)
                    for (j=0; j < No; j=j+1) begin
                        $display("Filter och=%02d: \n",j);
                        for(i = 0; i < 3; i = i + 1) begin
                            $display("%d\t%d\t%d",
                                $signed(filter[(j*Fx*Fy*Ni) + (3*i  )][7:0]),
                                $signed(filter[(j*Fx*Fy*Ni) + (3*i+1)][7:0]),
                                $signed(filter[(j*Fx*Fy*Ni) + (3*i+2)][7:0]));
                        end
                        $display("\n");						
                    end
                    
            #(100*CLK_PERIOD) 
                    @(posedge clk)
                        preload = 1'b0;	
        
        Step 3: 		
            // Loop for convolutions: It outputs row, col, and ctrl_data_run                        
            #(100*CLK_PERIOD) 
                    for(row = 0; row < IFM_HEIGHT; row = row + 1)	begin 
                        @(posedge clk)
                            ctrl_data_run  = 0;
                        #(100*CLK_PERIOD) 			
                        for (col = 0; col < IFM_WIDTH; col = col + 1) begin 
                            @(posedge clk)
                                ctrl_data_run  = 1;
                        end 
                    end
                @(posedge clk)
                        ctrl_data_run = 1'b0;			
            #(100*CLK_PERIOD) 
                    @(posedge clk) $stop;	        

        Step 4: 
            // Generate din, win
            wire is_first_row = (row == 0) ? 1'b1: 1'b0;
            wire is_last_row  = (row == IFM_HEIGHT-1) ? 1'b1: 1'b0;
            wire is_first_col = (col == 0) ? 1'b1: 1'b0;
            wire is_last_col  = (col == IFM_WIDTH-1) ? 1'b1 : 1'b0;

            always@(*) begin
                vld_i = 0;
                din = 128'd0;
                win[0] = 0;
                win[1] = 0;
                win[2] = 0;
                win[3] = 0;
                if(ctrl_data_run) begin
                    vld_i = 1;
                    // Tiled IFM data
                    din[ 7: 0] = (is_first_row || is_first_col) ? 8'd0 : in_img[(row-1) * IFM_WIDTH + (col-1)];
                    din[15: 8] = (is_first_row                ) ? 8'd0 : in_img[(row-1) * IFM_WIDTH +  col   ];
                    din[23:16] = (is_first_row || is_last_col ) ? 8'd0 : in_img[(row-1) * IFM_WIDTH + (col+1)];
                    din[31:24] = (                is_first_col) ? 8'd0 : in_img[ row    * IFM_WIDTH + (col-1)];
                    din[39:32] =                                         in_img[ row    * IFM_WIDTH +  col   ];
                    din[47:40] = (                is_last_col ) ? 8'd0 : in_img[ row    * IFM_WIDTH + (col+1)];
                    din[55:48] = (is_last_row ||  is_first_col) ? 8'd0 : in_img[(row+1) * IFM_WIDTH + (col-1)];
                    din[63:56] = (is_last_row                 ) ? 8'd0 : in_img[(row+1) * IFM_WIDTH + col  ];
                    din[71:64] = (is_last_row ||  is_last_col ) ? 8'd0 : in_img[(row+1) * IFM_WIDTH + (col+1)];
                    // Tiled Filters
                    for(j = 0; j < 4; j=j+1) begin 	// Four sets <=> Four output channels
                        win[j][ 7: 0] = filter[(j*Fx*Fy*Ni)    ][7:0];
                        win[j][15: 8] = filter[(j*Fx*Fy*Ni) + 1][7:0];
                        win[j][23:16] = filter[(j*Fx*Fy*Ni) + 2][7:0];
                        win[j][31:24] = filter[(j*Fx*Fy*Ni) + 3][7:0];
                        win[j][39:32] = filter[(j*Fx*Fy*Ni) + 4][7:0];
                        win[j][47:40] = filter[(j*Fx*Fy*Ni) + 5][7:0];
                        win[j][55:48] = filter[(j*Fx*Fy*Ni) + 6][7:0];
                        win[j][63:56] = filter[(j*Fx*Fy*Ni) + 7][7:0];
                        win[j][71:64] = filter[(j*Fx*Fy*Ni) + 8][7:0];			
                    end 
                end    
            end 


    b. Simulation and Outputs: 
        run 1ms
        # Loading input feature maps from file: C:/yolohw/sim/inout_data_sw/log_feamap/CONV00_input_32b.hex
        # Loading input feature maps from file: C:/yolohw/sim/inout_data_sw/log_param/CONV00_param_weight.hex
        # Filter och= 0: 
        # 
        #   19	 -11	  -6
        #   61	 -17	 -42
        #   23	  -2	 -21
        # 
        # 
        # Filter och= 1: 
        # 
        #   12	 -15	 -17
        #    5	   5	 -18
        #    6	   2	 -17
        # 
        # 
        # Filter och= 2: 
        # 
        #    3	   6	  14
        #   -8	   1	  21
        #    5	 -22	   9
        # 
        # 
        # Filter och= 3: 
        # 
        #   24	  17	  12
        #   11	  23	  24
        #   -4	   9	  -1
        # 
        # 
        # Filter och= 4: 
        # 
        #  -10	  -2	   4
        #   -9	  -8	  -9
        #    8	   0	  10
        # 
        # 
        # Filter och= 5: 
        # 
        #   25	 -10	  22
        #   -7	 -32	   9
        #   -6	 -21	  -8
        # 
        # 
        # Filter och= 6: 
        # 
        #  -70	 -35	 -12
        #   47	  28	   0
        #   48	  16	   4
        # 
        # 
        # Filter och= 7: 
        # 
        #   -8	   2	  15
        #  -27	  -5	  32
        #  -27	  16	   9
        # 
        # 
        # Filter och= 8: 
        # 
        #  -21	 -26	 -25
        #  -60	 -95	 -32
        #  -38	 -79	 -28
        # 
        # 
        # Filter och= 9: 
        # 
        #   -8	   4	   8
        #   12	   5	   8
        #    4	  18	  13
        # 
        # 
        # Filter och=10: 
        # 
        #  -76	  21	 -45
        #  -37	 -18	  33
        #   29	  23	  50
        # 
        # 
        # Filter och=11: 
        # 
        #   53	  29	  30
        #   25	  -5	  -1
        #  -62	 -56	  -9
        # 
        # 
        # Filter och=12: 
        # 
        #    6	  53	  26
        #   23	  70	  46
        #   -9	  31	  11
        # 
        # 
        # Filter och=13: 
        # 
        #   20	  45	 -11
        #   -7	 -32	 -25
        #    4	 -28	 -17
        # 
        # 
        # Filter och=14: 
        # 
        #    7	 -65	  10
        #  -10	   5	   3
        #    1	 -22	   2
        # 
        # 
        # Filter och=15: 
        # 
        #   -8	  -9	 -18
        #    0	   2	  -2
        #    6	  13	   0
        # 
        # 
        # Saving output images to file: C:/yolohw/sim/inout_data_hw/CONV00_input_ch03.bmp
        # Saving output images to file: C:/yolohw/sim/inout_data_hw/CONV00_input_ch02.bmp
        # Saving output images to file: C:/yolohw/sim/inout_data_hw/CONV00_input_ch01.bmp
        # Saving output images to file: C:/yolohw/sim/inout_data_hw/CONV00_input_ch00.bmp
        # Saving output images to file: C:/yolohw/sim/inout_data_hw/CONV00_output_ch03.bmp
        # Saving output images to file: C:/yolohw/sim/inout_data_hw/CONV00_output_ch02.bmp
        # Saving output images to file: C:/yolohw/sim/inout_data_hw/CONV00_output_ch01.bmp
        # Saving output images to file: C:/yolohw/sim/inout_data_hw/CONV00_output_ch00.bmp
        # ** Note: $stop    : C:/yolohw/sim/conv_kern_tb.v(101)
        #    Time: 916400 ns  Iteration: 1  Instance: /conv_kern_tb
        # Break in Module conv_kern_tb at C:/yolohw/sim/conv_kern_tb.v line 101

    //--------------------------------------------------------------------
    // cnn_ctrl_tb.v
    //--------------------------------------------------------------------
    a. Code flow
        Test cnn_ctrl
        //-------------------------------------------------
        // Controller (FSM)
        //-------------------------------------------------
        cnn_ctrl u_cnn_ctrl (
        .clk			(clk			),
        .rstn			(rstn			),
        // Inputs
        .q_width		(q_width		),
        .q_height		(q_height		),
        .q_vsync_delay	(q_vsync_delay	),
        .q_hsync_delay	(q_hsync_delay	),
        .q_frame_size	(q_frame_size	),
        .q_start		(q_start		),
        //output
        .o_ctrl_vsync_run(ctrl_vsync_run),
        .o_ctrl_vsync_cnt(ctrl_vsync_cnt),
        .o_ctrl_hsync_run(ctrl_hsync_run),
        .o_ctrl_hsync_cnt(ctrl_hsync_cnt),
        .o_ctrl_data_run(ctrl_data_run	),
        .o_row			(row			),
        .o_col			(col			),
        .o_data_count	(data_count		),
        .o_end_frame	(end_frame		)
        );    
    
    b. Simulation and outputs
        Generate (row, col, data_count) from given q_width, q_height, and delays (q_vsync_delay, q_hsync_delay)
		
    //--------------------------------------------------------------------
    // cnn_ctrl_multi_layer_tb.v
    //--------------------------------------------------------------------
    a. Code flow
        Test cnn_ctrl for multiple layers 
        //-------------------------------------------------
        // Controller (FSM)
        //-------------------------------------------------
        cnn_ctrl u_cnn_ctrl (
        .clk			(clk			),
        .rstn			(rstn			),
        // Inputs
        .q_width		(q_width		),
        .q_height		(q_height		),
        .q_vsync_delay	(q_vsync_delay	),
        .q_hsync_delay	(q_hsync_delay	),
        .q_frame_size	(q_frame_size	),
        .q_start		(q_start		),
        //output
        .o_ctrl_vsync_run(ctrl_vsync_run),
        .o_ctrl_vsync_cnt(ctrl_vsync_cnt),
        .o_ctrl_hsync_run(ctrl_hsync_run),
        .o_ctrl_hsync_cnt(ctrl_hsync_cnt),
        .o_ctrl_data_run(ctrl_data_run	),
        .o_row			(row			),
        .o_col			(col			),
        .o_data_count	(data_count		),
        .o_end_frame	(end_frame		)
        );    
    
    //------------------------------------------------------------------   
	// Layer 1: width = height = 256
	//------------------------------------------------------------------
	q_width  = 256;
	q_height = 256;
	q_frame_size = 256*256;
	#(100*CLK_PERIOD) 
        @(posedge clk)
            q_start = 1'b1;
	#(4*CLK_PERIOD) 
        @(posedge clk)
            q_start = 1'b0;
    while(!layer_done) begin
        #(128*CLK_PERIOD) @(posedge clk);
    end
    $display("CONV_00: Done !!!");
        
    //------------------------------------------------------------------   
	// Layer 2: width = height = 128
	//------------------------------------------------------------------
	q_width  = 128;
	q_height = 128;
	q_frame_size = 128*128;
	#(100*CLK_PERIOD) 
        @(posedge clk)
            q_start = 1'b1;
	#(4*CLK_PERIOD) 
        @(posedge clk)
            q_start = 1'b0;
    while(!layer_done) begin
        #(128*CLK_PERIOD) @(posedge clk);
    end
    $display("CONV_02: Done !!!");     			
    
    //------------------------------------------------------------------   
	// Layer 3: width = height = 64
	//------------------------------------------------------------------
	q_width  = 64;
	q_height = 64;
	q_frame_size = 64*64;
	#(100*CLK_PERIOD) 
        @(posedge clk)
            q_start = 1'b1;
	#(4*CLK_PERIOD) 
        @(posedge clk)
            q_start = 1'b0;
    while(!layer_done) begin
        #(128*CLK_PERIOD) @(posedge clk);
    end
    $display("CONV_04: Done !!!");      
	
    b. Simulation and outputs
        Generate (row, col, data_count) from given q_width, q_height, and delays (q_vsync_delay, q_hsync_delay)		
		
		
    //--------------------------------------------------------------------
    // conv_layer_tb.v
    //--------------------------------------------------------------------
    a. Code flow     
        Step 1: 
            + in_img: Load images from  /sim/inout_data_sw/log_feamap
            + filter: Load filters  from  /sim/inout_data_sw/log_param
        
        Step 2: 
                // Show the filter			
            #(100*CLK_PERIOD) 
                    @(posedge clk)
                    for (j=0; j < No; j=j+1) begin
                        $display("Filter och=%02d: \n",j);
                        for(i = 0; i < 3; i = i + 1) begin
                            $display("%d\t%d\t%d",
                                $signed(filter[(j*Fx*Fy*Ni) + (3*i  )][7:0]),
                                $signed(filter[(j*Fx*Fy*Ni) + (3*i+1)][7:0]),
                                $signed(filter[(j*Fx*Fy*Ni) + (3*i+2)][7:0]));
                        end
                        $display("\n");						
                    end
                    
            #(100*CLK_PERIOD) 
                    @(posedge clk)
                        preload = 1'b0;	
        
        Step 3: 		
            // Loop for convolutions: It outputs row, col, chn and ctrl_data_run                        
			#(100*CLK_PERIOD) 
				for(row = 0; row < IFM_HEIGHT; row = row + 1)	begin 
					@(posedge clk)
						ctrl_data_run  = 0;
					#(100*CLK_PERIOD) @(posedge clk);
						ctrl_data_run  = 1;	
					for (col = 0; col < IFM_WIDTH; col = col + 1) begin 				
						for (chn = 0; chn < IFM_CHANNEL; chn = chn + 1) begin 				
							@(posedge clk) begin 
								if((col == IFM_WIDTH-1) && (chn == IFM_CHANNEL-1))
									ctrl_data_run = 0;
							end 
						end
					end 
				end
			@(posedge clk)
					ctrl_data_run = 1'b0;	        

        Step 4: 
			// Generate din, win
			wire is_first_row = (row == 0) ? 1'b1: 1'b0;
			wire is_last_row  = (row == IFM_HEIGHT-1) ? 1'b1: 1'b0;
			wire is_first_col = (col == 0) ? 1'b1: 1'b0;
			wire is_last_col  = (col == IFM_WIDTH-1) ? 1'b1 : 1'b0;

			always@(*) begin
				vld_i = 0;
				din = 128'd0;
				win[0] = 0;
				win[1] = 0;
				win[2] = 0;
				win[3] = 0;
				if(ctrl_data_run) begin
					vld_i = 1;
					// Tiled IFM data
					din[ 7: 0] = (is_first_row || is_first_col) ? 8'd0 : in_img[(row-1) * IFM_WIDTH + (col-1)][chn*8+:8];
					din[15: 8] = (is_first_row                ) ? 8'd0 : in_img[(row-1) * IFM_WIDTH +  col   ][chn*8+:8];
					din[23:16] = (is_first_row || is_last_col ) ? 8'd0 : in_img[(row-1) * IFM_WIDTH + (col+1)][chn*8+:8];
					
					din[31:24] = (                is_first_col) ? 8'd0 : in_img[ row    * IFM_WIDTH + (col-1)][chn*8+:8];
					din[39:32] =                                         in_img[ row    * IFM_WIDTH +  col   ][chn*8+:8];
					din[47:40] = (                is_last_col ) ? 8'd0 : in_img[ row    * IFM_WIDTH + (col+1)][chn*8+:8];
					
					din[55:48] = (is_last_row ||  is_first_col) ? 8'd0 : in_img[(row+1) * IFM_WIDTH + (col-1)][chn*8+:8];
					din[63:56] = (is_last_row                 ) ? 8'd0 : in_img[(row+1) * IFM_WIDTH +  col   ][chn*8+:8];
					din[71:64] = (is_last_row ||  is_last_col ) ? 8'd0 : in_img[(row+1) * IFM_WIDTH + (col+1)][chn*8+:8];
					// Tiled Filters
					for(j = 0; j < 4; j=j+1) begin 	// Four sets <=> Four output channels
						win[j][ 7: 0] = filter[(j*Fx*Fy*Ni) + chn*9    ][7:0];
						win[j][15: 8] = filter[(j*Fx*Fy*Ni) + chn*9 + 1][7:0];
						win[j][23:16] = filter[(j*Fx*Fy*Ni) + chn*9 + 2][7:0];			
						win[j][31:24] = filter[(j*Fx*Fy*Ni) + chn*9 + 3][7:0];
						win[j][39:32] = filter[(j*Fx*Fy*Ni) + chn*9 + 4][7:0];
						win[j][47:40] = filter[(j*Fx*Fy*Ni) + chn*9 + 5][7:0];			
						win[j][55:48] = filter[(j*Fx*Fy*Ni) + chn*9 + 6][7:0];
						win[j][63:56] = filter[(j*Fx*Fy*Ni) + chn*9 + 7][7:0];
						win[j][71:64] = filter[(j*Fx*Fy*Ni) + chn*9 + 8][7:0];			
					end 
				end    
			end 
			
		Step 5: Accumulator
			// In this case, we assume that each cycle convolves a filter 3x3 with a fmap window 3x3
			// In Layer 00, we must convolve a filter 3x3x3 with a fmap window 3x3x3. 
			// Therefore, we may compute three times across the channel direction. 
			// The output results from MACs are accumlated at the partial sum (psum)
			
			reg [15:0] chn_idx;
			reg [31:0] psum[0:3];
			wire valid_out = vld_o[0];

			always@(posedge clk, negedge rstn) begin 
				if(!rstn) begin 
					chn_idx <= 0;		
				end 
				else begin
					if(valid_out) begin 
						if(chn_idx == IFM_CHANNEL-1) 
							chn_idx <= 0;
						else 
							chn_idx <= chn_idx + 1;			
					end  
				end 
			end 
			reg write_pixel_ena;
			always@(posedge clk, negedge rstn) begin 
				if(!rstn) begin 
					psum[0] <= 0;		
					psum[1] <= 0;		
					psum[2] <= 0;		
					psum[3] <= 0;
					write_pixel_ena <= 0;		
				end 
				else begin
					if(valid_out) begin 
						if(chn_idx == 0) begin 
							psum[0] <= $signed(acc_o[0]);
							psum[1] <= $signed(acc_o[1]);
							psum[2] <= $signed(acc_o[2]);
							psum[3] <= $signed(acc_o[3]);
						end 
						else begin 
							psum[0] <= $signed(psum[0]) + $signed(acc_o[0]);
							psum[1] <= $signed(psum[1]) + $signed(acc_o[1]);
							psum[2] <= $signed(psum[2]) + $signed(acc_o[2]);
							psum[3] <= $signed(psum[3]) + $signed(acc_o[3]);
						end 

						if(chn_idx == IFM_CHANNEL-1)
							write_pixel_ena <= 1;
						else 
							write_pixel_ena <= 0; 
					end  
					else
						write_pixel_ena <= 0; 
				end 
			end		
		
		Step 6: Activation/Descaling
			+ Use RELU activation 
			wire [31:0]  psum_act0 = write_pixel_ena ? ((psum[0][31]==1)?0:psum[0]): 0;
			wire [31:0]  psum_act1 = write_pixel_ena ? ((psum[1][31]==1)?0:psum[1]): 0;
			wire [31:0]  psum_act2 = write_pixel_ena ? ((psum[2][31]==1)?0:psum[2]): 0;
			wire [31:0]  psum_act3 = write_pixel_ena ? ((psum[3][31]==1)?0:psum[3]): 0;
			
			+ Do dequantization or descaling to generate eight-bit output pixels. 			
			wire [7:0] conv_out_ch00 = write_pixel_ena?((psum_act0[31:7]>255)?255:psum_act0[14:7]):0; // Descaling: * 1/2^11	
			wire [7:0] conv_out_ch01 = write_pixel_ena?((psum_act1[31:7]>255)?255:psum_act1[14:7]):0; // Descaling: * 1/2^11	
			wire [7:0] conv_out_ch02 = write_pixel_ena?((psum_act2[31:7]>255)?255:psum_act2[14:7]):0; // Descaling: * 1/2^11	
			wire [7:0] conv_out_ch03 = write_pixel_ena?((psum_act3[31:7]>255)?255:psum_act3[14:7]):0; // Descaling: * 1/2^11

		Step 7: Write the results in an image file for debugging and visualization 		
			bmp_image_writer #(.OUTFILE(CONV_OUTPUT_IMG00),.WIDTH(IFM_WIDTH),.HEIGHT(IFM_HEIGHT))
			u_acc_img_ch0(
				./*input 			*/clk		(clk		  	),
				./*input 			*/rstn		(rstn		  	),
				./*input [WI-1:0] 	*/din		(conv_out_ch00	),
				./*input 			*/vld		(write_pixel_ena),
				./*output reg 		*/frame_done(		      	)
			);		
		
		IMPORTANT NOTES: YOU SHOULD WRITE TO HEX FILES WHICH CAN BE COMPARED WITH REFERENCE SOFTWARES
    
	b. Simulation and outputs
		# (vsim-4077) Logging very large object: /conv_layer_tb/in_img
		run 3ms
		# Loading input feature maps from file: C:/yolohw/sim/inout_data_sw/log_feamap/CONV00_input_32b.hex
		# Loading input feature maps from file: C:/yolohw/sim/inout_data_sw/log_param/CONV00_param_weight.hex
		# Filter och= 0: 
		# 
		#   19	 -11	  -6
		#   61	 -17	 -42
		#   23	  -2	 -21
		# 
		# 
		# Filter och= 1: 
		# 
		#   12	 -15	 -17
		#    5	   5	 -18
		#    6	   2	 -17
		# 
		# 
		# Filter och= 2: 
		# 
		#    3	   6	  14
		#   -8	   1	  21
		#    5	 -22	   9
		# 
		# 
		# Filter och= 3: 
		# 
		#   24	  17	  12
		#   11	  23	  24
		#   -4	   9	  -1
		# 
		# 
		# Filter och= 4: 
		# 
		#  -10	  -2	   4
		#   -9	  -8	  -9
		#    8	   0	  10
		# 
		# 
		# Filter och= 5: 
		# 
		#   25	 -10	  22
		#   -7	 -32	   9
		#   -6	 -21	  -8
		# 
		# 
		# Filter och= 6: 
		# 
		#  -70	 -35	 -12
		#   47	  28	   0
		#   48	  16	   4
		# 
		# 
		# Filter och= 7: 
		# 
		#   -8	   2	  15
		#  -27	  -5	  32
		#  -27	  16	   9
		# 
		# 
		# Filter och= 8: 
		# 
		#  -21	 -26	 -25
		#  -60	 -95	 -32
		#  -38	 -79	 -28
		# 
		# 
		# Filter och= 9: 
		# 
		#   -8	   4	   8
		#   12	   5	   8
		#    4	  18	  13
		# 
		# 
		# Filter och=10: 
		# 
		#  -76	  21	 -45
		#  -37	 -18	  33
		#   29	  23	  50
		# 
		# 
		# Filter och=11: 
		# 
		#   53	  29	  30
		#   25	  -5	  -1
		#  -62	 -56	  -9
		# 
		# 
		# Filter och=12: 
		# 
		#    6	  53	  26
		#   23	  70	  46
		#   -9	  31	  11
		# 
		# 
		# Filter och=13: 
		# 
		#   20	  45	 -11
		#   -7	 -32	 -25
		#    4	 -28	 -17
		# 
		# 
		# Filter och=14: 
		# 
		#    7	 -65	  10
		#  -10	   5	   3
		#    1	 -22	   2
		# 
		# 
		# Filter och=15: 
		# 
		#   -8	  -9	 -18
		#    0	   2	  -2
		#    6	  13	   0
		# 
		# 
		# Saving output images to file: C:/yolohw/sim/inout_data_hw/CONV00_input_ch03.bmp
		# Saving output images to file: C:/yolohw/sim/inout_data_hw/CONV00_input_ch02.bmp
		# Saving output images to file: C:/yolohw/sim/inout_data_hw/CONV00_input_ch01.bmp
		# Saving output images to file: C:/yolohw/sim/inout_data_hw/CONV00_input_ch00.bmp
		# Saving output images to file: C:/yolohw/sim/inout_data_hw/CONV00_output_ch03.bmp
		# Saving output images to file: C:/yolohw/sim/inout_data_hw/CONV00_output_ch02.bmp
		# Saving output images to file: C:/yolohw/sim/inout_data_hw/CONV00_output_ch01.bmp
		# Saving output images to file: C:/yolohw/sim/inout_data_hw/CONV00_output_ch00.bmp
		# Layer done !!!
		# ** Note: $stop    : C:/yolohw/sim/conv_layer_tb.v(108)
		#    Time: 2229680 ns  Iteration: 0  Instance: /conv_layer_tb
		# Break in Module conv_layer_tb at C:/yolohw/sim/conv_layer_tb.v line 108			
		
    //--------------------------------------------------------------------
    // yolo_engine_tb.v
    //--------------------------------------------------------------------		
	a. Code flow
		
		Step 1: An external memory model (Behave like DRAM)
		
		// AXI Slave External Memory: Input
		axi_sram_if #(  //New
		   .MEM_ADDRW(MEM_ADDRW), .MEM_DW(MEM_DW),
		   .A(A), .I(I), .L(L), .D(D), .M(M))
		u_axi_ext_mem_if_input(
		   .ACLK(clk), .ARESETn(rstn),
			
		   //AXI Slave IF
		   .AWID	(M_AWID		),       // Address ID
		   .AWADDR	(M_AWADDR	),     // Address Write
		   .AWLEN	(M_AWLEN	   ),      // Transfer length
		   .AWSIZE	(M_AWSIZE	),     // Transfer width
		   .AWBURST	(M_AWBURST	),    // Burst type
		   .AWLOCK	(M_AWLOCK	),     // Atomic access information
		   .AWCACHE	(M_AWCACHE	),    // Cachable/bufferable infor
		   .AWPROT	(M_AWPROT	),     // Protection info
		   .AWVALID	(M_AWVALID	),    // address/control valid handshake
		   .AWREADY	(M_AWREADY	),
		   //Write data channel
		   .WID		(M_WID		),        // Write ID
		   .WDATA	(M_WDATA	   ),      // Write Data bus
		   .WSTRB	(M_WSTRB	   ),      // Write Data byte lane strobes
		   .WLAST	(M_WLAST	   ),      // Last beat of a burst transfer
		   .WVALID	(M_WVALID	),     // Write data valid
		   .WREADY	(M_WREADY	),     // Write data ready
			//Write response channel
		   .BID		(M_BID		),        // buffered response ID
		   .BRESP	(M_BRESP	   ),      // Buffered write response
		   .BVALID	(M_BVALID	),     // Response info valid
		   .BREADY	(M_BREADY	),     // Response info ready (from Master)
			  
		   .ARID    (M_ARID		),   // Read addr ID
		   .ARADDR  (M_ARADDR	),   // Address Read 
		   .ARLEN   (M_ARLEN	   ),   // Transfer length
		   .ARSIZE  (M_ARSIZE	),   // Transfer width
		   .ARBURST (M_ARBURST	),   // Burst type
		   .ARLOCK  (M_ARLOCK	),   // Atomic access information
		   .ARCACHE (M_ARCACHE	),   // Cachable/bufferable infor
		   .ARPROT  (M_ARPROT	),   // Protection info
		   .ARVALID (M_ARVALID	),   // address/control valid handshake
		   .ARREADY (M_ARREADY	),
		   .RID     (M_RID		),   // Read ID
		   .RDATA   (M_RDATA	   ),   // Read data bus
		   .RRESP   (M_RRESP	   ),   // Read response
		   .RLAST   (M_RLAST	   ),   // Last beat of a burst transfer
		   .RVALID  (M_RVALID	),   // Read data valid 
		   .RREADY  (M_RREADY	),   // Read data ready (to Slave)

		   //Interface to SRAM 
		   .mem_addr(mem_addr	),
		   .mem_we  (mem_we		),
		   .mem_di  (mem_di		),
		   .mem_do  (mem_do		)
		);


		// Input
		// IMEM for SIM
		// Inputs
		sram #(
		   .FILE_NAME(IFM_FILE),
		   .SIZE(2**MEM_ADDRW),
		   .WL_ADDR(MEM_ADDRW),
		   .WL_DATA(MEM_DW))
		u_ext_mem_input (
		   .clk   (clk		   ),
		   .rst   (rstn		),
		   .addr  (mem_addr	),
		   .wdata (mem_di	   ),
		   .rdata (mem_do	   ),
		   .ena   (1'b0		)     // Read only
		   );		
		   
		Step 2: CNN Accelerator
			
		reg [31:0] i_0;
		reg [31:0] i_1;
		reg [31:0] i_2;
			
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
			   
			.i_ctrl_reg0(i_0     ), // network_start // {debug_big(1), debug_buf_select(16), debug_buf_addr(9)}
			.i_ctrl_reg1(i_1     ), // Read_address (INPUT)
			.i_ctrl_reg2(i_2     ), // Write_address
			.i_ctrl_reg3(32'd0   ), // Reserved

			.M_ARVALID	(M_ARVALID),
			.M_ARREADY	(M_ARREADY),
			.M_ARADDR	(M_ARADDR ),
			.M_ARID		(M_ARID	 ),
			.M_ARLEN	(M_ARLEN	 ),
			.M_ARSIZE	(M_ARSIZE ),
			.M_ARBURST	(M_ARBURST),
			.M_ARLOCK	(M_ARLOCK ),
			.M_ARCACHE	(M_ARCACHE),
			.M_ARPROT	(M_ARPROT ),
			.M_ARQOS	(			 ),
			.M_ARREGION(			 ),
			.M_ARUSER	(			 ),
			.M_RVALID	(M_RVALID ),
			.M_RREADY	(M_RREADY ),
			.M_RDATA	(M_RDATA	 ),
			.M_RLAST	(M_RLAST	 ),
			.M_RID		(M_RID	 ),
			.M_RUSER	(			 ),
			.M_RRESP	(M_RRESP	 ),
			
			.M_AWVALID	(M_AWVALID),
			.M_AWREADY	(M_AWREADY),
			.M_AWADDR	(M_AWADDR ),
			.M_AWID		(M_AWID	 ),
			.M_AWLEN	(M_AWLEN	 ),
			.M_AWSIZE	(M_AWSIZE ),
			.M_AWBURST	(M_AWBURST),
			.M_AWLOCK	(M_AWLOCK ),
			.M_AWCACHE	(M_AWCACHE),
			.M_AWPROT	(M_AWPROT ),
			.M_AWQOS	(			 ),
			.M_AWREGION(			 ),
			.M_AWUSER	(			 ),
			
			.M_WVALID	(M_WVALID ),
			.M_WREADY	(M_WREADY ),
			.M_WDATA	(M_WDATA	 ),
			.M_WSTRB	(M_WSTRB	 ),
			.M_WLAST	(M_WLAST	 ),
			.M_WID		(M_WID	 ),
			.M_WUSER	(			 ),
			
			.M_BVALID	(M_BVALID ),
			.M_BREADY	(M_BREADY ),
			.M_BRESP	(M_BRESP	 ),
			.M_BID		(M_BID	 ),
			.M_BUSER	(			 ),
			
			.network_done(network_done),
			.network_done_led(network_done_led)
		);		
		
		// Flow yolo_engine for details
			1. u_dma_ctrl: 
			Inputs 
				+ DRAM base addresses for Read/Write (dram_base_addr_rd, dram_base_addr_wr)
				+ Number of transactions for a request (num_trans). WE FIXED IT TO 16 HERE. 
				+ Maximum requests (max_req_blk_idx). For example, it is (256*256)/16 when we want to read an image
			Outputs: 
				+ Send trigger signals for read/write (ctrl_read/ctrl_write) to u_dma_read (axi_dma_rd) and u_dma_write (axi_dma_wr)
				
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
				
			2. u_dma_read
				Flow is: 
					1. Receive a READ request signal from u_dma_ctrl (ctrl_read, num_trans, read_addr)
					2. Send the read request to external memory via an axi interface
					3. Receive the return data via an axi interface
					4. Send the return data to a buffer 
						read_data		32-bit data 
						read_data_vld	1-bit valid for data
						read_data_cnt	data index in a burst request <= we request 16 x 32-bit (num_trans = 16)
						read_done		Mark the last data (e.g., 16th data)
		
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
				
			3. u_data_buffer: A buffer saves the data coming from u_dma_read
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
				
				
			4. u_dma_write
				Flow is: 
					1. Receive a WRITE request signal from u_dma_ctrl (ctrl_write, num_trans, write_addr)
					2. Send the write request to external memory via an axi interface
					3. Send the  data via an axi interface
					4. Send the return data to a buffer 
						write_data		32-bit data 
						indata_req_wr	1-bit request enable to u_data_buffer						
						write_done		Mark the last data (e.g., 16th data)			
				
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
				
	b. Simulation and outputs
		run 4ms
		# Initializing memory 'SimmemSync_rp0_wp0_cp1'..
		# Loading memory 'SimmemSync_rp0_wp0_cp1' from file: C:/yolohw/sim/inout_data_sw/log_feamap/CONV00_input_16b.hex
		# Saving output images to file: C:/yolohw/sim/inout_data_hw/CONV00_input_ch03.bmp
		# Saving output images to file: C:/yolohw/sim/inout_data_hw/CONV00_input_ch02.bmp
		# Saving output images to file: C:/yolohw/sim/inout_data_hw/CONV00_input_ch01.bmp
		# Saving output images to file: C:/yolohw/sim/inout_data_hw/CONV00_input_ch00.bmp
		# ** Note: $stop    : C:/yolohw/sim/yolo_engine_tb.v(251)
		#    Time: 3238880 ns  Iteration: 1  Instance: /yolo_engine_tb
		# Break in Module yolo_engine_tb at C:/yolohw/sim/yolo_engine_tb.v line 251				