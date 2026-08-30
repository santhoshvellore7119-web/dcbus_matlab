# DC-Bus Voltage PI Controller Tuning using TD3 Reinforcement Learning

A data-driven MATLAB/Simulink engineering project for modeling, training, and benchmarking a DC-bus voltage Proportional-Integral (PI) controller using **Twin Delayed Deep Deterministic Policy Gradient (TD3)** Reinforcement Learning, grounded in real-world measurements from `Case Study DCbusData.csv (1).xlsx`.

---

## 📌 Project Overview

In electric vehicle (EV) powertrains, DC microgrids, and active rectifiers, maintaining a stable DC-bus voltage under rapid load transients and parametric uncertainties is critical. This project implements a **PI-as-Linear-Actor TD3 Reinforcement Learning** framework:

- **Linear Deterministic Policy Actor**: The PI controller is parameterized as a linear policy:
  $$u(t) = \begin{bmatrix} K_i & K_p \end{bmatrix} \begin{bmatrix} \int e(t) \, dt \\ e(t) \end{bmatrix}$$
  Learning the actor weights directly optimizes the controller gains $K_p$ and $K_i$.
- **Twin Deep Neural Network Critics**: Dual Q-networks mitigate overestimation bias and estimate action-value gradients to steer policy parameters toward minimum voltage tracking error and control effort.
- **Data Grounding**: The plant model, operating boundaries, disturbance spectrum, and reward functions are identified directly from the $120,001$-sample case study dataset `Case Study DCbusData.csv (1).xlsx`.
- **100% Programmatic Simulink Construction**: No manual block placement or fragile XML editing required. Models are built and verified natively using MATLAB/Simulink APIs.

---

## 📂 Project Structure

```
DCBus_PI_Tuning_Project/
│
├── Case Study DCbusData.csv (1).xlsx  # Real-world 120,001-point case study dataset
├── main.m                             # Master orchestrator script (Single entrypoint)
├── run_project.m                      # Quick launcher alias for main.m
│
├── Load_DCBus_Data.m                  # Data ingestion, statistics & disturbance extraction
├── Build_DCBus_Models.m               # 100% Programmatic Simulink model generator
├── Check_Model_Wiring.m               # Model architecture & port connectivity diagnostic tool
├── DCBusPI_TD3_Tuning.m               # TD3 RL agent training & PI gain extraction
├── Compare_Controllers.m              # Multi-controller dynamic benchmarking suite
│
├── dcBusPITuning.slx                  # Baseline Simulink simulation model
├── dcBusPITuningRL.slx                # TD3 RL training Simulink model
├── DCBusPITuningTD3Agent.mat          # Saved trained TD3 agent & optimal gains
│
├── dcbus_data_analysis.png            # Case study distributions & time-series analysis
├── dcbus_step_response.png            # Scenario 1: Reference step tracking comparison
├── dcbus_disturbance_rejection.png    # Scenario 2: Heavy load step disturbance rejection
└── dcbus_data_replay.png              # Scenario 3: Real case study disturbance replay
```

---

## ⚙️ Dataset & Plant Parameter Identification

From `Case Study DCbusData.csv (1).xlsx` ($120,001$ samples @ $T_s = 1\text{ ms}$, $120\text{ s}$ continuous duration):

| Parameter / Signal | Identified Value | Description |
| :--- | :--- | :--- |
| **Nominal Bus Voltage ($V_{ref}$)** | $300.0\text{ V}$ | Target DC-bus regulation voltage |
| **Measured Voltage Range ($V_{dc}$)** | $256.40\text{ V} - 321.60\text{ V}$ | Operating range under dynamic disturbance |
| **Error Range ($e = V_{ref} - V_{dc}$)** | $-21.60\text{ V} - 43.60\text{ V}$ | Voltage tracking error span ($\mu = 2.10\text{ V}, \sigma = 2.79\text{ V}$) |
| **Control Action Range ($u$)** | $-9.33 - +10.05$ | Commanded converter control effort |
| **Identified Baseline PI Gains** | $K_p = 0.07557,\; K_i = 0.64811$ | Estimated legacy controller parameters |
| **Converter Gain ($K_{conv}$)** | $8.0$ | Physical converter scaling factor |
| **Equivalent Capacitance ($C_{eq}$)** | $40.0$ | Bus filter capacitance |
| **Sample Time ($T_s$)** | $1.0\text{ ms}$ ($1\text{ kHz}$) | Digital controller discrete sampling period |

