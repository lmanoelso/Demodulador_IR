module top_module (
    input wire sys_clk,
    input wire sys_rst_n,
    input wire infrared_in,
    output wire [5:0] sel,
    output wire [7:0] seg,
    output wire led
);

    wire repeat_en;
    wire [19:0] ir_data;
    wire [7:0] ir_cmd;
    wire [19:0] display_data;

    // Instância do receptor IR
    infrared_rcv infrared_rcv_inst (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .infrared_in(infrared_in),
        .repeat_en(repeat_en),
        .data(ir_data)
    );

    // Separar o comando do pacote IR (assumimos que comando está em bits [15:8])
    assign ir_cmd = ir_data[15:8];

    // Instância do controle de LED (standby)
    led_status_ctrl led_status_ctrl_inst (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .ir_cmd(ir_cmd),
        .ir_valid(repeat_en),
        .led(led)
    );

    // Instância do controle de canal
    channel_ctrl channel_ctrl_inst (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .ir_cmd(ir_cmd),
        .ir_valid(repeat_en),
        .display_data(display_data)
    );

    // Instância do display dinâmico
    seg_dynamic seg_dynamic_inst (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .data(display_data),
        .point(6'd0),
        .seg_en(1'b1),
        .sign(1'b0),
        .sel(sel),
        .seg(seg)
    );

endmodule
