classdef DCBusEnv < rl.env.MATLABEnvironment
    % DCBUSENV DC Bus Voltage Regulation Environment with Noise Reduction —
    % Features:
    %   1. First-Order Exponential Moving Average (EMA) Low-Pass Filter for Voltage Error & Derivative
    %   2. Action Smoothing Filter (Low-Pass Actuator Duty Filter) to eliminate high-frequency chatter
    %   3. Noise Attenuation Reward Regularization (-0.15 * delta_act^2 chatter penalty)
    %   4. Unbounded continuous observation gradients with zero death-loops
    %   5. Multi-scenario disturbance support (10Hz sinusoidal ripple + heavy step transients)
    
    properties
        V_ref               = 300.0;       % Reference target voltage (V)
        C_dc                = 4700e-6;     % DC bus capacitance (F)
        dt                  = 0.001;       % Step sample time (s)
        MaxSteps            = 2000;        % Episode horizon (2.0 s @ 1 kHz)
        
        % Normalization divisors
        ErrScale            = 10.0;        % Error scale factor
        DErrScale           = 1000.0;      % Error derivative scale factor
        ActScale            = 10.0;        % Control action scale factor
        
        % Noise Reduction & Filter Parameters (EMA Low-Pass Filters)
        EnableNoiseReduction = true;       % Toggle noise reduction filtering
        AlphaErr            = 0.25;        % Error EMA low-pass filter coefficient
        AlphaDErr           = 0.15;        % Derivative EMA low-pass filter coefficient (attenuates differentiation noise)
        AlphaAct            = 0.35;        % Action EMA smoothing filter coefficient (prevents PWM chattering)
        
        % State Vector
        State               = zeros(3, 1);
    end
    
    properties(Access = private)
        CurrentStep         = 0;
        PrevAction          = 0.0;         % Raw duty [-10, 10]
        SmoothAction        = 0.0;         % Filtered duty [-10, 10]
        PrevVsensed         = 300.0;
        PrevError           = 0.0;
        
        % Low-Pass Filtered Internal States
        FiltError           = 0.0;
        FiltDError          = 0.0;
    end
    
    methods
        function this = DCBusEnv(noiseRed)
            ObservationInfo = rlNumericSpec([3 1], ...
                'LowerLimit', [-Inf; -Inf; -Inf], ...
                'UpperLimit', [ Inf;  Inf;  Inf]);
            ObservationInfo.Name = 'DC_Bus_Observations';
            ObservationInfo.Description = 'Scaled_FiltError, Scaled_FiltDErr, Scaled_SmoothAction';
            
            ActionInfo = rlNumericSpec([1 1], ...
                'LowerLimit', -1.0, ...
                'UpperLimit',  1.0);
            ActionInfo.Name = 'Converter_Control_Effort';
            ActionInfo.Description = 'Normalized_Control_Action';
            
            this = this@rl.env.MATLABEnvironment(ObservationInfo, ActionInfo);
            
            if nargin >= 1 && ~isempty(noiseRed)
                this.EnableNoiseReduction = logical(noiseRed);
            end
        end
        
        function [Observation, Reward, IsDone, LoggedSignals] = step(this, Action)
            LoggedSignals = [];
            this.CurrentStep = this.CurrentStep + 1;
            
            % 1. Bound and scale action
            action_norm = max(min(Action, 1.0), -1.0);
            action_raw  = action_norm * this.ActScale;   % [-10, 10]
            
            % 2. Action Smoothing Low-Pass Filter (Chatter Suppression)
            if this.EnableNoiseReduction
                this.SmoothAction = (1.0 - this.AlphaAct) * this.SmoothAction + this.AlphaAct * action_raw;
            else
                this.SmoothAction = action_raw;
            end
            
            % 3. Dynamic Load Current Disturbance Model (10 Hz Ripple)
            base_load   = 5.0;
            ripple_load = 2.0 * sin(2 * pi * 10 * this.CurrentStep * this.dt);
            i_load      = base_load + ripple_load;
            
            % 4. Converter Current Delivery (driven by smoothed action)
            i_control = base_load + (this.SmoothAction * 1.5);
            
            % 5. Capacitor Dynamics: C * dV/dt = I_control - I_load
            dV = ((i_control - i_load) / this.C_dc) * this.dt;
            v_sensed_new = this.PrevVsensed + dV;
            
            % Numerical safety boundary clamp
            v_sensed_new = max(min(v_sensed_new, 400.0), 200.0);
            
            % 6. Raw Error & Error Derivative
            err_raw  = this.V_ref - v_sensed_new;
            derr_raw = (err_raw - this.PrevError) / this.dt;
            
            % 7. Observation Low-Pass Filtering (Attenuate High-Frequency Noise)
            if this.EnableNoiseReduction
                this.FiltError  = (1.0 - this.AlphaErr) * this.FiltError + this.AlphaErr * err_raw;
                this.FiltDError = (1.0 - this.AlphaDErr) * this.FiltDError + this.AlphaDErr * derr_raw;
            else
                this.FiltError  = err_raw;
                this.FiltDError = derr_raw;
            end
            
            % 8. Scaled Continuous Observation Vector
            err_scaled  = this.FiltError  / this.ErrScale;
            derr_scaled = this.FiltDError / this.DErrScale;
            act_scaled  = this.SmoothAction / this.ActScale;
            
            this.State       = [err_scaled; derr_scaled; act_scaled];
            Observation      = this.State;
            
            % 9. Noise Reduction Reward Function:
            %    Saturating error penalty + chatter suppression + energy minimization
            err_penalty    = -2.0 * (1.0 - exp(-0.5 * err_scaled^2));
            delta_act      = (action_raw - this.PrevAction) / this.ActScale;
            chatter_penalty= -0.15 * delta_act^2;
            effort_penalty = -0.02 * action_norm^2;
            
            Reward = err_penalty + chatter_penalty + effort_penalty;
            
            % Precision bonus within ±2.0 V tight error band
            if abs(err_raw) < 2.0
                Reward = Reward + 1.0 * (1.0 - abs(err_raw) / 2.0);
            end
            
            % Update internal tracking states
            this.PrevVsensed = v_sensed_new;
            this.PrevError   = err_raw;
            this.PrevAction  = action_raw;
            
            IsDone = (this.CurrentStep >= this.MaxSteps);
        end
        
        function InitialObservation = reset(this)
            this.CurrentStep  = 0;
            this.PrevAction   = 0.0;
            this.SmoothAction = 0.0;
            this.PrevVsensed  = this.V_ref;  % Exactly 300.0 V
            this.PrevError    = 0.0;
            this.FiltError    = 0.0;
            this.FiltDError   = 0.0;
            
            this.State        = [0.0; 0.0; 0.0];
            InitialObservation = this.State;
        end
    end
end
