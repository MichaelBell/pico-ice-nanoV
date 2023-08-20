`define USE_PICO_EMU_RAM

module nanoV_top(
    input ICE_CLK,  // cpu_clk
    input ICE_PB,   // rstn

`ifndef USE_PICO_EMU_RAM
    input ICE_SI,   // spi_miso
    output ICE_SO,  // spi_mosi
    output ICE_SCK, // spi_clk_out
    output SRAM_SS, // spi_select
`else
    input ICE_20_G3,   // spi_miso
    output ICE_19,  // spi_mosi
    output ICE_26, // spi_clk_out
    output ICE_23, // spi_select
`endif
    output ICE_SSN, // Flash select

    input ICE_27,   // uart_rxd
    output ICE_25,  // uart_txd
    output ICE_21,  // uart_rts

    output ICE_4,   // out0
    output ICE_2,   // out1
    output ICE_47,  // out2
    output ICE_45,  // out3
    output ICE_3,   // out4
    output ICE_48,  // out5
    output ICE_46,  // out6
    output ICE_44_G6,  // out7

    input ICE_43,   // in0
    input ICE_38,   // in1
    input ICE_34,   // in2
    input ICE_31,   // in3
    input ICE_42,   // in4
    input ICE_36,   // in5
    input ICE_32,   // in6
    input ICE_28,   // in7

    output LED_R,
    output LED_G,
    output LED_B
);
    wire cpu_clk = ICE_CLK;
    wire rstn = ICE_PB;

`ifndef USE_PICO_EMU_RAM
    wire spi_miso = ICE_SI;
    wire spi_clk_out;
    assign ICE_SCK = spi_clk_out;
    reg spi_select, spi_mosi;
    assign ICE_SO = spi_mosi;
    assign SRAM_SS = spi_select;
`else
    wire spi_miso = ICE_20_G3;
    wire spi_clk_out;
    assign ICE_26 = spi_clk_out;
    reg spi_select, spi_mosi;
    assign ICE_19 = spi_mosi;
    assign ICE_23 = spi_select;
`endif
    assign ICE_SSN = 1'b1;

    wire uart_rxd = ICE_27;
    wire uart_txd, uart_rts;
    assign ICE_25 = uart_txd;
    assign ICE_21 = uart_rts;

    reg buffered_spi_in;
    wire spi_data_out, spi_select_out, spi_clk_enable;
    wire [31:0] data_in;
    wire [31:0] addr_out;
    wire [31:0] data_out;
    wire is_data, is_addr, is_data_in;
    nanoV_cpu nano(
        cpu_clk, 
        rstn, 
        buffered_spi_in, 
        spi_select_out, 
        spi_data_out, 
        spi_clk_enable, 
        data_in,
        addr_out, 
        data_out, 
        is_data, 
        is_addr,
        is_data_in);

    localparam PERI_NONE = 0;
    localparam PERI_LEDS = 1;
    localparam PERI_GPIO_OUT = 2;
    localparam PERI_GPIO_IN = 3;
    localparam PERI_UART = 4;
    localparam PERI_UART_STATUS = 5;
    localparam PERI_MUSIC = 6;

    reg [2:0] connect_peripheral;
    
    always @(posedge cpu_clk) begin
        if (!rstn) begin 
            connect_peripheral <= PERI_NONE;
        end
        else if (is_addr) begin
            if (addr_out == 32'h10000000) connect_peripheral <= PERI_GPIO_OUT;
            else if (addr_out == 32'h10000004) connect_peripheral <= PERI_GPIO_IN;
            else if (addr_out == 32'h10000008) connect_peripheral <= PERI_LEDS;
            else if (addr_out == 32'h10000010) connect_peripheral <= PERI_UART;
            else if (addr_out == 32'h10000014) connect_peripheral <= PERI_UART_STATUS;
            else if (addr_out == 32'h10000020) connect_peripheral <= PERI_MUSIC;
            else connect_peripheral <= PERI_NONE;
        end
    end

    reg [7:0] output_data;
    reg [2:0] led_data;
    always @(posedge cpu_clk) begin
        if (!rstn) begin
            led_data <= 0;
            output_data <= 0;
        end else if (is_data) begin
            if (connect_peripheral == PERI_LEDS) led_data <= data_out[2:0];
            else if (connect_peripheral == PERI_GPIO_OUT) output_data <= data_out[7:0];
        end
    end

    assign { ICE_44_G6, ICE_46, ICE_48, ICE_3, ICE_45, ICE_47, ICE_2, ICE_4 } = output_data;
    wire led_r, led_g, led_b;
    assign { led_r, led_g, led_b } = led_data;

    wire uart_tx_busy;
    wire uart_rx_valid;
    wire [7:0] uart_rx_data;
    assign data_in[31:8] = 0;
    assign data_in[7:0] = connect_peripheral == PERI_GPIO_OUT ? output_data :
                          connect_peripheral == PERI_GPIO_IN ? {ICE_28, ICE_32, ICE_36, ICE_42, ICE_31, ICE_34, ICE_38, ICE_43} :
                          connect_peripheral == PERI_LEDS ? {5'b0, led_data} :
                          connect_peripheral == PERI_UART ? uart_rx_data :
                          connect_peripheral == PERI_UART_STATUS ? {6'b0, uart_rx_valid, uart_tx_busy} : 0;

    wire uart_tx_start = is_data && connect_peripheral == PERI_UART;
    wire [7:0] uart_tx_data = data_out[7:0];

    uart_tx #(.CLK_HZ(16_000_000), .BIT_RATE(115_200)) i_uart_tx(
        .clk(cpu_clk),
        .resetn(rstn),
        .uart_txd(uart_txd),
        .uart_tx_en(uart_tx_start),
        .uart_tx_data(uart_tx_data),
        .uart_tx_busy(uart_tx_busy) 
    );

    uart_rx #(.CLK_HZ(16_000_000), .BIT_RATE(115_200)) i_uart_rx(
        .clk(cpu_clk),
        .resetn(rstn),
        .uart_rxd(uart_rxd),
        .uart_rts(uart_rts),
        .uart_rx_read(connect_peripheral == PERI_UART && is_data_in),
        .uart_rx_valid(uart_rx_valid),
        .uart_rx_data(uart_rx_data) 
    );

    // TODO: Probably need to use SB_IO directly for reading/writing with good timing
    always @(negedge cpu_clk) begin
        buffered_spi_in <= spi_miso;
    end

    always @(posedge cpu_clk) begin
`ifndef USE_PICO_EMU_RAM        
        if (!rstn)
            spi_select <= 0;
        else
            spi_select <= !spi_select_out;
`else
        if (!rstn)
            spi_select <= 1;
        else
            spi_select <= spi_select_out;
`endif

        spi_mosi <= spi_data_out;
    end

    assign spi_clk_out = !cpu_clk && spi_clk_enable;

    SB_RGBA_DRV #(
    .CURRENT_MODE("0b1"),       // half current
    .RGB0_CURRENT("0b000001"),  // 4 mA
    .RGB1_CURRENT("0b000001"),  // 4 mA
    .RGB2_CURRENT("0b000001")   // 4 mA
  ) rgba_drv (
    .CURREN(1'b1),
    .RGBLEDEN(1'b1),
    .RGB0(LED_G), .RGB0PWM(led_g),
    .RGB1(LED_B), .RGB1PWM(led_b),
    .RGB2(LED_R), .RGB2PWM(led_r)
  );

endmodule