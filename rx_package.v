module rx_package
	#(
	  parameter TOGGLE = 1'b0,	                    // for pingpong buffer
	  parameter FIFO_DEPTH = 16,
	  parameter FIFO_BUFFER_DEP = 256,
	  parameter SOF_LENGTH = 6,
	  parameter SOF_PATTERN = 48'h244750474741,		// $GPGGA
	  parameter EOF_DETECTION = 1'b1,		        // sof + eof mode
	  parameter EOF_LENGTH = 1,
	  parameter EOF_PATTERN = 8'h0A,				// /n
	  parameter FRAME_LENGTH_FIXED = 1'b1,			// sof + framecnt mode
	  parameter FRAME_CNT = 67,
	  parameter SUB = 1'b1,							// valid for substitute
	  parameter SUB_POS = 7,
	  parameter SUB_LENGTH = 9,
	  parameter PICK_POS = 17,
	  parameter PICK_LENGTH = 9
	)
	(
	  input		    					 clk_i,
	  input								 reset_n_i,
	  input								 enable_i,
	  
	  input								 rx_datavld_i,
	  input [7:0]						 rx_data_i,
	  
	  input 					   		 sub_datavld_i,
	  input [SUB_LENGTH * 8 - 1:0] 		 sub_data_i,
	  
	  output reg [PICK_LENGTH * 8 - 1:0] pick_data_o,
	  output reg						 pick_datavld_o,
	  output reg 						 FIFO_clear_o,
	  
	  output reg [TOGGLE:0]				 frame_datavld_o,
	  output reg [7:0]					 frame_data_o,
	  output reg [10:0]					 frame_cnt_o,
	  output reg [TOGGLE:0]				 frame_interrupt_o
	);
	
	localparam SM_IDEL = 4'd1;
	localparam SM_DET_SOF = 4'd2;
	localparam SM_RCV_DATA = 4'd4;
	localparam SM_OUTPUT_DELAY = 4'd8;
	
	reg [3:0] state;
	reg [3:0] state_next;
	
	// fifo
	reg [7:0] fifo_0 [FIFO_DEPTH - 1:0];			// 16 * 8 fifo
	reg [7:0] fifo_1 [FIFO_BUFFER_DEP - 1:0];
	reg [7:0] fifo_2 [FIFO_BUFFER_DEP - 1:0];
	reg [3:0] write_ptr;
	reg [3:0] read_ptr;
	reg [3:0] fifo_cnt;
	reg fifo_datavld;
	reg toggle_cnt;
	reg [7:0] data_cnt;
	
	// fsm state transition
	reg [3:0] sof_cnt;
	reg [7:0] eof_cnt;
	reg [3:0] delay_cnt;
	reg flag_sof_det;
	reg flag_eof_det;
	reg flag_start_det;
	reg flag_delay_finish;
	reg [47:0] sof_pattern;
	reg [31:0] eof_pattern;
	
	// pick and sub operation
	reg flag_fifo_out;		// control the output of fifo
	reg flag_pick_finish;
	reg flag_sub_op;
	reg [7:0] pick_pos_cnt;
	reg [7:0] sub_pos_cnt;
	reg [7:0] pick_len_cnt;
	reg [7:0] sub_len_cnt;
	reg [SUB_LENGTH * 8 - 1:0] sub_buffer;
	reg [PICK_LENGTH * 8 - 1:0] pick_buffer;
	
	reg [7:0] test;
	
	// toggle fifo operation
	always @ ( posedge clk_i or negedge reset_n_i )
	begin
		if( !reset_n_i )
		begin
			toggle_cnt <= 1'b0;
			data_cnt <= 8'b0;
			FIFO_clear_o <= 1'b1;
		end
		else
		begin
			if( TOGGLE )
			begin
				if( flag_delay_finish )
				begin
					toggle_cnt <= ~toggle_cnt;
					data_cnt <= 8'b0;
					FIFO_clear_o <= 1'b0;
				end
			end
			else
			begin
				if( flag_delay_finish )
				begin
					data_cnt <= 8'b0;
					FIFO_clear_o <= 1'b0;
				end
			end
		end
	end
	
	// fifo operation
	always @ ( posedge clk_i or negedge reset_n_i )
	begin
		if(!reset_n_i)
		begin
			write_ptr = 4'b0;
			read_ptr = 4'b0;
			fifo_cnt = 4'b0;
			fifo_datavld = 1'b0;
		end
		else
		begin
			case( { flag_fifo_out, rx_datavld_i } )
			  2'b00:
			    begin
					fifo_cnt = fifo_cnt;
					fifo_datavld = 1'b0;
				end
			// write to fifo
			  2'b01:
			    begin
					if( SUB && flag_sub_op ) 		// change here
					begin
						fifo_0[write_ptr] = ( ( sub_buffer >> ( ( SUB_LENGTH - sub_len_cnt - 1 ) * 8 ) ) & 8'hFF );
						sub_len_cnt <= sub_len_cnt + 8'b1;
					end
					else
					begin
						fifo_0[write_ptr] = rx_data_i;
					end
					
					fifo_cnt = ( fifo_cnt == FIFO_DEPTH - 1 ) ? ( FIFO_DEPTH - 1 ) : ( fifo_cnt + 4'b1 );     // test
					write_ptr = ( write_ptr == FIFO_DEPTH - 1 ) ? 4'b0 : write_ptr + 4'b1;
					fifo_datavld = 1'b1;
				end
			// read to fifo
			  2'b10:
			    begin
					frame_data_o = fifo_0[read_ptr];
					// toggle fifo operation
					if( !toggle_cnt )
					begin
						fifo_1[data_cnt] = fifo_0[read_ptr];
					end
					else
					begin
						fifo_2[data_cnt] = fifo_0[read_ptr];
					end
					
					data_cnt = data_cnt + 8'b1;
					fifo_cnt = fifo_cnt - 4'b1;
					read_ptr = ( read_ptr == FIFO_DEPTH - 1 ) ? 4'b0 : read_ptr + 4'b1;
					fifo_datavld = 1'b0;
				end
			// read and write
			  2'b11:
			    begin
					if( SUB && flag_sub_op ) 		// change here
					begin
						fifo_0[write_ptr] = ( ( sub_buffer >> ( ( SUB_LENGTH - sub_len_cnt - 1 ) * 8 ) ) & 8'hFF );
						sub_len_cnt <= sub_len_cnt + 8'b1;
					end
					else
					begin
						fifo_0[write_ptr] = rx_data_i;
					end
					frame_data_o = fifo_0[read_ptr];
					// toggle fifo operation
					if( !toggle_cnt )
					begin
						fifo_1[data_cnt] = fifo_0[read_ptr];
					end
					else
					begin
						fifo_2[data_cnt] = fifo_0[read_ptr];
					end
					
					data_cnt = data_cnt + 8'b1;
					write_ptr = ( write_ptr == FIFO_DEPTH - 1 ) ? 4'b0 : write_ptr + 4'b1;
					read_ptr = ( read_ptr == FIFO_DEPTH - 1) ? 4'b0 : read_ptr + 4'b1;
					fifo_datavld = 1'b1;
				end
			  default:
			    begin
					write_ptr = 4'b0;
					read_ptr = 4'b0;
					fifo_cnt = 4'b0;
					fifo_datavld = 1'b0;
			    end
			endcase
		end
	end
	
	//assign FIFO_clear_o = ( fifo_cnt == 4'b0 );
	
	// sub_buffer operation
	always @ ( posedge clk_i or negedge reset_n_i )
	begin
		if( !reset_n_i )
		begin
			sub_pos_cnt <= 8'b0;
			sub_len_cnt <= 8'b0;
			sub_buffer <= 0;
			flag_sub_op <= 1'b0;
		end
		else
		begin
			if( sub_datavld_i )
			begin
				sub_buffer <= sub_data_i;
			end
			
			if( state == SM_IDEL )
			begin
				sub_pos_cnt <= 8'b0;
				sub_len_cnt <= 8'b0;
			end
			
			if( state == SM_RCV_DATA && rx_datavld_i )
			begin
				if( sub_pos_cnt != ( SUB_POS - SOF_LENGTH ) )
				begin
					sub_pos_cnt <= sub_pos_cnt + 8'b1;
				end
			end
			
			// flag_sub_op
			if( sub_pos_cnt == ( SUB_POS - SOF_LENGTH ) && sub_len_cnt != SUB_LENGTH )
			begin
				flag_sub_op <= 1'b1;
			end
			else
			begin
				flag_sub_op <= 1'b0;
			end
		end
	end
	
	// '$' detection
	always @ ( posedge clk_i or negedge reset_n_i )
	begin
		if( !reset_n_i )
		begin
			flag_start_det <= 1'b0;
		end
		else
		begin
			if( fifo_0[write_ptr - 1] == 8'h24 )
				flag_start_det <= 1'b1;
			else
				flag_start_det <= 1'b0;
		end
	end
	
	// SOF detection
	always @ ( posedge clk_i or negedge reset_n_i )
	begin
		if( !reset_n_i )
		begin
			sof_pattern <= SOF_PATTERN;
			flag_sof_det <= 1'b0;
			sof_cnt <= 4'b0;
		end
		else
		begin
			// change here to corparte with fifo_datavld
			/*
			if( state == SM_DET_SOF && fifo_datavld )
			begin
				if( write_ptr == 4'b0 )
				begin
					if( fifo_0[FIFO_DEPTH - 1] == ( ( SOF_PATTERN >> ( SOF_LENGTH - 1 - sof_cnt ) ) & 8'h01 ) )
					begin
						sof_cnt <= sof_cnt + 4'b1;
					end
				end
				else
				begin
					if( fifo_0[write_ptr - 1] == ( ( SOF_PATTERN >> ( SOF_LENGTH - 1 - sof_cnt ) ) & 8'h01 ) )
					begin
						sof_cnt <= sof_cnt + 4'b1;
					end
				end
			end
			*/
			
			if( state == SM_DET_SOF && rx_datavld_i )
			begin
				if( rx_data_i == ( ( sof_pattern >> ( SOF_LENGTH - 2 - sof_cnt ) * 8 ) & 8'hFF ) )
				begin
					sof_cnt <= sof_cnt + 4'b1;
				end
			end
			
			if( sof_cnt == ( SOF_LENGTH - 1 ) )
			begin
				flag_sof_det <= 1'b1;
				sof_cnt <= 4'b0;
			end
			else
				flag_sof_det <= 1'b0;
		end
	end
	
	// EOF detection
	always @ ( posedge clk_i or negedge reset_n_i )
	begin
		if( !reset_n_i )
		begin
			eof_pattern <= EOF_PATTERN;
			flag_eof_det <= 1'b0;
			eof_cnt <= 8'b0;
		end
		else
		begin
			if( EOF_DETECTION )
			begin
				if( state == SM_RCV_DATA && fifo_datavld )
				begin
					if( fifo_0[write_ptr - 1] == ( ( eof_pattern >> ( EOF_LENGTH - 1 - eof_cnt ) * 8 ) & 8'hFF ) )
					begin
						eof_cnt <= eof_cnt + 8'b1;
					end
				end
				
				if( eof_cnt == EOF_LENGTH )
			    begin
					flag_eof_det <= 1'b1;
					eof_cnt <= 8'b0;
				end
			    else
				    flag_eof_det <= 1'b0;
			end
			
			// test here
			if( FRAME_LENGTH_FIXED )
			begin
				if( state == SM_RCV_DATA && fifo_datavld )
				begin
					eof_cnt <= eof_cnt + 8'b1;
				end
				
				if( eof_cnt == FRAME_CNT )
			    begin
					flag_eof_det <= 1'b1;
					eof_cnt <= 8'b0;
				end
			    else
				begin
				    flag_eof_det <= 1'b0;
				end
			end
		end
	end
	
	// FSM 1
	always @ (posedge clk_i or negedge reset_n_i)
	begin
		if(!reset_n_i)
		begin
			state <= SM_IDEL;	        // complete here
		end
		else
		begin
			if( enable_i ) 				// async
				state <= state_next;
		end
	end
	
	// FSM 2
	always @ ( * )
	begin
		state_next = state;
		case( state )
		  SM_IDEL:
			if( flag_start_det )
			begin
				state_next = SM_DET_SOF;
			end
		  SM_DET_SOF:
			if( flag_sof_det )
			begin
				state_next = SM_RCV_DATA;
			end
		  SM_RCV_DATA:
		    if( flag_eof_det )
			begin
				state_next = SM_OUTPUT_DELAY;
			end
		  SM_OUTPUT_DELAY:
			if( flag_delay_finish )
			begin
				state_next = SM_IDEL;
			end
		  default:
		    state_next = SM_IDEL;
		endcase
	end
	
	// FSM 3 output 
	
	// frame_data_o frame_datavld_o frame_cnt_o frame_interrupt_o
	// configure the read_ptr
	always @ ( * )
	begin
		if( state == SM_DET_SOF && state_next == SM_RCV_DATA ) 			// test
		begin
			read_ptr <= ( write_ptr >= SOF_LENGTH - 1 ) ? ( write_ptr - SOF_LENGTH ) : ( FIFO_DEPTH - SOF_LENGTH + write_ptr );
		end
	end
	
	always @ ( posedge clk_i or negedge reset_n_i )
	begin
		if( !reset_n_i )
		begin
			flag_fifo_out <= 1'b0;
			flag_delay_finish <= 1'b0;
			frame_data_o <= 8'b0;
			frame_datavld_o <= 1'b0;				// toggle buffer change
			frame_cnt_o <= 11'b0;
			frame_interrupt_o <= 1'b0;
			delay_cnt <= 4'b0;
		end
		else
		begin
			// configure the flag_fifo_out delay_cnt
			if( state == SM_RCV_DATA || ( state == SM_OUTPUT_DELAY && delay_cnt != SOF_LENGTH ) )
			begin
				flag_fifo_out <= rx_datavld_i;			// delay one clock period
				if( state == SM_OUTPUT_DELAY && rx_datavld_i )
				begin
					delay_cnt <= delay_cnt + 4'b1;
				end
			end
			else
			begin
				flag_fifo_out <= 1'b0;
			end
			
			// configure frame_cnt_o frame_interrupt_o flag_delay_finish
			if( delay_cnt == SOF_LENGTH )
			begin
				flag_delay_finish <= 1'b1;
				frame_cnt_o <= frame_cnt_o + 11'b1;
				frame_interrupt_o <= 1'b1;
				delay_cnt <= 4'b0;
			end
			else
			begin
				flag_delay_finish <= 1'b0;
			end
			
			// configure frame_datavld_o
			if( flag_fifo_out )
			begin
				frame_datavld_o <= 1'b1;
			end
			else
				frame_datavld_o <= 1'b0;
		end
	end
	
	// pick_data_o pick_datavld_o
	always @ ( posedge clk_i or negedge reset_n_i )
	begin
		if( !reset_n_i )
		begin
			pick_pos_cnt <= 8'b0;
			pick_len_cnt <= 8'b0;
			pick_buffer <= 0;
			pick_data_o <= 0;
			pick_datavld_o <= 1'b0;
			flag_pick_finish <= 1'b0;
		end
		else
		begin
			// count
			if( state == SM_RCV_DATA && rx_datavld_i )
			begin
				if( pick_pos_cnt != ( PICK_POS - SOF_LENGTH ) )
				begin
					pick_pos_cnt = pick_pos_cnt + 8'b1;
				end
				else
				begin
					if( pick_len_cnt != PICK_LENGTH )
					begin
						pick_buffer = pick_buffer + ( rx_data_i << ( ( PICK_LENGTH - pick_len_cnt - 1 ) * 8 ) );
						pick_len_cnt = pick_len_cnt + 8'b1;
					end
				end
			end
			
			if( state == SM_IDEL )
			begin
				pick_buffer = 0;
				pick_pos_cnt <= 8'b0;
				pick_len_cnt <= 8'b0;
				flag_pick_finish <= 1'b0;
			end
			
			if( pick_len_cnt == PICK_LENGTH && !flag_pick_finish )
			begin
				pick_data_o <= pick_buffer;
				pick_datavld_o <= 1'b1;
				flag_pick_finish <= 1'b1;
			end
			else
				pick_datavld_o <= 1'b0;
		end
	end
	
endmodule