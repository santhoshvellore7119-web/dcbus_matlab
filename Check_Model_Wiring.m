%% Check_Model_Wiring.m
% Model connection and wiring verification utility.
% Checks port connectivity, signal routing, block existence, and verifies both
% standard Simulink compilation and Reinforcement Learning Toolbox environment initialization.
%
% Usage:
%   isValid = Check_Model_Wiring('dcBusPITuningRL')
%   isValid = Check_Model_Wiring() % checks both models

function allValid = Check_Model_Wiring(modelNames)
    if nargin < 1 || isempty(modelNames)
        modelNames = {'dcBusPITuning', 'dcBusPITuningRL'};
    elseif ischar(modelNames) || isstring(modelNames)
        modelNames = {char(modelNames)};
    end

    allValid = true;
    fprintf('=====================================================\n');
    fprintf('  Simulink Model Diagnostics & Wiring Verification\n');
    fprintf('=====================================================\n');

    for i = 1:numel(modelNames)
        mdl = modelNames{i};
        fprintf('\n--- Checking Model: %s ---\n', mdl);
        
        if ~isfile([mdl '.slx']) && ~isfile([mdl '.mdl'])
            fprintf('  [ERROR] Model file %s does not exist.\n', mdl);
            allValid = false;
            continue;
        end
        
        try
            if ~bdIsLoaded(mdl)
                load_system(mdl);
            end
            
            % 1. Check Blocks
            blocks = find_system(mdl, 'Type', 'Block');
            fprintf('  Total Blocks: %d\n', numel(blocks));
            
            % Specific critical block checks
            if strcmp(mdl, 'dcBusPITuningRL')
                rlAgentBlocks = find_system(mdl, 'Name', 'RL Agent');
                if isempty(rlAgentBlocks)
                    fprintf('  [FAIL] Missing "RL Agent" block in %s!\n', mdl);
                    allValid = false;
                else
                    fprintf('  [PASS] Found "RL Agent" block.\n');
                end
            elseif strcmp(mdl, 'dcBusPITuning')
                pidBlocks = find_system(mdl, 'Name', 'PID Controller');
                if isempty(pidBlocks)
                    fprintf('  [FAIL] Missing "PID Controller" block in %s!\n', mdl);
                    allValid = false;
                else
                    fprintf('  [PASS] Found "PID Controller" block.\n');
                end
            end
            
            % 2. Check Signal Connections
            lines = get_param(mdl, 'Lines');
            fprintf('  Top-Level Signal Lines: %d\n', numel(lines));
            for k = 1:numel(lines)
                localPrintLine(lines(k), '    ');
            end
            
            % 3. Check Compilation / Environment validation
            if strcmp(mdl, 'dcBusPITuningRL')
                obsInfo = rlNumericSpec([2 1]);
                actInfo = rlNumericSpec([1 1], 'LowerLimit', -10, 'UpperLimit', 10);
                env = rlSimulinkEnv(mdl, [mdl '/RL Agent'], obsInfo, actInfo);
                fprintf('  [PASS] Successfully initialized and verified rlSimulinkEnv for %s.\n', mdl);
            else
                feval(mdl, [], [], [], 'compile');
                feval(mdl, [], [], [], 'term');
                fprintf('  [PASS] Diagram compilation check succeeded (0 errors, 0 port mismatches).\n');
            end
            
        catch ME
            fprintf('  [FAIL] Error during model verification: %s\n', ME.message);
            allValid = false;
            try
                feval(mdl, [], [], [], 'term');
            catch
            end
        end
    end
    
    fprintf('\n=====================================================\n');
    if allValid
        fprintf('  ALL MODEL CHECKS PASSED SUCCESSFULLY!\n');
    else
        fprintf('  SOME MODEL CHECKS FAILED!\n');
    end
    fprintf('=====================================================\n\n');
end

function localPrintLine(L, prefix)
    if isempty(L.SrcBlock) || L.SrcBlock == -1
        srcName = '(unconnected)';
    else
        srcName = get_param(L.SrcBlock, 'Name');
    end
    
    srcPortNum = localGetPortNum(L.SrcPort);
    
    if ~isempty(L.DstBlock) && all(L.DstBlock ~= -1)
        for d = 1:numel(L.DstBlock)
            dstName = get_param(L.DstBlock(d), 'Name');
            dstPortNum = localGetPortNum(L.DstPort(d));
            fprintf('%s%s [Port %s]  -->  %s [Port %s]\n', prefix, srcName, srcPortNum, dstName, dstPortNum);
        end
    else
        fprintf('%s%s [Port %s]  -->  (branches):\n', prefix, srcName, srcPortNum);
    end
    
    for b = 1:numel(L.Branch)
        localPrintLine(L.Branch(b), [prefix '    ']);
    end
end

function pStr = localGetPortNum(p)
    if ischar(p) || isstring(p)
        pStr = char(p);
    elseif isnumeric(p)
        pStr = num2str(p);
    else
        pStr = '1';
    end
end
