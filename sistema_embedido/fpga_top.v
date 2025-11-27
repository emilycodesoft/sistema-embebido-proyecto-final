module fpga_top (
    // Relojes
    input  wire CLOCK_50,           // reloj 50 MHz del DE1-SoC
    
    // UART
    input  wire UART_RXD,           // RX desde FT232
    output wire UART_TXD,           // TX hacia FT232 (eco)
    
    // LEDs de debug (opcionales)
    output wire [9:0] LEDR          // para ver estado
);

    // ========================================
    // Señales internas
    // ========================================
    
    // UART → BRAM
    wire [7:0] uart_data;           // byte recibido por UART
    wire       uart_valid;          // pulso cuando llega byte
	 wire       frame_error;          // Error en stop bits
    
    // Contador de dirección para escritura
    reg [18:0] write_addr = 19'd0;  // 0 a 307199
    
    // Señal para VGA (preparada para futuro)
    wire [18:0] read_addr;          // dirección de lectura VGA
    wire [7:0]  pixel_data;         // dato leído desde BRAM
    
    // ========================================
    // Instancia UART FSM RX
    // ========================================
    uart_rx uart_module (
        .clk        (CLOCK_50),
        .rx_raw         (UART_RXD),
        .data_out   (uart_data),
        .data_valid (uart_valid),
		  .frame_error (frame_error)
    );
    
    // ========================================
    // Control de escritura en BRAM
    // ========================================
    always @(posedge CLOCK_50) begin
        if (uart_valid) begin
            write_addr <= write_addr + 1'b1;
            
            // Reset al completar la imagen
            if (write_addr == 19'd307199)
                write_addr <= 19'd0;
        end
    end
    
    // ========================================
    // Instancia BRAM (RAM 2-PORT)
    // ========================================
    ram_2port bram_image (
        // Puerto de ESCRITURA (UART)
        .data      (uart_data),     // byte recibido
        .wraddress (write_addr),    // dirección secuencial
        .wrclock   (CLOCK_50),      // reloj 50 MHz
        .wren      (uart_valid),    // escribir cuando llega byte
        
        // Puerto de LECTURA (VGA - por ahora en 0)
        .rdaddress (read_addr),     // dirección de lectura
        .rdclock   (CLOCK_50),      // reloj pixel (por ahora 50MHz)
        .q         (pixel_data)     // pixel leído
    );
    
    // ========================================
    // Temporalmente: lectura en 0 (sin VGA aún)
    // ========================================
    assign read_addr = 19'd0;
    
    // ========================================
    // Debug LEDs
    // ========================================
    // Mostrar los últimos 8 bits recibidos + estado
    assign LEDR[7:0] = uart_data;
    assign LEDR[8]   = uart_valid;
    assign LEDR[9]   = (write_addr > 19'd0); // indica si se ha escrito algo

endmodule