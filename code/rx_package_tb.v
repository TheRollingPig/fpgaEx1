`timescale 1ns / 100ps

module rx_package_tb;
	
	reg clk_100m;
	reg reset_n;
	
	wire clk_en;
	
	reg  [7:0]  rx_data;
	reg  		sub_datavld;
	reg	 [71:0]  sub_data;
	wire [71:0]  pick_data;		
	wire        pick_datavld;	
	wire		FIFO_clear;		
	wire 		frame_datavld;
	wire [7:0]	frame_data;		
	wire [10:0]	frame_cnt;
	wire 		frame_interrupt;
	
	integer fd_in;
	integer fd_out;
	reg [7:0] char;

	clk_divider
	#(
	  .DIVISOR 		 (868),
	  .OVERSAMP_RATE (16)
	)
	u_clk_divider
	(
	  .clk_i	    (clk_100m),
	  .reset_n_i	(reset_n),
	  .clk_en_o     (clk_en),
	  .clk16_en_o	()
	);
	
	rx_package
	#(
	  .TOGGLE						(1'b0),	                    // for pingpong buffer
	  .FIFO_DEPTH 					(16),
	  .FIFO_BUFFER_DEP				(256),
	  .SOF_LENGTH					(6),
	  .SOF_PATTERN					(48'h244750474741),			// $GPGGA
	  .EOF_DETECTION				(1'b1),		        		// sof + eof mode
	  .EOF_LENGTH					(1),
	  .EOF_PATTERN					(8'h0A),					// /n
	  .FRAME_LENGTH_FIXED			(1'b0),						// sof + framecnt mode
	  .FRAME_CNT					(67),
	  .SUB							(1'b1),						// valid for substitute
	  .SUB_POS						(7),
	  .SUB_LENGTH					(9),
	  .PICK_POS						(17),
	  .PICK_LENGTH					(9)
	)
	u_rx_package
	(
	  .clk_i						(clk_100m),
	  .reset_n_i					(reset_n),
	  .enable_i						(1'b1),

	  .rx_datavld_i					(clk_en),
	  .rx_data_i					(rx_data),

	  .sub_datavld_i				(sub_datavld),
	  .sub_data_i					(sub_data),

	  .pick_data_o					(pick_data),
	  .pick_datavld_o				(pick_datavld),
	  .FIFO_clear_o					(FIFO_clear),

	  .frame_datavld_o				(frame_datavld),
	  .frame_data_o					(frame_data),
	  .frame_cnt_o					(frame_cnt),
	  .frame_interrupt_o			(frame_interrupt)
	);
	
	parameter CLK_FREQUENCY = 100_000_000;
	parameter HALF_PERIOD = 5;
	parameter FULL_PERIOD = 10;
	parameter BAUD_RATE = 115200;
	parameter BAUD_PERIOD = CLK_FREQUENCY * FULL_PERIOD / BAUD_RATE;
	parameter FRAME_BIT_NUM = 10;

	initial
	begin
		clk_100m = 1;
		forever #HALF_PERIOD clk_100m = ~clk_100m;
	end
	
	// reset_n
	initial
	begin
		reset_n = 1;
		#(FULL_PERIOD * 2)
		reset_n = 0;
		#(FULL_PERIOD * 1)
		reset_n = 1;
	end
	
	initial
	begin
		sub_data = 72'h2121212121212E2121;
		sub_datavld = 1'b0;
		#(BAUD_PERIOD * 50)
		sub_datavld = 1'b1;
		#(FULL_PERIOD * 1)
		sub_datavld = 1'b0;
	end
	
	initial
	begin
		fd_in = $fopen ( "test_data.TXT", "r" );
		fd_out = $fopen ( "result_data.txt", "a" );
	end
	
	always @ ( posedge clk_en )
	begin
		char = $fgetc( fd_in );
		rx_data = char;
	end
	
	always @ ( posedge frame_datavld )
	begin
		$fwrite( fd_out, "%c", frame_data );
	end
	
endmodule
