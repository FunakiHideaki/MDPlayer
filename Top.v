module Top(RST, XtalIn, XtalOut, CS, SCK, MISO, MOSI, DREQ, DIR, PWM, Error);
input RST, XtalIn, CS, SCK, MOSI;
output XtalOut;
output reg MISO, DREQ, Error;
output [5:0] DIR, PWM;


//初期定義
/*initial begin
	SckCnt<=0;
	ByteFlag<=0;
	data<=0;
	
	SMFHeadFlag<=0;
	TrackHeadFlag<=0;
	ByteCnt<=0;
	
	DtimeFlag<=0;
	Dtime[16]<=0;
	cmd[16]<=0;
	height[16]<=0;
	velocity[16]<=0;
	SetEventFlag<=0;
	MetaEventFlag<=0;
	MetaEventCnt<=0;
	MetaEvent[16]<=0;
	
	BuffInitFlag<=0;
//	BlankBuff<=0;
	
//	DtimeCnt<=0;
	ExeBuff<=0;
	ExeFlag<=0;
	
	SwFlag<=0;
	
	tempo<=500000;
	
//[7:0] ExeCmd[35:0];
//[7:0] ExeHeight[35:0];
//[7:0] ExeVelocity[35:0];
	$finish;

end*/


//発振回路
assign XtalOut=~XtalIn;


reg [2:0] SckCnt;//
reg [0:0] ByteFlag;
reg [7:0] data;

always @(posedge SCK or negedge RST) begin
//MISO<=1'bz;
if(RST==0) begin
	SckCnt<=0;
	ByteFlag<=0;
	data<=0;
	end
else begin
	if(CS) begin
		SckCnt<=0;
		end
	else begin
		if(SckCnt<=7) begin
			if(SckCnt==0) begin
				data= MOSI;
				SckCnt<=1;
				end
			else begin
				data=(MOSI<<(7-SckCnt))+data;
				if(SckCnt>=7) begin
					SckCnt<=0;
					ByteFlag<=1;
					end
				else begin
					SckCnt<=SckCnt+1;
					ByteFlag<=0;
					end
				end
			end
		else begin
			SckCnt<=0;
			end
		end
	end
end


wire [7:0] SendData;
assign SendData=ExeFlag;//height[16];

always @(negedge SCK or negedge RST) begin
if(RST==0) begin
	MISO<=1'bz;
	end
else begin
	if(CS) begin
		MISO<=1'bz;
		end
	else begin
		MISO<=SendData[7-SckCnt];
		end
	end
end


reg [0:0] SMFHeadFlag;
reg [0:0] TrackHeadFlag;
reg [7:0] ByteCnt;

//SMF Header
reg [7:0] SMFHeader[13:0];
reg [7:0] TrackHeader[7:0];
wire [15:0] Format;
wire [15:0] TrackSize;
wire [15:0] TimeUnit;

assign Format=(SMFHeader[8]<<8)+SMFHeader[9];
assign TrackSize=(SMFHeader[10]<<8)+SMFHeader[11];
assign TimeUnit=(SMFHeader[12]<<8)+SMFHeader[13];

//Track Header
reg [0:0] DtimeFlag;
reg [23:0] Dtime[16:0];
reg [7:0] cmd[16:0];
reg [7:0] height[16:0];
reg [7:0] velocity[16:0];
reg [0:0] SetEventFlag;
reg [0:0] MetaEventFlag;
reg [7:0] MetaEventCnt;
reg [23:0] MetaEvent[16:0];

always @(posedge ByteFlag or negedge RST) begin//negedge ByteFlagの方が良いかも。
if(RST==0) begin
	SMFHeadFlag<=0;
	TrackHeadFlag<=0;
	ByteCnt<=0;
	
	DtimeFlag<=0;
	Dtime[16]<=0;
	cmd[16]<=0;
	height[16]<=0;
	velocity[16]<=0;
	SetEventFlag<=0;
	MetaEventFlag<=0;
	MetaEventCnt<=0;
	MetaEvent[16]<=0;
	end
