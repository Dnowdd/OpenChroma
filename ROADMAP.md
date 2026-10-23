# O que falta no OpenChroma

Lista do que ainda não existe ou está incompleto, mais ou menos em ordem de
prioridade. Atualize quando algo for feito.

## 1. Drivers

Os drivers vêm do OpenRGB, compilados dentro do app (`windows/drivers` e
`third_party/openrgb`), mais os plugins JavaScript do OpenChroma
([docs/PLUGINS.md](docs/PLUGINS.md)). O OpenChroma não depende nem conversa
com o SignalRGB ou com o OpenRGB instalado.

- [x] Núcleo nativo com os drivers do OpenRGB e uma API nossa
      (`oc_drivers.dll`).
- [x] Remover tudo do SignalRGB.
- [x] Licença GPL-2.0-or-later.
- [x] Formato de plugin próprio em JavaScript, com prioridade sobre os
      drivers embutidos.
- [x] Primeiros plugins migrados e melhorados: DualShock 4 (com bateria),
      teclados ROYUAN (com limite de escrita) e Logitech G403 HERO (sem gravar
      na memória do mouse).
- [x] Bateria de dispositivos sem fio (plugins).
- [x] Escolher um efeito do próprio hardware em vez das cores do app.
- [x] Ajustar velocidade, brilho, direção e cores dos efeitos do hardware
      (drivers embutidos e plugins).
- [x] Rotina de atualização do OpenRGB (`scripts/update-openrgb.ps1`).
- [x] Recarregar plugins sem reiniciar o app (sozinho ao salvar o `.js`).
- [x] Teclado ROYUAN com cor ao vivo, sem piscar (testado no Attack Shark
      K86, a 30 atualizações por segundo).
- [x] Bateria que o Windows já conhece (Bluetooth): aparece no dispositivo
      quando ele também tem luz e numa lista "Outros sem fio" quando não tem.
- [x] Plugin novo: Attack Shark X11 (luz, efeitos do mouse e bateria, no
      cabo e pelo receptor 2.4 GHz), protocolo aprendido do app oficial e
      testado no mouse.
- [ ] Migrar mais drivers populares para plugins (Razer, Corsair, SteelSeries,
      HyperX), principalmente para ter a bateria dos modelos sem fio.
      **Precisa do aparelho para testar**: os drivers embutidos já acendem
      esses modelos, e um plugin sem teste pode piorar o que funciona.
- [ ] Teclado ROYUAN tecla por tecla: o único comando por tecla conhecido
      grava uma imagem na memória do teclado. **Precisa do app oficial do
      teclado** (não do mouse) para descobrir um modo ao vivo.

## 2. Dispositivos que ainda não funcionam

- [ ] Drivers de rede que ficaram de fora: Philips Hue, Nanoleaf (precisam de
      TLS/mDNS) e E1.31 (a `libe131` é Apache-2.0, incompatível com a GPL-2.0).
      Dá para reescrever o E1.31, que é um protocolo simples.
- [ ] Teclados QMK/VIA (o driver do OpenRGB depende do Qt).
- [ ] Telas LCD de water coolers e gabinetes.

## 3. Iluminação

- [ ] Efeito que copia as cores da tela (ambilight).
- [ ] Editor visual de efeitos `.ocfx`, sem precisar escrever JSON.
- [ ] Rotação no layout (hoje só posição e tamanho).
- [ ] Biblioteca de componentes ARGB: escolher "fan de 120 mm com 16 LEDs"
      em vez de digitar a quantidade de LEDs.
- [x] Trocar de perfil sozinho quando um jogo ou programa abre (e voltar
      quando ele fecha).
- [ ] Mais efeitos próprios (todos os efeitos do OpenChroma são exclusivos;
      nunca copiar efeitos de outros apps).

## 4. Ventoinhas e sensores

- [ ] Mais chips de placa-mãe além dos ITE (Nuvoton, Fintek).
- [ ] Ventoinhas de placas de vídeo AMD e Intel (hoje só NVIDIA).
- [ ] Usar a temperatura do líquido do water cooler nas curvas.

## 5. App

- [ ] **Atualização automática**: avisar e baixar a versão nova do GitHub.
- [ ] **Assinatura de código** do `.exe` e do instalador, para o Windows não
      mostrar o aviso do SmartScreen ("o Windows protegeu seu computador").
- [ ] App em inglês (hoje só português).
- [ ] Build automático no GitHub Actions: compilar, rodar os testes e anexar
      os arquivos na release ao criar uma tag.
- [ ] Versão para Windows ARM64.
- [ ] Relatório de erros opcional (hoje os crashes ficam só em
      `%APPDATA%\OpenChroma\crash.log`).
