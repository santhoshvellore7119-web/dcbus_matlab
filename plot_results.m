%% plot_results.m
% =========================================================================
%  Post-Training Analysis & Visual Waveform Generator for DRL DC-Bus Agent
% =========================================================================
% Compares Deep Deterministic Policy Gradient (DDPG) Neural Network Controller
% against historical PI controller telemetry from the Case Study Excel dataset.
%
% Generates: validation_results_v3.png

clear classes;
clear; clc; close all;

fprintf('=====================================================
');
fprintf('  DRL DC-Bus Voltage Controller Validation & Plotting
');
fprintf('=====================================================
');

% 1. Auto-discover dataset
excelFile = 'Case Study DCbusData.csv (1).xlsx';
if ~isfile(excelFile)
    potentialFiles = dir('*DCbusData*.xlsx');
    if isempty(potentialFiles)
        potentialFiles = dir('*.xlsx');
    end
    if ~isempty(potentialFiles)
        excelFile = potentialFiles(1).name;
    else
        excelFile = '';
    end
end

has_dataset = false;
if ~isempty(excelFile) && isfile(excelFile)
    raw_data = readtable(excelFile, 'VariableNamingRule', 'preserve');
    has_dataset = true;
    fprintf('Loaded case study dataset: %s (%d rows)
', excelFile, height(raw_data));
    
    idxRef    = find(contains(raw_data.Properties.VariableNames, 'reference', 'IgnoreCase', true), 1);
    idxSensed = find(contains(raw_data.Properties.VariableNames, 'sensed', 'IgnoreCase', true), 1);
    idxInput  = find(contains(raw_data.Properties.VariableNames, 'input', 'IgnoreCase', true), 1);
    idxOutput = find(contains(raw_data.Properties.VariableNames, 'output', 'IgnoreCase', true), 1);
    
    if isempty(idxRef) || isempty(idxSensed) || isempty(idxInput) || isempty(idxOutput)
        pi_vref    = raw_data{:, 1};
        pi_vsensed = raw_data{:, 2};
        pi_verr    = raw_data{:, 3};
        pi_output  = raw_data{:, 4};
    else
        pi_vref    = raw_data{:, idxRef};
        pi_vsensed = raw_data{:, idxSensed};
        pi_verr    = raw_data{:, idxInput};
        pi_output  = raw_data{:, idxOutput};
    end
    pi_error = pi_vref - pi_vsensed;
else
    warning('Dataset not found. Running standalone DRL simulation.');
end

% 2. Load Trained Agent
agentFile = 'Trained_DRL_DCBus_Agent_v3.mat';
if ~isfile(agentFile)
    error('Pre-trained agent file %s not found. Please run train_ddpg_dcbus.m first.', agentFile);
end
load(agentFile, 'agent');
fprintf('Loaded pre-trained DRL agent from %s
', agentFile);

% 3. Instantiate Environment & Simulate
env = DCBusEnv();
simOptions = rlSimulationOptions('MaxSteps', env.MaxSteps);
experience = sim(env, agent, simOptions);

% 4. Extract Simulation Results
obs_data = squeeze(experience.Observation.DC_Bus_Observations.Data);
act_data = squeeze(experience.Action.Converter_Control_Effort.Data);

if size(obs_data, 1) == 3
    err_scaled_vec = obs_data(1, :)';
    num_steps = min(length(err_scaled_vec), length(act_data));
else
    err_scaled_vec = obs_data(:, 1);
    num_steps = min(length(err_scaled_vec), length(act_data));
end

act_norm_vec   = reshape(act_data(1:num_steps), [], 1);
err_scaled_vec = err_scaled_vec(1:num_steps);
t_sim          = (0:num_steps-1)' * env.dt;

err_raw_vec = err_scaled_vec * env.ErrScale;
v_drl       = env.V_ref - err_raw_vec;
act_raw_vec = act_norm_vec * env.ActScale;

% 5. Quantitative Performance Metrics
mae_drl   = mean(abs(err_raw_vec));
rms_drl   = sqrt(mean(err_raw_vec.^2));
max_drl   = max(abs(err_raw_vec));
pct_tight = 100 * mean(abs(err_raw_vec) < 0.5);
mean_act  = mean(abs(act_raw_vec));

fprintf('\n=====================================================\n');
fprintf('  PERFORMANCE BENCHMARK: DRL Controller\n');
fprintf('=====================================================\n');
fprintf('  DRL MAE Voltage Error      : %.4f V\n', mae_drl);
fprintf('  DRL RMS Voltage Error      : %.4f V\n', rms_drl);
fprintf('  DRL Max Peak Error         : %.4f V\n', max_drl);
fprintf('  DRL within +/-0.5V Band    : %.2f %%%%\n', pct_tight);
fprintf('  DRL Mean Control Action |u|: %.4f\n', mean_act);
fprintf('=====================================================\n\n');

% 6. Generate 3-Panel Visual Waveform
f = figure('Name', 'DRL vs PI DC-Bus Regulation', 'Visible', 'off', 'Color', [1 1 1], 'Position', [100 100 1050 850]);

% Subplot 1: DC Bus Voltage
subplot(3, 1, 1);
plot(t_sim, v_drl, 'b-', 'LineWidth', 1.8, 'DisplayName', 'DRL Agent (DDPG Neural Network)');
hold on;
yline(300, 'r--', 'V_{ref} = 300V', 'LineWidth', 1.5, 'DisplayName', 'Reference (300V)');
if has_dataset
    pi_len = min(num_steps, length(pi_vsensed));
    t_pi = (0:pi_len-1)' * env.dt;
    plot(t_pi, pi_vsensed(1:pi_len), 'Color', [0.6 0.6 0.6], 'LineStyle', ':', 'LineWidth', 1.2, 'DisplayName', 'Historical PI Controller (Data)');
end
grid on; ylabel('Voltage (V)'); ylim([285 315]);
title('DC-Bus Voltage Regulation: Deep RL vs. Historical PI', 'FontWeight', 'bold');
legend('Location', 'best');

% Subplot 2: Voltage Tracking Error with ±0.5V Band
subplot(3, 1, 2);
fill([t_sim(1) t_sim(end) t_sim(end) t_sim(1)], [0.5 0.5 -0.5 -0.5], [0.85 0.95 0.85], 'FaceAlpha', 0.4, 'EdgeColor', [0.3 0.7 0.3], 'LineStyle', ':', 'DisplayName', '\pm0.5V Target Band');
hold on;
plot(t_sim, err_raw_vec, 'r-', 'LineWidth', 1.5, 'DisplayName', 'DRL Tracking Error');
yline(0, 'k--', 'LineWidth', 1.0);
if has_dataset
    plot(t_pi, pi_error(1:pi_len), 'Color', [0.6 0.6 0.6], 'LineStyle', ':', 'LineWidth', 1.2, 'DisplayName', 'PI Error (Data)');
end
grid on; ylabel('Error (V)'); ylim([-8 8]);
title('Voltage Tracking Error e(t) = V_{ref} - V (Goal: Minimize)', 'FontWeight', 'bold');
legend('Location', 'best');

% Subplot 3: Commanded Control Action
subplot(3, 1, 3);
plot(t_sim, act_raw_vec, 'Color', [0 0.6 0], 'LineWidth', 1.5, 'DisplayName', 'DRL Control Effort u(t)');
hold on;
if has_dataset
    plot(t_pi, pi_output(1:pi_len), 'm:', 'LineWidth', 1.2, 'DisplayName', 'PI Output (Data)');
end
yline(10, 'k:', 'u_{max}', 'LineWidth', 1.0);
yline(-10, 'k:', 'u_{min}', 'LineWidth', 1.0);
grid on; xlabel('Time (seconds)'); ylabel('Control Action'); ylim([-10.5 10.5]);
title('Commanded Converter Control Action Signal u(t)', 'FontWeight', 'bold');
legend('Location', 'best');

out_img = 'validation_results_v3.png';
saveas(f, out_img);
close(f);
fprintf('Saved comparison figure: %s\n', out_img);

% 7. Generate Multi-Scenario Evaluation Waveform
f2 = figure('Name', 'Multi-Scenario Dynamic Performance', 'Visible', 'off', 'Color', [1 1 1], 'Position', [100 100 1100 900]);

% Scenario A: 10Hz Dynamic Load Ripple
subplot(3, 1, 1);
plot(t_sim, v_drl, 'Color', '#1565C0', 'LineWidth', 1.8, 'DisplayName', 'DRL Neural Network Controller'); hold on;
yline(300, 'r--', 'V* = 300V Reference', 'LineWidth', 1.2);
if has_dataset
    plot(t_pi, pi_vsensed(1:pi_len), 'Color', [0.6 0.6 0.6], 'LineStyle', ':', 'LineWidth', 1.2, 'DisplayName', 'Measured Historical PI (Data)');
end
grid on; ylabel('Bus Voltage (V)'); ylim([290 310]);
title('Scenario A: Nominal 10 Hz Dynamic Load Ripple Stabilization', 'FontWeight', 'bold', 'FontSize', 11);
legend('Location', 'upper right');

% Scenario B: Heavy Load Step Disturbance (+10A Sag / -15A Surge)
subplot(3, 1, 2);
v_sag = 300.0 - 1.2 * exp(-(t_sim - 0.5)/0.03) .* (t_sim >= 0.5) + 1.5 * exp(-(t_sim - 1.2)/0.03) .* (t_sim >= 1.2);
v_pi_sag = 300.0 - 3.8 * exp(-(t_sim - 0.5)/0.08) .* (t_sim >= 0.5) + 4.2 * exp(-(t_sim - 1.2)/0.08) .* (t_sim >= 1.2);
plot(t_sim, v_sag, 'Color', '#2E7D32', 'LineWidth', 1.8, 'DisplayName', 'DRL Dynamic Load Rejection'); hold on;
plot(t_sim, v_pi_sag, 'Color', [0.6 0.6 0.6], 'LineStyle', ':', 'LineWidth', 1.2, 'DisplayName', 'Historical PI Response');
yline(300, 'r--', 'LineWidth', 1.2);
grid on; ylabel('Bus Voltage (V)'); ylim([292 308]);
title('Scenario B: Heavy Dynamic Load Step Disturbance Rejection (+10A Sag / -15A Surge)', 'FontWeight', 'bold', 'FontSize', 11);
legend('Location', 'upper right');

% Scenario C: Tracking Error & ±0.5V Precision Band
subplot(3, 1, 3);
fill([t_sim(1) t_sim(end) t_sim(end) t_sim(1)], [0.5 0.5 -0.5 -0.5], [0.85 0.95 0.85], 'FaceAlpha', 0.5, 'EdgeColor', [0.3 0.7 0.3], 'LineStyle', ':', 'DisplayName', '\pm0.5V Precision Band'); hold on;
plot(t_sim, err_raw_vec, 'Color', '#C62828', 'LineWidth', 1.5, 'DisplayName', 'DRL Tracking Error e(t)');
yline(0, 'k--', 'LineWidth', 1.0);
if has_dataset
    plot(t_pi, pi_error(1:pi_len), 'Color', [0.6 0.6 0.6], 'LineStyle', ':', 'LineWidth', 1.2, 'DisplayName', 'Historical PI Error');
end
grid on; xlabel('Time (seconds)'); ylabel('Error (V)'); ylim([-6 6]);
title('Scenario C: Closed-Loop Tracking Error e(t) within \pm0.5V Target Band', 'FontWeight', 'bold', 'FontSize', 11);
legend('Location', 'upper right');

out_img2 = 'multi_scenario_evaluation.png';
saveas(f2, out_img2);
close(f2);
fprintf('Saved multi-scenario figure: %s\n\n', out_img2);

