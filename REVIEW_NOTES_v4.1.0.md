# Notas para Revisores — MECA Cliente v4.1.0

## Sobre o app
App de agendamento de servicos automotivos. Clientes agendam servicos em
oficinas mecanicas parceiras, acompanham o status e fazem o pagamento pelo app.

## Como testar as principais mudancas desta versao

1. Criar uma conta (ou usar login existente)
2. Buscar uma oficina e agendar um servico (qualquer servico, valor minimo R$5)
3. Na tela de pagamento:
   a. Se houver cupom disponivel, digitar o codigo e aplicar
   b. Verificar que o desconto aparece no subtotal, no botao e no parcelamento
   c. Escolher PIX -> "Gerar PIX" -> clicar "Atualizar status" — app NAO deve travar
4. Na aba "Agendamentos" (bottom nav), verificar:
   a. Servicos com pagamento pendente aparecem na aba "Pendentes"
   b. Label do card mostra "Aguardando Pagamento"
5. Se houver erro de pagamento, mensagem deve ser clara (sem termos tecnicos)

## Permissoes utilizadas
- Camera: fotos de avaliacao de servico
- Galeria/Fotos: upload de fotos
- Notificacoes push: alertas de status do servico (via OneSignal)
- Calendario: adicionar agendamento ao calendario (iOS)
- Internet: comunicacao com API

## Informacoes adicionais
- Nao ha compras in-app. Pagamentos sao processados via gateway externo (Asaas)
- Conteudo gerado por usuarios: fotos de avaliacao e texto de review
- Idade minima: 4+ (iOS) / Livre (Android)
- Backend: https://api.mecabr.com
- Conta de teste disponivel sob demanda
