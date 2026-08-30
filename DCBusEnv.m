classdef DCBusEnv < rl.env.MATLABEnvironment
    % DCBUSENV DC Bus Voltage Regulation Reinforcement Learning Environment
    % Supports both continuous Deep Neural Network (DDPG/TD3) training and
    % multi-scenario validation (Synthetic Sinusoidal or Real Case Study Disturbance).
    %
    % Physics Model:
    %   C * (dVdc/dt) = I_control(t) - I_load(t)
    %   I_control(t)  = I_base + 1.5 * u(t)
    %
    % State Vector:
    %   s_t = [ (V_ref - V) / ErrScale; (d(V_ref - V)/dt) / DErrScale; u_{t-1} / ActScale ]
    
    properties
        V_ref             = 300.0;       % Reference target voltage (V)
        C_dc              = 4700e-6;     % DC bus capacitance (F)
        dt                = 0.001;       % Step sample time (s)
        MaxSteps          = 2000;        % Episode horizon (steps)
        DisturbanceMode   = 'synthetic'; % 'synthetic' or 'excel'
        
        % Normalization & Scaling Divisors
        ErrScale          = 10.0;        % Divisor for raw voltage error
        DErrScale         = 1000.0;      % Divisor for error derivative
        ActScale          = 10.0;        % Divisor for control action
        
        % Injected Disturbance Vector for Excel mode
        DisturbanceVector = [];
        
        State             = zeros(3, 1);
    end
    
    properties(Access = private)
        CurrentStep = 0;
        PrevAction  = 0.0;     % Raw action [-10, 10]
        PrevVsensed = 300.0;
        PrevError   = 0.0;
    end
    
    methods
        function this = DCBusEnv(distMode, distVector)
            % Construct observation and action specifications
            ObservationInfo = rlNumericSpec([3 1], ...
                'LowerLimit', [-Inf; -Inf; -Inf], ...
                'UpperLimit', [ Inf;  Inf;  Inf]);
            ObservationInfo.Name = 'DC_Bus_Observations';
            ObservationInfo.Description = 'Scaled_Error, Scaled_dError, Scaled_PrevAction';
            
            % Normalized action in [-1, 1], internally scaled to [-10, 10]
            ActionInfo = rlNumericSpec([1 1], ...
                'LowerLimit', -1.0, ...
                'UpperLimit',  1.0);
            ActionInfo.Name = 'Converter_Control_Effort';
            ActionInfo.Description = 'Normalized_Control_Action';
            
            this = this@rl.env.MATLABEnvironment(ObservationInfo, ActionInfo);
            
            if nargin >= 1 && ~isempty(distMode)
                this.DisturbanceMode = distMode;
            end
            if nargin >= 2 && ~isempty(distVector)
                this.DisturbanceVector = distVector;
                this.MaxSteps = length(distVector);
            end
        end
        
        function [Observation, Reward, IsDone, LoggedSignals] = step(this, Action)
            LoggedSignals = [];
            this.CurrentStep = this.CurrentStep + 1;
            
            % 1. Bound and scale action to physical converter range [-10, 10]
            action_norm = max(min(Action, 1.0), -1.0);
            action_raw  = action_norm * this.ActScale;
            
            % 2. Calculate dynamic load current disturbance
            base_load = 5.0;
            if strcmpi(this.DisturbanceMode, 'excel') && ~isempty(this.DisturbanceVector)
                idx = min(this.CurrentStep, length(this.DisturbanceVector));
                i_load = base_load + this.DisturbanceVector(idx);
            else
                % Default synthetic sinusoidal disturbance (10 Hz ripple)
                ripple_load = 2.0 * sin(2 * pi * 10 * this.CurrentStep * this.dt);
                i_load = base_load + ripple_load;
            end
            
            % 3. Converter current delivery
            i_control = base_load + (action_raw * 1.5);
            
            % 4. Capacitor Voltage Dynamics: C * (dV/dt) = I_control - I_load
            dV = ((i_control - i_load) / this.C_dc) * this.dt;
            v_sensed_new = this.PrevVsensed + dV;
            
            % Numerical safety boundary clamp
            v_sensed_new = max(min(v_sensed_new, 400.0), 200.0);
            
            % 5. Raw error and error derivative
            err_raw  = this.V_ref - v_sensed_new;
            derr_raw = (err_raw - this.PrevError) / this.dt;
            
            % 6. Scaled observations (continuous unbounded gradients)
            err_scaled  = err_raw  / this.ErrScale;
            derr_scaled = derr_raw / this.DErrScale;
            act_scaled  = this.PrevAction / this.ActScale;
            
            % Update internal tracking states
            this.PrevVsensed = v_sensed_new;
            this.PrevError   = err_raw;
            this.State       = [err_scaled; derr_scaled; act_scaled];
            Observation      = this.State;
            
            % 7. Reward Function: Saturating error penalty + smoothness + tight band bonus
            err_penalty    = -2.0 * (1.0 - exp(-0.5 * err_scaled^2));
            delta_act      = action_norm - act_scaled;
            smooth_penalty = -0.1 * delta_act^2;
            effort_penalty = -0.02 * action_norm^2;
            
            Reward = err_penalty + smooth_penalty + effort_penalty;
            
            % Continuous bonus for tight regulation within +/- 2.0 V band
            if abs(err_raw) < 2.0
                Reward = Reward + 1.0 * (1.0 - abs(err_raw) / 2.0);
            end
            
            this.PrevAction = action_raw;
            IsDone = (this.CurrentStep >= this.MaxSteps);
        end
        
        function InitialObservation = reset(this)
            this.CurrentStep = 0;
            this.PrevAction  = 0.0;
            this.PrevVsensed = this.V_ref;  % Deterministic reset at nominal 300.0 V
            this.PrevError   = 0.0;
            this.State       = [0.0; 0.0; 0.0];
            InitialObservation = this.State;
        end
    end
end
