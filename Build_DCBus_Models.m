%% Build_DCBus_Models.m
% Programmatically constructs the Simulink models for DC-Bus PI Tuning:
%   1) dcBusPITuning.slx            - Baseline/Training simulation model with PID block
%   2) dcBusPITuningRL.slx          - RL Training model with native 'rllib/RL Agent' block
%   3) dcBusPITuning_Validation.slx - Excel Data-Replay Simulink model with 'From Workspace' blocks
%
% Fully automated: 0 manual steps and 0 XML hacks.
% Accepts plant parameters directly from Load_DCBus_Data.m or defaults.

function Build_DCBus_Models(params)
    if nargin < 1 || isempty(params)
        if isfile('Case Study DCbusData.csv (1).xlsx')
            [~, params, ~] = Load_DCBus_Data('Case Study DCbusData.csv (1).xlsx', false);
        else
            params = struct();
            params.Vref        = 300;
            params.Vdc0        = 280;
            params.Kconv       = 8.0;
            params.Ceq         = 40.0;
            params.Ts          = 1e-3;
            params.uMin        = -10.0;
            params.uMax        = 10.0;
            params.noisePower  = 5.0;
            params.noiseSeed   = 23341;
            params.Kp_baseline = 0.07557;
            params.Ki_baseline = 0.64811;
        end
    end

    fprintf('=====================================================\n');
    fprintf('  Building Programmatic Simulink Models for DC-Bus\n');
    fprintf('=====================================================\n');

    bdclose('all');

    Vref0     = params.Vref;
    Vdc0      = params.Vdc0;
    Kconv     = params.Kconv;
    Ceq       = params.Ceq;
    Ts        = params.Ts;
    uMin      = params.uMin;
    uMax      = params.uMax;
    noisePow  = 5.0; % Normalized noise power for training dynamics
    noiseSeed = params.noiseSeed;
    P0        = params.Kp_baseline;
    I0        = params.Ki_baseline;
    Ru        = 0.01;

    %% ==========================================================
    %% MODEL 1: dcBusPITuning (Baseline PID Model)
    %% ==========================================================
    mdl1 = 'dcBusPITuning';
    if bdIsLoaded(mdl1)
        close_system(mdl1, 0);
    end
    if isfile([mdl1 '.slx'])
        delete([mdl1 '.slx']);
    end
    
    new_system(mdl1);
    open_system(mdl1);
    
    % Solver Configuration: Fixed-step Runge-Kutta for fast deterministic simulations
    set_param(mdl1, 'SolverType', 'Fixed-step', 'Solver', 'ode4', 'FixedStep', num2str(Ts), 'StopTime', '1.0');

    % Reference & Error Sum
    add_block('simulink/Sources/Constant', [mdl1 '/Vdc Reference'], ...
        'Value', num2str(Vref0), 'Position', [30 100 90 130]);

    add_block('simulink/Math Operations/Sum', [mdl1 '/ErrorSum'], ...
        'Inputs', '+-', 'Position', [150 95 180 135]);

    % PID Controller (PI Mode) with Saturation
    add_block('simulink/Continuous/PID Controller', [mdl1 '/PID Controller'], ...
        'Controller', 'PI', ...
        'P', num2str(P0), 'I', num2str(I0), 'D', '0', ...
        'LimitOutput', 'on', ...
        'UpperSaturationLimit', num2str(uMax), ...
        'LowerSaturationLimit', num2str(uMin), ...
        'AntiWindupMode', 'clamping', ...
        'Position', [240 90 320 140]);

    % Disturbance Noise
    add_block('simulink/Sources/Band-Limited White Noise', [mdl1 '/Band-Limited White Noise'], ...
        'Cov', num2str(noisePow), 'Ts', num2str(Ts), 'seed', num2str(noiseSeed), ...
        'Position', [30 240 90 270]);

    % DC-Bus System Subsystem
    sub1 = [mdl1 '/DC-Bus System'];
    add_block('built-in/SubSystem', sub1, 'Position', [420 90 540 200]);
    add_block('simulink/Sources/In1', [sub1 '/u'], 'Position', [30 30 60 50]);
    add_block('simulink/Sources/In1', [sub1 '/Iload'], 'Position', [30 130 60 150]);
    add_block('simulink/Math Operations/Gain', [sub1 '/Kconv'], ...
        'Gain', num2str(Kconv), 'Position', [110 25 150 55]);
    add_block('simulink/Math Operations/Sum', [sub1 '/PlantSum'], ...
        'Inputs', '+-', 'Position', [200 60 230 110]);
    add_block('simulink/Math Operations/Gain', [sub1 '/invC'], ...
        'Gain', num2str(1/Ceq), 'Position', [270 70 310 100]);
    add_block('simulink/Continuous/Integrator', [sub1 '/Vdc'], ...
        'InitialCondition', num2str(Vdc0), 'Position', [350 70 390 100]);
    add_block('simulink/Sinks/Out1', [sub1 '/VdcOut'], 'Position', [430 75 460 95]);

    add_line(sub1, 'u/1', 'Kconv/1');
    add_line(sub1, 'Kconv/1', 'PlantSum/1');
    add_line(sub1, 'Iload/1', 'PlantSum/2');
    add_line(sub1, 'PlantSum/1', 'invC/1');
    add_line(sub1, 'invC/1', 'Vdc/1');
    add_line(sub1, 'Vdc/1', 'VdcOut/1');

    % Cost Function: (e/10)^2 + Ru * u^2
    add_block('simulink/Math Operations/Gain', [mdl1 '/eScale'], ...
        'Gain', '0.1', 'Position', [380 250 420 280]);
    add_block('simulink/Math Operations/Math Function', [mdl1 '/eSquare'], ...
        'Operator', 'square', 'Position', [440 250 480 280]);
    add_block('simulink/Math Operations/Math Function', [mdl1 '/uSquare'], ...
        'Operator', 'square', 'Position', [440 320 480 350]);
    add_block('simulink/Math Operations/Gain', [mdl1 '/RuGain'], ...
        'Gain', num2str(Ru), 'Position', [510 320 550 350]);
    add_block('simulink/Math Operations/Sum', [mdl1 '/CostSum'], ...
        'Inputs', '++', 'Position', [580 270 610 320]);

    % Logging & Sinks
    add_block('simulink/Sinks/To Workspace', [mdl1 '/simout'], ...
        'VariableName', 'simout', 'SaveFormat', 'Timeseries', 'Position', [650 90 730 120]);
    add_block('simulink/Sinks/To Workspace', [mdl1 '/u_out'], ...
        'VariableName', 'u_out', 'SaveFormat', 'Timeseries', 'Position', [420 30 500 60]);
    add_block('simulink/Sinks/To Workspace', [mdl1 '/e_out'], ...
        'VariableName', 'e_out', 'SaveFormat', 'Timeseries', 'Position', [240 30 320 60]);
    add_block('simulink/Sinks/To Workspace', [mdl1 '/cost'], ...
        'VariableName', 'cost', 'SaveFormat', 'Timeseries', 'Position', [650 280 730 310]);
    add_block('simulink/Sinks/Scope', [mdl1 '/Scope'], 'Position', [650 150 690 180]);

    % Top Level Connections
    add_line(mdl1, 'Vdc Reference/1', 'ErrorSum/1');
    add_line(mdl1, 'ErrorSum/1', 'PID Controller/1');
    add_line(mdl1, 'ErrorSum/1', 'e_out/1', 'autorouting', 'on');
    add_line(mdl1, 'PID Controller/1', 'DC-Bus System/1');
    add_line(mdl1, 'PID Controller/1', 'u_out/1', 'autorouting', 'on');
    add_line(mdl1, 'Band-Limited White Noise/1', 'DC-Bus System/2');
    add_line(mdl1, 'DC-Bus System/1', 'simout/1');
    add_line(mdl1, 'DC-Bus System/1', 'Scope/1');
    add_line(mdl1, 'DC-Bus System/1', 'ErrorSum/2', 'autorouting', 'on');

    add_line(mdl1, 'ErrorSum/1', 'eScale/1', 'autorouting', 'on');
    add_line(mdl1, 'eScale/1', 'eSquare/1');
    add_line(mdl1, 'PID Controller/1', 'uSquare/1', 'autorouting', 'on');
    add_line(mdl1, 'uSquare/1', 'RuGain/1');
    add_line(mdl1, 'eSquare/1', 'CostSum/1', 'autorouting', 'on');
    add_line(mdl1, 'RuGain/1', 'CostSum/2');
    add_line(mdl1, 'CostSum/1', 'cost/1');

    save_system(mdl1);
    close_system(mdl1);
    fprintf('  [OK] Built and saved: %s.slx\n', mdl1);

    %% ==========================================================
    %% MODEL 2: dcBusPITuningRL (RL Training Model with RL Agent)
    %% ==========================================================
    mdl2 = 'dcBusPITuningRL';
    if bdIsLoaded(mdl2)
        close_system(mdl2, 0);
    end
    if isfile([mdl2 '.slx'])
        delete([mdl2 '.slx']);
    end

    new_system(mdl2);
    open_system(mdl2);

    % Solver Configuration
    set_param(mdl2, 'SolverType', 'Fixed-step', 'Solver', 'ode4', 'FixedStep', num2str(Ts), 'StopTime', '1.0');

    % Reference & Error
    add_block('simulink/Sources/Constant', [mdl2 '/Vdc Reference'], ...
        'Value', num2str(Vref0), 'Position', [30 100 90 130]);

    add_block('simulink/Math Operations/Sum', [mdl2 '/ErrorSum'], ...
        'Inputs', '+-', 'Position', [140 95 170 135]);

    % Observation Vector: [integral(e) dt ; e]
    add_block('simulink/Continuous/Integrator', [mdl2 '/ErrIntegrator'], ...
        'Position', [220 40 260 70]);
    add_block('simulink/Signal Routing/Mux', [mdl2 '/ObsMux'], ...
        'Inputs', '2', 'Position', [300 35 320 85]);

    % Load Reinforcement Learning Library and add native RL Agent block
    load_system('rllib');
    add_block('rllib/RL Agent', [mdl2 '/RL Agent'], ...
        'Position', [360 85 430 145]);

    % Action Saturation [-10, 10]
    add_block('simulink/Discontinuities/Saturation', [mdl2 '/ActionSaturation'], ...
        'UpperLimit', num2str(uMax), 'LowerLimit', num2str(uMin), ...
        'Position', [470 100 500 130]);

    % Disturbance Noise
    add_block('simulink/Sources/Band-Limited White Noise', [mdl2 '/Band-Limited White Noise'], ...
        'Cov', num2str(noisePow), 'Ts', num2str(Ts), 'seed', num2str(noiseSeed), ...
        'Position', [30 250 90 280]);

    % DC-Bus System Subsystem
    sub2 = [mdl2 '/DC-Bus System'];
    add_block('built-in/SubSystem', sub2, 'Position', [550 90 670 200]);
    add_block('simulink/Sources/In1', [sub2 '/u'], 'Position', [30 30 60 50]);
    add_block('simulink/Sources/In1', [sub2 '/Iload'], 'Position', [30 130 60 150]);
    add_block('simulink/Math Operations/Gain', [sub2 '/Kconv'], ...
        'Gain', num2str(Kconv), 'Position', [110 25 150 55]);
    add_block('simulink/Math Operations/Sum', [sub2 '/PlantSum'], ...
        'Inputs', '+-', 'Position', [200 60 230 110]);
    add_block('simulink/Math Operations/Gain', [sub2 '/invC'], ...
        'Gain', num2str(1/Ceq), 'Position', [270 70 310 100]);
    add_block('simulink/Continuous/Integrator', [sub2 '/Vdc'], ...
        'InitialCondition', num2str(Vdc0), 'Position', [350 70 390 100]);
    add_block('simulink/Sinks/Out1', [sub2 '/VdcOut'], 'Position', [430 75 460 95]);

    add_line(sub2, 'u/1', 'Kconv/1');
    add_line(sub2, 'Kconv/1', 'PlantSum/1');
    add_line(sub2, 'Iload/1', 'PlantSum/2');
    add_line(sub2, 'PlantSum/1', 'invC/1');
    add_line(sub2, 'invC/1', 'Vdc/1');
    add_line(sub2, 'Vdc/1', 'VdcOut/1');

    % Cost & Normalized Reward Calculation
    add_block('simulink/Math Operations/Gain', [mdl2 '/eScale'], ...
        'Gain', '0.1', 'Position', [380 250 420 280]);
    add_block('simulink/Math Operations/Math Function', [mdl2 '/eSquare'], ...
        'Operator', 'square', 'Position', [440 250 480 280]);
    add_block('simulink/Math Operations/Math Function', [mdl2 '/uSquare'], ...
        'Operator', 'square', 'Position', [440 320 480 350]);
    add_block('simulink/Math Operations/Gain', [mdl2 '/RuGain'], ...
        'Gain', num2str(Ru), 'Position', [510 320 550 350]);
    add_block('simulink/Math Operations/Sum', [mdl2 '/CostSum'], ...
        'Inputs', '++', 'Position', [580 270 610 320]);
    add_block('simulink/Math Operations/Gain', [mdl2 '/RewardGain'], ...
        'Gain', '-0.01', 'Position', [650 280 690 310]);

    % Sinks & Logging
    add_block('simulink/Sinks/To Workspace', [mdl2 '/simout'], ...
        'VariableName', 'simout', 'SaveFormat', 'Timeseries', 'Position', [730 90 810 120]);
    add_block('simulink/Sinks/To Workspace', [mdl2 '/cost'], ...
        'VariableName', 'cost', 'SaveFormat', 'Timeseries', 'Position', [730 340 810 370]);
    add_block('simulink/Sinks/Scope', [mdl2 '/Scope'], 'Position', [730 150 770 180]);

    % Wiring Top Level
    add_line(mdl2, 'Vdc Reference/1', 'ErrorSum/1');
    add_line(mdl2, 'DC-Bus System/1', 'ErrorSum/2', 'autorouting', 'on');
    add_line(mdl2, 'ErrorSum/1', 'ErrIntegrator/1', 'autorouting', 'on');
    add_line(mdl2, 'ErrIntegrator/1', 'ObsMux/1');
    add_line(mdl2, 'ErrorSum/1', 'ObsMux/2', 'autorouting', 'on');

    % RL Agent inputs: Port 1 = Observation, Port 2 = Reward
    add_line(mdl2, 'ObsMux/1', 'RL Agent/1', 'autorouting', 'on');
    add_line(mdl2, 'RewardGain/1', 'RL Agent/2', 'autorouting', 'on');

    % RL Agent output -> Saturation -> Plant
    add_line(mdl2, 'RL Agent/1', 'ActionSaturation/1');
    add_line(mdl2, 'ActionSaturation/1', 'DC-Bus System/1');
    add_line(mdl2, 'Band-Limited White Noise/1', 'DC-Bus System/2');
    add_line(mdl2, 'DC-Bus System/1', 'simout/1');
    add_line(mdl2, 'DC-Bus System/1', 'Scope/1');

    % Cost calculations
    add_line(mdl2, 'ErrorSum/1', 'eScale/1', 'autorouting', 'on');
    add_line(mdl2, 'eScale/1', 'eSquare/1');
    add_line(mdl2, 'ActionSaturation/1', 'uSquare/1', 'autorouting', 'on');
    add_line(mdl2, 'uSquare/1', 'RuGain/1');
    add_line(mdl2, 'eSquare/1', 'CostSum/1', 'autorouting', 'on');
    add_line(mdl2, 'RuGain/1', 'CostSum/2');
    add_line(mdl2, 'CostSum/1', 'RewardGain/1');
    add_line(mdl2, 'CostSum/1', 'cost/1', 'autorouting', 'on');

    save_system(mdl2);
    close_system(mdl2);
    fprintf('  [OK] Built and saved: %s.slx\n', mdl2);

    %% ==========================================================
    %% MODEL 3: dcBusPITuning_Validation (Excel Data-Replay Model)
    %% ==========================================================
    mdl3 = 'dcBusPITuning_Validation';
    if bdIsLoaded(mdl3)
        close_system(mdl3, 0);
    end
    if isfile([mdl3 '.slx'])
        delete([mdl3 '.slx']);
    end

    new_system(mdl3);
    open_system(mdl3);

    % Solver Configuration
    set_param(mdl3, 'SolverType', 'Fixed-step', 'Solver', 'ode4', 'FixedStep', num2str(Ts), 'StopTime', '10.0');

    % Inputs: 'From Workspace' for Reference and Injected Real Disturbance
    add_block('simulink/Sources/From Workspace', [mdl3 '/Vref_In'], ...
        'VariableName', 'vRef_ts', 'SampleTime', num2str(Ts), 'Interpolate', 'on', ...
        'OutputAfterFinalValue', 'Holding final value', ...
        'Position', [30 95 110 135]);

    add_block('simulink/Sources/From Workspace', [mdl3 '/Iload_In'], ...
        'VariableName', 'iLoad_ts', 'SampleTime', num2str(Ts), 'Interpolate', 'on', ...
        'OutputAfterFinalValue', 'Holding final value', ...
        'Position', [30 240 110 280]);

    add_block('simulink/Math Operations/Sum', [mdl3 '/ErrorSum'], ...
        'Inputs', '+-', 'Position', [170 95 200 135]);

    % PID Controller (PI Mode) with Saturation
    add_block('simulink/Continuous/PID Controller', [mdl3 '/PID Controller'], ...
        'Controller', 'PI', ...
        'P', num2str(P0), 'I', num2str(I0), 'D', '0', ...
        'LimitOutput', 'on', ...
        'UpperSaturationLimit', num2str(uMax), ...
        'LowerSaturationLimit', num2str(uMin), ...
        'AntiWindupMode', 'clamping', ...
        'Position', [260 90 340 140]);

    % DC-Bus System Subsystem
    sub3 = [mdl3 '/DC-Bus System'];
    add_block('built-in/SubSystem', sub3, 'Position', [440 90 560 200]);
    add_block('simulink/Sources/In1', [sub3 '/u'], 'Position', [30 30 60 50]);
    add_block('simulink/Sources/In1', [sub3 '/Iload'], 'Position', [30 130 60 150]);
    add_block('simulink/Math Operations/Gain', [sub3 '/Kconv'], ...
        'Gain', num2str(Kconv), 'Position', [110 25 150 55]);
    add_block('simulink/Math Operations/Sum', [sub3 '/PlantSum'], ...
        'Inputs', '+-', 'Position', [200 60 230 110]);
    add_block('simulink/Math Operations/Gain', [sub3 '/invC'], ...
        'Gain', num2str(1/Ceq), 'Position', [270 70 310 100]);
    add_block('simulink/Continuous/Integrator', [sub3 '/Vdc'], ...
        'InitialCondition', num2str(Vdc0), 'Position', [350 70 390 100]);
    add_block('simulink/Sinks/Out1', [sub3 '/VdcOut'], 'Position', [430 75 460 95]);

    add_line(sub3, 'u/1', 'Kconv/1');
    add_line(sub3, 'Kconv/1', 'PlantSum/1');
    add_line(sub3, 'Iload/1', 'PlantSum/2');
    add_line(sub3, 'PlantSum/1', 'invC/1');
    add_line(sub3, 'invC/1', 'Vdc/1');
    add_line(sub3, 'Vdc/1', 'VdcOut/1');

    % Sinks: Log all key signals
    add_block('simulink/Sinks/To Workspace', [mdl3 '/simout'], ...
        'VariableName', 'simout', 'SaveFormat', 'Timeseries', 'Position', [650 90 730 120]);
    add_block('simulink/Sinks/To Workspace', [mdl3 '/u_out'], ...
        'VariableName', 'u_out', 'SaveFormat', 'Timeseries', 'Position', [440 30 520 60]);
    add_block('simulink/Sinks/To Workspace', [mdl3 '/e_out'], ...
        'VariableName', 'e_out', 'SaveFormat', 'Timeseries', 'Position', [260 30 340 60]);

    % Top-level wiring
    add_line(mdl3, 'Vref_In/1', 'ErrorSum/1');
    add_line(mdl3, 'ErrorSum/1', 'PID Controller/1');
    add_line(mdl3, 'ErrorSum/1', 'e_out/1', 'autorouting', 'on');
    add_line(mdl3, 'PID Controller/1', 'DC-Bus System/1');
    add_line(mdl3, 'PID Controller/1', 'u_out/1', 'autorouting', 'on');
    add_line(mdl3, 'Iload_In/1', 'DC-Bus System/2');
    add_line(mdl3, 'DC-Bus System/1', 'simout/1');
    add_line(mdl3, 'DC-Bus System/1', 'ErrorSum/2', 'autorouting', 'on');

    save_system(mdl3);
    close_system(mdl3);
    fprintf('  [OK] Built and saved: %s.slx\n', mdl3);
    fprintf('=====================================================\n\n');
end
