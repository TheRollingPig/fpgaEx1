`timescale 1ns / 100ps

module uart_rx_op_tb;
	
	reg clk_100m;
	wire clk16_en;
	
	// for rx
	reg reset_n;
	reg rx_data;
	reg [9:0] rx_data_1 = 10'b0101010101;
	reg [9:0] rx_data_2 = 10'b0111100001;
	reg [9:0] rx_data_3 = 10'b0100000111;
	wire [7:0] data_out;
	wire data_out_valid;
	wire int_parity_error;
	wire uart_rx_busy;
	
	integer i;

	clk_divider
	#(
	  .DIVISOR 		 (868),
	  .OVERSAMP_RATE (16)
	)
	u_clk_divider_2
	(
	  .clk_i	    (clk_100m),
	  .reset_n_i	(1'b1),
	  .clk_en_o     (),
	  .clk16_en_o	(clk16_en)
	);
	
	uart_rx_op
    //baud rate: 115200 start bit: 1 data bits: 8 parity bit: none stop bit: 1
	#(
	  .DATA_BIT_NUM   (8),		     // 5 6 7 8
	  .PARITY_TYPE    (3'b001),		 // none even odd
	  .STOP_BIT_NUM   (3'b001), 	 // 1 1.5 2
	  .OVERSAMP_RATE  (16)
	)
	u_uart_rx_op
	(
	  .clk_i				(clk_100m),
	  .reset_n_i			(reset_n),
	  .clk_sample_i			(clk16_en),
	  .uart_rx_i			(rx_data),
	  .int_clear_n_i		(1'b1),
	  .data_out_o       	(data_out),
	  .data_out_valid_o		(data_out_valid),
	  .int_parity_error_o	(int_parity_error),
	  .uart_rx_busy_o       (uart_rx_busy)
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
		rx_data = 1'b1;
		#(FULL_PERIOD * 10)
		
		for( i = 0; i < FRAME_BIT_NUM; i = i + 1 )
		begin
			rx_data = rx_data_1[9 - i];
			#BAUD_PERIOD;
		end
		
		#(BAUD_PERIOD * 20)
		for( i = 0; i < FRAME_BIT_NUM; i = i + 1 )
		begin
			rx_data = rx_data_2[9 - i];
			#BAUD_PERIOD;
		end
		
		#(BAUD_PERIOD * 20)
		for( i = 0; i < FRAME_BIT_NUM; i = i + 1 )
		begin
			rx_data = rx_data_3[9 - i];
			#BAUD_PERIOD;
		end
		
	end
	
endmodule