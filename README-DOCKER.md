# Build 100% Containerizado do APK Flutter

Este projeto está pronto para build 100% dentro de um container Docker, sem dependências externas.

## Pré-requisitos
- Docker instalado
- Dependências locais (mega_commons, mega_features, etc) devem estar no mesmo diretório pai deste projeto

## Como gerar o APK

1. **Build da imagem Docker:**

   ```sh
   docker build -t meca-app-cliente-apk .
   ```

2. **Rodar o container para gerar o APK:**

   ```sh
   docker run --rm -v $(pwd)/output:/output meca-app-cliente-apk
   ```
   - O APK gerado estará disponível em `./output/app-release.apk` após o comando acima.

   > No Windows (cmd):
   >
   > ```cmd
   > docker run --rm -v %cd%\output:/output meca-app-cliente-apk
   > ```

3. **O APK estará disponível em `output/app-release.apk` no seu host.**

## Observações
- Todo o build ocorre dentro do container, garantindo ambiente limpo e reprodutível.
- Se alterar dependências locais, rode o build novamente.
- Não é necessário Docker Compose.

