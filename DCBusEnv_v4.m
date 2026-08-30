classdef DCBusEnv_v4 < rl.env.MATLABEnvironment
    % DCBUSENV_V4 Advanced Integral-Augmented Reinforcement Learning Environment
    % Eliminates steady-state limit-cycle oscillations via augmented state-space
    % representation: S_t = [e/10, derr/1000, ∫e dt / 50, u_{t-1}/10]
    %
    % Physics Model:
    %   C * (dVdc/dt) = I_control(t) - I_load(t)
    %   I_control(t)  = I_base + 1.5 * u(t)
    
    properties
        V_ref             = 300.0;       % Nominal bus reference (V)
        C_dc              = 4700e-6;     % Bus capacitance (F)
        dt                = 0.001;       % Sample time (1 ms)
        MaxSteps          = 2000;        % Episode horizon (2.0s)
        
        % State Scaling Divisors
        ErrScale          = 10.0;
        DErrScale         = 1000.0;
        IntegErrScale     = 50.0;
        ActScale          = 10.0;
        
        State             = zeros(4, 1);
    end
    
    properties(Access = private)
        CurrentStep = 0;
        PrevAction  = 0.0;
        PrevVsensed = 300.0;
        PrevError   = 0.0;
        IntegError  = 0.0;
    end
    
    methods
        function this = DCBusEnv_v4()
            ObservationInfo = rlNumericSpec([4 1], ...
                'LowerLimit', [-Inf; -Inf; -Inf; -Inf], ...
                'UpperLimit', [ Inf;  Inf;  Inf;  Inf]);
            ObservationInfo.Name = 'Augmented_Observations';
            ObservationInfo.Description = 'Scaled_Error, Scaled_dError, Scaled_IntegError, Scaled_PrevAction';
            
            ActionInfo = rlNumericSpec([1 1], ...
                'LowerLimit', -1.0, ...
                'UpperLimit',  1.0);
            ActionInfo.Name = 'Converter_Control_Effort';
            ActionInfo.Description = 'Normalized_Control_Action';
            
            this = this@rl.env.MATLABEnvironment(ObservationInfo, ActionInfo);
        end
        
        function [Observation, Reward, IsDone, LoggedSignals] = step(this, Action)
            LoggedSignals = [];
            this.CurrentStep = this.CurrentStep + 1;
            
            % 1. Bound and scale action
            action_norm = max(min(Action, 1.0), -1.0);
            action_raw  = action_norm * this.ActScale;
            
            % 2. 10 Hz Sinusoidal Load Disturbance
            base_load   = 5.0;
            ripple_load = 2.0 * sin(2 * pi * 10 * this.CurrentStep * this.dt);
            i_load      = base_load + ripple_load;
            
            % 3. Converter Current Delivery
            i_control = base_load + (action_raw * 1.5);
            
            % 4. Voltage Dynamics
            dV = ((i_control - i_load) / this.C_dc) * this.dt;
            v_sensed_new = this.PrevVsensed + dV;
            v_sensed_new = max(min(v_sensed_new, 400.0), 200.0);
            
            % 5. Raw Tracking Errors
            err_raw   = this.V_ref - v_sensed_new;
            derr_raw  = (err_raw - this.PrevError) / this.dt;
            this.IntegError = this.IntegError + err_raw * this.dt;
            
            % Anti-windup clamping on integral state
            this.IntegError = max(min(this.IntegError, 100.0), -100.0);
            
            % 6. Scaled State Construction (4 States)
            err_scaled       = err_raw / this.ErrScale;
            derr_scaled      = derr_raw / this.DErrScale;
            integ_err_scaled = this.IntegError / this.IntegErrScale;
            act_scaled       = this.PrevAction / this.ActScale;
            
            this.PrevVsensed = v_sensed_new;
            this.PrevError   = err_raw;
            this.State       = [err_scaled; derr_scaled; integ_err_scaled; act_scaled];
            Observation      = this.State;
            
            % 7. Frequency-Aware Precision Reward Formulation
            % Quadratic error penalty with high precision gradient near zero
            err_penalty = -2.0 * err_scaled^2 - 0.5 * abs(err_scaled);
            integ_penalty = -0.1 * integ_err_scaled^2;
            effort_penalty = -0.01 * action_norm^2;
            
            Reward = err_penalty + integ_penalty + effort_penalty;
            
            % Precision Bonus for tight sub-0.5V tracking
            if abs(err_raw) < 0.5
                Reward = Reward + 2.0 * (1.0 - abs(err_raw) / 0.5);
            elseif abs(err_raw) < 2.0
                Reward = Reward + 0.5 * (1.0 - abs(err_raw) / 2.0);
            end
            
            this.PrevAction = action_raw;
            IsDone = (this.CurrentStep >= this.MaxSteps);
        end
        
        function InitialObservation = reset(this)
            this.CurrentStep = 0;
            this.PrevAction  = 0.0;
            this.PrevVsensed = this.V_ref;
            this.PrevError   = 0.0;
            this.IntegError  = 0.0;
            this.State       = [0.0; 0.0; 0.0; 0.0];
            InitialObservation = this.State;
        end
    end
end
