%% main.m
% =========================================================================
%  DC-BUS VOLTAGE CONTROLLER: PI TUNING & DRL MULTI-AGENT FRAMEWORK
%  Data-Driven Twin Delayed DDPG (TD3) & Deep Deterministic Policy Gradient
% =========================================================================
% Master orchestrator script coordinating:
%   1. Dataset ingestion & disturbance extraction ('Case Study DCbusData.csv (1).xlsx')
%   2. Programmatic Simulink model generation & wiring verification
%   3. TD3 RL PI gain tuning & optimal parameter extraction
%   4. Deep Deterministic Policy Gradient (DDPG) Neural Network Controller validation
%   5. Dynamic multi-scenario benchmarking & visual comparisons
%   6. Simulink real Excel replay & export to 'DCbusData_Simulink_Output.xlsx'
%
% Usage:
%   main()               % Mode 1: Fast benchmark & validation (default)
%   main(1)              % Mode 1: Fast evaluation (loads pre-trained agents)
%   main(2, 100)         % Mode 2: Retrain TD3 PI Agent (100 episodes)
%   main(3, 500)         % Mode 3: Retrain DDPG Neural Network Agent (500 episodes)
%   main(4)              % Mode 4: Run 9-Step DRL Environment Validation Suite

function [metricsTable, simResults] = main(mode, numEpisodes)
    clc;
    close all;
    
    excelFile = 'Case Study DCbusData.csv (1).xlsx';
    td3AgentFile = 'DCBusPITuningTD3Agent.mat';
    drlAgentFile = 'Trained_DRL_DCBus_Agent_v3.mat';

    if nargin < 1 || isempty(mode)
        mode = 1; % Fast benchmark mode default
    end
    if nargin < 2 || isempty(numEpisodes)
        numEpisodes = 50;
    end

    if mode == 4
        fprintf('=========================================================================\n');
        fprintf('   RUNNING 9-STEP DRL ENVIRONMENT VALIDATION SUITE\n');
        fprintf('=========================================================================\n\n');
        run validate_env;
        metricsTable = [];
        simResults = [];
        return;
    end

    fprintf('=========================================================================\n');
    fprintf('   DC-BUS VOLTAGE REGULATOR: PI TUNING & DRL BENCHMARK SUITE\n');
    fprintf('=========================================================================\n');
    fprintf('Execution Mode: %s\n', localGetModeName(mode));
    fprintf('Data Source   : %s\n', excelFile);
    fprintf('MATLAB Release: %s\n', version);
    fprintf('=========================================================================\n\n');

    %% STEP 1: Load and Profile Case Study Data
    fprintf('[STEP 1/6] Ingesting and Profiling Case Study Dataset...\n');
    [dcBusData, plantParams, distProfile] = Load_DCBus_Data(excelFile, true);

    %% STEP 2: Programmatically Construct Simulink Models
    fprintf('[STEP 2/6] Programmatically Constructing Simulink Models...\n');
    Build_DCBus_Models(plantParams);

    %% STEP 3: Model Diagnostics & Wiring Verification
    fprintf('[STEP 3/6] Verifying Model Architecture & Port Connectivity...\n');
    modelsValid = Check_Model_Wiring({'dcBusPITuning', 'dcBusPITuningRL'});
    if ~modelsValid
        error('Simulink model diagnostics failed. Please inspect model configuration.');
    end

    %% STEP 4: Train / Load TD3 Reinforcement Learning Agent
    fprintf('[STEP 4/6] Executing TD3 RL Tuning Pipeline...\n');
    if mode == 2 || ~isfile(td3AgentFile)
        doTrainTD3 = true;
    else
        doTrainTD3 = false;
    end
    [agentTD3, Kp_RL, Ki_RL, trainStats] = DCBusPI_TD3_Tuning(doTrainTD3, numEpisodes, excelFile);

    %% STEP 5: DRL Deep Neural Network Controller Validation
    fprintf('[STEP 5/6] Validating Deep Deterministic Policy Gradient (DDPG) Agent...\n');
    if mode == 3 || ~isfile(drlAgentFile)
        fprintf('  Retraining DDPG Neural Network Agent...\n');
        run train_ddpg_dcbus;
    elseif isfile('plot_results.m')
        fprintf('  Evaluating pre-trained DDPG Neural Network Agent...\n');
        run plot_results;
    end

    %% STEP 6: Multi-Controller Dynamic Benchmarks & Excel Export
    fprintf('[STEP 6/6] Running Multi-Controller Dynamic Benchmarks & Exporting Excel...\n');
    [metricsTable, simResults] = Compare_Controllers([Kp_RL, Ki_RL], excelFile, true);
    
    excelOutputFile = 'DCbusData_Simulink_Output.xlsx';
    [simExcelTable, simExcelMetrics] = Run_Excel_Simulink_Validation(excelFile, excelOutputFile, 10.0);

    fprintf('=========================================================================\n');
    fprintf('  PROJECT EXECUTION COMPLETED SUCCESSFULLY!\n');
    fprintf('=========================================================================\n');
    fprintf('Generated Figures:\n');
    fprintf('  - dcbus_simulink_vs_excel.png    : Simulink vs Excel original measurements comparison\n');
    fprintf('  - validation_results_v3.png      : DRL Neural Network vs Historical PI comparison\n');
    fprintf('  - dcbus_data_analysis.png        : Case study voltage, error & disturbance profiles\n');
    fprintf('  - dcbus_step_response.png        : Voltage reference step tracking comparison\n');
    fprintf('  - dcbus_disturbance_rejection.png: Heavy load step disturbance rejection comparison\n');
    fprintf('  - dcbus_data_replay.png          : Real case study disturbance replay comparison\n');
    fprintf('Saved Models & Output Spreadsheets:\n');
    fprintf('  - dcBusPITuning.slx              : Baseline Simulink model\n');
    fprintf('  - dcBusPITuningRL.slx            : TD3 RL training Simulink model\n');
    fprintf('  - dcBusPITuning_Validation.slx   : Data-replay Simulink model\n');
    fprintf('  - DCBusPITuningTD3Agent.mat      : Tuned TD3 agent & optimal gains [Kp, Ki]\n');
    fprintf('  - Trained_DRL_DCBus_Agent_v3.mat : Pre-trained DDPG Neural Network weights\n');
    fprintf('  - DCbusData_Simulink_Output.xlsx : Output Excel spreadsheet with full Simulink results\n');
    fprintf('=========================================================================\n\n');
end

function str = localGetModeName(m)
    switch m
        case 1
            str = 'Mode 1 (Fast Evaluation & Benchmark - Load Saved Agents)';
        case 2
            str = 'Mode 2 (Retrain TD3 PI Agent & Benchmark)';
        case 3
            str = 'Mode 3 (Retrain DDPG Neural Network Agent & Benchmark)';
        case 4
            str = 'Mode 4 (Run 9-Step DRL Environment Validation Suite)';
        otherwise
            str = 'Mode 1 (Default)';
    end
end
