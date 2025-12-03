# 🔧 Correções para Publicação nas Lojas - MECA Cliente v1.7.5

## ✅ Problemas Corrigidos

### 1. ✅ Google Play Store - Permissão READ_MEDIA_IMAGES

**Problema:**
- Rejeição: "Política de permissões de acesso a fotos e vídeos: O uso da permissão não tem relação direta com a finalidade principal do app."

**Correções Aplicadas:**

1. **AndroidManifest.xml:**
   - Adicionado `android:minSdkVersion="33"` na permissão `READ_MEDIA_IMAGES` para deixar claro que é apenas para Android 13+
   - Adicionado comentário explicativo sobre o uso da permissão
   - Mantida a permissão `READ_EXTERNAL_STORAGE` com `maxSdkVersion="32"` para versões anteriores

2. **Arquivo de Declaração Criado:**
   - `GOOGLE_PLAY_PERMISSION_DECLARATION.md` - Contém o texto completo para preencher no formulário do Google Play Console

**Próximos Passos:**
1. Fazer rebuild do AAB com as correções
2. Ao fazer upload no Google Play Console, quando solicitado sobre a permissão `READ_MEDIA_IMAGES`, usar o texto do arquivo `GOOGLE_PLAY_PERMISSION_DECLARATION.md`

---

### 2. ✅ Apple App Store - Documentação de Criptografia

**Problema:**
- Aviso: "Especifique seu uso de criptografia no Xcode adicionando a chave O aplicativo usa criptografia não isenta no arquivo Info.plist"

**Correção Aplicada:**

1. **Info.plist:**
   - Adicionada a chave `ITSAppUsesNonExemptEncryption` com valor `false`
   - Isso indica que o app usa apenas criptografia padrão do sistema operacional (HTTPS, TLS, etc.)

**Arquivo Modificado:**
- `ios/Runner/Info.plist`

**Próximos Passos:**
1. Fazer rebuild do IPA com a correção
2. Fazer upload novamente no App Store Connect
3. O aviso sobre criptografia deve desaparecer

---

### 3. ⚠️ Apple App Store - Build Number Não Aparecendo

**Problema:**
- Build number não está aparecendo na loja mesmo após fazer build archive e distribute app no Xcode

**Verificações Realizadas:**
- ✅ `CFBundleVersion` está configurado como `$(FLUTTER_BUILD_NUMBER)` no Info.plist
- ✅ `CURRENT_PROJECT_VERSION` está configurado como `$(FLUTTER_BUILD_NUMBER)` no project.pbxproj
- ✅ `VERSIONING_SYSTEM` está configurado como `apple-generic`

**Possíveis Causas:**
1. O build pode não ter sido processado completamente no App Store Connect
2. Pode ser necessário aguardar alguns minutos para o processamento
3. Verificar se o build foi enviado corretamente via Xcode ou Transporter

**Solução Recomendada:**
1. Verificar no App Store Connect se o build está em "Processando"
2. Aguardar o processamento completo (pode levar 10-30 minutos)
3. Se o problema persistir, verificar se o build foi feito com a versão correta:
   - Versão: 1.7.5
   - Build: 159

**Para verificar a versão do build:**
```bash
cd meca-app-cliente
flutter build ipa --release
# Verificar no output se mostra:
# Version Number: 1.7.5
# Build Number: 159
```

---

## 📝 Arquivos Modificados

1. ✅ `android/app/src/main/AndroidManifest.xml`
   - Adicionado `android:minSdkVersion="33"` na permissão `READ_MEDIA_IMAGES`
   - Adicionado comentário explicativo

2. ✅ `ios/Runner/Info.plist`
   - Adicionada chave `ITSAppUsesNonExemptEncryption` com valor `false`

3. ✅ `GOOGLE_PLAY_PERMISSION_DECLARATION.md` (novo)
   - Texto completo para preencher no Google Play Console

---

## 🚀 Próximos Passos

### Para Google Play Store:

1. **Rebuild do AAB:**
   ```bash
   cd meca-app-cliente
   flutter clean
   flutter pub get
   flutter build appbundle --release
   ```

2. **Fazer upload do novo AAB:**
   - Localização: `build/app/outputs/bundle/release/app-release.aab`

3. **Preencher declaração de permissão:**
   - Quando solicitado sobre `READ_MEDIA_IMAGES`, usar o texto de `GOOGLE_PLAY_PERMISSION_DECLARATION.md`

### Para Apple App Store:

1. **Rebuild do IPA:**
   ```bash
   cd meca-app-cliente
   flutter clean
   flutter pub get
   flutter build ipa --release
   ```

2. **Fazer upload do novo IPA:**
   - Via Xcode: Archive → Distribute App
   - Ou via Transporter: `build/ios/ipa/*.ipa`

3. **Verificar processamento:**
   - Aguardar processamento completo no App Store Connect
   - Verificar se o build number aparece após processamento

---

## ✅ Status das Correções

- ✅ Google Play Store - Permissão corrigida e documentada
- ✅ Apple App Store - Criptografia corrigida
- ⚠️ Apple App Store - Build number (aguardar processamento)

