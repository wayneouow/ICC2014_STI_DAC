module STI_DAC(clk ,reset, load, pi_data, pi_length, pi_fill, pi_msb, pi_low, pi_end,
	       so_data, so_valid,
	       oem_finish, oem_dataout, oem_addr,
	       odd1_wr, odd2_wr, odd3_wr, odd4_wr, even1_wr, even2_wr, even3_wr, even4_wr);

input		clk, reset;
input		load, pi_msb, pi_low, pi_end; 
input	[15:0]	pi_data;
input	[1:0]	pi_length;
input		pi_fill;
output		so_data, so_valid;

output  oem_finish, odd1_wr, odd2_wr, odd3_wr, odd4_wr, even1_wr, even2_wr, even3_wr, even4_wr;
output [4:0] oem_addr;
output [7:0] oem_dataout;

//==============================================================================
wire so_data;
reg	so_valid;

reg  oem_finish, odd1_wr, odd2_wr, odd3_wr, odd4_wr, even1_wr, even2_wr, even3_wr, even4_wr;
reg [4:0] oem_addr;
reg [7:0] oem_dataout;

reg [31:0] data_buf;
reg [ 4:0] data_buf_i;
reg [ 4:0] serial_cnt;

reg [1:0]st;
assign so_data = data_buf[data_buf_i];

wire remain;
assign remain = pi_end && st == 2'd3;

