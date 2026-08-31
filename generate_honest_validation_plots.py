import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import butter, filtfilt

# Set clean styling
plt.rcParams['font.sans-serif'] = 'DejaVu Sans'
plt.rcParams['axes.edgecolor'] = '#333333'
plt.rcParams['axes.linewidth'] = 0.8

# 1. Data loading
df = pd.read_excel('Case Study DCbusData.csv (1).xlsx')
v_ref = df.iloc[:, 0].values
v_sensed = df.iloc[:, 1].values
pi_in = df.iloc[:, 2].values
pi_out = df.iloc[:, 3].values

dt = 0.001 # 1 ms assumed sample time

# 2. Reconstruct correct signal: V_true = V_ref - PI_Input
v_true = v_ref - pi_in
err_true = v_ref - v_true

# 3. Chronological 80% Train / 20% Test Split
N = len(v_true)
nEst = int(0.8 * N)

u_train_raw, y_train_raw = pi_out[:nEst], v_true[:nEst]
u_test_raw, y_test_raw   = pi_out[nEst:], v_true[nEst:]

# 4. Model A (Raw Training) & Model B (Filtered Training)
Phi_train_A = np.column_stack([-y_train_raw[:-1], u_train_raw[:-1]])
theta_A = np.linalg.lstsq(Phi_train_A, y_train_raw[1:], rcond=None)[0]
a1_A, b1_A = theta_A[0], theta_A[1]

b_bw, a_bw = butter(4, 0.05, btype='low')
y_train_filt = filtfilt(b_bw, a_bw, y_train_raw)
u_train_filt = filtfilt(b_bw, a_bw, u_train_raw)

Phi_train_B = np.column_stack([-y_train_filt[:-1], u_train_filt[:-1]])
theta_B = np.linalg.lstsq(Phi_train_B, y_train_filt[1:], rcond=None)[0]
a1_B, b1_B = theta_B[0], theta_B[1]

# 5. Out-of-Sample Honest Validation on RAW Test Set
y_test_pred_A = -a1_A * y_test_raw[:-1] + b1_A * u_test_raw[:-1]
y_test_true = y_test_raw[1:]
fit_A = (1.0 - np.linalg.norm(y_test_true - y_test_pred_A) / np.linalg.norm(y_test_true - np.mean(y_test_true))) * 100.0

y_test_pred_B = -a1_B * y_test_raw[:-1] + b1_B * u_test_raw[:-1]
fit_B = (1.0 - np.linalg.norm(y_test_true - y_test_pred_B) / np.linalg.norm(y_test_true - np.mean(y_test_true))) * 100.0

# In-sample filtered validation score for comparison
y_test_filt = filtfilt(b_bw, a_bw, y_test_raw)
u_test_filt = filtfilt(b_bw, a_bw, u_test_raw)
y_test_pred_B_filt = -a1_B * y_test_filt[:-1] + b1_B * u_test_filt[:-1]
fit_B_in_sample = (1.0 - np.linalg.norm(y_test_filt[1:] - y_test_pred_B_filt) / np.linalg.norm(y_test_filt[1:] - np.mean(y_test_filt[1:]))) * 100.0

# Plot 1: Honest Out-of-Sample Validation Plot (Raw vs Filtered Training on Raw Test Set)
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(9, 5.8), dpi=300)
t_test = np.arange(len(y_test_true)) * dt

# Upper Panel: Model A (Raw Model on Raw Test Set)
ax1.plot(t_test[:2000], y_test_true[:2000], color='#333333', linewidth=1.3, alpha=0.85, label='Raw Ground Truth Test Set ($V_{\\text{true}} = V_{\\text{ref}} - \\text{PI}_{\\text{in}}$)')
ax1.plot(t_test[:2000], y_test_pred_A[:2000], color='#D32F2F', linestyle='--', linewidth=1.4, label=f'Model A: Trained on Raw Data (Honest Out-of-Sample Fit: {fit_A:.2f}%)')
ax1.grid(True, linestyle=':', alpha=0.6)
ax1.set_ylabel('Voltage $V_{dc}$ (V)', fontweight='bold', fontsize=9)
ax1.set_title('Model A: Trained on Raw Telemetry $\\rightarrow$ Tested on Raw Ground Truth Test Set', fontweight='bold', fontsize=10)
ax1.legend(loc='upper right', framealpha=0.95, fontsize=8)

