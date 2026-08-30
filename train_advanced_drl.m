%% train_advanced_drl.m
% =========================================================================
%  ADVANCED INTEGRAL-AUGMENTED DRL TRAINING (V4)
% =========================================================================
% Trains a 4-state integral-augmented continuous actor for zero steady-state
% oscillation in DC-bus voltage regulation.

clear classes; clear; clc; close all;

fprintf('=====================================================\n');
fprintf('  Training Advanced Integral-Augmented DRL Agent (V4)\n');
fprintf('=====================================================\n');

env = DCBusEnv_v4();
obsInfo = getObservationInfo(env);
actInfo = getActionInfo(env);

% 4-State Actor Network
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

% Concatenation Critic Network
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
critic = rlQValueFunction(dlnetwork(criticLG), obsInfo, actInfo);

agentOpts = rlDDPGAgentOptions(...
    'SampleTime', env.dt, ...
    'TargetSmoothFactor', 1e-3, ...
    'DiscountFactor', 0.99, ...
    'MiniBatchSize', 128, ...
    'ExperienceBufferLength', 1e6);
agentOpts.ActorOptimizerOptions.LearnRate  = 1e-4;
agentOpts.CriticOptimizerOptions.LearnRate = 1e-3;
agentOpts.NoiseOptions.Variance            = 0.2;
agentOpts.NoiseOptions.VarianceDecayRate   = 1e-4;

agent = rlDDPGAgent(actor, critic, agentOpts);

trainOpts = rlTrainingOptions(...
    'MaxEpisodes', 1000, ...
    'MaxStepsPerEpisode', env.MaxSteps, ...
    'ScoreAveragingWindowLength', 30, ...
    'Plots', 'none', ...
    'Verbose', true, ...
    'StopTrainingCriteria', 'AverageReward', ...
    'StopTrainingValue', 2500);

fprintf('Starting Training for Advanced Agent V4...\n');
trainingStats = train(agent, env, trainOpts);

save('Trained_Advanced_DRL_Agent_v4.mat', 'agent', 'trainingStats');
fprintf('[SUCCESS] Saved to Trained_Advanced_DRL_Agent_v4.mat\n');
