# O que falta no OpenChroma

Lista do que ainda não existe ou está incompleto, mais ou menos em ordem de
prioridade. Atualize quando algo for feito.

## 1. Drivers

Os drivers vêm do OpenRGB, compilados dentro do app (`windows/drivers` e
`third_party/openrgb`). O OpenChroma não depende nem conversa com o SignalRGB
ou com o OpenRGB instalado.

- [x] Núcleo nativo com os drivers do OpenRGB e uma API nossa
      (`oc_drivers.dll`).
- [x] Remover tudo do SignalRGB (plugins, shim da API, traduções, efeitos,
      imagens).
- [x] Licença GPL-2.0-or-later.
- [ ] **Formato de plugin próprio em JavaScript**, para drivers novos ou
      melhorados sem recompilar: como o driver se identifica (VID/PID, tipo,
      zonas e LEDs), inicia, recebe as cores e desliga. O motor já trata os
      dispositivos de forma genérica; falta o runtime (QuickJS) e a API.
- [ ] Migrar aos poucos os drivers mais usados para o formato próprio,
      melhorando o que der (por exemplo, posição real de cada LED do teclado).
- [ ] Mostrar a bateria de mouses e headsets sem fio.
- [ ] Deixar escolher um modo do próprio hardware (os efeitos que o
      dispositivo faz sozinho) em vez de só o modo controlado pelo app.
- [ ] Rotina para atualizar o `third_party/openrgb` com a versão nova do
      OpenRGB (`scripts/update-openrgb.py`) e testar.

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
