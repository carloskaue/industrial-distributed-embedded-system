# Documento de Controle de Interface Serial (ICD)
**Projeto:** Sistema Embarcado Distribuído Industrial (IDES)  
**Documento:** ICD-SER-001  
**Revisão:** 1.0.0  
**Data:** 2026-09-03  
**Status:** Aprovado para Implementação  

---

## 1. Visão Geral e Camada Física

Este documento estabelece o protocolo de enlace e de aplicação para a comunicação serial entre o **Nó 1 (Gateway Linux - Raspberry Pi Zero)** e os nós escravos/sensores distribuídos (Hercules TMS570, ESP32-S2, ESP32-CAM, MSP430 e Bancada HIL).

### 1.1 Parâmetros da UART
* **Taxa de Transmissão (Baud Rate):** 115200 bps
* **Bits de Dados:** 8
* **Paridade:** Nenhuma (None)
* **Bits de Parada:** 1 stop bit
* **Controle de Fluxo:** Nenhum (Hardware Flow Control desativado)
* **Nível Lógico:** TTL 3.3V (Transições de nós 5V devem passar por divisor de tensão resistivo $1.8\text{ k}\Omega / 3.3\text{ k}\Omega$).

---

## 2. Estrutura do Pacote de Enlace (Frame Layout)

Todas as transmissões no barramento utilizam um pacote binário determinístico de tamanho delimitado com verificação de redundância cíclica de 16 bits (**CRC16-CCITT**).

```text
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|          SYNC HEADER          |    NODE_ID    |   MSG_TYPE    |
|     0xAA      |     0x55      |   (Origem)    |   (Opcode)    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  PAYLOAD_LEN  |           PAYLOAD DATA (0 a 32 bytes)         |
|  (0 a 32 B)   |                      ...                      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|       CRC16-CCITT (MSB)       |       CRC16-CCITT (LSB)       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+.
```

### 2.1 Detalhamento dos Campos

| Campo  | Tamanho | Valor/Faixa|Descrição|
| ------------- | ------------- | ------------- |:-------------:|
| SYNC_HEADER| 2 Bytes| 0xAA 0x55| Preâmbulo constante para sincronização de frame e alinhamento de receptor.|
NODE_ID| 1 Byte| 0x01 a 0x06| Identificador do nó remetente da mensagem.|
MSG_TYPE| 1 Byte| 0x10 a 0x4F| Código de operação (Opcode) que determina a semântica e formato do payload.|
PAYLOAD_LEN| 1 Byte| 0x00 a 0x20| Quantidade de bytes de dados no campo PAYLOAD (máximo de 32 bytes).|
PAYLOAD| Variável| 0 a 32 Bytes| Dados específicos da transação serial (big-endian/network byte order).|
CRC16| 2 Bytes| 0x0000 a 0xFFFF| Checksum cobrindo do byte NODE_ID até o último byte de PAYLOAD (MSB primeiro).|

----

## 3. Identificadores de Nós (Node IDs)

NODE_ID | Identificador Mnemônico | Plataforma de Hardware | Função Primária|
| ------------- | ------------- | ------------- |:-------------:|
0x01 | NODE_ID_GATEWAYRaspberry| Pi Zero (ARM11) | Gateway Linux / Mestre de Telemetria |
0x02 | NODE_ID_SAFETYTI| Hercules TMS570 (Cortex-R4F) | Intertravamento e Controle do Motor  |
0x03 | NODE_ID_AUTOMATION | ESP32-S2 | Automação Local, LCD 2x16 e Relés  |
0x04 | NODE_ID_ACCESS | ESP32-CAM | Controle de Acesso RFID e Imagem |
0x05 | NODE_ID_SENSOR | TI MSP430 Launchpad | Sensor Ultrabaixo Consumo (DHT11) |
0x06 | NODE_ID_HIL | Stellaris TM4C / Arduino AVR  | Bancada HIL e Injeção de Falhas |

----

## 4. Opcodes e Estruturas de Payloads (MSG_TYPE)

Todos os campos numéricos compostos de mais de 1 byte adotam ordem Big-Endian (Rede).

### 4.1 Opcodes do Sistema

