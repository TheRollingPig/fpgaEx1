module clk_divider
	#(
	  parameter DIVISOR = 6'd868,    // 115200
	  parameter OVERSAMP_RATE = 8'd16
	  //parameter BAUDRATE = 115200
	)
	(
	  input clk_i,
	  input reset_n_i,
	  output reg clk_en_o,
	  output reg clk16_en_o
	);
	
	localparam DIVISOR_16 = DIVISOR / OVERSAMP_RATE;
	
	reg [15:0] clk_dividor1 = 0;
	reg [15:0] clk_dividor2 = 0;
	
	// for clk_en_o
	always @ (posedge clk_i or negedge reset_n_i)
	begin
		if(!reset_n_i)
		begin
			clk_dividor1 <= 16'b0;
			clk_en_o <= 1'b0;
		end
		else
		begin
			if(clk_dividor1 != DIVISOR)
			begin
				clk_dividor1 <= clk_dividor1 + 1'b1;
				clk_en_o <= 1'b0;
			end
			else
			begin
				clk_dividor1 <= 6'b0;
				clk_en_o <= 1'b1; 
			end
		end
	end
	
	//for clk16_en_o
	always @ (posedge clk_i or negedge reset_n_i)
	begin
		if(!reset_n_i)
		begin
			clk_dividor2 <= 16'b0;
			clk16_en_o <= 1'b0;
		end
		else
		begin
			if(clk_dividor2 != DIVISOR_16)
			begin
				clk_dividor2 <= clk_dividor2 + 1'b1;
				clk16_en_o <= 1'b0;
			end
			else
			begin
				clk_dividor2 <= 6'b0;
				clk16_en_o <= 1'b1; 
			end
		end
	end
	
	/*
	localparam clk_fre   = 100_000_000;
	localparam acc_width = 16;
	localparam acc_inc   = 
	
	reg [acc_width:0] acc;
	
	always @ ( posedge clk_i )
	begin
		if(!reset_n_i)
		begin
			acc <= 16'b0;
			clk_en_o <= 1'b0;
		end
	end
	*/
	
endmodule