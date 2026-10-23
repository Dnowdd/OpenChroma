# Plugins de dispositivos

Um plugin é um arquivo `.js` que ensina o OpenChroma a falar com um
dispositivo USB HID: quais modelos ele atende, quantos LEDs eles têm e quais
bytes mandar para pintar cada um. Os plugins têm prioridade sobre os drivers
embutidos: quando um plugin declara um modelo, os drivers embutidos nem abrem
aquele dispositivo.

- Plugins que vêm com o app: [`assets/plugins`](../assets/plugins).
- Seus plugins: `%APPDATA%\OpenChroma\plugins` (Configurações › Plugins de
  dispositivos › Abrir pasta). Um arquivo com o mesmo nome de um plugin
  incluído substitui o incluído. O app recarrega sozinho quando um `.js` da
  pasta é salvo, criado ou apagado (ou pelo botão de recarregar, ao lado de
  "Abrir pasta"): só os dispositivos daquele plugin reiniciam, e um modelo
  que um plugin passa a atender sai dos drivers embutidos na hora.

Cada dispositivo roda o seu plugin numa instância separada do QuickJS
(JavaScript ES2020), sem acesso a arquivos, rede ou outros dispositivos.

## Exemplo

```js
plugin({
  name: 'Mouse Exemplo',
  vendor: 'Exemplo',
  type: 'mouse',
  devices: [{ vid: 0x1234, pid: 0x5678, name: 'Exemplo M1' }],
  endpoint: { interface: 1, usagePage: 0xFF00 },
  zones: [
    { name: 'Logo', leds: 1 },
    { name: 'Roda', leds: 1 }
  ],

  start: function (dev) {
    dev.write([0x01, 0x10]); // modo controlado pelo software
  },

  render: function (dev, colors) {
    // colors: [r, g, b] de cada LED, na ordem das zonas
    dev.write([0x02].concat(colors));
  },

  stop: function (dev) {
    dev.write([0x01, 0x00]); // devolve o controle ao mouse
  }
});
```

## A descrição

