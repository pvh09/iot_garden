/* USER CODE BEGIN Header */
/**
 ******************************************************************************
 * @file           : main.c
 * @brief          : Main program body
 ******************************************************************************
 * @attention
 *
 * Copyright (c) 2025 STMicroelectronics.
 * All rights reserved.
 *
 * This software is licensed under terms that can be found in the LICENSE file
 * in the root directory of this software component.
 * If no LICENSE file comes with this software, it is provided AS-IS.
 *
 ******************************************************************************
 */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/

#include "main.h"
#include "DHT.h"
#include "Garden.h"
#include <stdio.h>
#include <string.h>

/* Private variables ---------------------------------------------------------*/
ADC_HandleTypeDef hadc1;
SPI_HandleTypeDef hspi1;
TIM_HandleTypeDef htim1;
UART_HandleTypeDef huart1;
UART_HandleTypeDef huart2;

#define LIGHT_PIN GPIO_PIN_12
#define FAN_PIN GPIO_PIN_13
#define PUMP_PIN GPIO_PIN_14

Garden garden1;
DHT_DataTypedef DHT11_Data;
float Temperature, Humidity;
long last = 0;
int i = 0;

/* ADC calibration values */
const float ADC_WET = 1200.0f; // Gia tri khi dat rat uot
const float ADC_DRY = 3800.0f; // Gia tri khi dat kho

/* NRF24 address */
static uint8_t ADDR_UP[5] = {'N','O','D','E','1'}; // STM -> ESP (sensor uplink)
static uint8_t ADDR_DN[5] = {'G','A','T','E','1'}; // ESP -> STM (command downlink)

#ifdef __GNUC__
#define PUTCHAR_PROTOTYPE int __io_putchar(int ch)
#else
#define PUTCHAR_PROTOTYPE int fputc(int ch, FILE *f)
#endif

PUTCHAR_PROTOTYPE
{
  if (huart1.gState == HAL_UART_STATE_READY || huart1.gState == HAL_UART_STATE_BUSY_TX)
  {
    HAL_UART_Transmit(&huart1, (uint8_t *)&ch, 1, 10);
  }
  return ch;
}

/* Function prototypes */
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_ADC1_Init(void);
static void MX_SPI1_Init(void);
static void MX_TIM1_Init(void);
static void MX_USART1_UART_Init(void);
static void MX_USART2_UART_Init(void);
void sendText(char *text);

/* NRF24 functions */
void NRF24_Config_Common(void);
void Read_NRF(void (*Control_Device)(Garden *));
void ProcessNRFMessage(Garden *g, uint8_t *data);

/* Sensor functions */
void Read_All_Sensor(void);
float Compute_Soil_Moisture(uint32_t raw_adc);

/* Control functions */
void Control_Device_Manual(Garden *g);
void Control_Device_Auto(Garden *g);

int main(void)
{
  HAL_Init();
  SystemClock_Config();

  /* Initialize all configured peripherals */
  MX_GPIO_Init();
  MX_ADC1_Init();
  MX_SPI1_Init();
  MX_TIM1_Init();
  HAL_TIM_Base_Start(&htim1);
  MX_USART1_UART_Init();
  MX_USART2_UART_Init();

  // --- Cho DHT khoi dong ---
  sendText("Cho DHT khoi dong...\r\n");
  HAL_Delay(2000); // DHT11 can it nhat 1s sau khi cap nguon

  sendText("Bat dau cau hinh nRF24...\r\n");
  NRF24_Config_Common();
	uint8_t feat = nrf24_r_reg(FEATURE, 1);
	uint8_t dynp = nrf24_r_reg(DYNPD, 1);
	char buf[64];
	sprintf(buf, "[DEBUG] FEATURE=0x%02X DYNPD=0x%02X\r\n", feat, dynp);
	sendText(buf);
	sendText("Khoi dong hoan tat - NRF san sang.\r\n");

  // --- Gia tri khoi tao ---
  garden1.mode = 0; // 0 = AUTO, 1 = MANUAL
  sendText("He thong khoi dong o che do: AUTO\r\n");

  // --- Vong lap chinh ---
  while (1)
  {
    if (garden1.mode == 1)
    {
      sendText("Chuyen sang che do MANUAL\r\n");
      while (garden1.mode == 1)
      {
        Read_All_Sensor();
        Read_NRF(Control_Device_Manual);
        HAL_Delay(100);
      }
      sendText("Thoat khoi che do MANUAL\r\n");
    }
    else
    {
      sendText("Che do AUTO dang hoat dong\r\n");
      while (garden1.mode == 0)
      {
        Read_All_Sensor();
        Read_NRF(Control_Device_Auto);
        HAL_Delay(1000);
      }
      sendText("Thoat khoi che do AUTO\r\n");
    }
  }
}

