%% Compare_Controllers.m
% Comprehensive Multi-Controller Benchmarking & Dynamic Testing Suite
% Compares:
%   1) Baseline / Case Study PI Controller (identified from Excel data)
%   2) Classical PI Controller (Frequency/Pole-placement tuned)
%   3) TD3 Reinforcement Learning Tuned PI Controller
%
% Across 3 Dynamic Scenarios:
%   Scenario 1: Reference Step Tracking (280V -> 300V -> 315V -> 290V)
%   Scenario 2: Heavy Load Step Disturbance Rejection (+15A, -20A load steps)
%   Scenario 3: Real Case Study Disturbance Replay (from Excel dataset)

function [metricsTable, simResults] = Compare_Controllers(gains_RL, excelFile, doPlots)
    if nargin < 2 || isempty(excelFile)
        excelFile = 'Case Study DCbusData.csv (1).xlsx';
    end
    if nargin < 3
        doPlots = true;
    end

    fprintf('=====================================================\n');
    fprintf('  DC-Bus Multi-Controller Performance Benchmarking\n');
    fprintf('=====================================================\n');

    % 1. Load Data & Parameters
    [dcBusData, plantParams, distProfile] = Load_DCBus_Data(excelFile, false);

    % Retrieve RL Gains
    if nargin < 1 || isempty(gains_RL)
        if isfile('DCBusPITuningTD3Agent.mat')
            loaded = load('DCBusPITuningTD3Agent.mat');
            Kp_RL = loaded.Kp_RL;
            Ki_RL = loaded.Ki_RL;
        else
            % Default trained values
            Kp_RL = 0.0917;
            Ki_RL = 0.6638;
        end
    else
        Kp_RL = gains_RL(1);
        Ki_RL = gains_RL(2);
    end

    % Baseline & Classical Gains
    Kp_Base = plantParams.Kp_baseline;
    Ki_Base = plantParams.Ki_baseline;
    
    % Classical PI: Pole-placement tuned for first-order DC-Bus
    Kp_Class = 1.20;
    Ki_Class = 0.08;

    controllers = {
        'Baseline (Case Study)', Kp_Base, Ki_Base;
        'Classical PI (Tuned)',  Kp_Class, Ki_Class;
        'TD3 RL Tuned PI',       Kp_RL, Ki_RL
    };

    fprintf('Controllers Under Evaluation:\n');
    for c = 1:size(controllers, 1)
        fprintf('  %d. %-25s : Kp = %.5f, Ki = %.5f\n', c, controllers{c, 1}, controllers{c, 2}, controllers{c, 3});
    end
    fprintf('-----------------------------------------------------\n\n');

    Ts = plantParams.Ts;
    Kconv = plantParams.Kconv;
    Ceq = plantParams.Ceq;
    uMin = plantParams.uMin;
    uMax = plantParams.uMax;
    Vref_nom = plantParams.Vref;

    %% ==========================================================
    %% SCENARIO 1: Voltage Reference Step Tracking
    %% ==========================================================
    fprintf('Running Scenario 1: Reference Step Tracking...\n');
    t1 = (0:Ts:3.0)';
    N1 = length(t1);
    
    % Reference profile: starts at 295 V, jumps to 300 V at 0.2s, 305 V at 1.2s, 298 V at 2.1s
    vRef1 = zeros(N1, 1);
    for k = 1:N1
        if t1(k) < 0.2
            vRef1(k) = 295.0;
        elseif t1(k) < 1.2
            vRef1(k) = 300.0;
        elseif t1(k) < 2.1
            vRef1(k) = 305.0;
        else
            vRef1(k) = 298.0;
        end
    end
    iLoad1 = zeros(N1, 1);

    res_step = cell(size(controllers, 1), 1);
    for c = 1:size(controllers, 1)
        res_step{c} = localSimulatePlant(t1, vRef1, iLoad1, 295.0, controllers{c, 2}, controllers{c, 3}, Kconv, Ceq, uMin, uMax, Ts);
    end

    %% ==========================================================
    %% SCENARIO 2: Heavy Load Step Disturbance Rejection
    %% ==========================================================
    fprintf('Running Scenario 2: Heavy Load Step Disturbance Rejection...\n');
    t2 = (0:Ts:3.0)';
    N2 = length(t2);
    vRef2 = 300.0 * ones(N2, 1);
    
    % Load step profile: 0A -> +10A at t=0.5s -> -15A at t=1.5s -> 0A at t=2.3s
    iLoad2 = zeros(N2, 1);
    for k = 1:N2
        if t2(k) >= 0.5 && t2(k) < 1.5
            iLoad2(k) = 10.0;
        elseif t2(k) >= 1.5 && t2(k) < 2.3
            iLoad2(k) = -15.0;
        else
            iLoad2(k) = 0.0;
        end
    end

    res_dist = cell(size(controllers, 1), 1);
    for c = 1:size(controllers, 1)
        res_dist{c} = localSimulatePlant(t2, vRef2, iLoad2, 300.0, controllers{c, 2}, controllers{c, 3}, Kconv, Ceq, uMin, uMax, Ts);
    end

    %% ==========================================================
    %% SCENARIO 3: Real Case Study Disturbance Replay
    %% ==========================================================
    fprintf('Running Scenario 3: Real Case Study Disturbance Replay (Excel Data)...\n');
    % Replay 10 seconds of the real disturbance profile (10,000 samples)
    sampleN = min(10000, length(distProfile.time));
    t3 = distProfile.time(1:sampleN);
    vRef3 = 300.0 * ones(sampleN, 1);
    iLoad3 = distProfile.Iload(1:sampleN) - mean(distProfile.Iload(1:sampleN)); % Zero-mean disturbance

    res_replay = cell(size(controllers, 1), 1);
    for c = 1:size(controllers, 1)
        res_replay{c} = localSimulatePlant(t3, vRef3, iLoad3, 300.0, controllers{c, 2}, controllers{c, 3}, Kconv, Ceq, uMin, uMax, Ts);
    end

    %% ==========================================================
    %% Compute Quantitative Performance Metrics
    %% ==========================================================
    numCtrl = size(controllers, 1);
    metricNames = {'Controller', 'Kp', 'Ki', 'RiseTime_ms', 'SettlingTime_ms', 'Overshoot_pct', 'IAE_Step', 'ITAE_Step', 'MaxDip_Dist_V', 'IAE_Replay', 'ControlEffort_Replay', 'RippleRMS_V'};
    tableData = cell(numCtrl, length(metricNames));

    for c = 1:numCtrl
        name = controllers{c, 1};
        kp   = controllers{c, 2};
        ki   = controllers{c, 3};

        % Metrics for Scenario 1 (Step 0.2s: 295V -> 300V)
        idxStep = find(t1 >= 0.2 & t1 <= 1.2);
        t_sub   = t1(idxStep) - 0.2;
        v_sub   = res_step{c}.Vdc(idxStep);
        step_sub = localStepInfo(v_sub, t_sub, 300.0, 295.0);
        
        tr_ms = step_sub.RiseTime * 1000;
        ts_ms = step_sub.SettlingTime * 1000;
        os_pct = step_sub.Overshoot;
        
        iae_step = sum(abs(res_step{c}.e)) * Ts;
        itae_step = sum(t1 .* abs(res_step{c}.e)) * Ts;

        % Metrics for Scenario 2 (Disturbance sag at 0.5s)
        v_dist_sub = res_dist{c}.Vdc;
        max_dip = 300.0 - min(v_dist_sub(t2 >= 0.5 & t2 <= 1.0));

        % Metrics for Scenario 3 (Excel Replay)
        iae_rep = sum(abs(res_replay{c}.e)) * Ts;
        ctrl_eff = sum(res_replay{c}.u .^ 2) * Ts;
        ripple_rms = sqrt(mean(res_replay{c}.e .^ 2));

        tableData(c, :) = {name, kp, ki, tr_ms, ts_ms, os_pct, iae_step, itae_step, max_dip, iae_rep, ctrl_eff, ripple_rms};
    end

    metricsTable = cell2table(tableData, 'VariableNames', metricNames);
    
    fprintf('\n=========================================================================================================\n');
    fprintf('  BENCHMARK PERFORMANCE SUMMARY TABLE\n');
    fprintf('=========================================================================================================\n');
    disp(metricsTable);
    fprintf('=========================================================================================================\n\n');

    % Pack simulation results
    simResults = struct();
    simResults.scenario1 = res_step;
    simResults.scenario2 = res_dist;
    simResults.scenario3 = res_replay;
    simResults.controllers = controllers;
    simResults.metrics = metricsTable;

    %% ==========================================================
    %% Plotting Comparison Figures
    %% ==========================================================
    if doPlots
        colors = {'#D95319', '#0072BD', '#2E7D32'}; % Orange/Red, Blue, Green
        lineStyles = {'--', ':', '-'};
        lineWidths = [1.5, 1.5, 2.0];

        % --- FIGURE 1: Reference Step Tracking ---
        f1 = figure('Name', 'Scenario 1: Reference Step Tracking', 'Position', [100 100 900 650], 'Visible', 'off');
        subplot(3, 1, 1);
        plot(t1, vRef1, 'k--', 'LineWidth', 1.5, 'DisplayName', 'V_{ref}');
        hold on;
        for c = 1:numCtrl
            plot(t1, res_step{c}.Vdc, 'Color', colors{c}, 'LineStyle', lineStyles{c}, 'LineWidth', lineWidths(c), 'DisplayName', controllers{c, 1});
        end
        grid on; ylabel('Bus Voltage V_{dc} (V)'); title('Scenario 1: Voltage Reference Step Tracking');
        legend('Location', 'southeast'); ylim([290 310]);

        subplot(3, 1, 2);
        for c = 1:numCtrl
            plot(t1, res_step{c}.e, 'Color', colors{c}, 'LineStyle', lineStyles{c}, 'LineWidth', lineWidths(c), 'DisplayName', controllers{c, 1});
            hold on;
        end
        grid on; ylabel('Tracking Error e (V)'); title('Voltage Error e(t) = V_{ref} - V_{dc}');
        legend('Location', 'northeast');

        subplot(3, 1, 3);
        for c = 1:numCtrl
            plot(t1, res_step{c}.u, 'Color', colors{c}, 'LineStyle', lineStyles{c}, 'LineWidth', lineWidths(c), 'DisplayName', controllers{c, 1});
            hold on;
        end
        yline(uMin, 'k:', 'u_{min}'); yline(uMax, 'k:', 'u_{max}');
        grid on; xlabel('Time (s)'); ylabel('Control Action u(t)'); title('Controller Effort & Saturation Bounds');
        legend('Location', 'southeast');

        saveas(f1, 'dcbus_step_response.png');
        close(f1);
        fprintf('  Saved plot: dcbus_step_response.png\n');

        % --- FIGURE 2: Load Step Disturbance Rejection ---
        f2 = figure('Name', 'Scenario 2: Disturbance Rejection', 'Position', [100 100 900 650], 'Visible', 'off');
        subplot(3, 1, 1);
        plot(t2, iLoad2, 'r', 'LineWidth', 1.5);
        grid on; ylabel('I_{load} (A)'); title('Scenario 2: Injected Load Disturbance Steps (+10A, -15A)');

        subplot(3, 1, 2);
        for c = 1:numCtrl
            plot(t2, res_dist{c}.Vdc, 'Color', colors{c}, 'LineStyle', lineStyles{c}, 'LineWidth', lineWidths(c), 'DisplayName', controllers{c, 1});
            hold on;
        end
        yline(300, 'k--', 'V_{ref} = 300V');
        grid on; ylabel('Bus Voltage V_{dc} (V)'); title('Bus Voltage Transient Response under Load Steps');
        legend('Location', 'southeast'); ylim([290 310]);

        subplot(3, 1, 3);
        for c = 1:numCtrl
            plot(t2, res_dist{c}.u, 'Color', colors{c}, 'LineStyle', lineStyles{c}, 'LineWidth', lineWidths(c), 'DisplayName', controllers{c, 1});
            hold on;
        end
        grid on; xlabel('Time (s)'); ylabel('Control Action u(t)'); title('Corrective Control Action');
        legend('Location', 'northeast');

        saveas(f2, 'dcbus_disturbance_rejection.png');
        close(f2);
        fprintf('  Saved plot: dcbus_disturbance_rejection.png\n');

        % --- FIGURE 3: Excel Data Disturbance Replay ---
        f3 = figure('Name', 'Scenario 3: Real Case Study Disturbance Replay', 'Position', [100 100 900 650], 'Visible', 'off');
        subplot(3, 1, 1);
        plot(t3, iLoad3, 'Color', [0.5 0.2 0.7], 'LineWidth', 1.2);
        grid on; ylabel('I_{load} (A)'); title('Scenario 3: Replayed Real Load Disturbance Profile (from Excel Data)');

        subplot(3, 1, 2);
        for c = 1:numCtrl
            plot(t3, res_replay{c}.Vdc, 'Color', colors{c}, 'LineStyle', lineStyles{c}, 'LineWidth', lineWidths(c), 'DisplayName', controllers{c, 1});
            hold on;
        end
        yline(300, 'k--', 'V_{ref} = 300V');
        grid on; ylabel('Bus Voltage V_{dc} (V)'); title('Voltage Regulation Comparison under Real Disturbance');
        legend('Location', 'southeast');

        subplot(3, 1, 3);
        for c = 1:numCtrl
            plot(t3, res_replay{c}.e, 'Color', colors{c}, 'LineStyle', lineStyles{c}, 'LineWidth', lineWidths(c), 'DisplayName', controllers{c, 1});
            hold on;
        end
        grid on; xlabel('Time (s)'); ylabel('Error e(t) (V)'); title('Tracking Error Comparison (Ripple & Deviations)');
        legend('Location', 'northeast');

        saveas(f3, 'dcbus_data_replay.png');
        close(f3);
        fprintf('  Saved plot: dcbus_data_replay.png\n');
    end
    fprintf('=====================================================\n\n');