| Campo | Obrigatório | O que é |
|---|---|---|
| `name` | sim | Nome do plugin. |
| `vendor` | não | Fabricante. |
| `type` | não | `keyboard`, `mouse`, `headset`, `mousepad`, `motherboard`, `gpu`, `ram`, `ledstrip`, `cooler`, `gamepad`, `speakers`, `microphone`, `case` ou `other`. Define o desenho do dispositivo no app. |
| `devices` | sim | Lista de `{ vid, pid, name }` atendidos. |
| `endpoint` | não | Qual coleção HID abrir: um objeto com os campos que precisam bater (`interface`, `usagePage`, `usage`, `collection`) ou uma função `(endpoints) => índice` (-1 recusa). Sem ele, a primeira coleção. |
| `zones` | sim | Grupos de LEDs, na ordem das cores: `{ name, leds }` (uma fileira) ou `{ name, width, height, map }` (matriz; `map` tem `width × height` posições com o índice do LED na zona ou `-1`). Pode ser uma função `(dev) => zonas`, chamada depois do `start`. |
| `modes` | não | Efeitos do próprio hardware: `[{ id, name, speed, brightness, colors, random }]`. O usuário escolhe na tela do dispositivo. Só `id` e `name` são obrigatórios; os outros campos mostram controles para o efeito (veja [Efeitos do hardware](#efeitos-do-hardware)). Também pode ser uma função. |
| `settings` | não | Opções mostradas no app: `{ nome: { label, type, default, min, max, values, description } }`, com `type` `number`, `boolean`, `color` ou `combobox`. |
| `fps` | não | Quadros por segundo de `render` (padrão 30, máximo 60). |
| `pollMs` | não | Intervalo de `poll` em milissegundos (padrão 1000). |

## As funções

Todas recebem `dev` primeiro; `this` é o próprio objeto do plugin, então dá
para guardar estado nele (`this.ultimaCor = ...`).

| Função | Quando |
|---|---|
| `start(dev)` | Ao abrir o dispositivo. Retornar `false` recusa o dispositivo. |
| `render(dev, colors)` | A cada quadro, com as cores de todos os LEDs (`[r, g, b, r, g, b, ...]`, 0 a 255, já com o brilho aplicado). O app só chama quando as cores mudam. |
| `mode(dev, id, opções)` | O usuário escolheu um efeito do hardware (`id` de `modes`) ou mudou as opções dele, ou `null` para voltar às cores do app. |
| `poll(dev)` | A cada `pollMs`: ler bateria, estado etc. |
| `settingChanged(dev, nome, valor)` | O usuário mudou uma opção. |
| `stop(dev)` | O app vai fechar ou o dispositivo foi desativado. |

## Efeitos do hardware

Cada efeito em `modes` pode declarar o que o usuário ajusta:

| Campo | O que é |
|---|---|
| `speed` | `{ min, max, default }`: `min` é o mais lento e `max` o mais rápido, mesmo que `min` seja o número maior (como em aparelhos que medem a velocidade em tempo por ciclo). |
| `brightness` | `{ min, max, default }`, do mais fraco ao mais forte. |
| `colors` | Quantas cores o efeito usa (`1`), ou `{ min, max, default: ['#ff0000', ...] }` para deixar o usuário escolher quantas. Sem `default`, as cores começam brancas. |
| `random` | `true` se o aparelho também sabe escolher as cores sozinho (arco-íris). Começa ligado. |

`mode(dev, id, opções)` recebe os valores escolhidos (ou os `default`):
`{ speed, brightness, colors: [[r, g, b], ...], random }`, só com os campos
que o efeito declarou. A função é chamada de novo a cada mudança, então
mande o comando completo do efeito.

```js
modes: [
  { id: 0x02, name: 'Respirar', speed: { min: 0, max: 4, default: 2 }, colors: 1, random: true },
  { id: 0x00, name: 'Desligado' }
],

mode: function (dev, id, opcoes) {
  if (id === null) return; // o próximo render manda as cores do app
  var cor = opcoes.random ? [0, 0, 0] : opcoes.colors[0];
  dev.write([0x01, id, opcoes.speed, opcoes.random ? 1 : 0].concat(cor));
}
```

## O objeto `dev`

| Membro | O que faz |
|---|---|
| `dev.info` | `{ vid, pid, serial, product, manufacturer, name }`. |
| `dev.write(bytes)` | Relatório de saída; `bytes[0]` é o ID do relatório (0 se o dispositivo não usa IDs). Completa com zeros até o tamanho do relatório. Retorna os bytes escritos ou -1. |
| `dev.read(tamanho, timeoutMs)` | Próximo relatório de entrada (ID 0 removido), ou `[]` se nada chegar a tempo (padrão 100 ms). |
| `dev.sendFeature(bytes)` | Relatório de feature; `bytes[0]` é o ID. |
| `dev.getFeature(id, tamanho)` | Lê um relatório de feature. |
| `dev.getInputReport(id, tamanho)` | Lê um relatório de entrada pelo canal de controle. |
| `dev.clearInput()` | Descarta relatórios de entrada acumulados. |
| `dev.endpoints()` | Todas as coleções HID do dispositivo. |
| `dev.useEndpoint(filtro)` | Passa a usar outra coleção (ex.: um mouse com comandos curtos numa e longos noutra). |
| `dev.sleep(ms)` | Espera. |
| `dev.log(...)` | Mensagem no log do dispositivo. |
| `dev.setting(nome)` | Valor atual de uma opção. |
| `dev.setBattery(percentual, carregando)` | Mostra a bateria no app. |

## Boas práticas

- **Não grave na memória do dispositivo a cada quadro.** Muitos dispositivos
  salvam a cor quando recebem o comando de modo; se for o caso, use o modo
  "sem salvar" do aparelho (como no `logitech-g403-hero.js`) ou limite a taxa
  (como no `royuan-keyboard.js`).
- Em `stop`, deixe o dispositivo num estado sensato: apagado ou de volta ao
  efeito salvo nele.
- Plugins baseados em código do OpenRGB continuam GPL-2.0-or-later: mantenha
  o crédito e a linha `SPDX-License-Identifier` no topo, como nos incluídos.

## Testar

`test/plugins_test.dart` roda os plugins incluídos contra um dispositivo falso
e confere os bytes que eles mandam. Para um plugin novo, siga o mesmo modelo:

```powershell
flutter build windows --release
$env:PATH = "$PWD\build\windows\x64\runner\Release;$env:PATH"
$env:OC_PLUGIN_TEST = "1"
flutter test test\plugins_test.dart
```
