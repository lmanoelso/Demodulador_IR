// Verilog 2001
module channel_ctrl(
    input wire clk,
    input wire rst_n,
    input wire [7:0] ir_cmd,
    input wire ir_valid,
    output reg [19:0] display_data
);

    // Códigos IR relevantes
    localparam CMD_POWER    = 8'h80;
    localparam CMD_CH_PLUS  = 8'h18;
    localparam CMD_CH_MINUS = 8'h38;

    // Estados como parâmetros (Verilog 2001 compatível)
    localparam STATE_OFF = 2'b00;
    localparam STATE_ON  = 2'b01;

    reg [1:0] state;
    reg [6:0] channel; // Canal atual (1 a 64)

    // Prefixo "C" para display (BCD 8421 = 12 para C)
    localparam [3:0] CHAR_C = 4'd12;

    // Atualiza estado e canal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_OFF;
            channel <= 7'd1;
        end else if (ir_valid) begin
            case (state)
                STATE_OFF: begin
                    if (ir_cmd == CMD_POWER)
                        state <= STATE_ON;
                end
                STATE_ON: begin
                    case (ir_cmd)
                        CMD_CH_PLUS: begin
                            if (channel < 7'd64)
                                channel <= channel + 1;
                        end
                        CMD_CH_MINUS: begin
                            if (channel > 7'd1)
                                channel <= channel - 1;
                        end
                    endcase
                end
            endcase
        end
    end

    // Atualiza display_data com canal
    wire [3:0] ch_tens  = (channel / 10) % 10;
    wire [3:0] ch_units = channel % 10;

    always @(*) begin
        if (state == STATE_ON)
            display_data = {CHAR_C, 4'd0, 4'd0, ch_tens, ch_units};
        else
            display_data = 20'd0; // Desliga display
    end

endmodule


`timescale 1ns / 1ps

module tb_channel_ctrl;

    reg clk;
    reg rst_n;
    reg [7:0] ir_cmd;
    reg ir_valid;
    wire [19:0] display_data;

    // DUT
    channel_ctrl uut (
        .clk(clk),
        .rst_n(rst_n),
        .ir_cmd(ir_cmd),
        .ir_valid(ir_valid),
        .display_data(display_data)
    );

    // Clock de 50 MHz
    always #10 clk = ~clk;

    // Task para envio de comando IR
    task send_ir_cmd;
        input [7:0] cmd;
        begin
            ir_cmd = cmd;
            ir_valid = 1;
            #20;
            ir_valid = 0;
        end
    endtask

    // Decodifica e exibe o conteúdo do display_data
    always @(posedge clk) begin
        if (uut.state == 1) begin  // STATE_ON
            $display("Tempo: %0t | Display: %s%0d%0d",
                $time,
                (display_data[19:16] == 4'd12) ? "C" : "?",
                display_data[7:4],
                display_data[3:0]
            );
        end else begin
            $display("Tempo: %0t | Display: [DESLIGADO]", $time);
        end
    end

    initial begin
        $display("===== Teste do Controle de Canal =====");
        clk = 0;
        rst_n = 0;
        ir_cmd = 0;
        ir_valid = 0;

        #50;
        rst_n = 1;

        // POWER ON → Canal 1
        send_ir_cmd(8'h45);
        #100;

        // CH+ → Canal 2
        send_ir_cmd(8'h18);
        #100;

        // CH+ → Canal 3
        send_ir_cmd(8'h18);
        #100;

        // CH- → Canal 2
        send_ir_cmd(8'h52);
        #100;

        // CH- → Canal 1
        send_ir_cmd(8'h52);
        #100;

        // CH- → permanece Canal 1
        send_ir_cmd(8'h52);
        #100;

        // CH+ até canal 10
        repeat (9) begin
            send_ir_cmd(8'h18);
            #100;
        end

        $display("===== Fim do Teste =====");
        $stop;
    end

endmodule

