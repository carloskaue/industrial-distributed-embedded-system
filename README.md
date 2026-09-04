# **Industrial Distributed Embedded System (IDES)**

![]() ![]() ![]() ![]()  
Arquitetura multiprocessada distribuída para supervisão industrial, intertravamento crítico de segurança e telemetria de borda. O projeto adota práticas industriais de engenharia de software embarcado, eliminando bibliotecas de prototipagem amadora em favor de implementações diretas sobre registradores (bare-metal), kernels de tempo real (FreeRTOS, Zephyr RTOS), Linux Embarcado gerado via Buildroot e verificação formal estática.

## **1\. Visão Geral da Arquitetura**

O sistema é composto por 6 nós funcionais conectados via barramento serial padronizado com verificação por CRC16, além de interface MQTT/TLS com a nuvem.

                             \[ Cloud / Broker MQTT \]  
                                        ▲  
                                        │ TLS 1.3 / Port 8883  
                                        ▼  
                   \+-----------------------------------------+  
                   |       Nó 1: Gateway Linux Embarcado     |  
                   |      (Raspberry Pi Zero \- ARM1176)      |  
                   |      Buildroot Custom \+ C++17 Daemon    |  
                   \+-----------------------------------------+  
                                        ▲  
                                        │ UART / Modbus (Frames \+ CRC16)  
         \+------------------------------+------------------------------+  
         │                              │                              │  
         ▼                              ▼                              ▼  
\+-------------------+          \+-------------------+          \+-------------------+  
|  Nó 2: Segurança  |          | Nó 3: Automação   |          | Nó 4: Acesso/Audit|  
|  TMS570LS (R4F)   |          | ESP32-S2          |          | ESP32-CAM         |  
|  FreeRTOS / MISRA |          | ESP-IDF Native    |          | DMA Capture / BT  |  
|  L298N \+ LCD 5110 |          | LCD 2x16 \+ Relés  |          | RFID-RC522 \+ Cam  |  
\+-------------------+          \+-------------------+          \+-------------------+  
         ▲                              ▲  
         │ (Fault Injections)           │ 1-Wire / Low-Power Mode  
         ▼                              ▼  
\+-------------------+          \+-------------------+  
| Nó 6: HIL Bench   |          | Nó 5: Ultrabaixo  |  
| 2x AVR-GCC (Uno)  |          | MSP430 (16-bit)   |  
| \+ TM4C / Zephyr   |          | Bare-Metal C / CCS|  
| Monitor / Jitter  |          | DHT11 \+ Timer IRQ |  
\+-------------------+          \+-------------------+

## **2\. Subsistemas e Especificações Técnicas**

| Nó | Silício / Arquitetura | Toolchain / SO | Periféricos / Atuação | Função Principal |
| :---- | :---- | :---- | :---- | :---- |
| **Nó 1 (Gateway)** | RPi Zero (ARM1176JZF-S) | Buildroot / C++17 | USB-Serial, Wi-Fi | Agregação multithread POSIX, filtragem de telemetria e despacho MQTT via TLS. |
| **Nó 2 (Safety)** | Hercules TMS570 (Cortex-R4F) | HALCoGen \+ ARM-GCC / FreeRTOS | L298N (Ponte H), LCD Nokia 5110 (SPI) | Intertravamento crítico, controle determinístico do motor e aderência a MISRA C:2012. |
| **Nó 3 (Automation)** | ESP32-S2 (Xtensa 32-bit) | ESP-IDF / FreeRTOS nativo | LCD 2x16, Módulo 2 Relés | Orquestração assíncrona orientada a eventos (esp\_event\_loop) e acionamento local. |
| **Nó 4 (Access)** | ESP32-CAM (Xtensa Dual-Core) | ESP-IDF / C | RC522 (SPI), Câmera OV2640, JY-MCU (BT) | Controle de acesso RFID, aquisição de imagem via DMA e despacho de logs via serial/BT. |
| **Nó 5 (Sensor)** | MSP430 Launchpad (16-bit) | CCS / Bare-Metal C | Sensor DHT11 (1-Wire temporal) | Aquisição por interrupções de hardware, manipulação direta de registradores e LPM. |
| **Nó 6 (HIL Bench)** | 2x ATmega328P \+ TM4C123G | AVR-GCC / Zephyr RTOS | Linhas de pulso, UART Sniffer | Injeção de falhas determinísticas nos nós críticos e medição temporal de jitter. |

