// ============================================================================
// Módulo: vga_image_display (VERSIÓN RGB111 - COLOR + CURSOR)
// Descripción: Lee imagen RGB111 de BRAM y genera señales RGB con cursor
// ============================================================================

module vga_image_display (
    input  wire clk_25mhz,
    input  wire reset,
    
    // Desde VGA controller
    input  wire display_enable,
    input  wire [9:0] hcount,
    input  wire [9:0] vcount,
    
    // Posición del cursor
    input  wire [9:0] cursor_x,
    input  wire [9:0] cursor_y,
    
    // Hacia BRAM (puerto de lectura)
    output wire [18:0] bram_addr,
    input  wire [7:0] bram_data,
    
    // Salidas RGB
    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b
);

    // ========================================================================
    // Generador de parpadeo del cursor (~2 Hz)
    // ========================================================================
    localparam BLINK_PERIOD = 25_000_000 / 2;  // 25 MHz / 2 = 0.5 segundos
    
    reg [24:0] blink_counter = 0;
    reg        cursor_visible = 0;
    
    always @(posedge clk_25mhz) begin
        if (reset) begin
            blink_counter  <= 0;
            cursor_visible <= 0;
        end else begin
            if (blink_counter == BLINK_PERIOD - 1) begin
                blink_counter  <= 0;
                cursor_visible <= ~cursor_visible;  // Toggle cada 0.5s
            end else begin
                blink_counter <= blink_counter + 1;
            end
        end
    end
    
    // ========================================================================
    // Detección de posición del cursor
    // ========================================================================
    wire at_cursor = (hcount == cursor_x) && (vcount == cursor_y);
    wire show_cursor = at_cursor && cursor_visible && display_enable;

    // ========================================================================
    // Cálculo de dirección BRAM (igual que antes)
    // ========================================================================
    wire [9:0] x_pos = hcount;
    wire [9:0] y_pos = vcount;
    
    wire [18:0] addr_calc = (y_pos << 9) + (y_pos << 7) + x_pos;
    
    reg [18:0] addr_reg = 0;
    
    always @(posedge clk_25mhz) begin
        if (display_enable)
            addr_reg <= addr_calc;
        else
            addr_reg <= 0;
    end
    
    assign bram_addr = addr_reg;
    
    // ========================================================================
    // Extracción de bits RGB111 (NUEVO)
    // ========================================================================
    // Formato: byte = 00000RGB
    //                      │││
    //                      ││└─ B (bit 0)
    //                      │└── G (bit 1)
    //                      └─── R (bit 2)
    
    wire bit_r = bram_data[2];  // Bit rojo
    wire bit_g = bram_data[1];  // Bit verde
    wire bit_b = bram_data[0];  // Bit azul
    
    // ========================================================================
    // Expandir 1 bit → 8 bits por canal
    // ========================================================================
    // Opción A: 0 → 00000000, 1 → 11111111 (máximo contraste)
    wire [7:0] red_value   = bit_r ? 8'b11111111 : 8'b00000000;
    wire [7:0] green_value = bit_g ? 8'b11111111 : 8'b00000000;
    wire [7:0] blue_value  = bit_b ? 8'b11111111 : 8'b00000000;
    
    // ========================================================================
    // Invertir color cuando el cursor está visible
    // ========================================================================
    wire [7:0] red_final   = show_cursor ? ~red_value   : red_value;
    wire [7:0] green_final = show_cursor ? ~green_value : green_value;
    wire [7:0] blue_final  = show_cursor ? ~blue_value  : blue_value;
    
    // ========================================================================
    // Salidas RGB (con display_enable)
    // ========================================================================
    assign vga_r = display_enable ? red_final   : 8'b00000000;
    assign vga_g = display_enable ? green_final : 8'b00000000;
    assign vga_b = display_enable ? blue_final  : 8'b00000000;

endmodule