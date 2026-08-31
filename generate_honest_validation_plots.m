%% generate_honest_validation_plots.m
% =========================================================================
%  7-STEP HONEST OUT-OF-SAMPLE VALIDATION & SIGNAL RECONSTRUCTION PIPELINE
% =========================================================================
% Performs signal reconstruction from telemetry, chronological 80/20 split,
% Model A (raw training) vs Model B (filtered training), and honest scoring
% on the raw unfiltered test set.

clear classes; clear; clc; close all;

fprintf('=========================================================================\n');
fprintf('  7-STEP HONEST OUT-OF-SAMPLE VALIDATION PIPELINE EXECUTION\n');
fprintf('=========================================================================\n\n');

%% STEP 1: Data Loading & Sample Time
excelFile = 'Case Study DCbusData.csv (1).xlsx';
if ~isfile(excelFile)
    error('Dataset file not found: %s', excelFile);
end

dataTable = readtable(excelFile, 'VariableNamingRule', 'preserve');
v_ref    = dataTable{:, 1}; % Vdc reference
v_sensed = dataTable{:, 2}; % Vdc Sensed (Quantized / Broken ADC sensor)
pi_in    = dataTable{:, 3}; % PI Input (Tracking Error e = Vref - Vtrue)
pi_out   = dataTable{:, 4}; % PI Output (Control Duty u)
dt       = 0.001;           % Assumed sample time Delta t = 1 ms (1 kHz)

fprintf('[1/7] Data Loaded: %d samples. Assumed sample time dt = 1.0 ms\n', numel(v_ref));

%% STEP 2: Signal Reconstruction Fix
v_true   = v_ref - pi_in;
err_true = v_ref - v_true;
num_unique_sensed = numel(unique(v_sensed));

fprintf('[2/7] Reconstructed Ground Truth Voltage V_true = V_ref - PI_Input\n');
fprintf('      V_true Range        : [%.2f, %.2f] V\n', min(v_true), max(v_true));
fprintf('      Tracking Error Mean : %.2f V | Std: %.2f V | MAE: %.2f V | RMS: %.2f V\n', ...
    mean(err_true), std(err_true), mean(abs(err_true)), sqrt(mean(err_true.^2)));
fprintf('      Quantization Check  : V_sensed has only %d discrete levels (Sensor Quantized!)\n\n', num_unique_sensed);

%% STEP 3: Honest Chronological Train / Test Split (80% Train, 20% Test)
N = numel(v_true);
nEst = round(0.8 * N);

u_train_raw = pi_out(1:nEst);     y_train_raw = v_true(1:nEst);
u_test_raw  = pi_out(nEst+1:end); y_test_raw  = v_true(nEst+1:end);

fprintf('[3/7] Chronological 80/20 Train/Test Split:\n');
fprintf('      Train Horizon : %d samples (0 to %.1f s)\n', nEst, nEst * dt);
fprintf('      Test Horizon  : %d samples (%.1f to %.1f s) [Kept Unfiltered Ground Truth]\n\n', ...
    N - nEst, nEst * dt, N * dt);

%% STEP 4: Model Training (Model A on Raw, Model B on Filtered)
% Model A: Raw Training Data
Phi_train_A = [-y_train_raw(1:end-1), u_train_raw(1:end-1)];
theta_A = Phi_train_A \ y_train_raw(2:end);
a1_A = theta_A(1); b1_A = theta_A(2);

% Model B: Exponential Moving Average (EMA) Low-Pass Filtered Training Data ONLY
alpha_filt = 0.25;
y_train_filt = zeros(size(y_train_raw)); u_train_filt = zeros(size(u_train_raw));
y_train_filt(1) = y_train_raw(1); u_train_filt(1) = u_train_raw(1);
for k = 2:length(y_train_raw)
    y_train_filt(k) = (1 - alpha_filt) * y_train_filt(k-1) + alpha_filt * y_train_raw(k);
    u_train_filt(k) = (1 - alpha_filt) * u_train_filt(k-1) + alpha_filt * u_train_raw(k);
