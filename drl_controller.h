/* ========================================================================= */
/*  DRL DC-BUS VOLTAGE CONTROLLER EMBEDDED C FIRMWARE HEADER                 */
/*  Target: TI C2000 / ARM Cortex-M / STM32 / Embedded DSPs                  */
/* ========================================================================= */

#ifndef DRL_CONTROLLER_H
#define DRL_CONTROLLER_H

#ifdef __cplusplus
extern "C" {
#endif

/* Controller Constants */
#define V_REF_NOMINAL   300.0f
#define ERR_SCALE       10.0f
#define DERR_SCALE      1000.0f
#define ACT_SCALE       10.0f
#define DT_SAMPLE       0.001f

/* Public API */
void DRL_Controller_Init(void);
float DRL_Controller_Step(float v_sensed, float v_ref);

#ifdef __cplusplus
}
#endif

#endif /* DRL_CONTROLLER_H */
