# Changelog - MECA App Cliente

## [2.1.1] - 2026-02-05

### Fixed
- Corrigida tela preta na tela de avaliacao de servico apos pagamento
- Resolvidos erros de semantics.parentDataDirty no Flutter
- Corrigidos conflitos de layout com Spacer dentro de SingleChildScrollView
- Melhorada estabilidade da renderizacao de widgets

### Changed
- Simplificada estrutura de layout da tela de avaliacao
- Removido LayoutBuilder e ConstrainedBox desnecessarios
- Substituido Spacer por SizedBox com altura fixa

## [2.1.0] - 2026-02-05

### Added
- Sistema de pagamento integrado com PagBank usando split marketplace
- Processamento automatico de pagamentos com distribuicao transparente

### Changed
- Interface de pagamento redesenhada para melhor experiencia do usuario
- Removida exibicao de detalhes de split (taxa MECA/oficina) para simplificar
- Melhorias de performance no backend para processamento mais rapido

### Fixed
- Corrigido erro "rota nao encontrada" no cadastro de veiculos
- Ajustes no sistema de notificacoes para entrega mais confiavel
- Corrigida validacao de dados de cartao de credito

### Security
- Fortalecida seguranca do processamento de transacoes financeiras
- Criptografia aprimorada para dados sensiveis durante transmissao
- Protecao adicional contra tentativas de fraude

## [2.0.0] - 2026-01-30

### Added
- Lancamento inicial da versao 2.0
- Sistema completo de agendamento de servicos automotivos
- Integracao com Google Maps para localizacao de oficinas
- Sistema de notificacoes push via OneSignal
- Autenticacao segura com suporte a biometria

### Features
- Cadastro e gerenciamento de veiculos
- Busca de oficinas por proximidade
- Agendamento de servicos com diferentes tipos
- Acompanhamento de status de servicos em tempo real
- Sistema de avaliacoes e comentarios
- Historico completo de agendamentos
