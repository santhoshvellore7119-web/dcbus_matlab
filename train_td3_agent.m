%% train_td3_agent.m
% =========================================================================
%  TWIN-DELAYED DEEP DETERMINISTIC POLICY GRADIENT (TD3) AGENT IN MATLAB
% =========================================================================
% Demonstrates continuous Deep Reinforcement Learning for DC-bus voltage
% regulation using the Twin-Delayed DDPG (TD3) algorithm.
%
% Key TD3 Architectural Features:
%   1. Twin Q-Value Critics: Mitigates value overestimation bias
%   2. Delayed Policy Updates: Updates actor less frequently than critics
%   3. Target Policy Smoothing: Adds clipped Gaussian noise to target actions
%
% Toolboxes Required:
%   - Reinforcement Learning Toolbox
%   - Deep Learning Toolbox

clear classes; clear; clc; close all;

fprintf('=========================================================================\n');
fprintf('  DC-BUS VOLTAGE REGULATOR: TD3 AGENT ARCHITECTURE & TRAINING PIPELINE   \n');
fprintf('=========================================================================\n\n');

%% 1. Instantiate 100% MATLAB Environment
fprintf('[1/4] Initializing MATLAB DC-Bus RL Environment (DCBusEnv)...
');
env = DCBusEnv();
obsInfo = getObservationInfo(env);
actInfo = getActionInfo(env);

numObs = obsInfo.Dimension(1); % 3 State observations [e, de/dt, u_{t-1}]
numAct = actInfo.Dimension(1); % 1 Continuous action u(t)

fprintf('      Observation Dimension: %d continuous states
', numObs);
fprintf('      Action Dimension     : %d continuous action

', numAct);

%% 2. Construct Deep Neural Network Continuous Deterministic Actor
fprintf('[2/4] Constructing Continuous Deterministic Actor Network (3 -> 128 -> 128 -> 1)...
');
actorNet = [
    featureInputLayer(numObs, 'Normalization', 'none', 'Name', 'StateIn')
    fullyConnectedLayer(128, 'Name', 'ActorFC1')
    reluLayer('Name', 'ActorRelu1')
    fullyConnectedLayer(128, 'Name', 'ActorFC2')
    reluLayer('Name', 'ActorRelu2')
    fullyConnectedLayer(numAct, 'Name', 'ActorOut')
    tanhLayer('Name', 'ActorTanh')
];
actorNet = dlnetwork(actorNet);
actor = rlContinuousDeterministicActor(actorNet, obsInfo, actInfo);

%% 3. Construct Twin Deep Q-Value Critics (Critic 1 & Critic 2)
fprintf('[3/4] Constructing Twin Q-Value Critic Networks (Clipped Double Q-Learning)...
');

function critic = localCreateCritic(obsInfo, actInfo, cName)
    statePath = [
        featureInputLayer(obsInfo.Dimension(1), 'Normalization', 'none', 'Name', [cName '_StateIn'])
        fullyConnectedLayer(128, 'Name', [cName '_StateFC'])
    ];
    actionPath = [
        featureInputLayer(actInfo.Dimension(1), 'Normalization', 'none', 'Name', [cName '_ActionIn'])
        fullyConnectedLayer(128, 'Name', [cName '_ActionFC'])
    ];
    commonPath = [
        concatenationLayer(1, 2, 'Name', [cName '_Concat'])
        reluLayer('Name', [cName '_Relu1'])
        fullyConnectedLayer(128, 'Name', [cName '_FC2'])
        reluLayer('Name', [cName '_Relu2'])
        fullyConnectedLayer(1, 'Name', [cName '_QValue'])
    ];
    criticLG = layerGraph();
    criticLG = addLayers(criticLG, statePath);
    criticLG = addLayers(criticLG, actionPath);
    criticLG = addLayers(criticLG, commonPath);
    criticLG = connectLayers(criticLG, [cName '_StateFC'],  [cName '_Concat/in1']);
    criticLG = connectLayers(criticLG, [cName '_ActionFC'], [cName '_Concat/in2']);
    critic = rlQValueFunction(dlnetwork(criticLG), obsInfo, actInfo);
end

critic1 = localCreateCritic(obsInfo, actInfo, 'Critic1');
critic2 = localCreateCritic(obsInfo, actInfo, 'Critic2');

%% 4. Configure TD3 Hyperparameters & Training Options
fprintf('[4/4] Configuring TD3 Agent Options & Target Policy Smoothing...
');

agentOpts = rlTD3AgentOptions(...
    'SampleTime', env.dt, ...
    'TargetSmoothFactor', 1e-3, ...
    'DiscountFactor', 0.99, ...
    'MiniBatchSize', 128, ...
    'ExperienceBufferLength', 1e6, ...
    'TargetPolicySmoothModel', rlTargetPolicySmoothModel('Variance', 0.2, 'LowerLimit', -0.5, 'UpperLimit', 0.5));

agentOpts.ActorOptimizerOptions.LearnRate    = 1e-4;
agentOpts.CriticOptimizerOptions.LearnRate   = 1e-3;
agentOpts.ExplorationModel.Variance         = 0.2;
agentOpts.ExplorationModel.VarianceDecayRate = 1e-4;

agent = rlTD3Agent(actor, [critic1, critic2], agentOpts);

trainOpts = rlTrainingOptions(...
    'MaxEpisodes', 1000, ...
    'MaxStepsPerEpisode', env.MaxSteps, ...
    'ScoreAveragingWindowLength', 30, ...
    'Plots', 'training-progress', ...
    'Verbose', true, ...
    'StopTrainingCriteria', 'AverageReward', ...
    'StopTrainingValue', 2500);

fprintf('=========================================================================\n');
fprintf('  TD3 AGENT READY FOR TRAINING!\n');
fprintf('  To train agent from scratch in MATLAB, execute:\n');
fprintf('    trainingStats = train(agent, env, trainOpts);\n');
fprintf('    save(''Trained_TD3_DCBus_Agent.mat'', ''agent'', ''trainingStats'');\n');
fprintf('=========================================================================\n\n');

% Optional automatic training execution:
% trainingStats = train(agent, env, trainOpts);
% save('Trained_TD3_DCBus_Agent.mat', 'agent', 'trainingStats');
