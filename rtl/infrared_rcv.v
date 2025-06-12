
module infrared_rcv (
    input wire sys_clk,
    input wire sys_rst_n,
    input wire infrared_in,
    output reg [19:0] data,
    output reg repeat_en,
    output reg data_valid
);

    parameter CNT_0_56MS_MIN = 20000,
              CNT_0_56MS_MAX = 35000,
              CNT_1_69MS_MIN = 80000,
              CNT_1_69MS_MAX = 90000,
              CNT_2_25MS_MIN = 100000,
              CNT_2_25MS_MAX = 125000,
              CNT_4_5MS_MIN = 175000,
              CNT_4_5MS_MAX = 275000,
              CNT_9MS_MIN = 400000,
              CNT_9MS_MAX = 490000;

    parameter IDLE = 5'b00001,
              S_T9 = 5'b00010,
              S_JUDGE = 5'b00100,
              S_IFR_DATA = 5'b01000,
              S_REPEAT = 5'b10000;

    reg infrared_in_dly;
    wire ifr_in_fall = (infrared_in_dly && !infrared_in);
    wire ifr_in_rise = (!infrared_in_dly && infrared_in);

    reg [18:0] cnt;
    reg [4:0] state;
    reg [5:0] data_cnt;
    reg [31:0] data_tmp;

    always @(posedge sys_clk or negedge sys_rst_n)
        if (!sys_rst_n)
            infrared_in_dly <= 0;
        else
            infrared_in_dly <= infrared_in;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            cnt <= 0;
        else begin
            case (state)
                IDLE: cnt <= 0;
                S_T9, S_JUDGE, S_IFR_DATA:
                    if (ifr_in_rise || ifr_in_fall)
                        cnt <= 0;
                    else
                        cnt <= cnt + 1;
                default: cnt <= 0;
            endcase
        end
    end

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            state <= IDLE;
        else case (state)
            IDLE: if (ifr_in_fall) state <= S_T9;
            S_T9: if (ifr_in_rise) state <= (cnt >= CNT_9MS_MIN && cnt <= CNT_9MS_MAX) ? S_JUDGE : IDLE;
            S_JUDGE: if (ifr_in_fall)
                        if (cnt >= CNT_4_5MS_MIN && cnt <= CNT_4_5MS_MAX)
                            state <= S_IFR_DATA;
                        else if (cnt >= CNT_2_25MS_MIN && cnt <= CNT_2_25MS_MAX)
                            state <= S_REPEAT;
                        else
                            state <= IDLE;
            S_IFR_DATA: if (data_cnt == 6'd32) state <= IDLE;
            S_REPEAT: if (ifr_in_rise) state <= IDLE;
            default: state <= IDLE;
        endcase
    end

    always @(posedge sys_clk or negedge sys_rst_n)
        if (!sys_rst_n)
            data_cnt <= 0;
        else if (state == S_IFR_DATA && ifr_in_fall)
            data_cnt <= data_cnt + 1;
        else if (data_cnt == 6'd32)
            data_cnt <= 0;

    always @(posedge sys_clk or negedge sys_rst_n)
        if (!sys_rst_n)
            data_tmp <= 0;
        else if (state == S_IFR_DATA && ifr_in_fall) begin
            if (cnt >= CNT_1_69MS_MIN && cnt <= CNT_1_69MS_MAX)
                data_tmp <= {data_tmp[30:0], 1'b1};
            else if (cnt >= CNT_0_56MS_MIN && cnt <= CNT_0_56MS_MAX)
                data_tmp <= {data_tmp[30:0], 1'b0};
        end

    wire checks_ok = (data_tmp[23:16] == ~data_tmp[31:24]) && (data_tmp[7:0] == ~data_tmp[15:8]);

    always @(posedge sys_clk or negedge sys_rst_n)
        if (!sys_rst_n)
            data <= 0;
        else if (data_cnt == 6'd32 && checks_ok)
            data <= {12'b0, data_tmp[23:16]};

    always @(posedge sys_clk or negedge sys_rst_n)
        if (!sys_rst_n)
            repeat_en <= 0;
        else
            repeat_en <= (state == S_REPEAT && ifr_in_rise && (data_tmp[23:16] == ~data_tmp[31:24]));

    always @(posedge sys_clk or negedge sys_rst_n)
        if (!sys_rst_n)
            data_valid <= 0;
        else
            data_valid <= (data_cnt == 6'd32 && checks_ok);

endmodule
