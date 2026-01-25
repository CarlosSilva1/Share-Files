# Complete Step-by-Step Instructions for Creating MAISEA_2.MQ4

Creating a new trading algorithm, MAISEA_2.MQ4, involves several structured steps. Below is a detailed guide to help you with the process.

## 1) Creating MAISEA_2.MQ4 Structure
- Open your MetaEditor and create a new file named `MAISEA_2.MQ4`.
- Set up the initial structure of the file by defining the required properties and including necessary libraries. 

## 2) Adding New Parameters
- Define any new parameters specific to the MAISEA_2 algorithm. For example:
  ```mql4
  input int NewParameter = 10;  // Define your new input parameter here
  ```

## 3) Implementing `DrawLogoMAIS_HD()` Function with Placeholder for Pixels
- Create the function signature for `DrawLogoMAIS_HD()`. Here’s a template:
  ```mql4
  void DrawLogoMAIS_HD(int pixels[]) {
      // Implementation will go here
  }
  ```
- Ensure to include a placeholder array for the pixel data.

## 4) Implementing `DeleteLogoMAIS_HD()` Function
- Define the `DeleteLogoMAIS_HD()` function to handle logo removal:
  ```mql4
  void DeleteLogoMAIS_HD() {
      // Clear-specific implementation goes here
  }
  ```

## 5) Updating `OnInit` and `OnDeinit` Calls
- Modify the `OnInit()` function to initialize your algorithm’s parameters and draw your logo:
  ```mql4
  int OnInit() {
      DrawLogoMAIS_HD(pixels);
      return INIT_SUCCEEDED;
  }
  ```
- Ensure you correctly update the `OnDeinit()` function to call `DeleteLogoMAIS_HD()` at the end of the script's lifecycle.

## 6) Where to Copy the Pixel Array from `Logo_MAIS_HD_Final.mq4`
- You will need to locate the pixel array in the `Logo_MAIS_HD_Final.mq4` file. Here’s where to find it:
  - Look for an array definition in `Logo_MAIS_HD_Final.mq4` similar to:
  ```mql4
  int pixels[16800] = { ... }; // Copy this array
  ```
  - Copy the entire pixel array and paste it in your `MAISEA_2.MQ4` file, preferably above the function definitions.

## 7) Compilation Steps
- Once you’ve added your code, click on the compile button in the MetaEditor to compile your new file. Ensure there are no errors or warnings.

## 8) Testing Checklist
- Before deploying your new algorithm, ensure you have the following checks completed:
  - [ ] Test the DrawLogoMAIS_HD() functionality.
  - [ ] Verify that parameters are working as expected.
  - [ ] Ensure the logo is drawn and removed correctly.
  - [ ] Test in the strategy tester for performance on historical data.
- Only after completing all tests should you consider deploying the algorithm in a live trading environment.