else begin
//	SetEventFlag=0;
	if(SMFHeadFlag==0) begin
		if(ByteCnt<=13) begin
			SMFHeader[ByteCnt]<=data;
			if(ByteCnt>=13) begin
				ByteCnt<=0;
				SMFHeadFlag<=1;
				end
			else begin
				ByteCnt<=ByteCnt+1;
				end
			end
		end
	else if(TrackHeadFlag==0) begin
		if(ByteCnt<=7) begin
			TrackHeader[ByteCnt]<=data;
			if(ByteCnt>=7) begin
				ByteCnt<=0;
				TrackHeadFlag<=1;
				end
			else begin
				ByteCnt<=ByteCnt+1;
				end
			end
		end
	else begin
		if(DtimeFlag==0) begin
			SetEventFlag<=0;
			if(ByteCnt==0) begin
				Dtime[16]<=(data&8'h7F);
//				SetEventFlag<=0;
				ByteCnt<=1;
				end
			else begin
				Dtime[16]<=(Dtime[16]<<7)|(data&8'h7F);
				end
			if((data>>7)==0) begin
				ByteCnt<=0;
				DtimeFlag<=1;
				end
			end
		else begin
			case(ByteCnt)
				0:begin
					cmd[16]<=data;
					ByteCnt<=ByteCnt+1;
					if(data==8'hFF) begin
						MetaEventFlag<=1;
						end
					end
				1:begin 
					height[16]<=data;
					ByteCnt<=ByteCnt+1;
					end
				2:begin
					velocity[16]<=data;
					MetaEvent[16]<=0;
					if(MetaEventFlag==0||data==0) begin
						ByteCnt<=0;
						DtimeFlag<=0;
						MetaEventFlag<=0;
						SetEventFlag<=1;
						end
					else begin
						ByteCnt<=ByteCnt+1;
						end
					end
				3:begin
					if((MetaEventCnt+1)<=velocity[16]) begin
						MetaEvent[16]=(MetaEvent[16]<<8)|data;
						if((MetaEventCnt+1)>=velocity[16]) begin
							MetaEventCnt<=0;
							MetaEventFlag<=0;
							ByteCnt<=0;
							DtimeFlag<=0;
							SetEventFlag<=1;
							end
						else begin
							MetaEventCnt<=MetaEventCnt+1;
							end
						end
					else begin
						MetaEventCnt<=0;
						MetaEventFlag<=0;
						ByteCnt<=0;
						DtimeFlag<=0;
						SetEventFlag<=0;
						end
					end
				endcase
			end
		end
	end
end


reg [0:0] BuffInitFlag;
reg [5:0] BlankBuff;

always @(posedge SetEventFlag or negedge RST) begin
if(RST==0) begin
//	BuffInitFlag<=0;
	BlankBuff<=0;
	end
else begin
	if(BlankBuff<=15) begin
		if(BlankBuff>=15) begin
			BlankBuff<=0;
			end
		else begin
			BlankBuff<=BlankBuff+1;
			end
		end
	else begin
		BlankBuff<=0;
		end
	end
end

always @(posedge SetEventFlag or negedge RST) begin
if(RST==0) begin
	BuffInitFlag<=0;
	end
else begin
	if(BlankBuff>=6) begin
		BuffInitFlag<=1;
		end
	else begin
		BuffInitFlag<=BuffInitFlag;
		end
	end
end


always @(posedge SetEventFlag) begin
Dtime[BlankBuff]<=Dtime[16];
cmd[BlankBuff]<=cmd[16];
height[BlankBuff]<=height[16];
velocity[BlankBuff]<=velocity[16];
MetaEvent[BlankBuff]<=MetaEvent[16];
end


wire DtimeClk;

UnitClockGenerator(XtalOut, RST, UnitClk, DtimeClk);

reg [23:0] DtimeCnt;
reg [5:0] ExeBuff;
reg [0:0] ExeFlag;

always @(posedge DtimeClk or negedge RST) begin
if(RST==0) begin
	DtimeCnt<=0;
	ExeFlag<=0;
	
	ExeBuff<=0;
	end
else begin
	if(BuffInitFlag>=1) begin
		if(DtimeCnt<=Dtime[ExeBuff]) begin
			if(DtimeCnt>=Dtime[ExeBuff]) begin
				DtimeCnt<=0;
				ExeFlag<=1;
				//移植してきた。
				if(ExeBuff<=15) begin
					if(ExeBuff>=15) begin
						ExeBuff<=0;
						end
				else begin
					ExeBuff<=ExeBuff+1;
					end
				end
				else begin
					ExeBuff<=0;
					end
					
				end
			else begin
				DtimeCnt<=DtimeCnt+1;
				ExeFlag<=0;
				end
			end
		else begin
			DtimeCnt<=0;
			end
		end
	end
end


/*always @(posedge ExeFlag or negedge RST) begin
if(RST==0) begin
	ExeBuff<=0;
	end
else begin
	if(ExeBuff<=15) begin
		if(ExeBuff>=15) begin
			ExeBuff<=0;
			end
		else begin
			ExeBuff<=ExeBuff+1;
			end
		end
	else begin
		ExeBuff<=0;
		end
	end
end*/


//always @(posedge SetEventFlag or posedge ExeFlag) begin
always @* begin
if(ExeBuff>=BlankBuff) begin
	if(((BlankBuff+16)-ExeBuff)<=6) begin
//	if((ExeBuff-BlankBuff)>10) begin
		DREQ<=1;
		end
	else begin
		DREQ<=0;
		end
	end
else begin
	if((BlankBuff-ExeBuff)<=6) begin
		DREQ<=1;
		end
	else begin
		DREQ<=0;
		end
	end
end


//実行部分

reg [35:0] SwFlag;
wire [5:0] ExeReg[5:0];

ExeRegSearch(XtalOut, 0, SwFlag, ExeReg[0]);
ExeRegSearch(XtalOut, 1, SwFlag, ExeReg[1]);
ExeRegSearch(XtalOut, 2, SwFlag, ExeReg[2]);
ExeRegSearch(XtalOut, 3, SwFlag, ExeReg[3]);
ExeRegSearch(XtalOut, 4, SwFlag, ExeReg[4]);
ExeRegSearch(XtalOut, 5, SwFlag, ExeReg[5]);


reg [7:0] ExeCmd[35:0];
reg [7:0] ExeHeight[35:0];
reg [7:0] ExeVelocity[35:0];
reg [23:0] tempo;
wire [23:0] UnitClk;
wire [3:0] Note;
wire [3:0] DeviceNum;
wire [5:0] OffNum;

assign UnitClk=tempo*20/TimeUnit;
assign Note=(cmd[ExeBuff]>>4)&4'hF;
assign DeviceNum=cmd[ExeBuff]&8'h0F;
assign OffNum=DeviceNum*6;

always @(posedge ExeFlag or negedge RST) begin
if(RST==0) begin
	tempo<=500000;
	SwFlag<=36'h0;
	end
else begin
	if(cmd[ExeBuff]==8'hFF) begin
		case(height[ExeBuff])
			8'h51:
				tempo<=MetaEvent[ExeBuff];
			8'h2F:
				;//終了
			endcase
		end
	else begin
		if(Note==9&&velocity[ExeBuff]!=0) begin
			ExeHeight[ExeReg[DeviceNum]]<=height[ExeBuff];
			ExeVelocity[ExeReg[DeviceNum]]<=velocity[ExeBuff];
			SwFlag[ExeReg[DeviceNum]]<=1;
			end
		else if(Note==8||(Note==9&&velocity[ExeBuff]==0)) begin
			if(ExeHeight[OffNum]==height[ExeBuff]&&SwFlag[OffNum]==1) begin
				SwFlag[OffNum]<=0;
				end
			else if(ExeHeight[OffNum+1]==height[ExeBuff]&&SwFlag[OffNum+1]==1) begin
				SwFlag[OffNum+1]<=0;
				end
			else if(ExeHeight[OffNum+2]==height[ExeBuff]&&SwFlag[OffNum+2]==1) begin
				SwFlag[OffNum+2]<=0;
				end
			else if(ExeHeight[OffNum+3]==height[ExeBuff]&&SwFlag[OffNum+3]==1) begin
				SwFlag[OffNum+3]<=0;
				end
			else if(ExeHeight[OffNum+4]==height[ExeBuff]&&SwFlag[OffNum+4]==1) begin
				SwFlag[OffNum+4]<=0;
				end
			else if(ExeHeight[OffNum+5]==height[ExeBuff]&&SwFlag[OffNum+5]==1) begin
				SwFlag[OffNum+5]<=0;
				end
			end
		end
	end
end

function BuffNum(input [3:0] DeviceNum, input [3:0] RegNum);

BuffNum=6*DeviceNum+RegNum;

endfunction


wire Sound[35:0];

SoundGenerator(XtalOut, SwFlag[0], ExeHeight[0], Sound[0]);
SoundGenerator(XtalOut, SwFlag[1], ExeHeight[1], Sound[1]);
SoundGenerator(XtalOut, SwFlag[2], ExeHeight[2], Sound[2]);
SoundGenerator(XtalOut, SwFlag[3], ExeHeight[3], Sound[3]);
SoundGenerator(XtalOut, SwFlag[4], ExeHeight[4], Sound[4]);
SoundGenerator(XtalOut, SwFlag[5], ExeHeight[5], Sound[5]);
SoundGenerator(XtalOut, SwFlag[6], ExeHeight[6], Sound[6]);
SoundGenerator(XtalOut, SwFlag[7], ExeHeight[7], Sound[7]);
SoundGenerator(XtalOut, SwFlag[8], ExeHeight[8], Sound[8]);
SoundGenerator(XtalOut, SwFlag[9], ExeHeight[9], Sound[9]);
SoundGenerator(XtalOut, SwFlag[10], ExeHeight[10], Sound[10]);
SoundGenerator(XtalOut, SwFlag[11], ExeHeight[11], Sound[11]);
SoundGenerator(XtalOut, SwFlag[12], ExeHeight[12], Sound[12]);
SoundGenerator(XtalOut, SwFlag[13], ExeHeight[13], Sound[13]);
SoundGenerator(XtalOut, SwFlag[14], ExeHeight[14], Sound[14]);
SoundGenerator(XtalOut, SwFlag[15], ExeHeight[15], Sound[15]);
SoundGenerator(XtalOut, SwFlag[16], ExeHeight[16], Sound[16]);
SoundGenerator(XtalOut, SwFlag[17], ExeHeight[17], Sound[17]);
SoundGenerator(XtalOut, SwFlag[18], ExeHeight[18], Sound[18]);
SoundGenerator(XtalOut, SwFlag[19], ExeHeight[19], Sound[19]);
SoundGenerator(XtalOut, SwFlag[20], ExeHeight[20], Sound[20]);
SoundGenerator(XtalOut, SwFlag[21], ExeHeight[21], Sound[21]);
SoundGenerator(XtalOut, SwFlag[22], ExeHeight[22], Sound[22]);
SoundGenerator(XtalOut, SwFlag[23], ExeHeight[23], Sound[23]);
SoundGenerator(XtalOut, SwFlag[24], ExeHeight[24], Sound[24]);
SoundGenerator(XtalOut, SwFlag[25], ExeHeight[25], Sound[25]);
SoundGenerator(XtalOut, SwFlag[26], ExeHeight[26], Sound[26]);
SoundGenerator(XtalOut, SwFlag[27], ExeHeight[27], Sound[27]);
SoundGenerator(XtalOut, SwFlag[28], ExeHeight[28], Sound[28]);
SoundGenerator(XtalOut, SwFlag[29], ExeHeight[29], Sound[29]);
SoundGenerator(XtalOut, SwFlag[30], ExeHeight[30], Sound[30]);
SoundGenerator(XtalOut, SwFlag[31], ExeHeight[31], Sound[31]);
SoundGenerator(XtalOut, SwFlag[32], ExeHeight[32], Sound[32]);
SoundGenerator(XtalOut, SwFlag[33], ExeHeight[33], Sound[33]);
SoundGenerator(XtalOut, SwFlag[34], ExeHeight[34], Sound[34]);
SoundGenerator(XtalOut, SwFlag[35], ExeHeight[35], Sound[35]);


wire [10:0] PSoundUnit [5:0];
wire [10:0] MSoundUnit [5:0];

assign PSoundUnit[0]
=ExeVelocity[BuffNum(0, 0)]*Sound[BuffNum(0, 0)]
+ExeVelocity[BuffNum(0, 1)]*Sound[BuffNum(0, 1)]
+ExeVelocity[BuffNum(0, 2)]*Sound[BuffNum(0, 2)]
+ExeVelocity[BuffNum(0, 3)]*Sound[BuffNum(0, 3)]
+ExeVelocity[BuffNum(0, 4)]*Sound[BuffNum(0, 4)]
+ExeVelocity[BuffNum(0, 5)]*Sound[BuffNum(0, 5)];

assign PSoundUnit[1]
=ExeVelocity[BuffNum(1, 0)]*Sound[BuffNum(1, 0)]
+ExeVelocity[BuffNum(1, 1)]*Sound[BuffNum(1, 1)]
+ExeVelocity[BuffNum(1, 2)]*Sound[BuffNum(1, 2)]
+ExeVelocity[BuffNum(1, 3)]*Sound[BuffNum(1, 3)]
+ExeVelocity[BuffNum(1, 4)]*Sound[BuffNum(1, 4)]
+ExeVelocity[BuffNum(1, 5)]*Sound[BuffNum(1, 5)];

assign PSoundUnit[2]
=ExeVelocity[BuffNum(2, 0)]*Sound[BuffNum(2, 0)]
+ExeVelocity[BuffNum(2, 1)]*Sound[BuffNum(2, 1)]
+ExeVelocity[BuffNum(2, 2)]*Sound[BuffNum(2, 2)]
+ExeVelocity[BuffNum(2, 3)]*Sound[BuffNum(2, 3)]
+ExeVelocity[BuffNum(2, 4)]*Sound[BuffNum(2, 4)]
+ExeVelocity[BuffNum(2, 5)]*Sound[BuffNum(2, 5)];

assign PSoundUnit[3]
=ExeVelocity[BuffNum(3, 0)]*Sound[BuffNum(3, 0)]
+ExeVelocity[BuffNum(3, 1)]*Sound[BuffNum(3, 1)]
+ExeVelocity[BuffNum(3, 2)]*Sound[BuffNum(3, 2)]
+ExeVelocity[BuffNum(3, 3)]*Sound[BuffNum(3, 3)]
+ExeVelocity[BuffNum(3, 4)]*Sound[BuffNum(3, 4)]
+ExeVelocity[BuffNum(3, 5)]*Sound[BuffNum(3, 5)];

assign PSoundUnit[4]
=ExeVelocity[BuffNum(4, 0)]*Sound[BuffNum(4, 0)]
+ExeVelocity[BuffNum(4, 1)]*Sound[BuffNum(4, 1)]
+ExeVelocity[BuffNum(4, 2)]*Sound[BuffNum(4, 2)]
+ExeVelocity[BuffNum(4, 3)]*Sound[BuffNum(4, 3)]
+ExeVelocity[BuffNum(4, 4)]*Sound[BuffNum(4, 4)]
+ExeVelocity[BuffNum(4, 5)]*Sound[BuffNum(4, 5)];

assign PSoundUnit[5]
=ExeVelocity[BuffNum(5, 0)]*Sound[BuffNum(5, 0)]
+ExeVelocity[BuffNum(5, 1)]*Sound[BuffNum(5, 1)]
+ExeVelocity[BuffNum(5, 2)]*Sound[BuffNum(5, 2)]
+ExeVelocity[BuffNum(5, 3)]*Sound[BuffNum(5, 3)]
+ExeVelocity[BuffNum(5, 4)]*Sound[BuffNum(5, 4)]
+ExeVelocity[BuffNum(5, 5)]*Sound[BuffNum(5, 5)];



assign MSoundUnit[0]
=ExeVelocity[BuffNum(0, 0)]*(~Sound[BuffNum(0, 0)])
+ExeVelocity[BuffNum(0, 1)]*(~Sound[BuffNum(0, 1)])
+ExeVelocity[BuffNum(0, 2)]*(~Sound[BuffNum(0, 2)])
+ExeVelocity[BuffNum(0, 3)]*(~Sound[BuffNum(0, 3)])
+ExeVelocity[BuffNum(0, 4)]*(~Sound[BuffNum(0, 4)])
+ExeVelocity[BuffNum(0, 5)]*(~Sound[BuffNum(0, 5)]);

assign MSoundUnit[1]
=ExeVelocity[BuffNum(1, 0)]*(~Sound[BuffNum(1, 0)])
+ExeVelocity[BuffNum(1, 1)]*(~Sound[BuffNum(1, 1)])
+ExeVelocity[BuffNum(1, 2)]*(~Sound[BuffNum(1, 2)])
+ExeVelocity[BuffNum(1, 3)]*(~Sound[BuffNum(1, 3)])
+ExeVelocity[BuffNum(1, 4)]*(~Sound[BuffNum(1, 4)])
+ExeVelocity[BuffNum(1, 5)]*(~Sound[BuffNum(1, 5)]);

assign MSoundUnit[2]
=ExeVelocity[BuffNum(2, 0)]*(~Sound[BuffNum(2, 0)])
+ExeVelocity[BuffNum(2, 1)]*(~Sound[BuffNum(2, 1)])
+ExeVelocity[BuffNum(2, 2)]*(~Sound[BuffNum(2, 2)])
+ExeVelocity[BuffNum(2, 3)]*(~Sound[BuffNum(2, 3)])
+ExeVelocity[BuffNum(2, 4)]*(~Sound[BuffNum(2, 4)])
+ExeVelocity[BuffNum(2, 5)]*(~Sound[BuffNum(2, 5)]);

assign MSoundUnit[3]
=ExeVelocity[BuffNum(3, 0)]*(~Sound[BuffNum(3, 0)])
+ExeVelocity[BuffNum(3, 1)]*(~Sound[BuffNum(3, 1)])
+ExeVelocity[BuffNum(3, 2)]*(~Sound[BuffNum(3, 2)])
+ExeVelocity[BuffNum(3, 3)]*(~Sound[BuffNum(3, 3)])
+ExeVelocity[BuffNum(3, 4)]*(~Sound[BuffNum(3, 4)])
+ExeVelocity[BuffNum(3, 5)]*(~Sound[BuffNum(3, 5)]);

assign MSoundUnit[4]
=ExeVelocity[BuffNum(4, 0)]*(~Sound[BuffNum(4, 0)])
+ExeVelocity[BuffNum(4, 1)]*(~Sound[BuffNum(4, 1)])
+ExeVelocity[BuffNum(4, 2)]*(~Sound[BuffNum(4, 2)])
+ExeVelocity[BuffNum(4, 3)]*(~Sound[BuffNum(4, 3)])
+ExeVelocity[BuffNum(4, 4)]*(~Sound[BuffNum(4, 4)])
+ExeVelocity[BuffNum(4, 5)]*(~Sound[BuffNum(4, 5)]);

assign MSoundUnit[5]
=ExeVelocity[BuffNum(5, 0)]*(~Sound[BuffNum(5, 0)])
+ExeVelocity[BuffNum(5, 1)]*(~Sound[BuffNum(5, 1)])
+ExeVelocity[BuffNum(5, 2)]*(~Sound[BuffNum(5, 2)])
+ExeVelocity[BuffNum(5, 3)]*(~Sound[BuffNum(5, 3)])
+ExeVelocity[BuffNum(5, 4)]*(~Sound[BuffNum(5, 4)])
+ExeVelocity[BuffNum(5, 5)]*(~Sound[BuffNum(5, 5)]);


wire [9:0] duty[5:0];

SoundSynthesizer(XtalOut, PSoundUnit[0], MSoundUnit[0], DIR[0], duty[0]);
SoundSynthesizer(XtalOut, PSoundUnit[1], MSoundUnit[1], DIR[1], duty[1]);
SoundSynthesizer(XtalOut, PSoundUnit[2], MSoundUnit[2], DIR[2], duty[2]);
SoundSynthesizer(XtalOut, PSoundUnit[3], MSoundUnit[3], DIR[3], duty[3]);
SoundSynthesizer(XtalOut, PSoundUnit[4], MSoundUnit[4], DIR[4], duty[4]);
SoundSynthesizer(XtalOut, PSoundUnit[5], MSoundUnit[5], DIR[5], duty[5]);


PwmGenerator(XtalOut, duty[0], PWM[0]);
PwmGenerator(XtalOut, duty[1], PWM[1]);
PwmGenerator(XtalOut, duty[2], PWM[2]);
PwmGenerator(XtalOut, duty[3], PWM[3]);
PwmGenerator(XtalOut, duty[4], PWM[4]);
PwmGenerator(XtalOut, duty[5], PWM[5]);


endmodule




module UnitClockGenerator(XtalOut, RST, UnitClk, ClkOut);
input XtalOut;
input RST;
input [23:0] UnitClk;
output reg ClkOut;

reg [23:0] cnt;

always @(posedge XtalOut or negedge RST) begin
if(RST==0) begin
	cnt<=0;
	ClkOut<=1;
	end
else begin
	if(cnt<=UnitClk) begin
		if(cnt>=UnitClk) begin
			cnt<=0;
			ClkOut<=1;
			end
		else begin
			cnt<=cnt+1;
//			if(cnt==(UnitClk>>1)) begin
				ClkOut<=0;
//				end
			end
		end
	else begin
		cnt<=0;
		ClkOut<=0;
		end
	end
end

endmodule


module ExeRegSearch(XtalOut, DeviceNum, SwFlag, ExeReg);
input XtalOut;
input [2:0] DeviceNum;
input [35:0] SwFlag;
output reg [5:0] ExeReg;

wire num[5:0];
assign num[0]=DeviceNum*6+0;
assign num[1]=DeviceNum*6+1;
assign num[2]=DeviceNum*6+2;
assign num[3]=DeviceNum*6+3;
assign num[4]=DeviceNum*6+4;
assign num[5]=DeviceNum*6+5;

always @* begin
if(SwFlag[num[0]]==0) begin
	ExeReg<=num[0];
	end
else if(SwFlag[num[1]]==0) begin
	ExeReg<=num[1];
	end
else if(SwFlag[num[2]]==0) begin
	ExeReg<=num[2];
	end
else if(SwFlag[num[3]]==0) begin
	ExeReg<=num[3];
	end
else if(SwFlag[num[4]]==0) begin
	ExeReg<=num[4];
	end
else if(SwFlag[num[5]]==0) begin
	ExeReg<=num[5];
	end
else begin
	ExeReg<=num[0];
	end
end

endmodule

module SoundGenerator(XtalOut, SwFlag, height, Sound);
input XtalOut, SwFlag;
input [7:0] height;
output reg Sound;

reg [23:0] WaveNum;

always @(posedge SwFlag) begin
	case(height)
		0:
			WaveNum<=1223242;
		1:
			WaveNum<=1154468;
		2:
			WaveNum<=1089681;
		3:
			WaveNum<=1028521;
		4:
			WaveNum<=970780;
		5:
			WaveNum<=916338;
		6:
			WaveNum<=864902;
		7:
			WaveNum<=816327;
		8:
			WaveNum<=770535;
		9:
			WaveNum<=727273;
		10:
			WaveNum<=686436;
		11:
			WaveNum<=647920;
		12:
			WaveNum<=611546;
		13:
			WaveNum<=577234;
		14:
			WaveNum<=544840;
		15:
			WaveNum<=514271;
		16:
			WaveNum<=485390;
		17:
			WaveNum<=458148;
		18:
			WaveNum<=432432;
		19:
			WaveNum<=408163;
		20:
			WaveNum<=385253;
		21:
			WaveNum<=363636;
		22:
			WaveNum<=343230;
		23:
			WaveNum<=323960;
		24:
			WaveNum<=305782;
		25:
			WaveNum<=288617;
		26:
			WaveNum<=272420;
		27:
			WaveNum<=257129;
		28:
			WaveNum<=242701;
		29:
			WaveNum<=229074;
		30:
			WaveNum<=216221;
		31:
			WaveNum<=204086;
		32:
			WaveNum<=192630;
		33:
			WaveNum<=181818;
		34:
			WaveNum<=171615;
		35:
			WaveNum<=161983;
		36:
			WaveNum<=152891;
		37:
			WaveNum<=144308;
		38:
			WaveNum<=136210;
		39:
			WaveNum<=128564;
		40:
			WaveNum<=121349;
		41:
			WaveNum<=114538;
		42:
			WaveNum<=108109;
		43:
			WaveNum<=102042;
		44:
			WaveNum<=96311;
		45:
			WaveNum<=90909;
		46:
			WaveNum<=85807;
		47:
			WaveNum<=80991;
		48:
			WaveNum<=76447;
		49:
			WaveNum<=72155;
		50:
			WaveNum<=68106;
		51:
			WaveNum<=64284;
		52:
			WaveNum<=60676;
		53:
			WaveNum<=57270;
		54:
			WaveNum<=54054;
		55:
			WaveNum<=51020;
		56:
			WaveNum<=48158;
		57:
			WaveNum<=45455;
		58:
			WaveNum<=42904;
		59:
			WaveNum<=40496;
		60:
			WaveNum<=38222;
		61:
			WaveNum<=36078;
		62:
			WaveNum<=34053;
		63:
			WaveNum<=32141;
		64:
			WaveNum<=30337;
		65:
			WaveNum<=28634;
		66:
			WaveNum<=27028;
		67:
			WaveNum<=25510;
		68:
			WaveNum<=24079;
		69:
			WaveNum<=22727;
		70:
			WaveNum<=21452;
		71:
			WaveNum<=20248;
		72:
			WaveNum<=19111;
		73:
			WaveNum<=18038;
		74:
			WaveNum<=17026;
		75:
			WaveNum<=16071;
		76:
			WaveNum<=15169;
		77:
			WaveNum<=14317;
		78:
			WaveNum<=13514;
		79:
			WaveNum<=12755;
		80:
			WaveNum<=12039;
		81:
			WaveNum<=11364;
		82:
			WaveNum<=10726;
		83:
			WaveNum<=10124;
		84:
			WaveNum<=9556;
		85:
			WaveNum<=9019;
		86:
			WaveNum<=8513;
		87:
			WaveNum<=8035;
		88:
			WaveNum<=7584;
		89:
			WaveNum<=7159;
		90:
			WaveNum<=6757;
		91:
			WaveNum<=6378;
		92:
			WaveNum<=6020;
		93:
			WaveNum<=5682;
		94:
			WaveNum<=5363;
		95:
			WaveNum<=5062;
		96:
			WaveNum<=4778;
		97:
			WaveNum<=4510;
		98:
			WaveNum<=4257;
		99:
			WaveNum<=4018;
		100:
			WaveNum<=3792;
		101:
			WaveNum<=3579;
		102:
			WaveNum<=3378;
		103:
			WaveNum<=3189;
		104:
			WaveNum<=3010;
		105:
			WaveNum<=2841;
		106:
			WaveNum<=2681;
		107:
			WaveNum<=2531;
		108:
			WaveNum<=2389;
		109:
			WaveNum<=2255;
		110:
			WaveNum<=2128;
		111:
			WaveNum<=2009;
		112:
			WaveNum<=1896;
		113:
			WaveNum<=1790;
		114:
			WaveNum<=1689;
		115:
			WaveNum<=1594;
		116:
			WaveNum<=1505;
		117:
			WaveNum<=1420;
		118:
			WaveNum<=1341;
		119:
			WaveNum<=1265;
		120:
			WaveNum<=1194;
		121:
			WaveNum<=1127;
		122:
			WaveNum<=1064;
		123:
			WaveNum<=1004;
		124:
			WaveNum<=948;
		125:
			WaveNum<=895;
		126:
			WaveNum<=845;
		127:
			WaveNum<=797;
		default:
			WaveNum<=24'hFFFFFF;
		endcase
end


reg [23:0] cnt;

always @(posedge XtalOut) begin
if(SwFlag==1) begin
	if(cnt<=(WaveNum<<1)) begin
		if(cnt>=(WaveNum<<1)) begin
			cnt<=0;
			Sound<=1;
			end
		else begin
			cnt<=cnt+1;
			if(cnt==WaveNum) begin
				Sound<=0;
				end
			if(cnt==0) begin
				Sound<=1;
				end
			end
		end
	else begin
		cnt<=0;
		Sound<=1;
		end
	end
end

endmodule



module SoundSynthesizer(XtalOut, PSoundUnit, MSoundUnit, DIR, duty);
input XtalOut;
input [10:0] PSoundUnit, MSoundUnit;
output reg DIR;
output reg [9:0] duty;

always @* begin
	if(PSoundUnit>=MSoundUnit) begin
		DIR<=1;
		if(((PSoundUnit-MSoundUnit)<<2)>1000) begin
			duty<=1000;
			end
		else begin
			duty<=(PSoundUnit-MSoundUnit)<<2;
			end
		end
	else begin
		DIR<=0;
		if(((MSoundUnit-PSoundUnit)<<2)>1000) begin
			duty<=1000;
			end
		else begin
			duty<=(MSoundUnit-PSoundUnit)<<2;
			end
		end
end

endmodule



module PwmGenerator(XtalOut, duty, PwmOut);
input XtalOut;
input [9:0] duty;
output reg PwmOut;

reg [9:0] cnt;

always @(posedge XtalOut) begin
if(cnt<=1000) begin
	if(cnt>=1000) begin
		cnt<=0;
		PwmOut<=1;
		end
	else begin
		cnt<=cnt+1;
		if(cnt==duty) begin
			PwmOut<=0;
			end
		if(cnt==0) begin
			PwmOut<=1;
			end
		end
	end
else begin
	cnt<=0;
	PwmOut<=0;
	end
end

endmodule















