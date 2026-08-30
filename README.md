# Deep Reinforcement Learning (Neural Network) for DC Bus Voltage Regulation

**Project:** AI/ML Voltage Controller for DC Microgrids & Power Converters  
**Method:** Deep Neural Network Continuous Actor-Critic Reinforcement Learning in MATLAB  

---

An AI/ML-driven continuous voltage controller designed to replace traditional Proportional-Integral (PI) control in DC microgrid / DC bus systems using **Deep Reinforcement Learning (Deep Neural Network Actor-Critic)**, grounded in the case study dataset `Case Study DCbusData.csv (1).xlsx`.

---

## 📌 Project Objectives

1. **Replace Traditional PI Control:** Formulate DC bus voltage stabilization as a continuous Deep Reinforcement Learning (DRL) control problem using a Deep Neural Network Actor ($3 \to 128 \to 128 \to 1$).
2. **Regulate Bus Voltage ($V_{\text{dc}}$):** Maintain sensed voltage at nominal target setpoint $V^* = 300\,\text{V}$ under dynamic disturbance loads.
3. **Minimize Tracking Error & Control Effort:** Bounded corrective action $u(t) \in [-10, +10]$ with high steady-state precision within $\pm 0.5\,\text{V}$.

---

## ⚡ System Physics & Neural Network Architecture

```
  V* (300V Ref) ──(+)──┐
                       ├──> V_err ───> [ 2-Layer MLP Neural Network ] ───> Control Effort (u) ───> [ DC Bus Converter ]
  V (Sensed)    ──(-)──┘                       (3 -> 128 -> 128 -> 1)                                     │
                                                                                                          ▼
                                                                                           Capacitor Voltage Dynamics:
                                                                                           C * (dV/dt) = I_control - I_load
```

### Physical Parameters
- **Reference Voltage ($V^*$):** $300.0\,\text{V}$
- **DC Bus Capacitance ($C_{\text{dc}}$):** $4700\,\mu\text{F}$ ($4.7\,\text{mF}$)
- **Simulation Time Step ($\Delta t$):** $1\,\text{ms}$ ($0.001\,\text{s}$)
- **Episode Duration:** $2,000\,\text{steps}$ ($2.0\,\text{s}$)
- **Disturbance Model:** $I_{\text{load}}(t) = 5.0\,\text{A} + 2.0 \sin(2\pi \cdot 10t)\,\text{A}$

---

## 🧠 Neural Network DRL Formulation (Continuous Actor-Critic)

### Observation Space (State)
Continuous state vector $S_t \in \mathbb{R}^3$:
$$S_t = \begin{bmatrix} \frac{V^* - V}{10.0} \\ \frac{1}{1000.0} \frac{d(V^* - V)}{dt} \\ \frac{u_{t-1}}{10.0} \end{bmatrix} = \begin{bmatrix} \text{Scaled Voltage Error} \\ \text{Scaled Error Derivative} \\ \text{Scaled Previous Action} \end{bmatrix}$$

### Action Space (Control Effort)
Continuous control effort $a_t \in [-1.0, 1.0]$, internally scaled to converter duty action $u_t \in [-10.0, 10.0]$:
$$I_{\text{control}} = I_{\text{base}} + 1.5 \cdot u_t$$

### Reward Function
Smooth, saturating error penalty with smoothness regularization and a tight tracking bonus:
$$R_t = -2.0 \left( 1 - \exp\left( -0.5 \left( \frac{V_{\text{err}}}{10} \right)^2 \right) \right) - 0.1 (\Delta u)^2 - 0.02 u^2 + R_{\text{bonus}}$$
Where $R_{\text{bonus}} = 1.0 \times \left(1 - \frac{|V_{\text{err}}|}{2.0}\right)$ for $|V_{\text{err}}| < 2.0\,\text{V}$.

---

## 📊 Comparative Performance Results

![DRL Neural Net vs Historical PI Controller Performance](validation_results_v3.png)

![DRL Training Progress](training_monitor_screenshot.png)

### Quantitative Benchmark Table

| Performance Metric | Historical PI Controller (Data) | Trained Neural Net DRL Controller | Winner / Improvement |
| :--- | :---: | :---: | :---: |
| **Episode Survival** | N/A | **2,000 / 2,000 steps (100%)** | 🏆 **Stable & Robust** |
| **Max Peak Error ($|V_{\text{err}}|$)** | **43.60 V (Full Dataset)** | **6.35 V** | 🏆 **DRL (85.4% Lower Peak Error)** |
| **Voltage Operating Range** | $[256.4, 321.6]\,\text{V}$ | $[294.04, 306.35]\,\text{V}$ | 🏆 **DRL (Strict Safety Bounds)** |
| **Mean Absolute Error (MAE)** | **2.33 V** | **3.10 V** | Baseline PI |
| **RMS Voltage Error** | **3.49 V** | **3.70 V** | Baseline PI |
| **Mean Control Effort $|u|$** | **6.03** | **0.56** | 🏆 **DRL (<10% Control Energy)** |

---

## 📂 Repository Structure

```
├── DCBusEnv.m                        # Custom MATLAB Reinforcement Learning Environment
├── train_ddpg_dcbus.m                # Deep Neural Network Actor-Critic Training Script
├── plot_results.m                    # 1-Click Validation & Comparison Waveform Generator
├── validate_env.m                    # 9-Step Environment Sanity Test Script
├── Trained_DRL_DCBus_Agent_v3.mat    # Pre-trained Neural Network Agent Weights (1000 episodes)
├── Case Study DCbusData.csv (1).xlsx # Benchmark Case Study Dataset
├── training_monitor_screenshot.png   # Training Progress GUI Screenshot
├── validation_results_v3.png         # DRL vs PI Performance Comparison Plot
└── README.md                         # Clean Documentation
```

---

## 🚀 How to Run & Reproduce

### 1. Evaluate Pre-Trained Neural Network Model (Instant 1-Click)
In MATLAB Command Window:
```matlab
plot_results
```

### 2. Run 9-Step Environment Sanity Test
```matlab
validate_env
```

### 3. Retrain Neural Network Agent from Scratch
```matlab
clear classes;
train_ddpg_dcbus
```

---

## 🛠️ System Requirements
- **MATLAB**: R2022b or later
- **Toolboxes**: Deep Learning Toolbox, Reinforcement Learning Toolbox
