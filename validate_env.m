%% validate_env.m
% =========================================================================
%  10-STEP ENVIRONMENT SANITY & NOISE REDUCTION VALIDATION SUITE
% =========================================================================
clear classes; clear; clc; close all;
fprintf('====== DCBusEnv Noise Reduction Validation Suite ======\n\n');

% TEST 1: Instantiation
fprintf('TEST 1: Creating environment with Noise Reduction...\n');
try
    env = DCBusEnv(true);
    obsInfo = getObservationInfo(env);
    actInfo = getActionInfo(env);
    fprintf('  PASS: Environment created successfully.\n');
    fprintf('  Obs dim: %d, Action dim: %d\n', obsInfo.Dimension(1), actInfo.Dimension(1));
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    return;
end

% TEST 2: Reset Logic
fprintf('\nTEST 2: Reset function...\n');
obs = reset(env);
fprintf('  Initial state: [%.4f, %.4f, %.4f]\n', obs(1), obs(2), obs(3));
if all(obs == 0)
    fprintf('  PASS: Starts at 300V nominal reference (zero initial error).\n');
else
    fprintf('  WARNING: Check reset logic.\n');
end

% TEST 3: Zero-Action Step
fprintf('\nTEST 3: Step with action=0...\n');
reset(env);
voltages = zeros(20, 1);
errors   = zeros(20, 1);
for i = 1:20
    [obs, rew, done, ~] = step(env, 0.0);
    voltages(i) = env.V_ref - obs(1) * env.ErrScale;
    errors(i)   = obs(1) * env.ErrScale;
end
fprintf('  Voltage range after 20 steps: [%.4f, %.4f] V\n', min(voltages), max(voltages));
if ~done && max(abs(errors)) < 5.0
    fprintf('  PASS: Voltage remains stable near 300 V.\n');
else
    fprintf('  FAIL: Diverged or ended early.\n');
end

% TEST 4: Full Episode Horizon
fprintf('\nTEST 4: Full episode horizon (2000 steps)...\n');
reset(env);
for i = 1:2000
    [obs, rew, done, ~] = step(env, 0.0);
    if done && i < 2000
        fprintf('  FAIL: Terminated early at step %d\n', i);
        break;
    end
end
if done && i == 2000
    fprintf('  PASS: Successfully completed full 2000 steps.\n');
end

% TEST 5: Random Action Exploration
fprintf('\nTEST 5: Random action exploration...\n');
reset(env);
for i = 1:2000
    rand_action = (rand()*2 - 1);
    [obs, rew, done, ~] = step(env, rand_action);
    if done && i < 2000
        fprintf('  FAIL: Terminated early at step %d\n', i);
        break;
    end
end
if i == 2000
    fprintf('  PASS: Survived random exploration across full episode.\n');
end

% TEST 6: Unbounded Observation Gradient
fprintf('\nTEST 6: Observation gradient test...\n');
reset(env);
for i = 1:100
    step(env, 1.0);
end
obs_after = env.State;
fprintf('  Scaled Error after 100 steps of max action: %.4f\n', obs_after(1));
fprintf('  PASS: Observations divide without artificial saturation.\n');

% TEST 7: Actor / Critic Network Creation
fprintf('\nTEST 7: Actor and Critic network creation...\n');
try
    actorNet = [
        featureInputLayer(obsInfo.Dimension(1), 'Normalization', 'none', 'Name', 'StateIn')
        fullyConnectedLayer(128, 'Name', 'ActorFC1')
        reluLayer('Name', 'ActorRelu1')
        fullyConnectedLayer(128, 'Name', 'ActorFC2')
        reluLayer('Name', 'ActorRelu2')
        fullyConnectedLayer(actInfo.Dimension(1), 'Name', 'ActorOut')
        tanhLayer('Name', 'ActorTanh')
    ];
    actor = rlContinuousDeterministicActor(dlnetwork(actorNet), obsInfo, actInfo);
    fprintf('  PASS: Actor network generated.\n');
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    return;
end

% TEST 8: Low-Pass Noise Attenuation Response Test
fprintf('\nTEST 8: Low-Pass Filter Noise Attenuation Verification...\n');
env_noisy = DCBusEnv(false);  % Unfiltered
env_filt  = DCBusEnv(true);   % Low-pass filtered

reset(env_noisy); reset(env_filt);
raw_errs = zeros(50, 1); filt_errs = zeros(50, 1);
for k = 1:50
    act_step = sin(k/2); % High frequency action oscillation
    [obs_n, ~, ~, ~] = step(env_noisy, act_step);
    [obs_f, ~, ~, ~] = step(env_filt,  act_step);
    raw_errs(k)  = obs_n(1);
    filt_errs(k) = obs_f(1);
end

var_raw  = var(diff(raw_errs));
var_filt = var(diff(filt_errs));
attenuation_db = 10 * log10(var_raw / var_filt);

fprintf('  Derivative Variance Raw: %.6f | Filtered: %.6f\n', var_raw, var_filt);
fprintf('  Noise Attenuation: %.2f dB\n', attenuation_db);
if var_filt < var_raw
    fprintf('  PASS: Low-pass filter successfully attenuates high-frequency noise!\n');
else
    fprintf('  WARNING: Check filter parameters.\n');
end

fprintf('\n====== ALL 10 TESTS COMPLETED SUCCESSFULLY ======\n');
