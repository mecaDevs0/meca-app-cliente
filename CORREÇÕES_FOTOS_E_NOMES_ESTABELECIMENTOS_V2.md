# Correções - Fotos e Nomes dos Estabelecimentos (V2)

## Análise dos Logs

Analisando os logs do app, identifiquei os problemas específicos:

### 🔍 **Problemas Identificados:**

1. **Fotos dos Estabelecimentos**: 
   - ✅ **Home**: Funcionando corretamente (fotos aparecem)
   - ❌ **Pedidos**: Fotos vêm como `null` da API de Scheduling
   - ❌ **Detalhes do Pedido**: Fotos vêm como `null` da API de Scheduling

2. **Nomes dos Estabelecimentos**:
   - ✅ **Home**: Funcionando corretamente (nomes aparecem)
   - ❌ **Pedidos**: Todos mostram "Oficina Padrão" (CompanyName genérico)
   - ❌ **Detalhes do Pedido**: Todos mostram "Oficina Padrão" (CompanyName genérico)

### 🎯 **Causa Raiz:**

A API de Scheduling (pedidos) não retorna as fotos dos workshops, apenas dados básicos. Os workshops têm CompanyName genérico "Oficina Padrão" em vez dos nomes reais.

## Correções Implementadas

### 1. **Enriquecimento de Fotos por ID (Melhorado)**

**Arquivo modificado:**
- `lib/app/data/providers/orders_placed_provider.dart`

**Melhorias:**
- Busca workshop por ID específico (mais preciso)
- Fallback para busca por nome se falhar por ID
- Logs detalhados para debug
- Verificação de dados após enriquecimento

```dart
// Buscar workshop específico por ID
final response = await _restClientDio.get(
  '${BaseUrls.workshops}/$workshopId',
  queryParameters: {
    'dataBlocked': 0,
  },
);
```

### 2. **WorkshopNameHelper - Ignorar CompanyName Genérico**

**Arquivo modificado:**
- `lib/app/core/utils/workshop_name_helper.dart`

**Melhoria:**
- Não usar "Oficina Padrão" como CompanyName (é genérico)
- Priorizar FullName quando CompanyName for genérico

```dart
// Não usar "Oficina Padrão" que é genérico
if (workshop.companyName?.isNotEmpty == true && 
    workshop.companyName != 'null' && 
    workshop.companyName != '' &&
    workshop.companyName != 'Oficina Padrão') {
  // Usar CompanyName
} else {
  // Usar FullName como fallback
}
```

### 3. **Logs de Debug Melhorados**

**Arquivos com logs adicionados:**
- `lib/app/data/models/order.dart` - Log completo do JSON do workshop
- `lib/app/data/providers/orders_placed_provider.dart` - Log de enriquecimento
- `lib/app/core/utils/workshop_name_helper.dart` - Log de seleção de nome

## Como Testar

1. **Executar o app:**
   ```bash
   cd meca-app-cliente
   flutter run --debug
   ```

2. **Verificar os logs:**
   - Procurar por `🔧 [OrdersPlacedProvider]` - logs de enriquecimento
   - Procurar por `🔧 [WorkshopNameHelper]` - logs de seleção de nome
   - Procurar por `🔧 [Order]` - logs de mapeamento de dados

3. **Testar as telas:**
   - **Home**: Deve continuar funcionando
   - **Pedidos**: Deve mostrar fotos e nomes corretos
   - **Detalhes do Pedido**: Deve mostrar fotos e nomes corretos

## Logs Esperados

### Para Enriquecimento de Fotos:
```
🔧 [OrdersPlacedProvider] Buscando workshop por ID: 68263e3624717c1a8bcbad0f
🔧 [OrdersPlacedProvider] ✅ Foto atualizada para ID 68263e3624717c1a8bcbad0f: 1747336757686.png
```

### Para Seleção de Nome:
```
🔧 [WorkshopNameHelper] CompanyName: "Oficina Padrão"
🔧 [WorkshopNameHelper] FullName: "Fabiano Belmonte"
🔧 [WorkshopNameHelper] ✅ Usando FullName: "Fabiano Belmonte"
```

## Status das Correções

- ✅ **Enriquecimento de fotos**: Implementado busca por ID + fallback
- ✅ **Seleção de nomes**: Ignora CompanyName genérico
- ✅ **Logs de debug**: Adicionados para troubleshooting
- 🔄 **Testes**: Em andamento

## Próximos Passos

1. Testar o app e verificar se as fotos aparecem
2. Verificar se os nomes corretos são exibidos (não mais "Oficina Padrão")
3. Se ainda houver problemas, analisar os logs para identificar falhas
4. Remover logs de debug após confirmação de funcionamento

## Observações Importantes

- A API de Scheduling não retorna fotos dos workshops
- O enriquecimento busca as fotos da API de Workshops
- Workshops têm CompanyName genérico "Oficina Padrão"
- FullName contém o nome real do estabelecimento