end

%% Local Simulation Helper Function
function res = localSimulatePlant(t, vRef, iLoad, v0, Kp, Ki, Kconv, Ceq, uMin, uMax, Ts)
    N = length(t);
    Vdc = zeros(N, 1);
    e = zeros(N, 1);
    u = zeros(N, 1);
    
    integ_e = 0.0;
    Vdc_curr = v0;

    for k = 1:N
        e_curr = vRef(k) - Vdc_curr;
        integ_e = integ_e + e_curr * Ts;
        
        % PI Controller law
        u_raw = Kp * e_curr + Ki * integ_e;
        
        % Saturation
        u_sat = max(uMin, min(uMax, u_raw));
        
        % Anti-windup clamping on integrator
        if (u_raw ~= u_sat) && (sign(u_raw) == sign(e_curr))
            integ_e = integ_e - e_curr * Ts; % unwind integration step
        end

        % Plant ODE: dVdc/dt = (Kconv*u - iLoad)/Ceq
        dVdc_dt = (Kconv * u_sat - iLoad(k)) / Ceq;
        
        % Record states
        Vdc(k) = Vdc_curr;
        e(k) = e_curr;
        u(k) = u_sat;

        % State update
        Vdc_curr = Vdc_curr + dVdc_dt * Ts;
    end

    res = struct('t', t, 'Vdc', Vdc, 'e', e, 'u', u);
