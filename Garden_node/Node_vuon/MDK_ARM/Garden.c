#include <string.h>
#include "Garden.h"
#include "main.h"
#include "stdio.h"
#include "stdint.h"
#include "DHT.h"
#include "nRF24.h"
#include "NRF24_reg_addresses.h"
#include "NRF24_conf.h"

extern UART_HandleTypeDef huart2;

// --- SETTER ---
void Garden_setNhietDo(Garden *g, float val) { g->nhietDo = val; }
void Garden_setDoAm(Garden *g, float val) { g->doAm = val; }
void Garden_setDoAmDat(Garden *g, float val) { g->doAmDat = val; }

void Garden_setPump(Garden *g, uint8_t val) { g->pump = val; }
void Garden_setFan(Garden *g, uint8_t val) { g->fan = val; }
void Garden_setLight(Garden *g, uint8_t val) { g->light = val; }
void Garden_setMode(Garden *g, uint8_t val) { g->mode = val; }

// --- GETTER ---
float Garden_getNhietDo(Garden *g) { return g->nhietDo; }
float Garden_getDoAm(Garden *g) { return g->doAm; }
float Garden_getDoAmDat(Garden *g) { return g->doAmDat; }

uint8_t Garden_getPump(Garden *g) { return g->pump; }
uint8_t Garden_getFan(Garden *g) { return g->fan; }
uint8_t Garden_getLight(Garden *g) { return g->light; }
uint8_t Garden_getMode(Garden *g) { return g->mode; }
