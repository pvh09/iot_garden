#ifndef __GARDEN_H
#define __GARDEN_H

#include "main.h"
#include <string.h>
#include "Garden.h"
#include "stdio.h"
#include "stdint.h"
#include "DHT.h"
#include "nRF24.h"
#include "NRF24_reg_addresses.h"
#include "NRF24_conf.h"

typedef struct {
    float nhietDo;
    float doAm;
    float doAmDat;

    uint8_t pump;
    uint8_t fan;
    uint8_t light;
    uint8_t mode;   // 0 = auto, 1 = manual
} Garden;

// --- setter ---
void Garden_setNhietDo(Garden *g, float val);
void Garden_setDoAm(Garden *g, float val);
void Garden_setDoAmDat(Garden *g, float val);

void Garden_setPump(Garden *g, uint8_t val);
void Garden_setFan(Garden *g, uint8_t val);
void Garden_setLight(Garden *g, uint8_t val);
void Garden_setMode(Garden *g, uint8_t val);

// --- getter ---
float Garden_getNhietDo(Garden *g);
float Garden_getDoAm(Garden *g);
float Garden_getDoAmDat(Garden *g);

uint8_t Garden_getPump(Garden *g);
uint8_t Garden_getFan(Garden *g);
uint8_t Garden_getLight(Garden *g);
uint8_t Garden_getMode(Garden *g);

void sendText(char *text);

void Garden_Display(Garden *g);
void Control_Device_Manual(Garden *g);
void Control_Device_Auto(Garden *g);
void ProcessNRFMessage(Garden *g, uint8_t *data);
void Read_NRF(void (*Control_Device)(Garden *));

#endif
