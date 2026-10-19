# O que falta no OpenChroma

Lista do que ainda não existe ou está incompleto, mais ou menos em ordem de
prioridade. Atualize quando algo for feito.

## 1. Drivers de dispositivo próprios (prioridade máxima)

Hoje os LEDs dos dispositivos só acendem num PC que tem o SignalRGB
instalado, porque o OpenChroma usa os drivers JavaScript dele. Isso vai sair:
o OpenChroma não deve depender nem conversar com o SignalRGB (código sem
licença, de uma empresa privada) nem precisar do OpenRGB instalado.

O plano:

- [ ] **Formato de driver próprio do OpenChroma**, com uma API nossa (não a
      `device.*` do SignalRGB): como o driver se identifica (VID/PID, tipo,
      zonas e LEDs), como inicia, como recebe as cores e como desliga.
- [ ] **Base de drivers vinda do OpenRGB.** O OpenRGB é open source sob a
      GPL-2.0-or-later (15 arquivos são GPL-2.0-only, incluindo o da placa
      Gigabyte Fusion2), então podemos usar e melhorar o código dele desde que
      o OpenChroma também seja GPL e continue com o código aberto. São cerca
      de 200 famílias de controladores e mais de mil dispositivos HID, além de
      RAM e placas de vídeo por SMBus.
- [ ] Começar pelos dispositivos do PC de desenvolvimento, que já existem no
      OpenRGB: Gigabyte B650M (ITE 048D:5702), teclado Royuan (3151:4015),
      Logitech G403 Hero (046D:C08F) e DualShock 4 (054C:09CC).
- [ ] Remover o carregamento dos plugins do SignalRGB e tudo que aponta para
      ele (`SignalRgbPaths`, o shim `prelude.dart`, traduções de textos dos
      plugins dele).
- [ ] Escolher e adicionar a licença do projeto (`LICENSE`), compatível com a
      GPL-2.0 por causa do código do OpenRGB.
- [ ] Teste automático que roda todos os drivers contra um dispositivo falso
      (como o `test/plugin_compat_test.dart` faz hoje com os plugins antigos).

## 2. Dispositivos que ainda não funcionam

- [ ] **Memória RAM e placas de vídeo com RGB** (SMBus/I2C). Precisa do driver
      PawnIO, que o app já usa para as ventoinhas.
- [ ] **Receptores sem fio** (Logitech Lightspeed, Corsair Slipstream, Razer
      HyperSpeed): um receptor pode ter vários dispositivos atrás dele.
- [ ] Dispositivos USB "crus" (não HID), seriais e de rede (fitas Wi-Fi,
      Philips Hue, Nanoleaf).
- [ ] Telas LCD de water coolers e gabinetes.
- [ ] Dois dispositivos idênticos sem número de série hoje viram um só.

## 3. Iluminação

- [ ] Efeito que copia as cores da tela (ambilight).
- [ ] Editor visual de efeitos `.ocfx`, sem precisar escrever JSON.
- [ ] Rotação no layout (hoje só posição e tamanho).
- [ ] Biblioteca de componentes ARGB: escolher "fan de 120 mm com 16 LEDs"
      em vez de digitar a quantidade de LEDs de cada canal.
- [ ] Trocar de perfil sozinho quando um jogo ou programa abre.
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
