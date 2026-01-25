## MAISEA_2 - Complete Upgrade Guide

### Overview
This guide provides complete code to upgrade MAISEA_1.MQ4 to MAISEA_2.MQ4 with High Definition logo support.

### What's New
- HD Logo (210x80 pixels, 16,800 pixel array)
- Transparent background support
- Configurable positioning
- Professional bitmap rendering

---

## STEP 1: Add New Parameters

**Location:** After line 59 (after `color colorcode = Blue;`)

**Add this code:**

```mql4
//════════════════════════════════════════════════════════════════
// LOGO HD PARAMETERS
//════════════════════════════════════════════════════════════════
input bool    Logo_Enable = true;              // Enable MAIS HD Logo
input bool    Logo_Transparent_BG = true;      // Transparent Background
input int     Logo_X_Distance = 10;            // X Distance (pixels)
input int     Logo_Y_Distance = 10;            // Y Distance (pixels)
input int     Logo_Corner = CORNER_LEFT_UPPER; // Chart Corner Position
```

---

## STEP 2: Replace Logo Functions

**Location:** Find and DELETE lines 882-961 (old CreateMaisLogo and DeleteMaisLogo functions)

**Replace with this complete code:**

```mql4
//════════════════════════════════════════════════════════════════
// LOGO HD MAIS - HIGH DEFINITION BITMAP
//════════════════════════════════════════════════════════════════
void DrawLogoMAIS_HD()
{
   if(!Logo_Enable || !Display) return;
   
   uint pixels[];
   ArrayResize(pixels, 16800, 0);
   
   // HD Logo pixel data (210x80 = 16,800 pixels)
   // Copy the entire pixel array from Logo_MAIS_HD_Final.mq4
   // Lines 14-800+ containing all pixels[0] through pixels[16799] assignments
   
   // Apply transparency if enabled
   if(Logo_Transparent_BG)
   {
      for(int i = 0; i < ArraySize(pixels); i++)
      {
         if(pixels[i] == 0xFFFFFFFF)  // Opaque white background
            pixels[i] = 0x00FFFFFF;    // Transparent white
      }
   }
   
   // Create bitmap resource and display on chart
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
```

**IMPORTANT:** Inside the `DrawLogoMAIS_HD()` function, after `ArrayResize(pixels, 16800, 0);`, you must copy ALL pixel assignments from `Logo_MAIS_HD_Final.mq4` (lines 14 onwards). These are lines like:
```mql4
pixels[0]=0xFFFFFFFF;   pixels[1]=0xFFFFFFFF;   pixels[2]=0xFFFFFFFF;
// ... continue for all 16,800 pixels
```

---

## STEP 3: Update Function Calls

### In init() function (around line 991):
**Change:**
```mql4
CreateMaisLogo();
```
**To:**
```mql4
DrawLogoMAIS_HD();
```

### In deinit() function (around line 994):
**Change:**
```mql4
DeleteMaisLogo();
```
**To:**
```mql4
DeleteLogoMAIS_HD();
```

---

## STEP 4: Copy Pixel Array

1. Open `Logo_MAIS_HD_Final.mq4` from this repository
2. Select ALL lines starting from line 14 (pixels[0]=...) through the end of the array
3. Copy these lines
4. Paste them in `MAISEA_2.MQ4` inside the `DrawLogoMAIS_HD()` function, right after the comment "// HD Logo pixel data"

---

## STEP 5: Save and Compile

1. Save the file as `MAISEA_2.MQ4`
2. Compile (F7 in MetaEditor)
3. Check for zero errors
4. Test on a chart

---

## Configuration Options

After installation, you can configure the logo through EA inputs:

- **Logo_Enable**: Turn logo on/off
- **Logo_Transparent_BG**: Enable transparent background
- **Logo_X_Distance**: Horizontal position (pixels from corner)
- **Logo_Y_Distance**: Vertical position (pixels from corner)
- **Logo_Corner**: Corner position (0=Upper Left, 1=Upper Right, 2=Lower Left, 3=Lower Right)

---

## Troubleshooting

**If compilation fails:**
- Verify all pixel array is copied (should have 16,800 pixel assignments)
- Check for missing semicolons
- Ensure closing braces are present

**If logo doesn't appear:**
- Check `Logo_Enable = true`
- Verify `Display = true`
- Try different corner positions
- Adjust X/Y distances

---

## Result

✅ High-definition 210x80 logo
✅ Transparent background support
✅ Fully configurable position
✅ Professional appearance
✅ Clean, maintainable code

---

**Created by:** GitHub Copilot
**Repository:** CarlosSilva1/Share-Files
**Date:** 2026-01-25 15:10:34