always@(posedge clk or posedge reset)begin
	if(reset)
		st <= 2'd0;
	else begin
		case(st)
			2'd0://IDLE
				if(load)
				st <= 2'd1;
			2'd1://LOAD
				st <= 2'd2;
			2'd2://OUTPUT
				if(serial_cnt == 5'd31 && pi_end)
				st <= 2'd3;
				else if(serial_cnt == 5'd31)
				st <= 2'd0;
			2'd3://FINISH
				st <= st;
			default:
				st <= 2'd0;
		endcase
	end
end


always@(posedge clk or posedge reset)
begin
	if(reset) 
		so_valid <= 1'd0;
	else if(st == 2'd1) 
		so_valid <= 1'd1;
	else if(serial_cnt == 5'd31)
		so_valid <= 1'd0;
end

always@(*)begin
	case(pi_length)
	
	// 8bits
	2'b00:
		data_buf[31:0] = (pi_low) ? {pi_data[15:8], 24'd0} : {pi_data[7:0], 24'd0};
	
	//16bits
	2'b01:
		data_buf[31:0] = {pi_data[15:0],16'd0};
	
	//24bits	
	2'b10:
		data_buf[31:0] = (pi_fill) ? {pi_data[15:0], 16'd0} : {8'd0, pi_data[15:0], 8'd0};

	//32bits
	2'b11:
		data_buf[31:0] = (pi_fill) ? {pi_data[15:0], 16'd0} : {16'd0, pi_data[15:0]};

	default:
		data_buf = 32'd0;
	endcase
	
end
always@(posedge clk or posedge reset)begin

	if(reset)
		serial_cnt <= 5'd0;
	else if(load)begin
		case(pi_length)
			2'b00:
				serial_cnt <= 5'd24;//cnt 8
			2'b01:
				serial_cnt <= 5'd16;//cnt 16
			2'b10: 
				serial_cnt <= 5'd8;//cnt 24
			2'b11: 
				serial_cnt <= 5'd0;//cnt32
		endcase
	end
	else if(st == 2'd2) 
		serial_cnt <= serial_cnt + 5'd1;
	
end

always@(posedge clk or posedge reset)
begin
	if(reset)
		data_buf_i <= 5'd0;
	else if(st == 2'd0)
	begin
		if(pi_msb) 
			data_buf_i <= 5'd31;
		else
		begin
			case(pi_length)
			2'b00: 
				data_buf_i <= 5'd24;
			2'b01: 
				data_buf_i <= 5'd16; 
			2'b10:
				data_buf_i <= 5'd8;
			2'b11:
				data_buf_i <= 5'd0;
			endcase
		end
	end
	else if(st == 2'd2)
	begin
		if(pi_msb) 
			data_buf_i <= data_buf_i - 5'd1;
		else 
			data_buf_i <= data_buf_i + 5'd1;
	end
	
end

reg [2:0]write;

always@(posedge clk or posedge reset)begin
	if(reset)
		write <= 1'd0;
	else if(write)
		write <= 1'd0;
	
	else if(st == 2'd2)begin
		case(serial_cnt)
			5'd0:
				write <= 3'd1;
			5'd8:
				write <= 3'd2;
			5'd16:
				write <= 3'd3;
			5'd24:
				write <= 3'd4;
			default:
				write <= 3'd0;
		endcase
	end
end

wire [2:0]four_sub_write;
assign four_sub_write = pi_length + write;
integer i;
always@(posedge clk or posedge reset)begin

	if(reset)
		oem_dataout <= 8'd0;
	else if(remain)
		oem_dataout <= 8'd0;
	else if(pi_msb)begin
		case(four_sub_write)
			3'd4:
				oem_dataout <= data_buf[31:24];
			3'd5:
				oem_dataout <= data_buf[23:16];
			3'd6:
				oem_dataout <= data_buf[15: 8];
			3'd7:
				oem_dataout <= data_buf[ 7: 0];
		endcase
	end
	
	else if(~pi_msb)begin
		case(write)
			3'd1:
			begin
				for(i=0 ; i <8 ;i=i+1)
					oem_dataout[i] <= data_buf[7-i];
			end
				//oem_dataout <= data_buf[ 0:7];
			3'd2:
			begin
				for(i=0 ; i <8 ;i=i+1)
					oem_dataout[i] <= data_buf[15-i];
			end
				//oem_dataout <= data_buf[ 8:15];
			3'd3://ok
			begin
				for(i=0 ; i <8 ;i=i+1)
					oem_dataout[i] <= data_buf[23-i];
			end
				//oem_dataout <= data_buf[16:23];
			3'd4:
			begin
				for(i=0 ; i <8 ;i=i+1)
					oem_dataout[i] <= data_buf[31-i];
			end
				//oem_dataout <= data_buf[24:31];
		endcase
	end
	
end

reg [7:0] m_addr;

always@(posedge clk or posedge reset)begin
	if(reset)
		m_addr <= 8'd255;
	else if(write)
		m_addr <= m_addr +1;
	else if(remain)
		m_addr <= m_addr +1;
end
reg two_row;
reg sw;

always@(posedge clk or posedge reset)begin //EVEN -E  ODD -O
	if(reset)
		sw <= 1'b1;
	else if(write && m_addr[2:0]==3'b111)
		sw <= sw;
	else if(write)
		sw <= ~sw;
end

reg [1:0] memory_num;

always@(posedge clk or posedge reset)begin
	if(reset)
		memory_num <= 2'd0;
		
	else begin
		case(m_addr)
			8'd255:
				memory_num <= 2'd0;
			8'd63:
				memory_num <= 2'd1;
			8'd127:
				memory_num <= 2'd2;
			8'd191:
				memory_num <= 2'd3;
		endcase	
	end	
end

reg wr;

always@(posedge clk or posedge reset)begin
	if(reset)
		oem_addr <= 5'd31;
	else if(m_addr[0] && write)
		oem_addr <= oem_addr +1;
	else if(remain && m_addr[0])
		oem_addr <= oem_addr +1;
end


always@(posedge clk or posedge reset)begin
	if(reset)
		wr <= 1'b0;
	else if(wr)
		wr <= 1'b0;
	else if(write)
		wr <= 1'b1;
end

//OM
always@(posedge clk or posedge reset)begin
	if(reset)
		odd1_wr <= 1'b0;
	else if(odd1_wr)
		odd1_wr <= 1'b0;
	else if(wr && memory_num==0 && sw)
		odd1_wr <= 1'b1;
	else
		odd1_wr <= 1'b0;
end

always@(posedge clk or posedge reset)begin
	if(reset)
		odd2_wr <= 1'b0;
	else if(odd2_wr)
		odd2_wr <= 1'b0;
	else if(wr && memory_num==1 && sw)
		odd2_wr <= 1'b1;
	else
		odd2_wr <= 1'b0;
end

always@(posedge clk or posedge reset)begin
	if(reset)
		odd3_wr <= 1'b0;
	else if(odd3_wr)
		odd3_wr <= 1'b0;
	else if(wr && memory_num==2 && sw)
		odd3_wr <= 1'b1;
	else
		odd3_wr <= 1'b0;
end

always@(posedge clk or posedge reset)begin
	if(reset)
		odd4_wr <= 1'b0;
	else if(odd4_wr)
		odd4_wr <= 1'b0;	
	else if(wr && memory_num==3 && sw)
		odd4_wr <= 1'b1;
	else if(remain)
		odd4_wr <= 1'b1;
	else
		odd4_wr <= 1'b0;
end

//EM
always@(posedge clk or posedge reset)begin
	if(reset)
		even1_wr <= 1'b0;
	else if(even1_wr)
		even1_wr <= 1'b0;
	else if(wr && memory_num==0 && ~sw)
		even1_wr <= 1'b1;
	else
		even1_wr <= 1'b0;
end

always@(posedge clk or posedge reset)begin
	if(reset)
		even2_wr <= 1'b0;
	else if(even2_wr)
		even2_wr <= 1'b0;
	else if(wr && memory_num==1 && ~sw)
		even2_wr <= 1'b1;
	else
		even2_wr <= 1'b0;
end

always@(posedge clk or posedge reset)begin
	if(reset)
		even3_wr <= 1'b0;
	else if(even3_wr)
		even3_wr <= 1'b0;
	else if(wr && memory_num==2 && ~sw)
		even3_wr <= 1'b1;
		
	else
		even3_wr <= 1'b0;	
end

always@(posedge clk or posedge reset)begin
	if(reset)
		even4_wr <= 1'b0;
	else if(even4_wr)
		even4_wr <= 1'b0;
	else if(wr && memory_num==3 && ~sw)
		even4_wr <= 1'b1;
	else if(remain)
		even4_wr <= 1'b1;
	else
		even4_wr <= 1'b0;
end

always@(posedge clk or posedge reset)begin
	if(reset)
		oem_finish <= 1'b0;
	else if(remain && m_addr == 8'd255)
		oem_finish <= 1'b1;
end

endmodule
