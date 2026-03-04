# MECA Cliente — v2.2.2 (Build 222)

---

## Notes for Reviewers (English)

This update resolves a critical bug in the payment flow and introduces a new pre-purchase inspection service, along with general stability and UX improvements.

**Pre-Purchase Service (Pré-Compra):**
The app now includes a new "Pre-Purchase Inspection" service where customers can request a detailed vehicle inspection report before purchasing a used car. This service uses a vehicle identification workflow (brand, model, year) without requiring the vehicle to be previously registered in the system.

**Payment Fix:**
A critical navigation bug was fixed where the payment screen would remain visible after a successful credit card payment. The root cause was a route management conflict between the in-app notification overlay (Flushbar) and the Flutter Navigator stack. The Flushbar library pushes a `PopupRoute` on the navigation stack, and our `Navigator.pop` was dismissing the overlay instead of the payment screen. This has been resolved by explicitly dismissing the overlay before triggering navigation.

**UI/UX:**
- Payment summary screen no longer shows internal split details (workshop net amount / MECA fee) — customers now only see the total amount to pay.
- Pre-purchase orders now appear in "My Bookings" (tab 2) alongside regular bookings, with a clear "Pre-Purchase" badge to differentiate them.

No third-party SDKs were added or changed. No new permissions are required.

---

## What's New — v2.2.2

### English

**Bug Fixes**
- Fixed: Payment screen stayed visible after successful credit card payment (navigation bug)
- Fixed: Pre-purchase payment endpoint rejected valid payments with status `aguardando_pagamento`
- Fixed: Payment summary was showing internal split details (workshop fee vs. MECA fee) instead of total amount only

**New Features**
- Pre-purchase inspection bookings now appear in "My Bookings" alongside regular service bookings
- Pre-purchase items display a "Pre-Purchase" badge for easy identification
- Tapping a pre-purchase booking opens the detailed inspection view with PDF report access

**Improvements**
- Payment flow is more reliable: overlay notifications are properly dismissed before screen navigation
- Booking list now loads pre-purchase and regular bookings in parallel for faster display

---

### Português (Brasil)

**Correções de Bugs**
- Corrigido: Tela de pagamento permanecia visível após pagamento aprovado com cartão de crédito (bug de navegação)
- Corrigido: Pagamento de pré-compra rejeitava transações válidas com status `aguardando_pagamento`
- Corrigido: Resumo de pagamento exibia detalhes internos de divisão (valor da oficina / taxa MECA) em vez de mostrar apenas o valor total a pagar

**Novas Funcionalidades**
- Agendamentos de pré-compra agora aparecem em "Meus Agendamentos" junto com os serviços regulares
- Itens de pré-compra exibem um badge "Pré-Compra" para fácil identificação
- Ao tocar em um agendamento de pré-compra, abre a tela de detalhes com acesso ao laudo em PDF

**Melhorias**
- Fluxo de pagamento mais confiável: notificações overlay são descartadas corretamente antes da navegação
- Lista de agendamentos carrega pré-compras e agendamentos regulares em paralelo para exibição mais rápida
