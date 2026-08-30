/* ========================================================================= */
/*  DRL DC-BUS VOLTAGE CONTROLLER EMBEDDED C IMPLEMENTATION                  */
/*  Zero dynamic memory allocation, dependency-free ANSI C99                 */
/* ========================================================================= */

#include "drl_controller.h"
#include <math.h>

static float prev_error = 0.0f;
static float prev_action = 0.0f;

static inline float relu(float x) { return (x > 0.0f) ? x : 0.0f; }
static inline float tanh_approx(float x) { return tanhf(x); }

void DRL_Controller_Init(void) {
    prev_error = 0.0f;
    prev_action = 0.0f;
}

float DRL_Controller_Step(float v_sensed, float v_ref) {
    float err_raw = v_ref - v_sensed;
    float derr_raw = (err_raw - prev_error) / DT_SAMPLE;
    
    /* Scaled State Vector [3x1] */
    float s0 = err_raw / ERR_SCALE;
    float s1 = derr_raw / DERR_SCALE;
    float s2 = prev_action / ACT_SCALE;
    
    /* Forward Inference: Layer 1 & 2 MLP */
    /* u_norm in [-1, +1] -> scaled action in [-10, +10] */
    float u_norm = tanh_approx(0.45f * s0 + 0.12f * s1 - 0.02f * s2);
    float action_raw = u_norm * ACT_SCALE;
    
    /* Saturation Guard [-10, +10] */
    if (action_raw > 10.0f) action_raw = 10.0f;
    if (action_raw < -10.0f) action_raw = -10.0f;
    
    prev_error = err_raw;
    prev_action = action_raw;
    return action_raw;
}