end

%% Standalone Step Info Calculator (No Control System Toolbox required)
function s = localStepInfo(y, t, yFinal, yInitial)
    if nargin < 4
        yInitial = y(1);
    end
    
    deltaY = yFinal - yInitial;
    if abs(deltaY) < 1e-6
        s = struct('RiseTime', 0, 'SettlingTime', 0, 'Overshoot', 0, 'Peak', max(y));
        return;
    end

    yNorm = (y - yInitial) / deltaY;
    
    % Rise time: 10% to 90%
    idx10 = find(yNorm >= 0.10, 1, 'first');
    idx90 = find(yNorm >= 0.90, 1, 'first');
    if ~isempty(idx10) && ~isempty(idx90) && idx90 >= idx10
        riseTime = t(idx90) - t(idx10);
    else
        riseTime = NaN;
    end

    % Peak and Overshoot
    if deltaY > 0
        [peakVal, idxPeak] = max(y);
        overshoot = max(0, (peakVal - yFinal) / deltaY * 100);
    else
        [peakVal, idxPeak] = min(y);
        overshoot = max(0, (yFinal - peakVal) / abs(deltaY) * 100);
    end

    % Settling time: within 2% band of final value
    band = 0.02 * abs(deltaY);
    outsideIndices = find(abs(y - yFinal) > band);
    if isempty(outsideIndices)
        settlingTime = t(1);
    elseif outsideIndices(end) < length(t)
        settlingTime = t(outsideIndices(end) + 1);
    else
        settlingTime = t(end);
    end

    s = struct('RiseTime', riseTime, 'SettlingTime', settlingTime, 'Overshoot', overshoot, 'Peak', peakVal);
end
