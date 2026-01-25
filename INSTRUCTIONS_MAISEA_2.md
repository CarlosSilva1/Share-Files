# Instructions for Updating MAISEA_1.MQ4 to MAISEA_2.MQ4 with HD Logo Integration

## Introduction
This document provides detailed instructions on how to update the `MAISEA_1.MQ4` code to `MAISEA_2.MQ4` while integrating the HD logo from `Logo_MAIS_HD_Final.mq4`.

## Step-by-Step Instructions
1. **Create a New File** 
   - Open your MetaEditor and create a new file named `MAISEA_2.MQ4`.
   
2. **Copy Existing Code** 
   - Open `MAISEA_1.MQ4` and copy all of its contents into `MAISEA_2.MQ4`.
   
3. **Integrate HD Logo** 
   - Open `Logo_MAIS_HD_Final.mq4` to extract the pixel array.
   - Locate the section in `Logo_MAIS_HD_Final.mq4` that defines the pixel array. This will be used to integrate the HD logo into your new file.

4. **Paste the Pixel Array** 
   - Find the appropriate location in `MAISEA_2.MQ4` to insert the pixel array, typically near graphical initialization code. 
   - Paste the pixel array.
   
5. **Adjust Code as Necessary** 
   - Ensure any references to the HD logo in the code are updated to reflect its new location in `MAISEA_2.MQ4`.

## Complete Code Structure
```mql
// Initializing the logo
int logo[][] = {
    // Insert pixel array here from Logo_MAIS_HD_Final.mq4
};

// Other existing code

void OnStart() {
    // Rest of your code...
}
```

## Conclusion
After following these steps, you should have a working `MAISEA_2.MQ4` file with HD logo integration. Remember to thoroughly test your code to ensure everything functions as expected.