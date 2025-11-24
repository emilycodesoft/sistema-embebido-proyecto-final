module fpga_top (
    input  wire clk,       // reloj de la FPGA
    input  wire uart_rx,   // RX desde FT232
    output wire uart_tx    // TX hacia FT232 (eco si quieres más adelante)
);

    // ---------------------------------------------------
    // Señales UART FSM
    // ---------------------------------------------------
    wire [7:0] uart_data;
    wire       data_valid;

    uart_fsm uart0 (
        .clk(clk),
        .rx(uart_rx),
        .tx(uart_tx),      // eco, si tu FSM lo tiene
        .data_out(uart_data),
        .data_valid(data_valid)
    );

    // ---------------------------------------------------
    // Señales BRAM
    // ---------------------------------------------------
    reg  [15:0] bram_addr = 0;   // 38400 direcciones aprox para 640x480
    reg  [7:0]  bram_data = 0;
    reg         bram_we = 0;
    wire [7:0]  bram_q;

    blk_mem_gen_0 bram_image (
        .clka(clk),
        .ena(1'b1),
        .wea(bram_we),
        .addra(bram_addr),
        .dina(bram_data),
        .douta(bram_q)
    );

    // ---------------------------------------------------
    // Control escritura BRAM
    // ---------------------------------------------------
    always @(posedge clk) begin
        if (data_valid) begin
            bram_data <= uart_data;
            bram_we   <= 1;
            bram_addr <= bram_addr + 1;
        end else begin
            bram_we <= 0;
        end
    end

endmodule
