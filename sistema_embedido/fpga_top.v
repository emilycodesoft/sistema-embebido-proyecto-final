module fpga_top (
    // Relojes
    input  wire CLOCK_50,           // reloj 50 MHz del DE1-SoC

    
    // UART
    input  wire UART_RXD,           // RX desde FT232
    output wire UART_TXD,           // TX hacia FT232 (eco)

    output wire       uart_valid,          // pulso cuando llega byte
	output wire       frame_error,         // Error en stop bits
	output wire [2:0] state,              // estado actual para debug solamente
    
    // LEDs de debug (opcionales)
    output wire [9:0] LEDR          // para ver estado
);

    // ========================================
    // Señales internas
    // ========================================
    
    // UART → BRAM
    wire [7:0] uart_data;           // byte recibido por UART
    
    // Contador de dirección para escritura
    reg [18:0] write_addr = 19'd0;  // 0 a 307199
    
    // Señal para VGA (preparada para futuro)
    wire [18:0] read_addr;          // dirección de lectura VGA
    wire [7:0]  pixel_data;         // dato leído desde BRAM

    // ========================================
    // Power-On Reset interno (no requiere pines)
    // Mantiene reset activo durante los primeros N ciclos
    //
    // Cómo exponer un `rst` externo (ejemplo):
    // - Si quieres un pin de reset, añade un puerto `input wire ext_rst`
    //   en la cabecera del módulo y mapea ese pin en el .qsf (ej. KEY0).
    // - Sincroniza la liberación del reset al reloj para evitar metaestabilidad:
    //     reg ext_rst_sync1, ext_rst_sync2;
    //     always @(posedge CLOCK_50) begin
    //         ext_rst_sync1 <= ext_rst;
    //         ext_rst_sync2 <= ext_rst_sync1;
    //     end
    // - Combina el reset externo sincronizado con el POR interno:
    //     wire global_rst = ext_rst_sync2 | por_rst; // activo alto
    // - Conecta `.rst(global_rst)` a las instancias (por ejemplo `uart_rx`).
    //
    // Nota: si prefieres no tocar pines usa el POR interno (`por_rst`) ya
    // añadido abajo. Si decides exponer `ext_rst` más tarde, solo añade el
    // puerto y la sincronización y conecta `global_rst` en lugar de `por_rst`.
    //
    // ¿Qué hace `por_rst` y cuánto dura?
    // - `por_rst` es una señal de reset activa-alto que se mantiene en '1'
    //   mientras `por_cnt != 0`.
    // - `por_cnt` se inicializa a 16'hFFFF y se decrementa cada flanco de
    //   `CLOCK_50`. Con reloj 50 MHz y valor 65535 la duración es aprox:
    //       65535 / 50e6 ≈ 1.31 ms
    // - Para cambiar la duración, ajusta el valor inicial de `por_cnt` o
    //   el ancho del contador (p. ej. 24 bits para más tiempo).
    // - Observación: la inicialización por HDL (`reg = 16'hFFFF`) suele
    //   ser aceptada por herramientas Intel/Altera, pero si quieres máxima
    //   portabilidad considera un mecanismo explícito de set-on-config.
    // ========================================
    reg [15:0] por_cnt = 16'hFFFF;
    wire por_rst = (por_cnt != 0);
    always @(posedge CLOCK_50) begin
        if (por_cnt != 0)
            por_cnt <= por_cnt - 1'b1;
    end
    
    // ========================================
    // Instancia UART FSM RX
    // ========================================
    uart_rx uart_module (
        .clk        (CLOCK_50),
        .rx_raw         (UART_RXD),
        .rst            (por_rst), // internal POR reset
        .data_out   (uart_data),
        .data_valid (uart_valid),
		.frame_error (frame_error),
		.state       (state)
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