* `0x10` - HEARTBEAT: Sinal de vivacidade periódico do nó.
* `0x20` - TELEMETRY_ENV: Leitura ambiental de temperatura e umidade (Nó 5).
* `0x21` - TELEMETRY_MOTOR: Estado operacional e rotação do atuador crítico (Nó 2).
* `0x22` - ACCESS_EVENT: Registro de passagem de tag RFID (Nó 4).
* `0x30` - SAFETY_ALARM: Notificação de desarme de emergência / intertravamento (Nó 2).
* `0x40` - CMD_RELAY_CONTROL: Comando de abertura/fechamento de relé (Nó 1 -> Nó 3).
* `0x41` - CMD_MOTOR_SET: Definição de velocidade/direção da ponte H (Nó 1 -> Nó 2).


### 4.2 Definições das Estruturas de Dados (`#pragma pack(1)`)

A. Heartbeat (`MSG_TYPE = 0x10`, `LEN = 5`)
Disparado a cada 1000 ms por nós ativos.

```
C

typedef struct {
    uint32_t uptime_seconds; /* Tempo de atividade do nó em segundos */
    uint8_t  system_state;    /* 0x00: INIT, 0x01: OK, 0x02: DEGRADED, 0xFF: FAULT */
} payload_heartbeat_t;
```

B. Telemetria Ambiental Nó 5 (`MSG_TYPE = 0x20`, `LEN = 6`)

```
C 

typedef struct {
    int16_t  temperature_centi_celsius; /* Temp em °C * 100 (ex: 2550 = 25.50 °C) */
    uint16_t humidity_centi_percent;    /* UR em % * 100 (ex: 6020 = 60.20 %) */
    uint16_t battery_milli_volts;       /* Tensão de alimentação (ex: 3300 mV) */
} payload_telemetry_env_t;
```

C. Telemetria do Motor Nó 2 (`MSG_TYPE = 0x21`, LEN = 6`)

```
C 

typedef struct {
    uint16_t current_rpm;        /* Rotação aferida em RPM */
    uint16_t current_milli_amps; /* Corrente estimada do L298N em mA */
    uint8_t  direction;          /* 0x00: STOP, 0x01: CW, 0x02: CCW */
    uint8_t  interlock_engaged;  /* 0x00: Aberto/Desarmado, 0x01: Fechado/Seguro */
} payload_telemetry_motor_t;
```
D. Evento de Acesso Nó 4 (`MSG_TYPE = 0x22`, `LEN = 6`)

```
C

typedef struct {
    uint8_t  uid_length;         /* Tamanho da UID (ex: 4 ou 7 bytes) */
    uint8_t  uid[4];             /* Primeiros 4 bytes da tag RFID */
    uint8_t  auth_status;        /* 0x00: REJECTED, 0x01: GRANTED */
} payload_access_event_t;
```

E. Alarme de Intertravamento Nó 2 (`MSG_TYPE = 0x30`, `LEN = 4`)

```
C

typedef struct {
    uint16_t fault_code;         /* Código de falha: 0xE001 (Stall), 0xE002 (E-Stop) */
    uint16_t reaction_time_us;   /* Tempo gasto até o corte de potência (microssegundos) */
} payload_safety_alarm_t;
```

F. Comando de Relés Nó 3 (`MSG_TYPE = 0x40`, `LEN = 2`)

```
C

typedef struct {
    uint8_t relay_index;         /* 0x01: Relé 1, 0x02: Relé 2, 0xFF: Ambos */
    uint8_t state;               /* 0x00: Desligar (Aberto), 0x01: Ligar (Fechado) */
} payload_cmd_relay_t;
```

---

## 5. Algoritmo CRC16-CCITT Compatível com MISRA C:2012
A verificação de integridade cobre os campos `[NODE_ID]`, `[MSG_TYPE]`, `[PAYLOAD_LEN]` e `[PAYLOAD]`. O `SYNC_HEADER` (`0xAA 0x55`) não entra no cálculo.

* Polinômio Gerador: x^16 + x^12 + x^5 + 1 (`0x1021`)
* Valor Inicial (Init): `0xFFFF`
* XOR Final: `0x0000`
* Reflexão de Entrada / Saída: Não (Processamento MSB-first direto)

### 5.1 Especificações de Conformidade MISRA C:2012
* Regra 8.4 & 8.7: Compatibilidade de prototipagem e escopo estático de tradução.
* Diretiva 4.6: Tipos básicos substituídos por tipos explícitos da biblioteca <stdint.h>.
* Regra 10.1 & 10.4: Operações lógicas de deslocamento limitadas estritamente a tipos sem sinal (uint16_t e uint8_t).
* Regra 15.6: Todas as instruções de controle (for, if) delimitadas por chaves.
* Regra 17.7: Tratamento ou uso obrigatório do retorno de funções.

### 5.2 Implementação Portável (`crc16.h`)

```
C

/**
 * @file crc16.h
 * @brief Implementação determinística de CRC16-CCITT em C estrito.
 */

#ifndef CRC16_H
#define CRC16_H

#include <stdint.h>
#include <stddef.h>

#define CRC16_INITIAL_VALUE ((uint16_t)0xFFFFU)

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Calcula o CRC16-CCITT sobre um buffer contíguo de memória.
 * @param[in] data    Ponteiro para o buffer de bytes a processar.
 * @param[in] length  Número de bytes do buffer.
 * @return uint16_t   Checksum CRC16 calculado.
 */
uint16_t crc16_ccitt_calculate(const uint8_t * const data, const size_t length);

/**
 * @brief Atualiza iterativamente o cálculo de CRC16 (byte a byte).
 * @param[in] current_crc Valor atual do acumulador CRC.
 * @param[in] byte        Byte a ser introduzido.
 * @return uint16_t       Novo valor do acumulador CRC.
 */
uint16_t crc16_ccitt_update(const uint16_t current_crc, const uint8_t byte);

#ifdef __cplusplus
}
#endif

