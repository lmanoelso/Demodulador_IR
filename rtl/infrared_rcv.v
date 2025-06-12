module infrared_rcv (
    input wire sys_clk,
    input wire sys_rst_n,
    input wire infrared_in,
    output reg [19:0] data,
    output reg repeat_en
);

    // parameter define
    parameter CNT_0_56MS_MIN = 20000,   // 0.56ms count from 0~27999
        CNT_0_56MS_MAX = 35000,
        CNT_1_69MS_MIN = 80000,         // 1.69ms count from 0~84499
        CNT_1_69MS_MAX = 90000,
        CNT_2_25MS_MIN = 100000,        // 2.25ms count from 0~112499
        CNT_2_25MS_MAX = 125000,
        CNT_4_5MS_MIN = 175000,         // 4.5ms count from 0~224999
        CNT_4_5MS_MAX = 275000,
        CNT_9MS_MIN = 400000,           // 9ms count from 0~449999
        CNT_9MS_MAX = 490000;

    // state
    parameter IDLE = 5'b0_0001,
             S_T9 = 5'b0_0010,
            S_JUDGE = 5'b0_0100,
            S_IFR_DATA = 5'b0_1000,
            S_REPEAT = 5'b1_0000;

    reg infrared_in_dly;
    wire ifr_in_fall;
    wire ifr_in_rise;
    reg [18:0] cnt;
    reg [4:0] state;
    reg [5:0] data_cnt;
    reg [31:0] data_tmp;

    // infrared_in_dly: infrared_in 1 clk cycle delayed.
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (sys_rst_n == 1'b0)
            infrared_in_dly <= 1'b0;
        else 
            infrared_in_dly <= infrared_in;
    end

    // ifr_in_fall: flag signal, detect the negedge of infrared_in
    assign ifr_in_fall = ((infrared_in_dly == 1'b1) && (infrared_in == 1'b0)) ? 1'b1 : 1'b0;

    // ifr_in_rise: flag signal, detect the posedge of infrared_in
    assign ifr_in_rise = ((infrared_in_dly == 1'b0) && (infrared_in == 1'b1)) ? 1'b1 : 1'b0;    

    // cnt: output of FSM
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (sys_rst_n == 1'b0)
            cnt <= 19'd0;
        else
            case (state)
                IDLE:   cnt <= 19'd0;

                S_T9:   if ((ifr_in_rise == 1'b1) && ((cnt >= CNT_9MS_MIN) && (cnt <= CNT_9MS_MAX)))
                            cnt <= 19'd0;
                        else 
                            cnt <= cnt + 1'b1;

                S_JUDGE:    if ((ifr_in_fall == 1'b1) && (((cnt >= CNT_4_5MS_MIN) && (cnt <= CNT_4_5MS_MAX)) || ((cnt >= CNT_2_25MS_MIN) && (cnt <= CNT_2_25MS_MAX))))
                                cnt <= 19'd0;
                            else
                                cnt <= cnt + 1'b1;
                        
                S_IFR_DATA: if ((ifr_in_rise == 1'b1) && ((cnt >= CNT_0_56MS_MIN) && (cnt <= CNT_0_56MS_MAX)))
                                cnt <= 19'd0;
                            else if ((ifr_in_fall == 1'b1) && (((cnt >= CNT_0_56MS_MIN) && (cnt <= CNT_0_56MS_MAX)) || ((cnt >= CNT_1_69MS_MIN) && (cnt <= CNT_1_69MS_MAX))))
                                cnt <= 19'd0;
                            else 
                                cnt <= cnt + 1'b1;
                            
                default:    cnt <= 19'd0;
            endcase
    end

    // state transition
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (sys_rst_n == 1'b0)
            state <= IDLE;
        else
            case (state)
                IDLE:   if (ifr_in_fall == 1'b1)
                            state <= S_T9;
                        else
                            state <= IDLE;               
                
                S_T9:   if ((ifr_in_rise == 1'b1) && ((cnt < CNT_9MS_MIN) || (cnt > CNT_9MS_MAX)))
                            state <= IDLE;
                        else if ((ifr_in_rise == 1'b1) && ((cnt >= CNT_9MS_MIN) && (cnt <= CNT_9MS_MAX)))
                            state <= S_JUDGE;
                        else 
                            state <= S_T9;

                S_JUDGE:    if ((ifr_in_fall == 1'b1) && ((cnt >= CNT_4_5MS_MIN) && (cnt <= CNT_4_5MS_MAX)))
                                state <= S_IFR_DATA;
                            else if ((ifr_in_fall == 1'b1) && ((cnt >= CNT_2_25MS_MIN) && (cnt <= CNT_2_25MS_MAX)))
                                state <= S_REPEAT;
                            else if ((ifr_in_fall == 1'b1) && ((cnt < CNT_2_25MS_MIN) || ((cnt > CNT_2_25MS_MAX) && (cnt < CNT_4_5MS_MIN)) || (cnt > CNT_4_5MS_MAX)))
                                state <= IDLE;
                            else 
                                state <= S_JUDGE;
                
                S_IFR_DATA: if ((ifr_in_rise == 1'b1) && ((cnt < CNT_0_56MS_MIN) || (cnt > CNT_0_56MS_MAX)))
                                state <= IDLE;
                            else if ((ifr_in_fall == 1'b1) && ((cnt < CNT_0_56MS_MIN) || ((cnt > CNT_0_56MS_MAX) && (cnt < CNT_1_69MS_MIN)) || (cnt > CNT_1_69MS_MAX)))
                                state <= IDLE;
                            else if (ifr_in_rise == 1'b1 && data_cnt == 6'd32) 
                                state <= IDLE;
                            else 
                                state <= S_IFR_DATA;

                S_REPEAT:   if (ifr_in_rise == 1'b1)
                                state <= IDLE;
                            else
                                state <= S_REPEAT;

                default:    state <= IDLE;
            endcase 
    end

    // data_cnt: count the amount(32) of data in Address and Command
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (sys_rst_n == 1'b0)
            data_cnt <= 6'd0;
        else if ((ifr_in_rise == 1'b1) && (data_cnt == 6'd32))
            data_cnt <= 6'd0;
        else if ((state == S_IFR_DATA) && (ifr_in_fall == 1'b1))
            data_cnt <= data_cnt + 1'b1;
    end

    // data_tmp: store 32 bit data in Address and command
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (sys_rst_n == 1'b0)
            data_tmp <= 32'b0;
        else if ((state == S_IFR_DATA) && (ifr_in_fall == 1'b1) && (cnt >= CNT_0_56MS_MIN && cnt <= CNT_0_56MS_MAX))
            data_tmp[data_cnt] <= 1'b0;
        else if ((state == S_IFR_DATA) && (ifr_in_fall == 1'b1) && (cnt >= CNT_1_69MS_MIN && cnt <= CNT_1_69MS_MAX))
            data_tmp[data_cnt] <= 1'b1;
    end

    // repeat_en: When push the buttom too long, it will generate repeat code. Repeat code can fire repeat_en signal.
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (sys_rst_n == 1'b0)
            repeat_en <= 1'b0;
        else if (state == S_REPEAT && (data_tmp[23:16] == ~data_tmp[31:24]))
            repeat_en <= 1'b1;
        else 
            repeat_en <= 1'b0;
    end

    // data
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (sys_rst_n == 1'b0)
            data <= 20'b0;
        else if (data_cnt == 6'd32 && data_tmp[23:16] == ~data_tmp[31:24] && data_tmp[7:0] == ~data_tmp[15:8])
            data <= {12'b0, data_tmp[23:16]};
    end
    
endmodule


`timescale 1ns / 1ps

module tb_infrared_rcv;

    reg sys_clk;
    reg sys_rst_n;
    reg infrared_in;
    wire [19:0] data;
    wire repeat_en;

    infrared_rcv uut (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .infrared_in(infrared_in),
        .data(data),
        .repeat_en(repeat_en)
    );

    // Clock 50 MHz
    always #10 sys_clk = ~sys_clk;

    initial begin
        sys_clk = 1;
        sys_rst_n = 0;
        infrared_in = 1;
        #100;
        sys_rst_n = 1;
        #100;

        // Enviar frame NEC para POWER ON (0x807F)
        send_nec(8'h4D, 8'h80);
        #50_000_000;
        $display("Comando decodificado: %h", data);
        $stop;
    end

    // Task para bit NEC
    task send_bit;
        input value;
        begin
            infrared_in = 0; #560_000;
            infrared_in = 1;
            if (value) #1690_000;
            else       #560_000;
        end
    endtask

    // Task para byte
    task send_byte;
        input [7:0] byte_val;
        integer i;
        begin
            for (i = 0; i < 8; i = i + 1)
                send_bit(byte_val[i]);
        end
    endtask

    // Task para frame NEC
    task send_nec;
        input [7:0] addr;
        input [7:0] cmd;
        reg [7:0] addr_inv, cmd_inv;
        begin
            addr_inv = ~addr;
            cmd_inv = ~cmd;
            // start
            infrared_in = 0; #9000_000;
            infrared_in = 1; #4500_000;
            // dados
            send_byte(addr);
            send_byte(addr_inv);
            send_byte(cmd);
            send_byte(cmd_inv);
            // pulso final
            infrared_in = 0; #560_000;
            infrared_in = 1;
        end
    endtask

endmodule
