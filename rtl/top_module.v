// Versão ajustada do top_module.v com integração do volume_ctrl, channel_ctrl, invalid_cmd_display e controle de ir_valid

module top_module (
    input wire sys_clk,
    input wire sys_rst_n,
    input wire infrared_in,
    output wire [5:0] sel,
    output wire [7:0] seg,
    output wire led,
    output wire ser,       // Saída serial para 74HC164
    output wire clk_disp   // Clock serial para 74HC164
);

    wire repeat_en;
    wire [19:0] ir_data;
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
        .repeat_en(repeat_en),
        .data(ir_data)
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
    led_fsm led_fsm_inst (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .ir_cmd(ir_cmd),
        .ir_valid(ir_valid),
        .led_out(standby_led)
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