void NRF24_Config_Common(void)
{
    nrf24_init();
    nrf24_pwr_up();

    nrf24_set_addr_width(5);
    nrf24_set_channel(40);
    nrf24_data_rate(_250kbps);
    nrf24_tx_pwr(n18dbm);
    nrf24_set_crc(en_crc, _1byte);

    // KHÔNG dùng DPL để tránh width=0
    nrf24_dpl(enable);
    nrf24_set_rx_dpl(0, enable);
    nrf24_set_rx_dpl(1, enable);

    // Auto-ACK + retry để chống rơi gói
    nrf24_auto_ack_all(disable);
    //nrf24_auto_ack(0, enable);
    nrf24_auto_retr_delay(10);
    nrf24_auto_retr_limit(15);

    // Uplink: STM -> ESP
    nrf24_open_tx_pipe(ADDR_UP);

    // Downlink: ESP -> STM (nhận đúng 4 byte)
    nrf24_open_rx_pipe(1, ADDR_DN);
    nrf24_pipe_pld_size(1, 4);

    HAL_Delay(50);
}


void Read_NRF(void (*Control_Device)(Garden *))
{
    static uint32_t last_tx_ms = 0;
    uint32_t now = HAL_GetTick();
    if (now - last_tx_ms < 2000) return;   // gửi cảm biến mỗi 2s
    last_tx_ms = now;

    // --- TX uplink ---
    nrf24_stop_listen();
    HAL_Delay(2);

    char msg[64];
    sprintf(msg, "<%.1f %.1f %.1f>", garden1.nhietDo, garden1.doAm, garden1.doAmDat);
    nrf24_en_dyn_ack(enable);                 // bật quyền "no_ack" nếu lib cần
		nrf24_transmit_no_ack((uint8_t*)msg, strlen(msg)+1);
    HAL_Delay(2);
    nrf24_clear_tx_ds(); nrf24_clear_max_rt(); nrf24_flush_tx();

    // --- RX window 150 ms để nhận lệnh ---
	
    nrf24_listen(); // pipe1, payload cố định 4 byte
    uint8_t rx_buf[4];
    uint32_t t0 = HAL_GetTick();
    while (HAL_GetTick()-t0 < 200) {
        if (nrf24_data_available()) {
            nrf24_receive(rx_buf, 4);        // không dùng r_pld_wid nữa
            nrf24_clear_rx_dr();

            // map lệnh
            garden1.pump  = rx_buf[0];
            garden1.fan   = rx_buf[1];
            garden1.light = rx_buf[2];
            garden1.mode  = rx_buf[3];

            char info[96];
            sprintf(info, "[RECV]: P=%d F=%d L=%d M=%d\r\n",
                    garden1.pump, garden1.fan, garden1.light, garden1.mode);
            sendText(info);
            break;
        }
        HAL_Delay(1);
    }
    nrf24_stop_listen();
    nrf24_flush_rx();

    // --- Điều khiển thiết bị ---
    Control_Device(&garden1);
}


void ProcessNRFMessage(Garden *g, uint8_t *data)
{
  // data[0] = pump, data[1] = fan, data[2] = light, data[3] = mode
  g->pump = data[0];
  g->fan = data[1];
  g->light = data[2];
  g->mode = data[3];

  char info[96];
  sprintf(info, "[RECV]: DATA tu ESP: Pump=%d | Fan=%d | Light=%d | Mode=%d\r\n", g->pump, g->fan, g->light, g->mode);
  sendText(info);
}

