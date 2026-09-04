# Alias para consultar o Gemini com o contexto do projeto carregado
alias gemini-dev='gemini --context .gemini-context.md'

# Alias focado em revisão estrita MISRA C
alias gemini-misra='gemini "Analise o arquivo a seguir sob as diretrizes MISRA C:2012 e aponte violações com correções em C puro:"'

# Alias para geração de issues para o GitHub CLI
alias gemini-issue='gemini "Converta a seguinte necessidade técnica em formato Markdown pronto para o GitHub Issue com Objetivo, DoD e Estimativa em horas:"'