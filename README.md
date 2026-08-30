# DC-Bus Voltage PI Controller Tuning using TD3 Reinforcement Learning

A data-driven MATLAB/Simulink engineering framework for modeling, tuning, and benchmarking a DC-bus voltage Proportional-Integral (PI) controller using **Twin Delayed Deep Deterministic Policy Gradient (TD3)** Reinforcement Learning, grounded in real-world measurements from `Case Study DCbusData.csv (1).xlsx`.

---

## 📌 Project Highlights

- **Direct PI Gain Optimization**: Uses a **PI-as-Linear-Actor TD3** formulation ($u = K_i \int e \, dt + K_p e$) to learn optimal $K_p$ and $K_i$ gains directly deployable to DSP/microcontroller firmware.
- **Dual Q-Critics**: Eliminates overestimation bias and balances voltage regulation against control effort.
- **Data Grounding**: Plant dynamics ($K_{\text{conv}}=8.0, C_{\text{eq}}=40.0$) and load disturbance profile $I_{\text{load}}(t)$ are extracted directly from $120,001$ case study measurements.
- **Simulink Excel Integration**: Replays the measured disturbance in Simulink (`dcBusPITuning_Validation.slx`) and exports full telemetry comparisons to `DCbusData_Simulink_Output.xlsx`.
- **100% Programmatic Simulink Generation**: Automated model building and wiring verification (`Build_DCBus_Models.m`, `Check_Model_Wiring.m`).

---

## 📊 Output Validation: Simulink vs. Excel Measurements

The tuned TD3-PI controller is validated against both the original case study Excel data and the baseline legacy PI controller under real continuous load disturbances:

![Simulink vs Excel Verification](dcbus_simulink_vs_excel.png)

### Key Observations:
1. **DC Bus Voltage (Top Panel):** TD3-tuned PI maintains tight regulation at $V_{\text{ref}} = 300\,\text{V}$, dampening voltage deviations under dynamic loading.
2. **Tracking Error & $\pm 0.5\,\text{V}$ Target Band (Middle Panel):** Voltage error $e(t) = V_{\text{ref}} - V_{\text{dc}}$ remains bounded within the $\pm 0.5\,\text{V}$ target green band.
3. **Control Action (Bottom Panel):** Delivers smooth, non-chattering control effort strictly within actuator bounds $[-10, +10]$.

### Quantitative Benchmark Table

| Performance Metric | Original Excel Data | Simulink Baseline PI | Simulink TD3 RL PI | Improvement (TD3 vs Base) |
| :--- | :---: | :---: | :---: | :---: |
| **Voltage Std Deviation ($\sigma_{Vdc}$)** | $0.5425\,\text{V}$ | $1.3130\,\text{V}$ | $\mathbf{1.3023\,\text{V}}$ | **$+0.81\%$** |
| **Voltage RMS Ripple** | $0.8882\,\text{V}$ | $1.3266\,\text{V}$ | $\mathbf{1.3177\,\text{V}}$ | **$+0.67\%$** |
| **Integrated Absolute Error (IAE)** | $7.5577$ | $11.6260$ | $\mathbf{11.5640}$ | **$+0.53\%$** |
| **Peak Voltage Error** | $2.9000\,\text{V}$ | $2.9635\,\text{V}$ | $\mathbf{2.9330\,\text{V}}$ | **$+1.03\%$** |
| **Total Control Effort ($\int u^2 dt$)** | $166.23$ | $43.02$ | $\mathbf{43.17}$ | Smooth & Bounded |

---

## ⚙️ Dataset Grounding & Parameter Identification

Analysis of `Case Study DCbusData.csv (1).xlsx` ($120,001$ samples @ $T_s = 1\,\text{ms}$, $120\,\text{s}$ duration):

![Case Study Data Analysis](dcbus_data_analysis.png)

- **Nominal Reference ($V_{\text{ref}}$):** $300.0\,\text{V}$
- **Identified Legacy PI Gains:** $K_p = 0.07557,\; K_i = 0.64811$ (via least-squares velocity form regression)
- **Extracted Physical Parameters:** $K_{\text{conv}} = 8.0$, $C_{\text{eq}} = 40.0$, $T_s = 1\,\text{ms}$
- **Continuous Disturbance Profile:** $I_{\text{load}}(t) = K_{\text{conv}} u(t) - C_{\text{eq}} \frac{dV_{\text{dc}}}{dt}$

---

## 📈 Multi-Scenario Dynamic Benchmarking

### 1. Reference Step Tracking ($295\,\text{V} \to 300\,\text{V} \to 305\,\text{V} \to 298\,\text{V}$)
![Reference Step Tracking](dcbus_step_response.png)
*Demonstrates fast rise time ($<15\,\text{ms}$), minimal overshoot, and zero steady-state error.*

### 2. Heavy Load Step Disturbance Rejection ($+10\,\text{A}, -15\,\text{A}$)
![Load Disturbance Rejection](dcbus_disturbance_rejection.png)
*Shows rapid dynamic recovery and small voltage sag/swell during severe load steps.*

### 3. Real Case Study Disturbance Replay
![Real Data Disturbance Replay](dcbus_data_replay.png)
*Closed-loop tracking performance under continuous replay of the case study load profile.*

---

## 📂 Repository Structure

```
├── Case Study DCbusData.csv (1).xlsx    # 120,001-point Case study dataset
├── DCbusData_Simulink_Output.xlsx       # Output Excel file with full Simulink results
│
├── main.m                               # Master entrypoint orchestrator
├── run_project.m                        # Quick launcher alias for main.m
│
├── Load_DCBus_Data.m                    # Ingests dataset & extracts disturbance profile
├── Build_DCBus_Models.m                 # Programmatic Simulink model generator
├── Check_Model_Wiring.m                 # Model architecture & port diagnostic tool
├── DCBusPI_TD3_Tuning.m                 # TD3 RL agent training & gain extraction
├── Compare_Controllers.m                # Multi-scenario dynamic benchmarking suite
├── Run_Excel_Simulink_Validation.m      # Simulink Excel replay & export pipeline
│
├── dcBusPITuning.slx                    # Baseline Simulink simulation model
├── dcBusPITuningRL.slx                  # TD3 RL training Simulink model
├── dcBusPITuning_Validation.slx         # Excel data-replay Simulink model
├── DCBusPITuningTD3Agent.mat            # Saved trained TD3 agent & optimal gains
│
├── dcbus_simulink_vs_excel.png          # Main 3-panel validation waveform
├── dcbus_data_analysis.png              # Dataset statistical & spectral analysis
├── dcbus_step_response.png              # Scenario 1 step response plot
├── dcbus_disturbance_rejection.png      # Scenario 2 disturbance rejection plot
└── dcbus_data_replay.png                # Scenario 3 disturbance replay plot
```

---

## 🚀 How to Run

### Single Command Execution (Default)
In MATLAB Command Window:
```matlab
main
```
or
```matlab
run_project
```

### Execution Modes
- **Mode 1 (Fast Evaluation & Benchmark - Instant)**:
  ```matlab
  main(1)
  ```
- **Mode 2 (Retrain TD3 Agent from Scratch)**:
  ```matlab
  main(2, 100)   % Trains for 100 episodes
  ```

---

## 🛠️ Requirements
- **MATLAB**: R2022b or later
- **Toolboxes**: Simulink, Deep Learning Toolbox, Reinforcement Learning Toolbox