## **3\. Segurança Elétrica e Níveis Lógicos**

**Atenção:** Componentes alimentados a 5V (Arduinos e módulos de relé) não devem ser conectados diretamente aos pinos GPIO dos dispositivos de 3.3V (Hercules, Stellaris, MSP430, ESP32 e Raspberry Pi). Para os sinais que transitam de 5V para 3.3V, utiliza-se o divisor de tensão resistivo:

V\_in (5V Sinal) \---\[ 1.8 kΩ \]---+---\> V\_out (3.23V para Nó 3.3V)  
                                │  
                              \[ 3.3 kΩ \]  
                                │  
                               GND

Cálculo nominal: V\_out \= 5V \* (3300 / (1800 \+ 3300)) \= 3.23V.

## **4\. Protocolo de Enlace Serial (ICD Resumido)**

A comunicação serial adota frames binários padronizados com verificação de redundância cíclica (CRC16-CCITT):

\+--------------+---------+----------+--------+------------------+---------------+  
| HEADER (2B)  | NODE\_ID | MSG\_TYPE | LENGTH |   PAYLOAD (N B)  |  CRC16 (2B)   |  
| 0xAA   0x55  |  (1B)   |   (1B)   |  (1B)  |  0 até 32 bytes  |  MSB  |  LSB  |  
\+--------------+---------+----------+--------+------------------+---------------+

> * **Header:** 0xAA 0x55 (Sincronização de início de pacote)  
> * **Node IDs:** 0x01 (RPi), 0x02 (Hercules), 0x03 (ESP32-S2), 0x04 (ESP32-CAM), 0x05 (MSP430)  
> * **Tipos de Mensagem:** 0x10 (Heartbeat), 0x20 (Telemetria), 0x30 (Alarme/Intertravamento), 0x40 (Comando)

## **5\. Estrutura de Diretórios**

.  
├── .github/              \# Workflows de CI/CD e templates de issues  
├── docs/                 \# Documentos de arquitetura, esquemáticos e ICD  
│   ├── architecture/     \# Mapeamentos de pinagem e protocolos  
│   └── planning/         \# EAP, cronograma e matriz de riscos  
├── firmware/  
│   ├── node1-gateway-rpi/        \# Buildroot configs e daemon C++17  
│   ├── node2-safety-hercules/    \# Projeto CCS, Safe C, FreeRTOS  
│   ├── node3-automation-esp32s2/ \# Firmware ESP-IDF nativo  
│   ├── node4-access-esp32cam/    \# Firmware do nó de acesso RFID \+ Câmera  
│   ├── node5-sensor-msp430/      \# Código bare-metal com economia de energia  
│   └── node6-hil-testbench/      \# Firmware AVR-GCC puro e monitor Zephyr  
└── tests/  
    ├── gtest/            \# Testes unitários do Gateway (C++17)  
    ├── unity/            \# Testes unitários para nós C (Hercules/MSP430)  
    └── python-hil/       \# Scripts de automação e estresse HIL

## **6\. Instruções de Compilação e Análise Estática**

### **Daemon Gateway C++17**

cd firmware/node1-gateway-rpi/app  
mkdir build && cd build  
cmake \-DCMAKE\_BUILD\_TYPE=Release ..  
cmake \--build .

### **Análise Estática e Testes Unitários**

cppcheck \--enable=all \--inconclusive \--error-exitcode=1 \--suppress=missingIncludeSystem firmware/ tests/

cd tests/gtest  
mkdir build && cd build  
cmake .. && cmake \--build . && ctest \--output-on-failure

## **7\. Licença**

Distribuído sob a licença MIT. Consulte o arquivo LICENSE para mais detalhes.