void Read_All_Sensor(void)
{
  static uint32_t last_ms = 0;
  uint32_t now = HAL_GetTick();

  // chi doc moi 5 giay
  if (last_ms != 0 && (now - last_ms) < 2000)
    return;
  last_ms = now;

  // ==== 1. DOC DHT11 ====
  DHT_GetData(&DHT11_Data);
  Temperature = DHT11_Data.Temperature;
  Humidity = DHT11_Data.Humidity;
  Garden_setNhietDo(&garden1, Temperature);
  Garden_setDoAm(&garden1, Humidity);

  // ==== 2. DOC CAM BIEN DO AM DAT ====
  uint32_t adc_raw = 0;
  HAL_ADC_Start(&hadc1);
  if (HAL_ADC_PollForConversion(&hadc1, 10) == HAL_OK)
  {
    adc_raw = HAL_ADC_GetValue(&hadc1);
  }
  HAL_ADC_Stop(&hadc1);

  float soil_pct = Compute_Soil_Moisture(adc_raw);
  Garden_setDoAmDat(&garden1, soil_pct);

  // ==== 3. IN KET QUA ====
  char msg[96];
  sprintf(msg, "Nhiet do: %.1f*C | Do am: %.1f%% | Soil: %.1f%%\r\n",
          Temperature, Humidity, soil_pct);
  sendText(msg);
}

float Compute_Soil_Moisture(uint32_t raw_adc)
{
  float moisture;

  // Noi suy tuyen tinh
  if (raw_adc <= ADC_WET)
  {
    moisture = 100.0f; // gioi han tren
  }
  else if (raw_adc >= ADC_DRY)
  {
    moisture = 0.0f; // gioi han duoi
  }
  else
  {
    moisture = (ADC_DRY - raw_adc) * 100.0f / (ADC_DRY - ADC_WET);
  }

  return moisture;
}

void Control_Device_Manual(Garden *g)
{
  uint8_t light_cmd = g->light;
  uint8_t fan_cmd = g->fan;
  uint8_t pump_cmd = g->pump;

  // active-high: SET = bat, RESET = tat
  HAL_GPIO_WritePin(GPIOB, LIGHT_PIN, light_cmd ? GPIO_PIN_SET : GPIO_PIN_RESET);
  HAL_GPIO_WritePin(GPIOB, FAN_PIN, fan_cmd ? GPIO_PIN_SET : GPIO_PIN_RESET);
  HAL_GPIO_WritePin(GPIOB, PUMP_PIN, pump_cmd ? GPIO_PIN_SET : GPIO_PIN_RESET);

  g->light = light_cmd;
  g->fan = fan_cmd;
  g->pump = pump_cmd;
}

void Control_Device_Auto(Garden *g)
{
  float t = Garden_getNhietDo(g);
  float soil = Garden_getDoAmDat(g);

  // --- Den va Quat ---
  if (t <= 32.0f)
  {
    HAL_GPIO_WritePin(GPIOB, LIGHT_PIN, GPIO_PIN_SET);
    HAL_GPIO_WritePin(GPIOB, FAN_PIN, GPIO_PIN_RESET);

    // Ghi lai vao bien trang thai
    g->light = 1;
    g->fan = 0;
  }
  else if (t > 36.0f)
  {
    HAL_GPIO_WritePin(GPIOB, LIGHT_PIN, GPIO_PIN_RESET);
    HAL_GPIO_WritePin(GPIOB, FAN_PIN, GPIO_PIN_SET);

    g->light = 0;
    g->fan = 1;
  }
  else
  {
    HAL_GPIO_WritePin(GPIOB, LIGHT_PIN, GPIO_PIN_RESET);
    HAL_GPIO_WritePin(GPIOB, FAN_PIN, GPIO_PIN_RESET);

    g->light = 0;
    g->fan = 0;
  }

  // --- May bom ---
  if (soil < 50.0f)
  {
    HAL_GPIO_WritePin(GPIOB, PUMP_PIN, GPIO_PIN_SET);
    g->pump = 1;
  }
  else
  {
    HAL_GPIO_WritePin(GPIOB, PUMP_PIN, GPIO_PIN_RESET);
    g->pump = 0;
  }
}

void sendText(char *text)
{
  HAL_UART_Transmit(&huart1, (uint8_t *)text, strlen(text), HAL_MAX_DELAY);
}