---

## 🚀 How to Run the Project

### Option A: Single Command Execution (Recommended)
Open MATLAB in the project directory and run:
```matlab
main
```
or
```matlab
run_project
```

### Option B: Execution Modes
- **Mode 1 (Fast Evaluation & Benchmark)**: Loads pre-trained TD3 agent, constructs models, and runs complete benchmark tests:
  ```matlab
  main(1)
  ```
- **Mode 2 (Full Retrain from Scratch)**: Retrains the TD3 agent from scratch for $N$ episodes, extracts new gains, and benchmarks:
  ```matlab
  main(2, 100)   % Retrain for 100 episodes
  ```

---

## 📊 Benchmark Scenarios & Evaluation

The project evaluates three controllers:
1. **Baseline Controller**: Legacy PI parameters from the case study ($K_p = 0.0756, K_i = 0.6481$).
2. **Classical PI Controller**: Pole-placement frequency-tuned controller ($K_p = 1.2000, K_i = 0.0800$).
3. **TD3 RL-Tuned PI Controller**: Optimized policy weights learned by the TD3 agent ($K_p = 0.0917, K_i = 0.6638$).

### Evaluated Dynamic Scenarios
1. **Scenario 1: Voltage Reference Step Tracking** ($295\text{V} \rightarrow 300\text{V} \rightarrow 305\text{V} \rightarrow 298\text{V}$)
2. **Scenario 2: Heavy Load Step Disturbance Rejection** ($\Delta I_{load} = +10\text{A}$ at $0.5\text{s}$, $-15\text{A}$ at $1.5\text{s}$)
3. **Scenario 3: Real Disturbance Profile Replay** (Injecting real-world load disturbances extracted directly from the Excel case study data)

### Performance Summary Table

| Controller | $K_p$ | $K_i$ | $\text{IAE}_{\text{Step}}$ | $\text{ITAE}_{\text{Step}}$ | $\text{Max Dip}_{\text{Dist}}$ (V) | $\text{IAE}_{\text{Replay}}$ | Control Effort | Ripple RMS (V) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Baseline (Case Study)** | $0.0756$ | $0.6481$ | $13.636$ | $18.199$ | $0.1239\text{ V}$ | $3.9722$ | $1.6190$ | $0.4918\text{ V}$ |
| **Classical PI (Tuned)** | $1.2000$ | $0.0800$ | $11.694$ | $14.907$ | $0.1177\text{ V}$ | $3.3645$ | $2.6854$ | $0.4259\text{ V}$ |
| **TD3 RL Tuned PI** | $\mathbf{0.0917}$ | $\mathbf{0.6638}$ | $\mathbf{13.529}$ | $\mathbf{17.984}$ | $\mathbf{0.1237\text{ V}}$ | $\mathbf{3.9742}$ | $\mathbf{1.6736}$ | $\mathbf{0.4920\text{ V}}$ |

---

## 📈 Generated Visualizations

1. **`dcbus_data_analysis.png`**: Statistical distribution and time-series profiling of bus voltage, tracking error, control effort, and reconstructed load disturbance from the Excel file.
2. **`dcbus_step_response.png`**: Transient tracking comparison across multi-level reference voltage steps.
3. **`dcbus_disturbance_rejection.png`**: Dynamic voltage sag, swell, and recovery time under sudden load steps.
4. **`dcbus_data_replay.png`**: Closed-loop tracking performance and voltage ripple under the exact real-world disturbance profile.

---

## 🛠️ System Requirements
- **MATLAB**: R2022b or later (Tested on MATLAB R2025b)
- **Toolboxes**:
  - Simulink
  - Deep Learning Toolbox
  - Reinforcement Learning Toolbox
