%% Run_Excel_Simulink_Validation.m
% =========================================================================
%  Simulink Data Integration & Validation with Real Case Study Excel Data
% =========================================================================
%
% This script runs the actual MATLAB/Simulink engine directly using the real
% Excel data disturbance profile, validates closed-loop tracking under both
% Baseline and TD3-tuned PI controllers, and exports the full simulated
% time-series and comparison metrics to an output Excel spreadsheet:
%
%   --> DCbusData_Simulink_Output.xlsx
%
% Output Sheets:
%   1. 'Simulink_Results': Time-series matching the Excel dataset
%   2. 'Summary_Metrics' : Quantitative comparison (RMSE, Ripple, Max Dip, Effort)

function [simResultsTable, metricsTable] = Run_Excel_Simulink_Validation(excelInput, excelOutput, simDuration)
    if nargin < 1 || isempty(excelInput)
        excelInput = 'Case Study DCbusData.csv (1).xlsx';
    end
    if nargin < 2 || isempty(excelOutput)
        excelOutput = 'DCbusData_Simulink_Output.xlsx';
    end
    if nargin < 3 || isempty(simDuration)
        simDuration = 10.0; % Run 10 seconds (10,000 discrete points @ 1 kHz)
    end

    fprintf('=========================================================================\n');
    fprintf('  SIMULINK EXCEL DATA INTEGRATION & VALIDATION PIPELINE\n');
    fprintf('=========================================================================\n');
    fprintf('Input Data File  : %s\n', excelInput);
    fprintf('Output Excel File: %s\n', excelOutput);
    fprintf('Simulation Length: %.1f seconds\n', simDuration);
    fprintf('=========================================================================\n\n');

    % 1. Ingest Case Study Excel Data
    [dcBusData, plantParams, distProfile] = Load_DCBus_Data(excelInput, false);
    
    Ts = plantParams.Ts;
    N = min(round(simDuration / Ts), length(dcBusData.time));
    t_sim = dcBusData.time(1:N);
    vRef_sim = dcBusData.vRef(1:N);
    vSensed_excel = dcBusData.vDcTrue(1:N);
    u_excel = dcBusData.u(1:N);
    e_excel = dcBusData.error(1:N);

    % Disturbance profile (zero-mean load current variations)
    iLoad_data = distProfile.Iload(1:N) - mean(distProfile.Iload(1:N));

    % 2. Retrieve Controller Gains
    Kp_Base = plantParams.Kp_baseline;
    Ki_Base = plantParams.Ki_baseline;

    if isfile('DCBusPITuningTD3Agent.mat')
        loaded = load('DCBusPITuningTD3Agent.mat');
        Kp_TD3 = loaded.Kp_RL;
        Ki_TD3 = loaded.Ki_RL;
    else
        Kp_TD3 = 0.09170;
        Ki_TD3 = 0.66378;
    end

    fprintf('Controllers to Simulate in Simulink:\n');
    fprintf('  1. Baseline PI Controller : Kp = %.5f, Ki = %.5f\n', Kp_Base, Ki_Base);
    fprintf('  2. TD3 RL-Tuned Controller: Kp = %.5f, Ki = %.5f\n\n', Kp_TD3, Ki_TD3);

    % 3. Ensure Simulink Model Exists & Rebuild if needed
    mdl = 'dcBusPITuning_Validation';
    Build_DCBus_Models(plantParams);
    if ~bdIsLoaded(mdl)
        load_system(mdl);
    end

    % Configure Simulation Time
    set_param(mdl, 'StopTime', num2str(t_sim(end)));

    % Assign input timeseries with an extra buffer point to avoid edge boundary issues
    t_extended = [t_sim; t_sim(end) + Ts];
    vRef_extended = [vRef_sim; vRef_sim(end)];
    iLoad_extended = [iLoad_data; iLoad_data(end)];

    assignin('base', 'vRef_ts', timeseries(vRef_extended, t_extended));
    assignin('base', 'iLoad_ts', timeseries(iLoad_extended, t_extended));

    %% 4. RUN 1: Execute Simulink with Baseline PI Controller
    fprintf('Running Simulink Model [%s] with Baseline PI...\n', mdl);
    set_param([mdl '/PID Controller'], 'P', num2str(Kp_Base), 'I', num2str(Ki_Base));
    simOut_Base = sim(mdl);

    vDc_sim_base = simOut_Base.simout.Data;
    u_sim_base   = simOut_Base.u_out.Data;
    e_sim_base   = simOut_Base.e_out.Data;
    t_sim_out    = simOut_Base.tout;

    % Resample if necessary to match exact length
    if length(vDc_sim_base) ~= N
        vDc_sim_base = interp1(t_sim_out, vDc_sim_base, t_sim, 'linear', 'extrap');
        u_sim_base   = interp1(t_sim_out, u_sim_base, t_sim, 'linear', 'extrap');
        e_sim_base   = interp1(t_sim_out, e_sim_base, t_sim, 'linear', 'extrap');
    end

    %% 5. RUN 2: Execute Simulink with TD3 RL-Tuned PI Controller
    fprintf('Running Simulink Model [%s] with TD3 RL-Tuned PI...\n', mdl);
    set_param([mdl '/PID Controller'], 'P', num2str(Kp_TD3), 'I', num2str(Ki_TD3));
    simOut_TD3 = sim(mdl);

    vDc_sim_td3 = simOut_TD3.simout.Data;
    u_sim_td3   = simOut_TD3.u_out.Data;
    e_sim_td3   = simOut_TD3.e_out.Data;

    if length(vDc_sim_td3) ~= N
        vDc_sim_td3 = interp1(simOut_TD3.tout, vDc_sim_td3, t_sim, 'linear', 'extrap');
        u_sim_td3   = interp1(simOut_TD3.tout, u_sim_td3, t_sim, 'linear', 'extrap');
        e_sim_td3   = interp1(simOut_TD3.tout, e_sim_td3, t_sim, 'linear', 'extrap');
    end

    close_system(mdl, 0);

    %% 6. Compile Results Table
    simResultsTable = table( ...
        t_sim, ...
        vRef_sim, ...
        vSensed_excel, ...
        e_excel, ...
        u_excel, ...
        vDc_sim_base, ...
        e_sim_base, ...
        u_sim_base, ...
        vDc_sim_td3, ...
        e_sim_td3, ...
        u_sim_td3, ...
        'VariableNames', { ...
            'Time_s', ...
            'Vdc_Reference_V', ...
            'Excel_Original_Vdc_V', ...
            'Excel_Original_Error_V', ...
            'Excel_Original_PI_Output', ...
            'Simulink_Baseline_Vdc_V', ...
            'Simulink_Baseline_Error_V', ...
            'Simulink_Baseline_PI_Output', ...
            'Simulink_TD3_Vdc_V', ...
            'Simulink_TD3_Error_V', ...
            'Simulink_TD3_PI_Output' ...
        } ...
    );

    %% 7. Calculate Statistical & Engineering Performance Metrics
    % Metrics for original data, baseline Simulink, and TD3 Simulink
    std_excel = std(vSensed_excel);
    std_base  = std(vDc_sim_base);
    std_td3   = std(vDc_sim_td3);

    rms_ripple_excel = sqrt(mean(e_excel .^ 2));
    rms_ripple_base  = sqrt(mean(e_sim_base .^ 2));
    rms_ripple_td3   = sqrt(mean(e_sim_td3 .^ 2));

    iae_excel = sum(abs(e_excel)) * Ts;
    iae_base  = sum(abs(e_sim_base)) * Ts;
    iae_td3   = sum(abs(e_sim_td3)) * Ts;

    max_err_excel = max(abs(e_excel));
    max_err_base  = max(abs(e_sim_base));
    max_err_td3   = max(abs(e_sim_td3));

    effort_excel = sum(u_excel .^ 2) * Ts;
    effort_base  = sum(u_sim_base .^ 2) * Ts;
    effort_td3   = sum(u_sim_td3 .^ 2) * Ts;

    metricsList = {
        'Voltage Std Deviation (V)';
        'Voltage RMS Ripple (V)';
        'Integrated Absolute Error (IAE)';
        'Peak Voltage Error (V)';
        'Total Control Effort (u^2 dt)'
    };
    val_excel = [std_excel; rms_ripple_excel; iae_excel; max_err_excel; effort_excel];
    val_base  = [std_base;  rms_ripple_base;  iae_base;  max_err_base;  effort_base];
    val_td3   = [std_td3;   rms_ripple_td3;   iae_td3;   max_err_td3;   effort_td3];
    
    imprv_pct = (val_base - val_td3) ./ val_base * 100;

    metricsTable = table( ...
        metricsList, ...
        val_excel, ...
        val_base, ...
        val_td3, ...
        imprv_pct, ...
        'VariableNames', { ...
            'Performance_Metric', ...
            'Excel_Case_Study_Data', ...
            'Simulink_Baseline_PI', ...
            'Simulink_TD3_RL_PI', ...
            'TD3_vs_Baseline_Improvement_pct' ...
        } ...
    );

    fprintf('\n=========================================================================================================\n');
    fprintf('  SIMULINK VS EXCEL CASE STUDY PERFORMANCE METRICS\n');
    fprintf('=========================================================================================================\n');
    disp(metricsTable);
    fprintf('=========================================================================================================\n\n');

    %% 8. Write Results to Excel Output File
    fprintf('Writing output sheets to %s...\n', excelOutput);
    if isfile(excelOutput)
        delete(excelOutput);
    end
    writetable(simResultsTable, excelOutput, 'Sheet', 'Simulink_Results');
    writetable(metricsTable, excelOutput, 'Sheet', 'Summary_Metrics');
    fprintf('  [OK] Successfully generated Excel output: %s\n', excelOutput);

    %% 9. Generate and Save Visual Verification Figure
    f = figure('Name', 'Simulink vs Excel Data Verification', 'Position', [100 100 1050 750], 'Visible', 'off');
    
    % Subplot 1: DC Bus Voltage Tracking
    subplot(3, 1, 1);
    plot(t_sim, vSensed_excel, 'Color', [0.7 0.7 0.7], 'LineWidth', 1.0, 'DisplayName', 'Original Measured V_{dc} (Excel)');
    hold on;
    plot(t_sim, vDc_sim_base, 'Color', '#D95319', 'LineStyle', '--', 'LineWidth', 1.5, 'DisplayName', sprintf('Simulink Baseline PI (Kp=%.3f, Ki=%.3f)', Kp_Base, Ki_Base));
    plot(t_sim, vDc_sim_td3, 'Color', '#2E7D32', 'LineStyle', '-', 'LineWidth', 1.8, 'DisplayName', sprintf('Simulink TD3 RL PI (Kp=%.3f, Ki=%.3f)', Kp_TD3, Ki_TD3));
    yline(300, 'k--', 'V_{ref} = 300V', 'LineWidth', 1.2);
    grid on; ylabel('Bus Voltage V_{dc} (V)'); ylim([295 305]);
    title('Simulink Voltage Regulation under Real Case Study Disturbance');
    legend('Location', 'southeast');

    % Subplot 2: Voltage Error Comparison
    subplot(3, 1, 2);
    plot(t_sim, e_excel, 'Color', [0.7 0.7 0.7], 'LineWidth', 1.0, 'DisplayName', 'Original Error (Excel)');
    hold on;
    plot(t_sim, e_sim_base, 'Color', '#D95319', 'LineStyle', '--', 'LineWidth', 1.5, 'DisplayName', 'Simulink Baseline Error');
    plot(t_sim, e_sim_td3, 'Color', '#2E7D32', 'LineStyle', '-', 'LineWidth', 1.8, 'DisplayName', 'Simulink TD3 RL Error');
    grid on; ylabel('Tracking Error e(t) (V)'); ylim([-5 5]);
    title('Voltage Tracking Error e(t) = V_{ref} - V_{dc}');
    legend('Location', 'northeast');

    % Subplot 3: Controller Output Comparison
    subplot(3, 1, 3);
    plot(t_sim, u_excel, 'Color', [0.7 0.7 0.7], 'LineWidth', 1.0, 'DisplayName', 'Original PI Action (Excel)');
    hold on;
    plot(t_sim, u_sim_base, 'Color', '#D95319', 'LineStyle', '--', 'LineWidth', 1.5, 'DisplayName', 'Simulink Baseline u(t)');
    plot(t_sim, u_sim_td3, 'Color', '#2E7D32', 'LineStyle', '-', 'LineWidth', 1.8, 'DisplayName', 'Simulink TD3 RL u(t)');
    grid on; xlabel('Time (s)'); ylabel('Control Action u(t)'); ylim([-10 10]);
    title('Commanded Converter Control Action u(t)');
    legend('Location', 'southeast');

    saveas(f, 'dcbus_simulink_vs_excel.png');
    close(f);
    fprintf('  [OK] Saved verification plot: dcbus_simulink_vs_excel.png\n');
    fprintf('=========================================================================\n\n');
end