end

Phi_train_B = [-y_train_filt(1:end-1), u_train_filt(1:end-1)];
theta_B = Phi_train_B \ y_train_filt(2:end);
a1_B = theta_B(1); b1_B = theta_B(2);

fprintf('[4/7] Model Identification:\n');
fprintf('      Model A (Raw Train)      : G_p(z) = %.7f / (z %+.7f)\n', b1_A, a1_A);
fprintf('      Model B (Filtered Train) : G_p(z) = %.7f / (z %+.7f)\n\n', b1_B, a1_B);

%% STEP 5: Honest Out-of-Sample Validation on RAW Test Set
y_test_pred_A = -a1_A * y_test_raw(1:end-1) + b1_A * u_test_raw(1:end-1);
y_test_true   = y_test_raw(2:end);
fit_A = (1 - norm(y_test_true - y_test_pred_A) / norm(y_test_true - mean(y_test_true))) * 100;

y_test_pred_B = -a1_B * y_test_raw(1:end-1) + b1_B * u_test_raw(1:end-1);
fit_B = (1 - norm(y_test_true - y_test_pred_B) / norm(y_test_true - mean(y_test_true))) * 100;

% In-sample circular score for comparison
y_test_filt = zeros(size(y_test_raw)); u_test_filt = zeros(size(u_test_raw));
y_test_filt(1) = y_test_raw(1); u_test_filt(1) = u_test_raw(1);
for k = 2:length(y_test_raw)
    y_test_filt(k) = (1 - alpha_filt) * y_test_filt(k-1) + alpha_filt * y_test_raw(k);
    u_test_filt(k) = (1 - alpha_filt) * u_test_filt(k-1) + alpha_filt * u_test_raw(k);
end
y_test_pred_B_filt = -a1_B * y_test_filt(1:end-1) + b1_B * u_test_filt(1:end-1);
fit_B_in_sample = (1 - norm(y_test_filt(2:end) - y_test_pred_B_filt) / norm(y_test_filt(2:end) - mean(y_test_filt(2:end)))) * 100;

fprintf('[5/7] Honest Out-of-Sample Validation Results:\n');
fprintf('      Model A (Trained on Raw, Tested on Raw Test Set)      : Fit = %.2f%%\n', fit_A);
fprintf('      Model B (Trained on Filtered, Tested on Raw Test Set) : Fit = %.2f%%\n', fit_B);
fprintf('      Model B (In-Sample Score on Filtered Test Set)        : Fit = %.2f%% [Circular In-Sample Inflation]\n\n', fit_B_in_sample);

%% STEP 6: Re-derived PI Gains & Saturation Audit
e_train  = pi_in(1:nEst);
ie_train = cumsum(e_train) * dt;
Phi_pi   = [e_train, ie_train];
theta_pi = Phi_pi \ u_train_raw;
Kp_est   = theta_pi(1); Ki_est = theta_pi(2);

sat_pct = 100 * mean(abs(pi_out) >= 9.9);
fprintf('[6/7] Control Audit:\n');
fprintf('      Re-derived PI Gains : Kp = %.5f, Ki = %.5f\n', Kp_est, Ki_est);
fprintf('      Actuator Range      : [%.2f, %.2f] | Saturation Ratio = %.2f%%\n\n', min(pi_out), max(pi_out), sat_pct);

%% STEP 7: Time-Domain Comparison Plot Generation
fprintf('[7/7] Generating Honest Validation Plots...\n');

f1 = figure('Name', 'Honest Validation Comparison', 'Visible', 'on', 'Color', [1 1 1], 'Position', [100 100 950 600]);
t_test = (0:length(y_test_true)-1) * dt;

