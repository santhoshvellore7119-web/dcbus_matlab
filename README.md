# Deep Reinforcement Learning (TD3) for DC Bus Voltage Regulation

**Project:** Minimal Native MATLAB Reinforcement Learning Voltage Controller  
**Methodology:** 100% Native MATLAB Twin-Delayed DDPG (TD3) Neural Network Controller  

---

A minimal, self-contained MATLAB implementation of a continuous **Twin-Delayed Deep Deterministic Policy Gradient (TD3)** neural network controller for DC microgrid voltage regulation, evaluated against telemetry from `Case Study DCbusData.csv (1).xlsx`.

---

## 📌 Project Summary

1. **Continuous Neural Network Actor:** Maps scaled state observations $S_t = [\text{V\_err}, \text{dV\_err/dt}, u_{t-1}] \in \mathbb{R}^3$ to control duty $u(t) \in [-10, +10]$.
2. **Signal Reconstruction:** Reconstructs continuous voltage $V_{\text{true}} = V_{\text{ref}} - \text{PI}_{\text{in}}$ to bypass 18-level ADC sensor quantization artifacts.
3. **Out-of-Sample System Identification:** Honest 80/20 train/test evaluation (Model A Raw: $34.81\%$, Model B Filtered: $35.75\%$).
4. **Transient Peak Clamping:** Reduces max peak voltage spikes from **44.00 V (PI Baseline)** down to **4.50 V (TD3 Agent)** (**89.8% Peak Error Reduction**).

---

## 📊 Benchmark Figures

### 1. Honest Out-of-Sample System Identification
![Honest Out-of-Sample Validation](honest_validation_comparison.png)

### 2. Closed-Loop TD3 DRL vs Historical PI Baseline Waveforms
![Closed-Loop Performance Comparison](matlab_validation_results.png)

---

## 📂 Minimal Repository Layout

```
c:\Users\Santhosh\Documents\antigravity\friendly-carson
│
├── Case Study DCbusData.csv (1).xlsx    # Experimental Telemetry Dataset
├── DCBusEnv.m                           # Custom MATLAB RL Environment Class
├── train_td3_agent.m                    # TD3 Agent Training Script
├── run_pipeline.m                       # 1-Click Master Execution Pipeline
│
├── Trained_TD3_DCBus_Agent.mat          # Pre-trained TD3 Neural Network Weights
├── DC_Bus_Voltage_Regulation_DRL_Report.pdf # Executive 7-Page Assessment Report
│
├── honest_validation_comparison.png     # Out-of-Sample Model Validation Figure
├── matlab_validation_results.png        # Closed-Loop DRL vs PI Performance Figure
│
├── .gitignore                           # Git Ignore Configuration
└── README.md                            # Project Documentation
```

---

## 🚀 How to Run (1-Click MATLAB Execution)

In the MATLAB Command Window, execute:
```matlab
run_pipeline
```
This runs the environment check, signal reconstruction, out-of-sample system identification, and displays all closed-loop performance figures.