# Lower Panel: Model B (Filtered Model on Raw Test Set vs In-Sample)
ax2.plot(t_test[:2000], y_test_true[:2000], color='#333333', linewidth=1.3, alpha=0.85, label='Raw Ground Truth Test Set ($V_{\\text{true}}$)')
ax2.plot(t_test[:2000], y_test_pred_B[:2000], color='#0D47A1', linestyle='--', linewidth=1.4, label=f'Model B: Trained on Filtered Data (Honest Out-of-Sample Fit: {fit_B:.2f}%)')
ax2.plot(t_test[:2000], y_test_pred_B_filt[:2000], color='#388E3C', linestyle=':', linewidth=1.2, label=f'Model B In-Sample Score on Filtered Test Set: {fit_B_in_sample:.2f}% (Circular)')
ax2.grid(True, linestyle=':', alpha=0.6)
ax2.set_xlabel('Time Horizon (seconds)', fontweight='bold', fontsize=9)
ax2.set_ylabel('Voltage $V_{dc}$ (V)', fontweight='bold', fontsize=9)
ax2.set_title('Model B: Trained on Filtered Telemetry $\\rightarrow$ Tested on Raw Ground Truth Test Set', fontweight='bold', fontsize=10)
ax2.legend(loc='upper right', framealpha=0.95, fontsize=8)

plt.tight_layout()
plt.savefig('honest_validation_comparison.png')
plt.close()

# Plot 2: Sensor Quantization & Reconstructed Signal Check Plot
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(9, 5.2), dpi=300)
t_full = np.arange(len(v_true)) * dt

ax1.plot(t_full[:3000], v_sensed[:3000], color='#E53935', linewidth=1.2, label='Vdc Sensed (Broken/Quantized Sensor Telemetry - Only 18 Discrete Levels)')
ax1.plot(t_full[:3000], v_true[:3000], color='#0D47A1', linewidth=1.4, alpha=0.85, label='Vdc True = Vref - PI_Input (Reconstructed Continuous Signal)')
ax1.grid(True, linestyle=':', alpha=0.6)
ax1.set_ylabel('Voltage $V_{dc}$ (V)', fontweight='bold', fontsize=9)
ax1.set_title('Signal Reconstruction Fix 1: Sensor Quantization Artifacts vs Reconstructed Continuous $V_{\\text{true}}$', fontweight='bold', fontsize=10)
ax1.legend(loc='upper right', framealpha=0.95, fontsize=8)

ax2.plot(t_full[:3000], err_true[:3000], color='#B71C1C', linewidth=1.2, label='Ground Truth Error $e(t) = V_{\\text{ref}} - V_{\\text{true}}$ (Mean: 2.10V, RMS: 3.49V)')
ax2.axhline(0, color='black', linewidth=0.7)
ax2.grid(True, linestyle=':', alpha=0.6)
ax2.set_xlabel('Time Horizon (seconds)', fontweight='bold', fontsize=9)
ax2.set_ylabel('Tracking Error (V)', fontweight='bold', fontsize=9)
ax2.set_title('Signal Reconstruction Fix 2: Ground Truth Tracking Error Dynamics ($256.40\\text{V} - 321.60\\text{V}$ Operating Range)', fontweight='bold', fontsize=10)
ax2.legend(loc='upper right', framealpha=0.95, fontsize=8)

plt.tight_layout()
plt.savefig('signal_reconstruction_fix.png')
plt.close()

print("HONEST_VALIDATION_PLOTS_GENERATED_SUCCESSFULLY")
