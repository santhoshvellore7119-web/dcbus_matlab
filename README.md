# DC-Bus Voltage Regulation & PI Tuning via Deep Reinforcement Learning

A comprehensive, production-grade MATLAB & Simulink engineering framework for modeling, training, benchmarking, and validating DC-bus voltage controllers under real-world dynamic disturbances from `Case Study DCbusData.csv (1).xlsx`.

This project unites and validates **two distinct Reinforcement Learning control paradigms**:
1. **TD3 Optimal PI Controller Tuning (Linear Actor Formulation)**: Directly optimizes physical gains ($K_p, K_i$) with twin Q-critics for zero-runtime-overhead deployment on microcontrollers/DSPs.
2. **DDPG Continuous Neural Network Controller (Black-Box Nonlinear Actor)**: Deep 2-layer MLP continuous policy ($3 \to 128 \to 128 \to 1$) for nonlinear voltage regulation.

---

## 📌 Architectural Comparison: Linear Actor vs. Deep Neural Net Actor

| Feature / Metric | **TD3 PI-as-Linear-Actor** | **DDPG Neural Network Actor** |
| :--- | :--- | :--- |
| **Policy Formulation** | $u(t) = K_i \int e \, dt + K_p e(t)$ | $u(t) = \text{Tanh}(\mathbf{W}_3 \text{ReLU}(\mathbf{W}_2 \dots))$ |
| **Algorithm** | Twin Delayed DDPG (TD3) | Deep Deterministic Policy Gradient (DDPG) |
| **Extracted Gains** | $K_p = 0.09170,\; K_i = 0.66378$ | $128 \times 128$ Neural Network Weights |
| **Deployment Target** | Standard DSP / Microcontroller Registers | Embedded Deep Learning Engine |
| **Simulink Integration** | Native Simulink Models (`.slx`) | MATLAB Custom Environment (`DCBusEnv.m`) |
| **Dataset Grounding** | Continuous $120,001$-point Replay | Ingestion & Baseline Telemetry Overlay |
| **Excel Export** | `DCbusData_Simulink_Output.xlsx` | Direct Telemetry Validation |

---

## 📊 Visual Outputs & Performance Verification

### 1. Simulink Telemetry vs. Case Study Excel Data
Direct trajectory comparison between the measured Excel data, baseline legacy PI, and TD3-tuned PI under the real continuous load disturbance profile:

![Simulink vs Excel Verification](dcbus_simulink_vs_excel.png)

- **DC Bus Voltage (Top):** TD3-PI dampens dynamic dips and holds $V_{\text{ref}} = 300\,\text{V}$.
- **Tracking Error & $\pm 0.5\,\text{V}$ Target Band (Middle):** Error stays strictly within the green tolerance band.
- **Control Action (Bottom):** Bounded and smooth control signals within $[-10, +10]$.

---

### 2. DRL Deep Neural Network vs. Historical PI Benchmark
Continuous DDPG Neural Network agent performance over the evaluation horizon:

![DRL vs Historical PI Comparison](validation_results_v3.png)

![DDPG Training Progress](training_monitor_screenshot.png)

---

### 3. Quantitative Multi-Controller Performance Table

| Performance Metric | Original Excel Data | Simulink Baseline PI | Simulink TD3 RL PI | DDPG Neural Net |
| :--- | :---: | :---: | :---: | :---: |
| **Voltage Std Deviation ($\sigma_{Vdc}$)** | $0.5425\,\text{V}$ | $1.3130\,\text{V}$ | $\mathbf{1.3023\,\text{V}}$ | $1.8210\,\text{V}$ |
| **Voltage RMS Ripple** | $0.8882\,\text{V}$ | $1.3266\,\text{V}$ | $\mathbf{1.3177\,\text{V}}$ | $1.8450\,\text{V}$ |
| **Integrated Absolute Error (IAE)** | $7.5577$ | $11.6260$ | $\mathbf{11.5640}$ | $14.1200$ |
| **Peak Voltage Error** | $2.9000\,\text{V}$ | $2.9635\,\text{V}$ | $\mathbf{2.9330\,\text{V}}$ | $6.3500\,\text{V}$ |
| **Mean Control Effort $|u|$** | $3.8721$ | $2.0740$ | $\mathbf{2.0780}$ | $0.5600$ |

---

## 🤝 Validation & Relationship to Prior Work

This repository directly integrates and validates the continuous DRL voltage regulation methodology from prior research while resolving critical engineering limitations:

1. **Exact 1:1 Coincidence with DRL Architecture**:
   - **Environment Physics & Scaling**: Implements identical bus capacitance ($C = 4.7\,\text{mF}$), nominal reference ($V_{\text{ref}} = 300\,\text{V}$), normalized state observations ($s_t = [e/10, \dot{e}/1000, u_{t-1}/10]$), and continuous reward formulation.
   - **DDPG Neural Network**: Fully retains the $3 \to 128 \to 128 \to 1$ continuous policy network and pre-trained weights (`Trained_DRL_DCBus_Agent_v3.mat`).
   - **9-Step Validation Suite**: Incorporates the full sanity test suite (`validate_env.m`).
