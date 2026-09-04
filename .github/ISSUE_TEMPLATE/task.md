---
name: "Entrega Técnica / Tarefa"
about: "Criar uma tarefa técnica para o sprint"
title: "[NÓ/FRENTE]: Descrição concisa da tarefa"
labels: ["enhancement", "sprint"]
assignees: ""
---

### 1. Contexto e Objetivo
<!-- Descreva qual subsistema ou funcionalidade este item cobre -->

### 2. Nó / Subsistema Afetado
- [ ] Nó 1 (RPi Zero - Buildroot / C++17)
- [ ] Nó 2 (Hercules TMS570 - Safety / FreeRTOS)
- [ ] Nó 3 (ESP32-S2 - Automação / ESP-IDF)
- [ ] Nó 4 (ESP32-CAM - Acesso / DMA)
- [ ] Nó 5 (MSP430 - Bare-Metal / LPM)
- [ ] Nó 6 (Bancada HIL - AVR-GCC / Zephyr)
- [ ] CI/CD & Infraestrutura

### 3. Critérios de Aceitação (DoD)
- [ ] Código compila sem warnings (`-Wall -Wextra -Werror`).
- [ ] Testes unitários implementados e aprovados.
- [ ] Conformidade de estilo/padrão validada (MISRA C para Nó 2, Clang-Tidy para C++).
- [ ] Documentação ou esquemático atualizado na pasta `/docs`.

### 4. Dependências Técnicas
- Bloqueado por: #
- Bloqueia: #