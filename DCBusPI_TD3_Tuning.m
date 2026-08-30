%% DCBusPI_TD3_Tuning.m
% Tune DC-Bus Voltage PI Controller Using Twin Delayed DDPG (TD3) Reinforcement Learning
% Grounded in real-world dataset: 'Case Study DCbusData.csv (1).xlsx'
%
% Architecture:
%   - Linear deterministic actor representing PI controller: u = [Ki, Kp] * [integral(e); e]
%   - Twin Deep Neural Network Q-value critics for robust value estimation
%   - Environment calibrated with physical parameters identified from the case study data

function [agent, Kp_RL, Ki_RL, trainStats] = DCBusPI_TD3_Tuning(doTraining, maxEpisodes, excelFile)
    if nargin < 1 || isempty(doTraining)
        doTraining = true;
    end
    if nargin < 2 || isempty(maxEpisodes)
        maxEpisodes = 100;
    end
    if nargin < 3 || isempty(excelFile)
        excelFile = 'Case Study DCbusData.csv (1).xlsx';
    end

    fprintf('=====================================================\n');
    fprintf('  DC-Bus PI Controller Tuning with TD3 Reinforcement Learning\n');
    fprintf('=====================================================\n');

    % 1. Load Data and Physical Plant Parameters
    [dcBusData, plantParams, ~] = Load_DCBus_Data(excelFile, false);
    
    Ts   = plantParams.Ts;
    Tf   = 1.0; % 1 second horizon per episode (1000 steps @ 1 kHz)
    Vref = plantParams.Vref;
    uMin = plantParams.uMin;
    uMax = plantParams.uMax;
    
    % Ensure models are built and verified
    if ~isfile('dcBusPITuningRL.slx') || ~isfile('dcBusPITuning.slx')
        Build_DCBus_Models(plantParams);
    end

    trainMdl = 'dcBusPITuningRL';
    if ~bdIsLoaded(trainMdl)
        load_system(trainMdl);
    end

    % 2. Create RL Environment
    obsInfo = rlNumericSpec([2 1]);
    obsInfo.Name = 'observations';
    obsInfo.Description = 'Integrated Vdc Error and Proportional Error';

    actInfo = rlNumericSpec([1 1]);
    actInfo.Name = 'control_action';
    actInfo.Description = 'PI Controller Output u(t)';
    actInfo.LowerLimit = uMin;
    actInfo.UpperLimit = uMax;

    env = rlSimulinkEnv(trainMdl, [trainMdl '/RL Agent'], obsInfo, actInfo);
    env.ResetFcn = @(in) localResetFcn(in, trainMdl, Vref);

    numObs = prod(obsInfo.Dimension);
    numAct = prod(actInfo.Dimension);

    % 3. Construct TD3 Agent
    % Initial PI gains starting point from identified baseline or reasonable values
    initialKi = single(plantParams.Ki_baseline);
    initialKp = single(plantParams.Kp_baseline);
    initialGain = [initialKi; initialKp];

    fprintf('Initial Gain Guess: Kp = %.5f, Ki = %.5f\n', initialKp, initialKi);

    % Linear deterministic actor
    actor = rlContinuousDeterministicActor( ...
        {@localBasisFcn, initialGain}, obsInfo, actInfo);

    % Critic Networks
    obsInputName = 'stateInLyr';
    actInputName = 'actionInLyr';
    criticNet1 = localCreateCriticNet(numObs, numAct, obsInputName, actInputName);
    criticNet2 = localCreateCriticNet(numObs, numAct, obsInputName, actInputName);

    critic1 = rlQValueFunction(criticNet1, obsInfo, actInfo, ...
        ObservationInputNames=obsInputName, ActionInputNames=actInputName);
    critic2 = rlQValueFunction(criticNet2, obsInfo, actInfo, ...
        ObservationInputNames=obsInputName, ActionInputNames=actInputName);
    critic = [critic1, critic2];

    % Optimization Options
    actorOpts  = rlOptimizerOptions(LearnRate=1e-3, GradientThreshold=1.0);
    criticOpts = rlOptimizerOptions(LearnRate=2e-3, GradientThreshold=1.0);

    agentOpts = rlTD3AgentOptions( ...
        SampleTime=Ts, ...
        MiniBatchSize=128, ...
        DiscountFactor=0.99, ...
        ExperienceBufferLength=1e5, ...
        MaxMiniBatchPerEpoch=10, ...
        LearningFrequency=-1, ...
        ActorOptimizerOptions=actorOpts, ...
        CriticOptimizerOptions=criticOpts);

    agentOpts.ExplorationModel.StandardDeviation = 0.3;
    agentOpts.ExplorationModel.StandardDeviationDecayRate = 1e-4;
    agentOpts.TargetPolicySmoothModel.StandardDeviation = 0.2;

    agent = rlTD3Agent(actor, critic, agentOpts);

    % 4. Training or Loading Saved Agent
    matFile = 'DCBusPITuningTD3Agent.mat';
    maxsteps = ceil(Tf / Ts);

    if doTraining
        fprintf('\nStarting TD3 Training (%d episodes, %d steps/episode)...\n', maxEpisodes, maxsteps);
        
        trainOpts = rlTrainingOptions( ...
            MaxEpisodes=maxEpisodes, ...
            MaxStepsPerEpisode=maxsteps, ...
            ScoreAveragingWindowLength=20, ...
            Verbose=true, ...
            Plots="none", ...
            StopOnError="on");

        trainStats = train(agent, env, trainOpts);
        
        % Extract trained actor gains
        actorFinal = getActor(agent);
        params = getLearnableParameters(actorFinal);
        Ki_RL = double(params{1}(1));
        Kp_RL = double(params{1}(2));

        % Save trained agent and gains
        save(matFile, 'agent', 'Kp_RL', 'Ki_RL', 'trainStats', 'plantParams');
        fprintf('\n[SUCCESS] Training Completed and Saved to %s\n', matFile);
    else
        if isfile(matFile)
            fprintf('\nLoading pre-trained agent from %s...\n', matFile);
            loadedData = load(matFile);
            agent = loadedData.agent;
            Kp_RL = loadedData.Kp_RL;
            Ki_RL = loadedData.Ki_RL;
            if isfield(loadedData, 'trainStats')
                trainStats = loadedData.trainStats;
            else
                trainStats = [];
            end
            fprintf('[SUCCESS] Loaded Agent: Kp = %.5f, Ki = %.5f\n', Kp_RL, Ki_RL);
        else
            error('Pre-trained file %s not found. Please set doTraining=true to train.', matFile);
        end
    end

    fprintf('=====================================================\n');
    fprintf('  TD3 Tuned PI Controller Parameters:\n');
    fprintf('    Proportional Gain (Kp) = %.5f\n', Kp_RL);
    fprintf('    Integral Gain     (Ki) = %.5f\n', Ki_RL);
    fprintf('=====================================================\n\n');
