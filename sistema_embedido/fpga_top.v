// ============================================================================
// Módulo: fpga_top
// Descripción: Sistema completo UART → BRAM → VGA
// ============================================================================

module fpga_top (
    // Reloj
    input  wire CLOCK_50,           // Reloj 50 MHz del DE1-SoC

    // Botones e interruptores
    input  wire [3:0] KEY,          // Botones para cursor (activos en bajo)
    input  wire [3:0] SW,           // SW[0]=enable pintar, SW[3:1]=color RGB

    // UART
    input  wire UART_RXD,           // RX desde FT232
    output wire UART_TXD,           // TX hacia FT232 (eco)
    output wire       uart_valid,          // pulso cuando llega byte
	output wire       frame_error,         // Error en stop bits
	output wire [2:0] state,              // estado actual para debug solamente


    // VGA
    output wire VGA_HS,             // Hsync
    output wire VGA_VS,             // Vsync
    output wire [3:0] VGA_R,        // Rojo
    output wire [3:0] VGA_G,        // Verde
    output wire [3:0] VGA_B,        // Azul
    
    // LEDs de debug (opcionales)
    output wire [9:0] LEDR          // para ver estado
);

    // ========================================
    // Power-On Reset interno (no requiere pines)
    // Mantiene reset activo durante los primeros N ciclos
    // `reset` es un reset interno activo-alto (~1.3 ms) tras encender.
    // Dura mientras `por_cnt != 0` (inicializado en 16'hFFFF).
    // ========================================
    reg [15:0] por_cnt = 16'hFFFF;
    wire reset = (por_cnt != 0);
    always @(posedge CLOCK_50) begin
        if (por_cnt != 0)
            por_cnt <= por_cnt - 1'b1;
    end

    // ========================================================================
    // Clock 25 MHz para VGA
    // ========================================================================
    wire clk_25mhz;
    
    clk_divider clk_div (
        .clk_50mhz  (CLOCK_50),
        .reset      (reset),
        .clk_25mhz  (clk_25mhz)
    );

    // ========================================================================
    // Señales UART → BRAM
    // ========================================================================
    wire [7:0] uart_data;           // byte recibido por UART
    
    // ========================================================================
    // Señales Cursor → BRAM
    // ========================================================================
    wire [9:0]  cursor_x;
    wire [9:0]  cursor_y;
    wire        cursor_write_en;
    wire [18:0] cursor_addr;
    wire [7:0]  cursor_data;
    
    // ========================================
    // Instancia UART FSM (RX + TX con eco)
    // ========================================
    uart_fsm uart_module (
        .clk        (CLOCK_50),
        .rst        (reset),        // internal POR reset
        .rx_raw     (UART_RXD),
        .tx         (UART_TXD),
        .data_out   (uart_data),
        .data_valid (uart_valid),
        .frame_error (frame_error),
        .rx_state    (state)
    );
    
    // ========================================
    // Instancia Control de Cursor
    // ========================================
    cursor_control cursor_ctrl (
        .clk            (CLOCK_50),
        .reset          (reset),
        .KEY            (KEY),
        .SW             (SW),
        .cursor_x       (cursor_x),
        .cursor_y       (cursor_y),
        .cursor_write_en(cursor_write_en),
        .cursor_addr    (cursor_addr),
        .cursor_data    (cursor_data)
    );

     // Contador de dirección para escritura UART
    reg [18:0] write_addr = 19'd0;  // 0 a 307199
    
    // ========================================
    // Control de escritura en BRAM (UART)
    // ========================================
    always @(posedge CLOCK_50) begin
        if (reset) begin
            write_addr <= 19'd0;
        end else if (uart_valid) begin
            write_addr <= write_addr + 1'b1;
            
            // Reset al completar imagen
            if (write_addr == 19'd307199)
                write_addr <= 19'd0;
        end
    end
    
    // ========================================
    // Multiplexor de escritura BRAM
    // Prioridad: UART > Cursor
    // ========================================
    wire [18:0] bram_wr_addr;
    wire [7:0]  bram_wr_data;
    wire        bram_wr_en;
    
    assign bram_wr_addr = uart_valid ? write_addr : cursor_addr;
    assign bram_wr_data = uart_valid ? uart_data  : cursor_data;
    assign bram_wr_en   = uart_valid | cursor_write_en;


    // ========================================================================
    // Señales VGA → BRAM
    // ========================================================================
    wire [9:0]  hcount;
    wire [9:0]  vcount;
    wire        display_enable;
    wire [18:0] read_addr; // dirección de lectura VGA
    wire [7:0]  pixel_data; // dato leído desde BRAM
    
    // VGA Controller
    vga_controller vga_ctrl (
        .clk_25mhz      (clk_25mhz),
        .reset          (reset),
        .hsync          (VGA_HS),
        .vsync          (VGA_VS),
        .display_enable (display_enable),
        .hcount         (hcount),
        .vcount         (vcount)
    );
    
    // VGA Image Display
    vga_image_display vga_img (
        .clk_25mhz      (clk_25mhz),
        .reset          (reset),
        .display_enable (display_enable),
        .hcount         (hcount),
        .vcount         (vcount),
        .cursor_x       (cursor_x),
        .cursor_y       (cursor_y),
        .bram_addr      (read_addr),
        .bram_data      (pixel_data),
        .vga_r          (VGA_R),
        .vga_g          (VGA_G),
        .vga_b          (VGA_B)
    );

    
    // ========================================
    // Instancia BRAM Dual-Port (RAM 2-PORT)
    // ========================================
    ram_2port bram_image (
        // Puerto de ESCRITURA (UART o Cursor)
        .data      (bram_wr_data),  // dato multiplexado
        .wraddress (bram_wr_addr),  // dirección multiplexada
        .wrclock   (CLOCK_50),      // reloj 50 MHz
        .wren      (bram_wr_en),    // enable multiplexado
        
        // Puerto de LECTURA (VGA)
        .rdaddress (read_addr),     // dirección de lectura
        .rdclock   (CLOCK_50),      // reloj pixel
        .q         (pixel_data)     // pixel leído
    );

    
    // ========================================
    // Debug LEDs
    // ========================================
    // Mostrar los últimos 8 bits recibidos + estado
    assign LEDR[7:0] = uart_data;
    assign LEDR[8]   = uart_valid;
    assign LEDR[9]   = (write_addr > 19'd0); // indica si se ha escrito algo

endmodule