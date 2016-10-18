`define HIGH 1'b1
`define LOW  1'b0

module uart_tx_op
//baud rate: 115200 start bit: 1 data bits: 8 parity bit: none stop bit: 1
	#(
	  parameter DATA_BIT_NUM = 4'd8,		// 5 6 7 8
	  parameter PARITY_TYPE = 3'b1,			// none even odd
	  parameter STOP_BIT_NUM = 3'b1 		// 1 1.5 2
	  //parameter BAUD_RATE = 115200
	)
	(
	  input		  clk_i,
	  input		  reset_n_i,
	  input	      clk_en_i,
	  input [7:0] data_in_i,
	  input		  shoot_i,
	  output reg  uart_tx_o,
	  output reg  uart_busy_o
	);
	
	//localparam one hot??
	localparam PARITY_NONE = 3'b001;
	localparam PARITY_EVEN = 3'b010;
	localparam PARITY_ODD  = 3'b100;
	
	localparam DATA_NUM_5  = 4'b0001;
	localparam DATA_NUM_6  = 4'b0010;
	localparam DATA_NUM_7  = 4'b0100;
	localparam DATA_NUM_8  = 4'b1000;
	
	localparam STOP_NUM_1  = 3'b001;
	localparam STOP_NUM_15 = 3'b010;
	localparam STOP_NUM_2  = 3'b100;
	
	
	//state localparam for FSM
	localparam SM_IDEL        = 13'd1;
	localparam SM_SEND_START  = 13'd2;
	localparam SM_SEND_DATA0  = 13'd4;
	localparam SM_SEND_DATA1  = 13'd8;
	localparam SM_SEND_DATA2  = 13'd16;
	localparam SM_SEND_DATA3  = 13'd32;
	localparam SM_SEND_DATA4  = 13'd64;
	localparam SM_SEND_DATA5  = 13'd128;
	localparam SM_SEND_DATA6  = 13'd256;
	localparam SM_SEND_DATA7  = 13'd512;
	localparam SM_SEND_PARITY = 13'd1024;
	localparam SM_SEND_STOP0  = 13'd2048;
	localparam SM_SEND_STOP1  = 13'd4096;
	
	// for FSM
	reg [12:0] state;
	reg [12:0] state_next;
	reg [7:0]  data_in_lch;
	reg start_cnt;
	
	always @ (posedge clk_i or negedge reset_n_i)
	begin
		if(!reset_n_i)
		begin
			state <= SM_IDEL;	// complete here
		end
		else
			state <= state_next;
	end
	
	//for data_in_lch
	always @ ( posedge clk_i or negedge reset_n_i )
	begin
		if( !reset_n_i )
		begin
			data_in_lch <= 0;
			start_cnt <= 0;
		end
		else
		begin
			if( state == SM_IDEL && shoot_i )
			begin
				data_in_lch <= data_in_i;
				start_cnt <= `HIGH;
			end
			
			if( state == SM_SEND_DATA0 )
			begin
				start_cnt <= `LOW;
			end
		end
	end
	
	always @ (*)
	begin
		state_next = state;
		case (state)
		  SM_IDEL:
			begin
				if( clk_en_i && start_cnt )
				begin
					state_next = SM_SEND_START;
				end
			end
		  SM_SEND_START:
			if(clk_en_i)
				state_next = SM_SEND_DATA0;			
		  SM_SEND_DATA0:
		    if(clk_en_i)
				state_next = SM_SEND_DATA1;
		  SM_SEND_DATA1:
		    if(clk_en_i)
				state_next = SM_SEND_DATA2;
		  SM_SEND_DATA2:
		    if(clk_en_i)
				state_next = SM_SEND_DATA3;
		  SM_SEND_DATA3:
		    if(clk_en_i)
				state_next = SM_SEND_DATA4;
		  SM_SEND_DATA4:
		    if(clk_en_i)
			begin
				if(DATA_BIT_NUM == DATA_NUM_5)
				begin
					if(PARITY_TYPE != PARITY_NONE)
						state_next = SM_SEND_PARITY;
					else
						state_next = SM_SEND_STOP0;
				end
				else
					state_next = SM_SEND_DATA5;
			end
		  SM_SEND_DATA5:
		    if(clk_en_i)
			begin
				if(DATA_BIT_NUM == DATA_NUM_6)
				begin
					if(PARITY_TYPE != PARITY_NONE)
						state_next = SM_SEND_PARITY;
					else
						state_next = SM_SEND_STOP0;
				end
				else
					state_next = SM_SEND_DATA6;
			end
		  SM_SEND_DATA6:
		    if(clk_en_i)
			begin
				if(DATA_BIT_NUM == DATA_NUM_7)
				begin
					if(PARITY_TYPE != PARITY_NONE)
						state_next = SM_SEND_PARITY;
					else
						state_next = SM_SEND_STOP0;
				end
				else
					state_next = SM_SEND_DATA7;
			end
		
 		  SM_SEND_DATA7:
			if(clk_en_i)
			begin
				if(PARITY_TYPE != PARITY_NONE)
					state_next = SM_SEND_PARITY;
				else
					state_next = SM_SEND_STOP0;
			end
		  SM_SEND_PARITY:
		    if(clk_en_i)
				state_next = SM_SEND_STOP0;
		  SM_SEND_STOP0:
			// not consider the 1.5 stop bit
			if(clk_en_i)
			begin
				if(STOP_BIT_NUM == STOP_NUM_1)
					state_next = SM_IDEL;
				else
					state_next = SM_SEND_STOP1;
			end
		  SM_SEND_STOP1:
		    if(clk_en_i)
				state_next = SM_IDEL;
		  default:
			begin
				state_next = SM_IDEL;
			end
		endcase
	end
	
	always @ (*)
	begin
		case (state)
		  SM_IDEL:
			begin
				uart_tx_o = `HIGH;
				uart_busy_o = `LOW;
			end
		  SM_SEND_START:
			begin
				uart_tx_o = `LOW;
				uart_busy_o = `HIGH;
			end
		  SM_SEND_DATA0,
		  SM_SEND_DATA1,
		  SM_SEND_DATA2,
		  SM_SEND_DATA3,
		  SM_SEND_DATA4,
		  SM_SEND_DATA5,
		  SM_SEND_DATA6,
		  SM_SEND_DATA7:
			begin
				uart_tx_o = ( (state >> 2) & data_in_lch ) != 0;
				uart_busy_o = `HIGH;
			end
		  //parity operation
		  SM_SEND_PARITY:
		    begin
				case (PARITY_TYPE)
				  PARITY_EVEN:
					uart_tx_o = ^data_in_lch;
				  PARITY_ODD:
					uart_tx_o = ~(^data_in_lch);
				  default:
				    uart_tx_o = `HIGH;
				endcase
				uart_busy_o = `HIGH;
			end
		  SM_SEND_STOP0:
		    begin
				uart_tx_o = `HIGH;
				uart_busy_o = `HIGH;
			end
		  SM_SEND_STOP1:
		    begin
				uart_tx_o = `HIGH;
				uart_busy_o = `HIGH;
			end
		  default:
			begin
				uart_tx_o = `HIGH;
				uart_busy_o = `LOW;
			end
		endcase
	end
	
endmodule
	