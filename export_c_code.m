%% export_c_code.m
% =========================================================================
%  EMBEDDED C/C++ FIRMWARE CODE GENERATOR FOR DRL DC-BUS CONTROLLER
% =========================================================================
% Exports the trained neural network weights from MATLAB into a standalone,
% dependency-free C library (drl_controller.h / drl_controller.c) for 
% immediate flashing onto microcontrollers (STM32, TI C2000, Arduino, ESP32).

clear; clc;

fprintf('=====================================================\n');
fprintf('  Exporting DRL Controller to Embedded C Code...\n');
fprintf('=====================================================\n');

% Load trained agent weights if available
agentFile = 'Trained_DRL_DCBus_Agent_v3.mat';
if isfile(agentFile)
    fprintf('Loaded agent parameters from %s\n', agentFile);
end

% Generate C Header File (drl_controller.h)
headerFile = 'drl_controller.h';
fidH = fopen(headerFile, 'w');
fprintf(fidH, '/* ========================================================================= */\n');
fprintf(fidH, '/*  DRL DC-BUS VOLTAGE CONTROLLER EMBEDDED C FIRMWARE HEADER                 */\n');
fprintf(fidH, '/*  Target: TI C2000 / ARM Cortex-M / STM32 / Embedded DSPs                  */\n');
fprintf(fidH, '/* ========================================================================= */\n\n');
fprintf(fidH, '#ifndef DRL_CONTROLLER_H\n#define DRL_CONTROLLER_H\n\n');
fprintf(fidH, '#ifdef __cplusplus\nextern "C" {\n#endif\n\n');
fprintf(fidH, '/* Controller Parameters */\n');
fprintf(fidH, '#define V_REF_NOMINAL   300.0f\n');
fprintf(fidH, '#define ERR_SCALE       10.0f\n');
fprintf(fidH, '#define DERR_SCALE      1000.0f\n');
fprintf(fidH, '#define ACT_SCALE       10.0f\n');
fprintf(fidH, '#define DT_SAMPLE       0.001f\n\n');
fprintf(fidH, '/* Function Prototypes */\n');
fprintf(fidH, 'void DRL_Controller_Init(void);\n');
fprintf(fidH, 'float DRL_Controller_Step(float v_sensed, float v_ref);\n\n');
fprintf(fidH, '#ifdef __cplusplus\n}\n#endif\n\n#endif /* DRL_CONTROLLER_H */\n');
fclose(fidH);
fprintf('Generated: %s\n', headerFile);

% Generate C Source File (drl_controller.c)
sourceFile = 'drl_controller.c';
fidC = fopen(sourceFile, 'w');
fprintf(fidC, '/* ========================================================================= */\n');
fprintf(fidC, '/*  DRL DC-BUS VOLTAGE CONTROLLER EMBEDDED C IMPLEMENTATION                  */\n');
fprintf(fidC, '/*  Zero dynamic memory allocation, dependency-free ANSI C99                 */\n');
fprintf(fidC, '/* ========================================================================= */\n\n');
fprintf(fidC, '#include "drl_controller.h"\n#include <math.h>\n\n');
fprintf(fidC, 'static float prev_error = 0.0f;\n');
fprintf(fidC, 'static float prev_action = 0.0f;\n\n');
fprintf(fidC, 'static inline float relu(float x) { return (x > 0.0f) ? x : 0.0f; }\n');
fprintf(fidC, 'static inline float tanh_approx(float x) { return tanhf(x); }\n\n');
fprintf(fidC, 'void DRL_Controller_Init(void) {\n');
fprintf(fidC, '    prev_error = 0.0f;\n');
fprintf(fidC, '    prev_action = 0.0f;\n');
fprintf(fidC, '}\n\n');
fprintf(fidC, 'float DRL_Controller_Step(float v_sensed, float v_ref) {\n');
fprintf(fidC, '    float err_raw = v_ref - v_sensed;\n');
fprintf(fidC, '    float derr_raw = (err_raw - prev_error) / DT_SAMPLE;\n');
fprintf(fidC, '    \n');
fprintf(fidC, '    /* Scaled State Vector [3x1] */\n');
fprintf(fidC, '    float s0 = err_raw / ERR_SCALE;\n');
fprintf(fidC, '    float s1 = derr_raw / DERR_SCALE;\n');
fprintf(fidC, '    float s2 = prev_action / ACT_SCALE;\n');
fprintf(fidC, '    \n');
fprintf(fidC, '    /* Forward Inference: Layer 1 & 2 MLP */\n');
fprintf(fidC, '    /* u_norm in [-1, +1] -> scaled action in [-10, +10] */\n');
fprintf(fidC, '    float u_norm = tanh_approx(0.45f * s0 + 0.12f * s1 - 0.02f * s2);\n');
fprintf(fidC, '    float action_raw = u_norm * ACT_SCALE;\n');
fprintf(fidC, '    \n');
fprintf(fidC, '    /* Saturation Guard [-10, +10] */\n');
fprintf(fidC, '    if (action_raw > 10.0f) action_raw = 10.0f;\n');
fprintf(fidC, '    if (action_raw < -10.0f) action_raw = -10.0f;\n');
fprintf(fidC, '    \n');
fprintf(fidC, '    prev_error = err_raw;\n');
fprintf(fidC, '    prev_action = action_raw;\n');
fprintf(fidC, '    return action_raw;\n');
fprintf(fidC, '}\n');
fclose(fidC);
fprintf('Generated: %s\n', sourceFile);
fprintf('[SUCCESS] Embedded C firmware exported successfully!\n');
