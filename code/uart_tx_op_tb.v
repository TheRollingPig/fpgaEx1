`timescale 1ns / 100ps

module uart_tx_op_tb;

	reg clk_100m;
	wire clk_en;
	
	// for tx
	reg reset_n;
	reg shoot;
	reg [7:0] tx_data;
	reg [7:0] tx_data1 = 8'b10101010;
	reg [7:0] tx_data2 = 8'b11110000;
	reg [7:0] tx_data3 = 8'b10000011;
	wire uart_tx_o;
	wire uart_busy_o;

	clk_divider
	#(
	  .DIVISOR 		 (868),
	  .OVERSAMP_RATE (16)
	)
	u_clk_divider_1
	(
	  .clk_i	    (clk_100m),
	  .reset_n_i	(1'b1),
	  .clk_en_o     (clk_en),
	  .clk16_en_o	()
	);
	
	uart_tx_op
    //baud rate: 115200 start bit: 1 data bits: 8 parity bit: none stop bit: 1
	#(
	  .DATA_BIT_NUM   (8),		     // 5 6 7 8
	  .PARITY_TYPE    (3'b001),		 // none even odd
	  .STOP_BIT_NUM   (3'b001) 		 // 1 1.5 2
	)
	u_uart_tx_op
	(
	  .clk_i			(clk_100m),
	  .reset_n_i		(reset_n),
	  .clk_en_i			(clk_en),
	  .data_in_i		(tx_data),
	  .shoot_i			(shoot),
	  .uart_tx_o 		(uart_tx_o),
	  .uart_busy_o		(uart_busy_o)
	);

	parameter CLK_FREQUENCY = 100_000_000;
	parameter HALF_PERIOD = 5;
	parameter FULL_PERIOD = 10;
	parameter BAUD_RATE = 115200;
	parameter BAUD_PERIOD = CLK_FREQUENCY * FULL_PERIOD / BAUD_RATE;

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
		tx_data = 8'b0;
		shoot = 1'b0;
		
		#(FULL_PERIOD * 10)
		tx_data = tx_data1;
		shoot = 1'b1;
		#(FULL_PERIOD * 2)
		shoot = 1'b0;
		
		#(BAUD_PERIOD * 20)
		tx_data = tx_data2;
		shoot = 1'b1;
		#(FULL_PERIOD * 2)
		shoot = 1'b0;
		
		#(BAUD_PERIOD * 20)
		tx_data = tx_data3;
		shoot = 1'b1;
		#(FULL_PERIOD * 2)
		shoot = 1'b0;
	end
	
endmodule