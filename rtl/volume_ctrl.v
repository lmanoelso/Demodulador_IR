// Verilog 2001
module volume_ctrl (
    input wire clk,
    input wire rst_n,
    input wire [7:0] ir_cmd,
    input wire ir_valid,
    output reg [19:0] display_data,
    output reg show_volume  // Sinal para indicar que o volume deve ser exibido
);

    // Códigos IR relevantes
    localparam CMD_VOL_UP   = 8'h30;
    localparam CMD_VOL_DOWN = 8'h08;

    // Prefixo "V" para display (BCD 8421 = 13 para V)
    localparam [3:0] CHAR_V = 4'd13;

    // Volume e timer
    reg [6:0] volume; // 0–100
    reg [22:0] timer; // Controla tempo de exibição (~5s com clk de 50MHz)

    wire timer_done = (timer == 23'd0);

    // FSM simples para controlar tempo de exibição
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            volume <= 7'd50;
            timer <= 23'd0;
            show_volume <= 1'b0;
        end else begin
            if (ir_valid && (ir_cmd == CMD_VOL_UP || ir_cmd == CMD_VOL_DOWN)) begin
                if (ir_cmd == CMD_VOL_UP && volume < 7'd100)
                    volume <= volume + 1;
                else if (ir_cmd == CMD_VOL_DOWN && volume > 7'd0)
                    volume <= volume - 1;

                timer <= 23'd250_0000; // ~5s para clk de 50 MHz
                show_volume <= 1'b1;
            end else if (!timer_done && show_volume) begin
                timer <= timer - 1;
            end else begin
                show_volume <= 1'b0;
            end
        end
    end

    // Conversão para BCD
    wire [3:0] vol_hundreds = (volume / 100);
    wire [3:0] vol_tens     = (volume / 10) % 10;
    wire [3:0] vol_units    = volume % 10;

    always @(*) begin
        if (show_volume)
            display_data = {CHAR_V, 4'd0, vol_hundreds, vol_tens, vol_units};
        else
            display_data = 20'd0;
    end
    

endmodule


//Testbench
`timescale 1ns/1ps

module tb_volume_ctrl;

    reg clk;
    reg rst_n;
    reg [7:0] ir_cmd;
    reg ir_valid;
    wire [19:0] display_data;
    wire show_volume;

    // Instantiate the module
    volume_ctrl uut (
        .clk(clk),
        .rst_n(rst_n),
        .ir_cmd(ir_cmd),
        .ir_valid(ir_valid),
        .display_data(display_data),
        .show_volume(show_volume)
    );

    // Clock generation
    always #10 clk = ~clk;

    // Task para imprimir o conteúdo do display
    task print_display;
        input integer tempo;
        begin
            if (show_volume)
                $display("Tempo: %0t | Display: V%0d%0d", tempo, display_data[7:4], display_data[3:0]);
            else
                $display("Tempo: %0t | Display: Retorno ao Canal", tempo);
        end
    endtask

    // Simulação
    integer i;
    initial begin
        clk = 0;
        rst_n = 0;
        ir_cmd = 8'h00;
        ir_valid = 0;

        #50;
        rst_n = 1;

        // Aumenta de 50 até 100
        for (i = 0; i < 50; i = i + 1) begin
            ir_cmd = 8'h30; // Código fictício para VOLUME+
            ir_valid = 1;
            #20;
            ir_valid = 0;
            #1980;
            print_display($time);
        end

        // Diminui de 100 até 0
        for (i = 0; i < 100; i = i + 1) begin
            ir_cmd = 8'h08; // Código fictício para VOLUME-
            ir_valid = 1;
            #20;
            ir_valid = 0;
            #1980;
            print_display($time);
        end

        // Espera para verificar retorno ao canal
        for (i = 0; i < 10; i = i + 1) begin
            #2000;
            print_display($time);
        end

        $display("===== Fim da simulação =====");
        $stop;
    end

endmodule
