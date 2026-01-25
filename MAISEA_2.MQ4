// MAISEA_1.MQ4 modifications for MAISEA_2.MQ4

// Logo HD Parameters
input bool    Logo_Enable = true;              // Exibir Logo MAIS HD
input bool    Logo_Transparent_BG = true;      // Fundo Transparente
input int     Logo_X_Distance = 250;           // Distância X (pixels)
input int     Logo_Y_Distance = 100;           // Distância Y (pixels)
input int     Logo_Corner = CORNER_RIGHT_LOWER; // Canto do Gráfico

//════════════════════════════════════════════════════════════════
// LOGO HD MAIS - HIGH DEFINITION BITMAP
//════════════════════════════════════════════════════════════════
void DrawLogoMAIS_HD()
{
   if(!Logo_Enable || !Display) return;
   
   uint pixels[];
   ArrayResize(pixels, 16800, 0);
   
   // Copy the entire pixel array from Logo_MAIS_HD_Final.mq4 (all 16800 pixels from line 14 to end)
   
   // Apply transparency if enabled
   if(Logo_Transparent_BG)
   {
      for(int i = 0; i < ArraySize(pixels); i++)
      {
         // Convert white background pixels to transparent
         if(pixels[i] == 0xFFFFFFFF)  // Opaque white
            pixels[i] = 0x00FFFFFF;    // Transparent white
      }
   }
   
   // Create bitmap on chart
   string logo_name = "MAIS_Logo_HD";
   int logo_width = 210;
   int logo_height = 80;
   
   if(ResourceCreate(logo_name, pixels, logo_width, logo_height, 0, 0, 0, COLOR_FORMAT_ARGB_NORMALIZE))
   {
      if(ObjectFind(0, logo_name) < 0)
      {
         ObjectCreate(0, logo_name, OBJ_BITMAP_LABEL, 0, 0, 0);
      }
      
      ObjectSetInteger(0, logo_name, OBJPROP_XDISTANCE, Logo_X_Distance);
      ObjectSetInteger(0, logo_name, OBJPROP_YDISTANCE, Logo_Y_Distance);
      ObjectSetInteger(0, logo_name, OBJPROP_CORNER, Logo_Corner);
      ObjectSetInteger(0, logo_name, OBJPROP_ANCHOR, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, logo_name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, logo_name, OBJPROP_SELECTABLE, false);
   }
}

void DeleteLogoMAIS_HD()
{
   string logo_name = "MAIS_Logo_HD";
   
   if(ObjectFind(0, logo_name) >= 0)
      ObjectDelete(0, logo_name);
      
   ResourceFree(logo_name);
} 

// This is the init() function, replace CreateMaisLogo() with DrawLogoMAIS_HD()
void init() {
   // Old: CreateMaisLogo();
   DrawLogoMAIS_HD();
}

// This is the deinit() function, replace DeleteMaisLogo() with DeleteLogoMAIS_HD()
void deinit() {
   // Old: DeleteMaisLogo();
   DeleteLogoMAIS_HD();
}