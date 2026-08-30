%% main.m
% =========================================================================
%  DC-BUS VOLTAGE PI CONTROLLER TUNING & EVALUATION PROJECT
%  Data-Driven Twin Delayed DDPG (TD3) Reinforcement Learning
% =========================================================================
%
% This is the master orchestrator script for the project.
% It coordinates the entire engineering workflow:
%   1. Ingests and analyzes 'Case Study DCbusData.csv (1).xlsx'
%   2. Programmatically constructs and verifies Simulink models (dcBusPITuning, dcBusPITuningRL)
%   3. Trains / Loads the TD3 Reinforcement Learning Agent
%   4. Benchmarks the TD3-tuned PI controller against Classical PI and Baseline
%   5. Generates publication-quality comparison plots & summary performance tables
%
% Usage:
%   main()               % Runs fast benchmark if agent exists, or trains 50 episodes
%   main(1)              % Mode 1: Fast evaluation (loads pre-trained agent)
%   main(2, 100)         % Mode 2: Full training (trains 100 episodes from scratch)

function [metricsTable, simResults] = main(mode, numEpisodes)
    clc;
    close all;
    
    excelFile = 'Case Study DCbusData.csv (1).xlsx';
    agentFile = 'DCBusPITuningTD3Agent.mat';

    if nargin < 1 || isempty(mode)
        if isfile(agentFile)
            mode = 1; % Fast benchmark mode
        else
            mode = 2; % Training mode
        end
    end
    if nargin < 2 || isempty(numEpisodes)
        numEpisodes = 50;
    end

    fprintf('=========================================================================\n');
    fprintf('   DC-BUS PI CONTROLLER TUNING WITH TD3 REINFORCEMENT LEARNING\n');
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
    if mode == 2 || ~isfile(agentFile)
        doTrain = true;
    else
        doTrain = false;
    end

    [agent, Kp_RL, Ki_RL, trainStats] = DCBusPI_TD3_Tuning(doTrain, numEpisodes, excelFile);

    %% STEP 5: Multi-Controller Dynamic Benchmarking & Visualization
    fprintf('[STEP 5/6] Running Multi-Controller Dynamic Benchmarks...\n');
    [metricsTable, simResults] = Compare_Controllers([Kp_RL, Ki_RL], excelFile, true);

    %% STEP 6: Simulink Direct Excel Data Integration & Export Output Spreadsheet
    fprintf('[STEP 6/6] Running Simulink with Real Excel Disturbance & Exporting Output Excel...\n');
    excelOutputFile = 'DCbusData_Simulink_Output.xlsx';
    [simExcelTable, simExcelMetrics] = Run_Excel_Simulink_Validation(excelFile, excelOutputFile, 10.0);

    fprintf('=========================================================================\n');
    fprintf('  PROJECT EXECUTION COMPLETED SUCCESSFULLY!\n');
    fprintf('=========================================================================\n');
    fprintf('Generated Figures:\n');
    fprintf('  - dcbus_data_analysis.png        : Case study voltage, error & disturbance profiles\n');
    fprintf('  - dcbus_step_response.png        : Voltage reference step tracking comparison\n');
    fprintf('  - dcbus_disturbance_rejection.png: Heavy load step disturbance rejection comparison\n');
    fprintf('  - dcbus_data_replay.png          : Real case study disturbance replay comparison\n');
    fprintf('  - dcbus_simulink_vs_excel.png    : Simulink vs Excel original measurements comparison\n');
    fprintf('Saved Models & Output Spreadsheets:\n');
    fprintf('  - dcBusPITuning.slx              : Baseline Simulink model\n');
    fprintf('  - dcBusPITuningRL.slx            : TD3 RL training Simulink model\n');
    fprintf('  - dcBusPITuning_Validation.slx   : Data-replay Simulink model\n');
    fprintf('  - DCBusPITuningTD3Agent.mat      : Tuned TD3 agent & optimal gains [Kp, Ki]\n');
    fprintf('  - DCbusData_Simulink_Output.xlsx : Output Excel spreadsheet with full Simulink results\n');
    fprintf('=========================================================================\n\n');
end

function str = localGetModeName(m)
    switch m
        case 1
            str = 'Mode 1 (Fast Evaluation & Benchmark - Load Saved Agent)';
        case 2
            str = 'Mode 2 (Full Retrain TD3 Agent & Benchmark)';
        otherwise
            str = 'Mode 1 (Default)';
    end
end
