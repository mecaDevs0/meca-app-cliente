# 📋 Declaração de Uso de Permissão - Google Play Store

## Permissão: READ_MEDIA_IMAGES

### Por que o app precisa desta permissão?

O app **MECA Cliente** precisa da permissão `READ_MEDIA_IMAGES` para permitir que os clientes enviem fotos dos serviços realizados em seus veículos como evidência para as oficinas.

### Uso específico da permissão:

1. **Envio de fotos de serviços**: Os clientes podem tirar fotos ou selecionar imagens da galeria para documentar visualmente os serviços que desejam solicitar às oficinas.

2. **Evidência para oficinas**: As fotos são enviadas para as oficinas como parte do processo de agendamento, permitindo que elas visualizem e avaliem o trabalho necessário antes de iniciar o serviço.

3. **Funcionalidade essencial**: Esta funcionalidade é **essencial** para o funcionamento principal do app, que é conectar clientes com oficinas para serviços automotivos.

### Quando a permissão é solicitada?

- A permissão é solicitada **apenas quando o usuário tenta**:
  - Tirar uma foto usando a câmera do dispositivo
  - Selecionar uma imagem da galeria para enviar como evidência do serviço

- A permissão **NÃO é solicitada**:
  - Ao abrir o app
  - Ao navegar pelas telas
  - Ao visualizar informações de oficinas
  - Em qualquer outro momento que não seja relacionado ao envio de fotos

### Limitação de uso:

- A permissão é usada **exclusivamente** para a funcionalidade de envio de fotos de serviços
- As imagens são enviadas apenas para as oficinas relacionadas ao agendamento do cliente
- Não há compartilhamento de imagens com terceiros
- As imagens são armazenadas temporariamente apenas durante o processo de upload

### Versão do Android:

- Esta permissão é necessária apenas para **Android 13 (API 33) e superior**
- Para versões anteriores do Android, o app usa `READ_EXTERNAL_STORAGE` (com `maxSdkVersion="32"`)

---

## Texto para o formulário do Google Play Console:

**Pergunta: Por que seu app precisa da permissão READ_MEDIA_IMAGES?**

**Resposta:**

O app MECA Cliente precisa da permissão READ_MEDIA_IMAGES para permitir que os clientes enviem fotos dos serviços realizados em seus veículos como evidência para as oficinas. Esta funcionalidade é essencial para o funcionamento principal do app, que é conectar clientes com oficinas para serviços automotivos.

A permissão é solicitada apenas quando o usuário tenta tirar uma foto ou selecionar uma imagem da galeria para enviar como evidência do serviço. As imagens são usadas exclusivamente para documentar visualmente os serviços solicitados e são enviadas apenas para as oficinas relacionadas ao agendamento do cliente. Não há compartilhamento de imagens com terceiros.

Esta permissão é necessária apenas para Android 13 (API 33) e superior. Para versões anteriores do Android, o app usa READ_EXTERNAL_STORAGE.

