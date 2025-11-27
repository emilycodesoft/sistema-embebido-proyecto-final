// ============================================================================
// Módulo: clk_divider
// Descripción: Divide 50 MHz → 25 MHz
// ============================================================================

module clk_divider (
    input  wire clk_50mhz,          // Clock de entrada (50 MHz)
    input  wire reset,
    output reg  clk_25mhz           // Clock de salida (25 MHz)
);

    always @(posedge clk_50mhz or posedge reset) begin
        if (reset)
            clk_25mhz <= 0;
        else
            clk_25mhz <= ~clk_25mhz;  // Toggle cada ciclo = dividir por 2
    end

endmodule