end

%% Local Functions
function feature = localBasisFcn(obs)
    % Linear basis function mapping [integral(e); e] directly to linear policy
    feature = obs;
end

function criticNet = localCreateCriticNet(numObs, numAct, obsInputName, actInputName)
    statePath = [
        featureInputLayer(numObs, Name=obsInputName)
        fullyConnectedLayer(64, Name='fc_obs')
        reluLayer(Name='relu_obs')
    ];
    actionPath = [
        featureInputLayer(numAct, Name=actInputName)
        fullyConnectedLayer(64, Name='fc_act')
        reluLayer(Name='relu_act')
    ];
    commonPath = [
        concatenationLayer(1, 2, Name='concat')
        fullyConnectedLayer(64, Name='fc_common')
        reluLayer(Name='relu_common')
        fullyConnectedLayer(1, Name='qvalOut')
    ];

    criticNet = dlnetwork();
    criticNet = addLayers(criticNet, statePath);
    criticNet = addLayers(criticNet, actionPath);
    criticNet = addLayers(criticNet, commonPath);
    criticNet = connectLayers(criticNet, 'relu_obs', 'concat/in1');
    criticNet = connectLayers(criticNet, 'relu_act', 'concat/in2');
end

function in = localResetFcn(in, mdl, Vref)
    % Randomize noise seed, reference voltage (+/- 5 V), and initial voltage
    randomSeed = randi(100000);
    noiseBlk = [mdl '/Band-Limited White Noise'];
    in = setBlockParameter(in, noiseBlk, 'Seed', num2str(randomSeed));

    vrefSample = Vref + 10 * (rand() - 0.5); % +/- 5 V variation around 300 V
    refBlk = [mdl '/Vdc Reference'];
    in = setBlockParameter(in, refBlk, 'Value', num2str(vrefSample));

    vdcInit = Vref - 15 * rand(); % initial voltage in [285 V, 300 V]
    initBlk = [mdl '/DC-Bus System/Vdc'];
    in = setBlockParameter(in, initBlk, 'InitialCondition', num2str(vdcInit));
end