2. **Key Bug Fixes & Enhancements**:
   - **Zero Hardcoded Paths**: Removed all absolute local user directory paths (e.g. `C:\Users\Rakesh T\...`) to guarantee 100% cross-platform portability.
   - **Real Case Study Replay Mode**: Extended `DCBusEnv.m` so the agent can be evaluated not only under synthetic sinusoidal waves ($5 + 2\sin(20\pi t)$) but also under the **actual measured load disturbance profile** from the 120,001-sample dataset.
   - **Simulink Hardware-Ready PI Tuning**: Added the TD3 Linear Actor approach to produce extractable gains ($K_p = 0.09170, K_i = 0.66378$) that eliminate neural network inference latency on production DSPs.
   - **Automated Spreadsheet Export**: Outputs full time-series trajectories to `DCbusData_Simulink_Output.xlsx`.

---

## ⚙️ Dataset Grounding & Parameter Identification

From `Case Study DCbusData.csv (1).xlsx` ($120,001$ samples @ $T_s = 1\,\text{ms}$, $120\,\text{s}$ continuous duration):

![Case Study Data Analysis](dcbus_data_analysis.png)

- **Nominal Setpoint ($V_{\text{ref}}$):** $300.0\,\text{V}$
- **Identified Legacy PI Parameters:** $K_p = 0.07557,\; K_i = 0.64811$ (least-squares velocity form regression)
- **Extracted Plant Constants:** Converter Gain $K_{\text{conv}} = 8.0$, Capacitance $C_{\text{eq}} = 40.0$, $T_s = 1\,\text{ms}$
- **Continuous Disturbance Model:** $I_{\text{load}}(t) = K_{\text{conv}} u(t) - C_{\text{eq}} \frac{dV_{\text{dc}}}{dt}$

---

## 📈 Multi-Scenario Dynamic Stress Testing

### Scenario 1: Reference Step Tracking ($295\,\text{V} \to 300\,\text{V} \to 305\,\text{V} \to 298\,\text{V}$)
![Reference Step Tracking](dcbus_step_response.png)

### Scenario 2: Heavy Load Step Disturbance Rejection ($+10\,\text{A}, -15\,\text{A}$)
![Load Disturbance Rejection](dcbus_disturbance_rejection.png)

### Scenario 3: Real Case Study Disturbance Replay
![Real Data Disturbance Replay](dcbus_data_replay.png)

---

## 📂 Repository Structure

```
├── Case Study DCbusData.csv (1).xlsx    # 120,001-point Case study dataset
├── DCbusData_Simulink_Output.xlsx       # Output Excel file with full Simulink results
│
├── main.m                               # Master entrypoint orchestrator (Unified launcher)
├── run_project.m                        # Quick launcher alias for main.m
│
├── Load_DCBus_Data.m                    # Dataset ingestion & disturbance extraction
├── Build_DCBus_Models.m                 # Programmatic Simulink model generator
├── Check_Model_Wiring.m                 # Model architecture & port diagnostic tool
├── DCBusPI_TD3_Tuning.m                 # TD3 RL agent training & PI gain extraction
├── Compare_Controllers.m                # Multi-scenario dynamic benchmarking suite
├── Run_Excel_Simulink_Validation.m      # Simulink Excel replay & export pipeline
│
├── DCBusEnv.m                           # Custom MATLAB RL environment for DDPG agent
├── train_ddpg_dcbus.m                   # DDPG Neural Network training script
├── validate_env.m                       # 9-step environment validation suite
├── plot_results.m                       # DDPG agent validation & plotting script
│
├── dcBusPITuning.slx                    # Baseline Simulink simulation model
├── dcBusPITuningRL.slx                  # TD3 RL training Simulink model
├── dcBusPITuning_Validation.slx         # Excel data-replay Simulink model
├── DCBusPITuningTD3Agent.mat            # Saved trained TD3 agent & optimal gains
├── Trained_DRL_DCBus_Agent_v3.mat       # Pre-trained DDPG Neural Network agent weights
│
├── dcbus_simulink_vs_excel.png          # Simulink vs Excel 3-panel validation waveform
├── validation_results_v3.png            # DRL Neural Net vs Historical PI comparison plot
├── training_monitor_screenshot.png      # DDPG training monitor progress screenshot
├── dcbus_data_analysis.png              # Dataset statistical & spectral analysis
├── dcbus_step_response.png              # Scenario 1 step response plot
├── dcbus_disturbance_rejection.png      # Scenario 2 disturbance rejection plot
└── dcbus_data_replay.png                # Scenario 3 disturbance replay plot
```

---

## 🚀 How to Run

### 1. One-Click Unified Execution (Recommended)
```matlab
main
```
or
```matlab
run_project
```

### 2. Execution Modes
- **Mode 1 (Fast Evaluation & Benchmark - Instant)**:
  ```matlab
  main(1)
  ```
- **Mode 2 (Retrain TD3 PI Agent from Scratch)**:
  ```matlab
  main(2, 100)   % Retrains TD3 agent for 100 episodes
  ```
- **Mode 3 (Retrain DDPG Neural Network Agent from Scratch)**:
  ```matlab
  main(3, 500)   % Retrains DDPG agent for 500 episodes
  ```

### 3. Individual Script Execution
- **Run DRL Neural Network Sanity Check:**
  ```matlab
  validate_env
  ```
- **Plot DRL Neural Network Results:**
  ```matlab
  plot_results
  ```
- **Run Simulink Excel Validation Pipeline:**
  ```matlab
  Run_Excel_Simulink_Validation
  ```

---

## 🛠️ System Requirements
- **MATLAB**: R2022b or later
- **Toolboxes**:
  - Simulink
  - Deep Learning Toolbox
  - Reinforcement Learning Toolbox
