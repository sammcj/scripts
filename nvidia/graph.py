# Only used to graph the fan speed response curves for documentation purposes
import matplotlib.pyplot as plt
import numpy as np

def fan_speed(TEMP, basePWM, maxPWM, sensitivity):
    x1 = 30
    y1 = basePWM
    x2 = 80 - (sensitivity-1)*5
    y2 = maxPWM
    PWM = (TEMP - x1)*(y2 - y1)/(x2 - x1) + y1

    # Make sure PWM values are within specified range
    PWM = max(min(PWM, maxPWM), basePWM)

    return PWM

TEMP = np.linspace(20, 100, 400)
basePWM = 70
maxPWM = 255

# Plot for different sensitivities
for sensitivity in [1, 5, 9]:
    PWM_values = [fan_speed(temp, basePWM, maxPWM, sensitivity) for temp in TEMP]
    plt.plot(TEMP, PWM_values, label=f'Sensitivity {sensitivity}')

plt.axhline(y=maxPWM, color='r', linestyle='--', label='Max PWM')
plt.axvspan(30, 80, color='gray', alpha=0.1, label='Primary Change Region')

plt.xlabel('GPU Temperature (°C)')
plt.ylabel('PWM Value')
plt.title('Fan Speed Response Curves')
plt.legend()
plt.grid(True)
plt.tight_layout()
plt.savefig("fan_response_curve_updated.svg", format="svg")
plt.show()
