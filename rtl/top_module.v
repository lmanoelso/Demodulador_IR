// Versão ajustada do top_module.v com integração do volume_ctrl, channel_ctrl, invalid_cmd_display e controle de ir_valid

module top_module (
    input wire sys_clk,
    input wire sys_rst_n,
    input wire infrared_in,
    input wire [19:0] test_ir_data,
    input wire test_repeat_en,

    //output wire [5:0] sel,
    //output wire [7:0] seg,
    output wire led,
    output wire ser,       // Saída serial para 74HC164
    output wire clk_disp   // Clock serial para 74HC164
);

    wire [19:0] ir_data_from_rcv;
    wire repeat_en_from_rcv;

    wire [19:0] ir_data = (test_ir_data !== 20'bx) ? test_ir_data : ir_data_from_rcv;
    wire repeat_en     = (test_ir_data !== 20'bx) ? test_repeat_en : repeat_en_from_rcv;
    wire [7:0] ir_cmd;
    wire ir_valid;
    wire standby_led;

    wire [19:0] channel_display;
    wire [19:0] volume_display;
    wire show_volume;

    wire [19:0] invalid_display;
    wire show_invalid;

    // Instancia o demodulador IR
    infrared_rcv infrared_rcv_inst (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .infrared_in(infrared_in),
        .repeat_en(repeat_en_from_rcv),
        .data(ir_data_from_rcv)
    );

    // Extração do comando IR
    assign ir_cmd = ir_data[7:0];

    // Geração do pulso ir_valid
    ir_valid_fsm ir_valid_fsm_inst (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .ir_data(ir_data),
        .repeat_en(repeat_en),
        .ir_valid(ir_valid)
    );

    // Controle do LED standby
    led_status_ctrl led_fsm_inst (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .ir_cmd(ir_cmd),
        .ir_valid(ir_valid),
        .led(standby_led)
    );

    assign led = standby_led;

    // Controle de Canal
    channel_ctrl channel_ctrl_inst (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .ir_cmd(ir_cmd),
        .ir_valid(ir_valid),
        .display_data(channel_display)
    );

    // Controle de Volume
    volume_ctrl volume_ctrl_inst (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .ir_cmd(ir_cmd),
        .ir_valid(ir_valid),
        .display_data(volume_display),
        .show_volume(show_volume)
    );

    // Exibição de comandos inválidos
    invalid_cmd_display invalid_cmd_display_inst (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .ir_cmd(ir_cmd),
        .ir_valid(ir_valid),
        .show_invalid(show_invalid),
        .display_data(invalid_display)
    );

    // Prioridade de exibição: inválido > volume > canal
    wire [19:0] active_display = (show_invalid) ? invalid_display :
                                 (show_volume)  ? volume_display  :
                                                   channel_display;

   /* // Módulo de display de 7 segmentos dinâmico
    seg_dynamic seg_dynamic_inst (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .data(active_display),
        .point(6'd0),
        .seg_en(1'b1),
        .sign(1'b0),
        .sel(sel),
        .seg(seg)
    );*/

    // Sinais internos
    wire [15:0] display_data_mux;
    wire ser_wire;
    wire clk_serial;

    assign display_data_mux = active_display[15:0];

    // Módulo do display serial com 74HC164
    serial_display_74hc164 display_serial_inst (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .bcd_data(display_data_mux),
        .ser(ser_wire),
        .clk_out(clk_serial)
    );

    // Redirecionamento de saídas
    assign ser      = ser_wire;
    assign clk_disp = clk_serial;

endmodule

`timescale 1ns / 1ps

module tb_top_module;

    reg sys_clk;
    reg sys_rst_n;
    reg infrared_in;
    reg [19:0] ir_data_tb;
    reg repeat_en_tb;

    wire [5:0] sel;
    wire [7:0] seg;
    wire led;
    wire ser;
    wire clk_disp;

    // Instancia o DUT com novas entradas de teste para ir_data e repeat_en
    top_module dut (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .infrared_in(infrared_in),
        .test_ir_data(ir_data_tb),
        .test_repeat_en(repeat_en_tb),
        .led(led),
        .ser(ser),
        .clk_disp(clk_disp)
    );

    // Clock de 10ns (100 MHz)
    initial sys_clk = 0;
    always #5 sys_clk = ~sys_clk;

    // Comandos IR simulados
    localparam CMD_POWER   = 8'h45;
    localparam CMD_VOL_UP  = 8'h40;
    localparam CMD_VOL_DN  = 8'h19;
    localparam CMD_CH_UP   = 8'h18;
    localparam CMD_CH_DN   = 8'h52;

    reg [7:0] command_sequence [0:9];
    integer i;

    initial begin
        command_sequence[0] = CMD_POWER;
        command_sequence[1] = CMD_CH_UP;
        command_sequence[2] = CMD_CH_UP;
        command_sequence[3] = CMD_CH_UP;
        command_sequence[4] = CMD_CH_DN;
        command_sequence[5] = CMD_CH_DN;
        command_sequence[6] = CMD_VOL_UP;
        command_sequence[7] = CMD_VOL_UP;
        command_sequence[8] = CMD_VOL_UP;
        command_sequence[9] = CMD_VOL_DN;
    end

    task send_ir_command;
        input [7:0] cmd;
        input is_repeat;
        begin
            ir_data_tb = {12'h000, cmd};
            repeat_en_tb = is_repeat;
            #20;
            ir_data_tb = 20'h00000;
            repeat_en_tb = 0;
            #200;
        end
    endtask

    function [31:0] seg_to_hex;
        input [7:0] seg_bits;
        begin
            case (seg_bits)
                8'b11000000: seg_to_hex = 8'h00;
                8'b11111001: seg_to_hex = 8'h01;
                8'b10100100: seg_to_hex = 8'h02;
                8'b10110000: seg_to_hex = 8'h03;
                8'b10011001: seg_to_hex = 8'h04;
                8'b10010010: seg_to_hex = 8'h05;
                8'b10000010: seg_to_hex = 8'h06;
                8'b11111000: seg_to_hex = 8'h07;
                8'b10000000: seg_to_hex = 8'h08;
                8'b10010000: seg_to_hex = 8'h09;
                default:     seg_to_hex = 8'hXX;
            endcase
        end
    endfunction

    initial begin
        $display("Iniciando teste do top_module...\n");
        $display("Sinal Enviado | Sinal Lido | Display 7seg | LED");

        sys_rst_n = 0;
        infrared_in = 0;
        ir_data_tb = 0;
        repeat_en_tb = 0;
        #50;
        sys_rst_n = 1;

        for (i = 0; i < 10; i = i + 1) begin
            send_ir_command(command_sequence[i], 0);
            #100; // Espera a atualização dos sinais internos
            $display("     0x%02X     |    0x%02X   |     0x%02X     |  %s",
                command_sequence[i],
                dut.ir_data[7:0],
                seg_to_hex(seg),
                led ? "ON" : "OFF");
        end

        send_ir_command(CMD_POWER, 0);
        #100;
        $display("     0x%02X     |    0x%02X   |     0x%02X     |  %s",
            CMD_POWER,
            dut.ir_data[7:0],
            seg_to_hex(seg),
            led ? "ON" : "OFF");

        #500;
        $display("\nFim da simulação.");
        $finish;
    end

endmodule
