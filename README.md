# 📱 MECA App Cliente

Aplicativo móvel Flutter para clientes da plataforma MECA - marketplace de serviços automotivos.

## 🎯 Funcionalidades

- **Autenticação:** Login/Cadastro, Google, Apple
- **Gestão de Veículos:** CRUD completo de veículos
- **Busca de Serviços:** Busca por proximidade e categoria
- **Detalhes da Oficina:** Fotos, serviços, horários, avaliações
- **Agendamento:** Calendário, disponibilidade, confirmação
- **Meus Agendamentos:** Histórico, status, detalhes
- **Pagamento:** Integração PagBank
- **Avaliações:** Sistema de reviews pós-serviço
- **Notificações:** Push notifications

## 🛠️ Tecnologias

- **Framework:** Flutter 3.24+
- **Linguagem:** Dart
- **Estado:** Provider
- **HTTP:** Dio
- **Storage:** SharedPreferences
- **Maps:** Google Maps
- **Auth:** Firebase Auth
- **Notifications:** Firebase Cloud Messaging

## 🚀 Como Executar

### Pré-requisitos
- Flutter SDK 3.24+
- Dart SDK
- Android Studio / VS Code
- Emulador ou dispositivo físico

### Instalação
```bash
# Clone o repositório
git clone https://github.com/mecaDevs0/meca-app-cliente.git
cd meca-app-cliente

# Instale as dependências
flutter pub get

# Execute o app
flutter run
```

### Web
```bash
# Execute na web
flutter run -d web-server --web-port 8081
```

## 📱 Telas Principais

### Autenticação
- **Login:** Email/senha, Google, Apple
- **Cadastro:** Formulário completo
- **Esqueci Senha:** Recuperação por email

### Home
- **Busca:** Campo de busca principal
- **Ações Rápidas:** Cards de navegação
- **Serviços Populares:** Lista de serviços

### Veículos
- **Lista:** Meus veículos cadastrados
- **Adicionar:** Formulário de cadastro
- **Editar:** Atualizar informações
- **Remover:** Confirmação e exclusão

### Busca
- **Resultados:** Lista de oficinas
- **Filtros:** Localização, preço, avaliação
- **Mapa:** Visualização no mapa

### Oficina
- **Detalhes:** Informações completas
- **Serviços:** Lista de serviços oferecidos
- **Avaliações:** Reviews dos clientes
- **Fotos:** Galeria de imagens

### Agendamento
- **Calendário:** Seleção de data
- **Horários:** Disponibilidade
- **Veículo:** Seleção do veículo
- **Confirmação:** Resumo do agendamento

### Meus Agendamentos
- **Lista:** Histórico completo
- **Status:** Pendente, confirmado, finalizado
- **Detalhes:** Informações do serviço
- **Cancelar:** Opção de cancelamento

### Pagamento
- **PagBank:** Integração completa
- **Confirmação:** Resumo da compra
- **Histórico:** Transações anteriores

## 🎨 Design

### Cores
- **Primária:** Verde MECA (#00c977)
- **Secundária:** Azul (#252940)
- **Fundo:** Branco (#FFFFFF)
- **Texto:** Cinza escuro (#334155)

### Componentes
- **Botões:** Bordas arredondadas (25px)
- **Cards:** Sombras suaves, bordas arredondadas
- **Inputs:** Bordas arredondadas (20px)
- **Ícones:** Lucide Icons

### Responsividade
- **Mobile First:** Otimizado para smartphones
- **Tablet:** Layout adaptativo
- **Web:** Interface web responsiva

## 🔧 Estrutura

```
lib/
├── main.dart                 # Entry point
├── screens/                  # Telas do app
│   ├── auth/                # Autenticação
│   ├── home/                # Home
│   ├── vehicles/            # Veículos
│   ├── search/              # Busca
│   ├── workshop/            # Oficina
│   ├── booking/             # Agendamento
│   └── profile/             # Perfil
├── providers/               # Gerenciamento de estado
├── models/                  # Modelos de dados
├── services/                # Serviços (API)
├── utils/                   # Utilitários
└── widgets/                 # Widgets reutilizáveis
```

## 🌐 Integração API

### Endpoints Principais
```dart
// Autenticação
POST /auth/customer/token
POST /auth/customer/register

// Veículos
GET /store/my-vehicles
POST /store/my-vehicles
PUT /store/my-vehicles/:id
DELETE /store/my-vehicles/:id

// Serviços
GET /store/services
GET /store/services/search

// Agendamentos
POST /store/book-service
GET /store/my-bookings
PUT /store/bookings/:id/cancel
```

## 🔐 Autenticação

### Login
```dart
final authProvider = Provider.of<AuthProvider>(context);
await authProvider.login(email, password);
```

### Google Sign In
```dart
await authProvider.signInWithGoogle();
```

### Apple Sign In
```dart
await authProvider.signInWithApple();
```

## 📍 Localização

### Geolocalização
```dart
// Buscar oficinas próximas
final location = await Geolocator.getCurrentPosition();
final nearbyWorkshops = await apiService.searchNearby(
  latitude: location.latitude,
  longitude: location.longitude,
  radius: 10.0
);
```

## 🔔 Notificações

### FCM Setup
```dart
// Configurar FCM
await FirebaseMessaging.instance.requestPermission();
final token = await FirebaseMessaging.instance.getToken();
```

### Receber Notificações
```dart
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  // Mostrar notificação local
});
```

## 🚀 Build

### Debug
```bash
flutter run --debug
```

### Release
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

## 📦 Deploy

### Google Play Store
```bash
flutter build appbundle --release
# Upload para Play Console
```

### Apple App Store
```bash
flutter build ios --release
# Upload via Xcode
```

### Web
```bash
flutter build web --release
# Deploy para servidor web
```

## 📝 Licença

© 2024 MECA - Todos os direitos reservados.

## 👥 Equipe

Desenvolvido pela equipe MECA Devs.