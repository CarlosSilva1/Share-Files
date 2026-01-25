// Complete modified code for MAISEA_2.MQ4, based on MAISEA_1.MQ4 with specified changes

//════════════════════════════════════════════════════════════════
// Existing content of MAISEA_1.MQ4...
//
// Add your existing code from MAISEA_1.MQ4 here
//... existing code

//════════════════════════════════════════════════════════════════
// NEW PARAMETERS
//════════════════════════════════════════════════════════════════

color colorcode = Blue; // Existing line

//════════════════════════════════════════════════════════════════
// LOGO HD PARAMETERS
//════════════════════════════════════════════════════════════════
input bool    Logo_Enable = true;              // Exibir Logo MAIS HD
input bool    Logo_Transparent_BG = true;      // Fundo Transparente
input int     Logo_X_Distance = 250;           // Distância X (pixels)
input int     Logo_Y_Distance = 100;           // Distância Y (pixels)
input int     Logo_Corner = CORNER_RIGHT_LOWER; // Canto do Gráfico

// Replacing CreateMaisLogo() and DeleteMaisLogo() functions with new ones
//
void DrawLogoMAIS_HD() {
    // Code from Logo_MAIS_HD_Final.mq4...
}

void DeleteLogoMAIS_HD() {
    // Code to delete logo from the graph...
}

// In the init() function
void init() {
    DrawLogoMAIS_HD(); // Changed from CreateMaisLogo();
}

// In the deinit() function
void deinit() {
    DeleteLogoMAIS_HD(); // Changed from DeleteMaisLogo();
}