/**
 * @brief System Clock Configuration
 * @retval None
 */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};
  RCC_PeriphCLKInitTypeDef PeriphClkInit = {0};

  /** Initializes the RCC Oscillators according to the specified parameters
   * in the RCC_OscInitTypeDef structure.
   */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSE;
  RCC_OscInitStruct.HSEState = RCC_HSE_ON;
  RCC_OscInitStruct.HSEPredivValue = RCC_HSE_PREDIV_DIV1;
  RCC_OscInitStruct.HSIState = RCC_HSI_ON;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
  RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSE;
  RCC_OscInitStruct.PLL.PLLMUL = RCC_PLL_MUL9;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the CPU, AHB and APB buses clocks
   */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK | RCC_CLOCKTYPE_SYSCLK | RCC_CLOCKTYPE_PCLK1 | RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV2;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_2) != HAL_OK)
  {
    Error_Handler();
  }
  PeriphClkInit.PeriphClockSelection = RCC_PERIPHCLK_ADC;
  PeriphClkInit.AdcClockSelection = RCC_ADCPCLK2_DIV6;
  if (HAL_RCCEx_PeriphCLKConfig(&PeriphClkInit) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
 * @brief ADC1 Initialization Function
 * @param None
 * @retval None
 */
static void MX_ADC1_Init(void)
{
  ADC_ChannelConfTypeDef sConfig = {0};

  /** Common config
   */
  hadc1.Instance = ADC1;
  hadc1.Init.ScanConvMode = ADC_SCAN_DISABLE;
  hadc1.Init.ContinuousConvMode = DISABLE;
  hadc1.Init.DiscontinuousConvMode = DISABLE;
  hadc1.Init.ExternalTrigConv = ADC_SOFTWARE_START;
  hadc1.Init.DataAlign = ADC_DATAALIGN_RIGHT;
  hadc1.Init.NbrOfConversion = 1;
  if (HAL_ADC_Init(&hadc1) != HAL_OK)
  {
    Error_Handler();
  }

  /** Configure Regular Channel
   */
  sConfig.Channel = ADC_CHANNEL_1;
  sConfig.Rank = ADC_REGULAR_RANK_1;
  sConfig.SamplingTime = ADC_SAMPLETIME_1CYCLE_5;
  if (HAL_ADC_ConfigChannel(&hadc1, &sConfig) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
 * @brief SPI1 Initialization Function
 * @param None
 * @retval None
 */
static void MX_SPI1_Init(void)
{

  hspi1.Instance = SPI1;
  hspi1.Init.Mode = SPI_MODE_MASTER;
  hspi1.Init.Direction = SPI_DIRECTION_2LINES;
  hspi1.Init.DataSize = SPI_DATASIZE_8BIT;
  hspi1.Init.CLKPolarity = SPI_POLARITY_LOW;
  hspi1.Init.CLKPhase = SPI_PHASE_1EDGE;
  hspi1.Init.NSS = SPI_NSS_SOFT;
  hspi1.Init.BaudRatePrescaler = SPI_BAUDRATEPRESCALER_8;
  hspi1.Init.FirstBit = SPI_FIRSTBIT_MSB;
  hspi1.Init.TIMode = SPI_TIMODE_DISABLE;
  hspi1.Init.CRCCalculation = SPI_CRCCALCULATION_DISABLE;
  hspi1.Init.CRCPolynomial = 10;
  if (HAL_SPI_Init(&hspi1) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
 * @brief TIM1 Initialization Function
 * @param None
 * @retval None
 */
static void MX_TIM1_Init(void)
{

  TIM_ClockConfigTypeDef sClockSourceConfig = {0};
  TIM_MasterConfigTypeDef sMasterConfig = {0};

  htim1.Instance = TIM1;
  htim1.Init.Prescaler = 71;
  htim1.Init.CounterMode = TIM_COUNTERMODE_UP;
  htim1.Init.Period = 65535;
  htim1.Init.ClockDivision = TIM_CLOCKDIVISION_DIV1;
  htim1.Init.RepetitionCounter = 0;
  htim1.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_DISABLE;
  if (HAL_TIM_Base_Init(&htim1) != HAL_OK)
  {
    Error_Handler();
  }
  sClockSourceConfig.ClockSource = TIM_CLOCKSOURCE_INTERNAL;
  if (HAL_TIM_ConfigClockSource(&htim1, &sClockSourceConfig) != HAL_OK)
  {
    Error_Handler();
  }
  sMasterConfig.MasterOutputTrigger = TIM_TRGO_RESET;
  sMasterConfig.MasterSlaveMode = TIM_MASTERSLAVEMODE_DISABLE;
  if (HAL_TIMEx_MasterConfigSynchronization(&htim1, &sMasterConfig) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
 * @brief USART1 Initialization Function
 * @param None
 * @retval None
 */
static void MX_USART1_UART_Init(void)
{
  huart1.Instance = USART1;
  huart1.Init.BaudRate = 115200;
  huart1.Init.WordLength = UART_WORDLENGTH_8B;
  huart1.Init.StopBits = UART_STOPBITS_1;
  huart1.Init.Parity = UART_PARITY_NONE;
  huart1.Init.Mode = UART_MODE_TX_RX;
  huart1.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart1.Init.OverSampling = UART_OVERSAMPLING_16;
  if (HAL_UART_Init(&huart1) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
 * @brief USART2 Initialization Function
 * @param None
 * @retval None
 */
static void MX_USART2_UART_Init(void)
{
  huart2.Instance = USART2;
  huart2.Init.BaudRate = 115200;
  huart2.Init.WordLength = UART_WORDLENGTH_8B;
  huart2.Init.StopBits = UART_STOPBITS_1;
  huart2.Init.Parity = UART_PARITY_NONE;
  huart2.Init.Mode = UART_MODE_TX_RX;
  huart2.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart2.Init.OverSampling = UART_OVERSAMPLING_16;
  if (HAL_UART_Init(&huart2) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
 * @brief GPIO Initialization Function
 * @param None
 * @retval None
 */
static void MX_GPIO_Init(void)
{
  GPIO_InitTypeDef GPIO_InitStruct = {0};
  __HAL_RCC_GPIOD_CLK_ENABLE();
  __HAL_RCC_GPIOA_CLK_ENABLE();
  __HAL_RCC_GPIOB_CLK_ENABLE();

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(GPIOB, GPIO_PIN_12, GPIO_PIN_RESET);

  /*Configure GPIO pin : PA0 */
  GPIO_InitStruct.Pin = GPIO_PIN_0;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

  /*Configure GPIO pin : PB12,13,14 */
  GPIO_InitStruct.Pin = GPIO_PIN_12 | GPIO_PIN_13 | GPIO_PIN_14;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

  // M?c d?nh k�o th?p
  HAL_GPIO_WritePin(GPIOB, GPIO_PIN_0 | GPIO_PIN_1, GPIO_PIN_RESET);
  // Tat het thiet bi luc khoi dong
  HAL_GPIO_WritePin(GPIOB, GPIO_PIN_12 | GPIO_PIN_13 | GPIO_PIN_14, GPIO_PIN_SET);

  // CE (PA4) & CSN (PA3)
  GPIO_InitStruct.Pin = GPIO_PIN_3 | GPIO_PIN_4;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_HIGH;
  HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

  HAL_GPIO_WritePin(GPIOA, GPIO_PIN_3 | GPIO_PIN_4, GPIO_PIN_RESET);
}

/**
 * @brief  This function is executed in case of error occurrence.
 * @retval None
 */
void Error_Handler(void)
{
  /* USER CODE BEGIN Error_Handler_Debug */
  /* User can add his own implementation to report the HAL error return state */
  __disable_irq();
  while (1)
  {
  }
  /* USER CODE END Error_Handler_Debug */
}
#ifdef USE_FULL_ASSERT
/**
 * @brief  Reports the name of the source file and the source line number
 *         where the assert_param error has occurred.
 * @param  file: pointer to the source file name
 * @param  line: assert_param error line source number
 * @retval None
 */
void assert_failed(uint8_t *file, uint32_t line)
{
  /* USER CODE BEGIN 6 */
  /* User can add his own implementation to report the file name and line number,
     ex: printf("Wrong parameters value: file %s on line %d\r\n", file, line) */
  /* USER CODE END 6 */
}
#endif /* USE_FULL_ASSERT */