#endif /* CRC16_H */
```

### 5.3 Implementação Portável (`crc16.c`)
```
C

/**
 * @file crc16.c
 * @brief Implementação bit a bit do CRC16-CCITT sem alocação dinâmica.
 */

#include "crc16.h"

#define CRC16_POLYNOMIAL ((uint16_t)0x1021U)

uint16_t crc16_ccitt_update(const uint16_t current_crc, const uint8_t byte)
{
    uint16_t crc = current_crc;
    uint8_t i;

    /* Desloca o byte de entrada para os 8 bits mais significativos */
    crc ^= (uint16_t)((uint16_t)byte << 8U);

    for (i = 0U; i < 8U; ++i)
    {
        if ((crc & (uint16_t)0x8000U) != 0U)
        {
            crc = (uint16_t)((uint16_t)(crc << 1U) ^ CRC16_POLYNOMIAL);
        }
        else
        {
            crc = (uint16_t)(crc << 1U);
        }
    }

    return crc;
}

uint16_t crc16_ccitt_calculate(const uint8_t * const data, const size_t length)
{
    uint16_t crc = CRC16_INITIAL_VALUE;
    size_t index;

    if (data != NULL)
    {
        for (index = 0U; index < length; ++index)
        {
            crc = crc16_ccitt_update(crc, data[index]);
        }
    }
    else
    {
        crc = 0U;
    }

    return crc;
}

```

# 6. Vetor de Teste de Validação (Test Vector)
Para validação cruzada entre ferramentas de testes unitários (Unity no C e Google Test no C++):

* Entrada de Teste (ASCII): `"123456789"` 
    * Representação Hexadecimal: `0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39`
* Resultado Esperado (CRC16-CCITT standard): `0x29B1`

Exemplo de Pacote Serial Válido (Telemetria do Nó 5)
* `SYNC_HEADER`: `0xAA 0x55`
* `NODE_ID`: `0x05` (MSP430)
* `MSG_TYPE`: `0x20` (Telemetria Ambiental)
* `LENGTH`: `0x06` (6 bytes)
* `PAYLOAD`: `0x09 0xC4` (25.00 °C), `0x17 0x70` (60.00 %), `0x0C 0xE4` (3300 mV)
* `DADOS COBERTOS PELO CRC`: `05 20 06 09 C4 17 70 0C E4`
* `CRC16 RESULTANTE`: `0x8D82` -> `0x8D` (MSB), `0x82` (LSB)
* Stream Completo de Saída:
    ```
    AA 55 05 20 06 09 C4 17 70 0C E4 8D 82
    ```