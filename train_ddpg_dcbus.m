%% train_ddpg_dcbus.m
% =========================================================================
%  DEEP REINFORCEMENT LEARNING DC BUS VOLTAGE CONTROLLER TRAINING (DDPG)
% =========================================================================
% Trains a Deep Deterministic Policy Gradient (DDPG) neural network controller
% for continuous DC-bus voltage regulation using DCBusEnv.
%
% Generates: Trained_DRL_DCBus_Agent_v3.mat

clear classes;
clear; clc; close all;

fprintf('=====================================================\n');
fprintf('  DDPG Neural Network Agent Training for DC-Bus\n');
fprintf('=====================================================\n');

% 1. Create Environment
env = DCBusEnv();
obsInfo = getObservationInfo(env);
actInfo = getActionInfo(env);

fprintf('Environment Configuration:\n');
fprintf('  Observations : 3 states [Error/10, dError/1000, PrevAction/10]\n');
fprintf('  Action       : Continuous control effort [-1, 1] -> [-10, 10]\n');
fprintf('  Horizon      : %d steps (%.1f seconds @ 1 kHz)\n\n', env.MaxSteps, env.MaxSteps * env.dt);

% 2. Deep Deterministic Actor Network (3 -> 128 -> 128 -> 1 -> Tanh)
actorNet = [
    featureInputLayer(obsInfo.Dimension(1), 'Normalization', 'none', 'Name', 'StateIn')
    fullyConnectedLayer(128, 'Name', 'ActorFC1')
    reluLayer('Name', 'ActorRelu1')
    fullyConnectedLayer(128, 'Name', 'ActorFC2')
    reluLayer('Name', 'ActorRelu2')
    fullyConnectedLayer(actInfo.Dimension(1), 'Name', 'ActorOut')
    tanhLayer('Name', 'ActorTanh')
];
actorNet = dlnetwork(actorNet);
actor = rlContinuousDeterministicActor(actorNet, obsInfo, actInfo);

% 3. Concatenation-based Critic Network
statePath = [
    featureInputLayer(obsInfo.Dimension(1), 'Normalization', 'none', 'Name', 'StateIn')
    fullyConnectedLayer(128, 'Name', 'CritStateFC')
];

actionPath = [
    featureInputLayer(actInfo.Dimension(1), 'Normalization', 'none', 'Name', 'ActionIn')
    fullyConnectedLayer(128, 'Name', 'CritActionFC')
];

commonPath = [
    concatenationLayer(1, 2, 'Name', 'ConcatStreams')
    reluLayer('Name', 'CritRelu1')
    fullyConnectedLayer(128, 'Name', 'CritFC2')
    reluLayer('Name', 'CritRelu2')
    fullyConnectedLayer(1, 'Name', 'QValue')
];

criticLG = layerGraph();
criticLG = addLayers(criticLG, statePath);
criticLG = addLayers(criticLG, actionPath);
criticLG = addLayers(criticLG, commonPath);
criticLG = connectLayers(criticLG, 'CritStateFC',  'ConcatStreams/in1');
criticLG = connectLayers(criticLG, 'CritActionFC', 'ConcatStreams/in2');

criticNet = dlnetwork(criticLG);
critic = rlQValueFunction(criticNet, obsInfo, actInfo);

% 4. DDPG Agent Setup
agentOpts = rlDDPGAgentOptions(...
    'SampleTime', env.dt, ...
    'TargetSmoothFactor', 1e-3, ...
    'DiscountFactor', 0.99, ...
    'MiniBatchSize', 128, ...
    'ExperienceBufferLength', 1e6);

agentOpts.ActorOptimizerOptions.LearnRate  = 1e-4;
agentOpts.CriticOptimizerOptions.LearnRate = 1e-3;
agentOpts.NoiseOptions.Variance            = 0.3;
agentOpts.NoiseOptions.VarianceDecayRate   = 1e-4;

agent = rlDDPGAgent(actor, critic, agentOpts);

% 5. Training Options
trainOpts = rlTrainingOptions(...
    'MaxEpisodes', 1000, ...
    'MaxStepsPerEpisode', env.MaxSteps, ...
    'ScoreAveragingWindowLength', 30, ...
    'Plots', 'none', ...
    'Verbose', true, ...
    'StopTrainingCriteria', 'AverageReward', ...
    'StopTrainingValue', -500, ...
    'SaveAgentCriteria', 'EpisodeReward', ...
    'SaveAgentValue', -300);

fprintf('Starting DDPG Agent Training (1000 Episodes max)...\n');
trainingStats = train(agent, env, trainOpts);

agentFile = 'Trained_DRL_DCBus_Agent_v3.mat';
save(agentFile, 'agent', 'trainingStats');
fprintf('\n[SUCCESS] Agent and Training Stats saved to %s\n', agentFile);

% Run post-training evaluation plot
run plot_results;
