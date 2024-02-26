#ifndef MODE_BUTTON_H
#define MODE_BUTTON_H

// Declare the global mode variable (if not already declared elsewhere)
extern int mode;

class ModeButton {
public:
  ModeButton(int p, int m);

  // If the button is pressed and if not locked, toggle the mode, but also lock it (to prevent multiple function calls within same button press request)
  // If the button is locked and the button is not being pressed, then unlock it (to allow the user to press it again to toggle mode)
  bool check();

  // Checks if button is currently pressed down
  bool isPressed() const;

private:
  // Pin represents the digital pin which corresponds to the toggle action
  int pin;

  // Mode associated with the button
  int btnMode;

  // Flag to prevent multiple toggles within a single press
  bool isLocked = false;

  void toggleMode();
};

#endif // MODE_BUTTON_H