subplot(2,1,1);
plot(t_test(1:2000), y_test_true(1:2000), 'Color', [0.2 0.2 0.2], 'LineWidth', 1.3, 'DisplayName', 'Raw Ground Truth Test Set (V_{true})'); hold on;
plot(t_test(1:2000), y_test_pred_A(1:2000), 'Color', '#D32F2F', 'LineStyle', '--', 'LineWidth', 1.4, 'DisplayName', sprintf('Model A: Trained on Raw (Honest Out-of-Sample Fit: %.2f%%)', fit_A));
grid on; ylabel('Voltage V_{dc} (V)', 'FontWeight', 'bold');
title('Model A: Trained on Raw Telemetry \rightarrow Tested on Raw Ground Truth Test Set', 'FontWeight', 'bold');
legend('Location', 'northeast');

subplot(2,1,2);
plot(t_test(1:2000), y_test_true(1:2000), 'Color', [0.2 0.2 0.2], 'LineWidth', 1.3, 'DisplayName', 'Raw Ground Truth Test Set (V_{true})'); hold on;
plot(t_test(1:2000), y_test_pred_B(1:2000), 'Color', '#0D47A1', 'LineStyle', '--', 'LineWidth', 1.4, 'DisplayName', sprintf('Model B: Trained on Filtered (Honest Out-of-Sample Fit: %.2f%%)', fit_B));
plot(t_test(1:2000), y_test_pred_B_filt(1:2000), 'Color', '#388E3C', 'LineStyle', ':', 'LineWidth', 1.2, 'DisplayName', sprintf('Model B In-Sample Score on Filtered Test Set: %.2f%% (Circular)', fit_B_in_sample));
grid on; xlabel('Time Horizon (s)', 'FontWeight', 'bold'); ylabel('Voltage V_{dc} (V)', 'FontWeight', 'bold');
title('Model B: Trained on Filtered Telemetry \rightarrow Tested on Raw Ground Truth Test Set', 'FontWeight', 'bold');
legend('Location', 'northeast');

exportgraphics(f1, 'honest_validation_comparison.png', 'Resolution', 300);
fprintf('Saved figure: honest_validation_comparison.png (300 DPI)\n');

f2 = figure('Name', 'Signal Reconstruction Fix', 'Visible', 'on', 'Color', [1 1 1], 'Position', [100 100 950 550]);
t_full = (0:length(v_true)-1) * dt;

subplot(2,1,1);
plot(t_full(1:3000), v_sensed(1:3000), 'Color', '#E53935', 'LineWidth', 1.2, 'DisplayName', 'Vdc Sensed (Broken/Quantized Sensor Telemetry - Only 18 Discrete Levels)'); hold on;
plot(t_full(1:3000), v_true(1:3000), 'Color', '#0D47A1', 'LineWidth', 1.4, 'DisplayName', 'Vdc True = Vref - PI_Input (Reconstructed Continuous Signal)');
grid on; ylabel('Voltage V_{dc} (V)', 'FontWeight', 'bold');
title('Signal Reconstruction Fix 1: Sensor Quantization Artifacts vs Reconstructed Continuous V_{true}', 'FontWeight', 'bold');
legend('Location', 'northeast');

subplot(2,1,2);
plot(t_full(1:3000), err_true(1:3000), 'Color', '#B71C1C', 'LineWidth', 1.2, 'DisplayName', 'Ground Truth Error e(t) = V_{ref} - V_{true} (Mean: 2.10V, RMS: 3.49V)');
yline(0, 'k-', 'LineWidth', 0.7);
grid on; xlabel('Time Horizon (s)', 'FontWeight', 'bold'); ylabel('Tracking Error (V)', 'FontWeight', 'bold');
title('Signal Reconstruction Fix 2: Ground Truth Tracking Error Dynamics (256.40V - 321.60V Operating Range)', 'FontWeight', 'bold');
legend('Location', 'northeast');

exportgraphics(f2, 'signal_reconstruction_fix.png', 'Resolution', 300);
fprintf('Saved figure: signal_reconstruction_fix.png (300 DPI)\n\n');

fprintf('=========================================================================\n');
fprintf('  [SUCCESS] 7-STEP HONEST VALIDATION PIPELINE COMPLETE!\n');
fprintf('=========================================================================\n');
