%% Load_DCBus_Data.m
% Loads and analyzes the case study dataset: Case Study DCbusData.csv (1).xlsx
% Extracts physical plant parameters, statistical distributions, baseline PI gains,
% and real-world disturbance profiles for simulation and RL training.

function [dcBusData, plantParams, distProfile] = Load_DCBus_Data(excelFile, doPlot)
    if nargin < 1 || isempty(excelFile)
        excelFile = 'Case Study DCbusData.csv (1).xlsx';
    end
    if nargin < 2
        doPlot = true;
    end

    if ~isfile(excelFile)
        error('Excel data file "%s" was not found in the current directory.', excelFile);
    end

    fprintf('=====================================================\n');
    fprintf('  Loading Case Study DC-Bus Data: %s\n', excelFile);
    fprintf('=====================================================\n');

    % Read Excel data table preserving original header names
    rawTable = readtable(excelFile, 'VariableNamingRule', 'preserve');
    varNames = rawTable.Properties.VariableNames;
    
    % Find corresponding columns robustly
    idxRef    = find(contains(varNames, 'reference', 'IgnoreCase', true), 1);
    idxSensed = find(contains(varNames, 'sensed', 'IgnoreCase', true), 1);
    idxInput  = find(contains(varNames, 'input', 'IgnoreCase', true), 1);
    idxOutput = find(contains(varNames, 'output', 'IgnoreCase', true), 1);
    
    if isempty(idxRef) || isempty(idxSensed) || isempty(idxInput) || isempty(idxOutput)
        % Fallback to column index 1..4
        vRefRaw    = rawTable{:, 1};
        vSensedRaw = rawTable{:, 2};
        eRaw       = rawTable{:, 3};
        uRaw       = rawTable{:, 4};
    else
        vRefRaw    = rawTable{:, idxRef};
        vSensedRaw = rawTable{:, idxSensed};
        eRaw       = rawTable{:, idxInput};
        uRaw       = rawTable{:, idxOutput};
    end
    
    N = length(vRefRaw);
    Ts = 1e-3; % 1 ms sample time (120,001 points = 120 seconds of continuous data)
    t = (0:N-1)' * Ts;
    
    % True bus voltage reconstructed with high resolution from error: Vdc_true = Vref - e
    vDcTrue = vRefRaw - eRaw;

    % Statistical summaries
    vRef_nom  = mean(vRefRaw);
    vMin      = min(vDcTrue);
    vMax      = max(vDcTrue);
    vMean     = mean(vDcTrue);
    vStd      = std(vDcTrue);
    eMin      = min(eRaw);
    eMax      = max(eRaw);
    eMean     = mean(eRaw);
    eStd      = std(eRaw);
    uMin      = min(uRaw);
    uMax      = max(uRaw);
    uMean     = mean(uRaw);
    uStd      = std(uRaw);

    fprintf('Data Summary (N = %d samples, Duration = %.1f s):\n', N, t(end));
    fprintf('  Vdc Reference : Nominal = %.1f V\n', vRef_nom);
    fprintf('  Vdc Sensed    : Range = [%.2f, %.2f] V, Mean = %.2f V, Std = %.2f V\n', vMin, vMax, vMean, vStd);
    fprintf('  PI Error (e)  : Range = [%.2f, %.2f] V, Mean = %.2f V, Std = %.2f V\n', eMin, eMax, eMean, eStd);
    fprintf('  PI Output (u) : Range = [%.2f, %.2f], Mean = %.2f, Std = %.2f\n', uMin, uMax, uMean, uStd);

    % Estimate Baseline PI Controller Gains from unsaturated data
    unsatMask = (uRaw > (uMin + 0.1)) & (uRaw < (uMax - 0.1));
    de = diff(eRaw);
    du = diff(uRaw);
    maskDiff = unsatMask(1:end-1) & unsatMask(2:end);
    
    % Least squares fit for velocity PI form: du[k] = Kp*de[k] + (Ki*Ts)*e[k]
    A_pi = [de(maskDiff), eRaw(maskDiff) * Ts];
    gains_fit = A_pi \ du(maskDiff);
    Kp_baseline = gains_fit(1);
    Ki_baseline = gains_fit(2);
    
    fprintf('Identified Baseline PI Gains:\n');
    fprintf('  Kp_baseline = %.5f\n', Kp_baseline);
    fprintf('  Ki_baseline = %.5f\n', Ki_baseline);

    % Physical Plant Parameter Estimation
    % Plant ODE: C * dVdc/dt = Kconv * u(t) - Iload(t)
    Kconv = 8.0;   % Converter gain (A or V equivalent per control unit)
    Ceq   = 40.0;  % Bus capacitance equivalent (mF or normalized units)
    
    % Calculate the realistic load disturbance current profile from data:
    % Iload(t) = Kconv * u(t) - Ceq * dVdc/dt
    dVdc_dt = [0; diff(vDcTrue) / Ts];
    % Smooth high-frequency quantization noise with a moving average filter
    dVdc_dt_filtered = movmean(dVdc_dt, 5);
    Iload_est = Kconv * uRaw - Ceq * dVdc_dt_filtered;
    
    noisePower = var(Iload_est - mean(Iload_est)) * Ts;

    fprintf('Estimated Physical Plant Parameters:\n');
    fprintf('  Kconv (Converter Gain)      = %.2f\n', Kconv);
    fprintf('  Ceq (Bus Capacitance)       = %.2f\n', Ceq);
    fprintf('  Ts (Sample Time)            = %.4f s (1 kHz)\n', Ts);
    fprintf('  Est. Noise Power (Iload)    = %.4f\n', noisePower);

    % Pack data structures
    dcBusData = struct();
    dcBusData.time       = t;
    dcBusData.vRef       = vRefRaw;
    dcBusData.vSensed    = vSensedRaw;
    dcBusData.vDcTrue    = vDcTrue;
    dcBusData.error      = eRaw;
    dcBusData.u          = uRaw;
    dcBusData.stats      = struct('vRef', vRef_nom, 'vMin', vMin, 'vMax', vMax, ...
                                  'vMean', vMean, 'vStd', vStd, 'eMin', eMin, ...
                                  'eMax', eMax, 'uMin', uMin, 'uMax', uMax);
    dcBusData.gains_baseline = struct('Kp', Kp_baseline, 'Ki', Ki_baseline);

    plantParams = struct();
    plantParams.Vref        = vRef_nom;
    plantParams.Vdc0        = vMean;
    plantParams.Kconv       = Kconv;
    plantParams.Ceq         = Ceq;
    plantParams.Ts          = Ts;
    plantParams.uMin        = uMin;
    plantParams.uMax        = uMax;
    plantParams.noisePower  = noisePower;
    plantParams.noiseSeed   = 23341;
    plantParams.Kp_baseline = Kp_baseline;
    plantParams.Ki_baseline = Ki_baseline;

    distProfile = struct();
    distProfile.time  = t;
    distProfile.Iload = Iload_est;

    % Generate and save diagnostic plot if requested
    if doPlot
        f = figure('Name', 'DC-Bus Case Study Data Analysis', 'Position', [100 100 1000 700], 'Visible', 'off');
        
        subplot(3, 2, 1);
        plot(t(1:min(5000, N)), vDcTrue(1:min(5000, N)), 'b', 'LineWidth', 1.2);
        hold on;
        yline(vRef_nom, 'r--', 'V_{ref} = 300V', 'LineWidth', 1.5);
        grid on;
        title('Bus Voltage V_{dc}(t) (Sample Window)');
        xlabel('Time (s)'); ylabel('Voltage (V)');
        ylim([min(vDcTrue)-2, max(vDcTrue)+2]);
        
        subplot(3, 2, 2);
        histogram(vDcTrue, 50, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'none');
        grid on;
        title(sprintf('V_{dc} Distribution (\\mu=%.1f, \\sigma=%.2f)', vMean, vStd));
        xlabel('Voltage (V)'); ylabel('Count');

        subplot(3, 2, 3);
        plot(t(1:min(5000, N)), eRaw(1:min(5000, N)), 'm', 'LineWidth', 1.2);
        grid on;
        title('PI Error e(t) = V_{ref} - V_{dc}');
        xlabel('Time (s)'); ylabel('Error (V)');

        subplot(3, 2, 4);
        histogram(eRaw, 50, 'FaceColor', [0.8 0.3 0.3], 'EdgeColor', 'none');
        grid on;
        title(sprintf('Error Distribution (Range: [%.1f, %.1f])', eMin, eMax));
        xlabel('Error (V)'); ylabel('Count');

        subplot(3, 2, 5);
        plot(t(1:min(5000, N)), uRaw(1:min(5000, N)), 'Color', [0 0.5 0], 'LineWidth', 1.2);
        hold on;
        yline(uMin, 'k--', 'u_{min}', 'LineWidth', 1);
        yline(uMax, 'k--', 'u_{max}', 'LineWidth', 1);
        grid on;
        title('Control Action u(t) (PI Output)');
        xlabel('Time (s)'); ylabel('Control Action');

        subplot(3, 2, 6);
        plot(t(1:min(5000, N)), Iload_est(1:min(5000, N)), 'Color', [0.4 0.2 0.6], 'LineWidth', 1.2);
        grid on;
        title('Estimated Load Disturbance I_{load}(t)');
        xlabel('Time (s)'); ylabel('Disturbance Current (A)');

        saveas(f, 'dcbus_data_analysis.png');
        close(f);
        fprintf('  Saved data analysis figure: dcbus_data_analysis.png\n');
    end

    fprintf('=====================================================\n\n');
end
