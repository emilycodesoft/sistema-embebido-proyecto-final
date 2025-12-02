// ============================================================================
// Módulo: clk_divider (VERSIÓN MEJORADA CON CLOCK ENABLE)
// Descripción: Genera pulso de habilitación a 25 MHz desde 50 MHz
// ============================================================================

module clk_divider (
    input  wire clk_50mhz,          // Clock de entrada (50 MHz)
    input  wire reset,              // Reset síncrono activo alto
    output reg  clk_enable_25mhz    // Clock enable (pulso cada 2 ciclos)
);

    // ========================================================================
    // Contador para generar enable cada 2 ciclos
    // ========================================================================
    reg counter = 1'b0;
    
    always @(posedge clk_50mhz) begin
        if (reset) begin
            counter <= 1'b0;
            clk_enable_25mhz <= 1'b0;
        end else begin
            counter <= ~counter;              // Toggle cada ciclo
            clk_enable_25mhz <= ~counter;     // Enable cuando counter=1
        end
    end

endmodule