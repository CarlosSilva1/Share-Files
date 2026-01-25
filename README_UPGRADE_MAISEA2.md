# README_UPGRADE_MAISEA2.md

## Introduction
This document provides complete step-by-step instructions to upgrade from MAISEA_1.MQ4 to MAISEA_2.MQ4, incorporating HD logo support. The upgrade includes new logo parameters and function implementations designed to enhance logo performance in the system.

## New Logo Parameters
After line 59, include the following parameters:
```mql4
Logo_Enable,
Logo_Transparent_BG,
Logo_X_Distance,
Logo_Y_Distance,
Logo_Corner
```

## DrawLogoMAIS_HD() Function Code
Replace the existing logo drawing function with the following code:
```mql4
void DrawLogoMAIS_HD() {
    // Insert pixel array from Logo_MAIS_HD_Final.mq4 here
}
```

## DeleteLogoMAIS_HD() Function Code
Implement the following code to handle logo deletion:
```mql4
void DeleteLogoMAIS_HD() {
    // Code to delete HD logo
}
```

## Replace CreateMaisLogo() Call
Replace the old `CreateMaisLogo()` call with `DrawLogoMAIS_HD()` in the `init()` function around line 991:
```mql4
// Old code
CreateMaisLogo();

// New code
DrawLogoMAIS_HD();
```

## Replace DeleteMaisLogo() Call
Similarly, replace `DeleteMaisLogo()` with `DeleteLogoMAIS_HD()` in the `deinit()` function around line 994:
```mql4
// Old code
DeleteMaisLogo();

// New code
DeleteLogoMAIS_HD();
```

## Copy Pixel Array Instructions
After implementing `DrawLogoMAIS_HD()`, users need to copy the pixel array from `Logo_MAIS_HD_Final.mq4` file. This includes lines 14 onwards with all `pixels[0]` through `pixels[16799]` assignments:
```mql4
// Copy the following lines from Logo_MAIS_HD_Final.mq4
pixels[0] = ...;  // Continue to pixels[16799]
```

## Troubleshooting
- Ensure all new parameters are correctly defined in your main file.
- If the logo does not display, check if the pixel array is correctly copied and the function calls are properly placed.

## Configuration Options After Installation
After the installation, refer to the configuration options listed in the code comments to customize logo settings as per requirements.