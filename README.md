# OpenChroma

Controle o PC inteiro de um lugar só: a iluminação RGB de todos os
dispositivos, as ventoinhas, a temperatura e a saúde do sistema. Gratuito,
open source e feito para Windows.

![Início](docs/screenshots/home.png)

## O que ele faz

**Iluminação**
- 25 efeitos próprios: Aurora, Plasma, Lava, Fogueira, Chuva Digital, Céu
  Estrelado, Arco-íris, Cor Sólida, Batimento, Sirene e mais. Cada um tem
  ajustes de cor e velocidade.
- Efeitos que reagem ao som do PC ou do microfone (Espectro, Equalizador
  Neon, Batida, Onda Sonora…).
- Layout: posicione cada dispositivo numa tela e o efeito "passa" por eles
  como se fossem um painel só.
- Perfis (Jogo, Trabalho, Noite, Desligado) que trocam efeito e brilho com um
  clique. Clique com o botão direito num perfil para salvar a iluminação atual
  nele.
- Luz reativa: os LEDs mostram a temperatura da CPU ou da GPU, do azul
  (frio) ao vermelho (quente).
- Importe efeitos `.ocfx` (veja abaixo) ou páginas HTML com canvas.

**Ventoinhas**
- Lê e controla as ventoinhas da placa-mãe (chips ITE) e da placa de vídeo
  NVIDIA, com perfis Silencioso, Equilibrado e Turbo ou uma curva sua.
- Marca qual ventoinha é a bomba do water cooler, para ela nunca parar.

**Desempenho**
- Monitor em tempo real: uso e temperatura de CPU e GPU, memória, discos,
  rede e os processos que mais pesam.
- Diagnóstico: testes de estresse de CPU, memória, GPU e disco que conferem
  os resultados (não só esquentam o PC), inventário de hardware, histórico de
  telas azuis e recomendações.

**Avisos**
- Notificação do Windows quando algo esquenta demais, a memória ou o disco
  enchem, ou a bomba do water cooler para. Funciona com o app na bandeja.
- Opcional: os LEDs piscam em vermelho junto com o aviso.

**Assistente de IA**
- Pergunte sobre o seu PC ("por que tá lento?", "o que esquenta a GPU?"): o
  assistente responde com as leituras reais da máquina.
- Peça um efeito ("cria um efeito azul calmo") e aplique com um clique.
- Explica o resultado do diagnóstico e sugere o que fazer.
- Funciona com a sua chave da Anthropic (Claude), da OpenAI (GPT) ou de
  qualquer serviço compatível com a API da OpenAI (OpenRouter, Groq, Ollama,
  LM Studio…). A lista de modelos é buscada no provedor e se atualiza
  sozinha.

**No dia a dia**
- Fecha para a bandeja e continua cuidando das luzes e ventoinhas.
- Pode abrir junto com o Windows, inclusive como administrador sem pedir UAC
  toda vez.

| Efeitos | Dispositivos |
|---|---|
| ![Efeitos](docs/screenshots/effects.png) | ![Dispositivos](docs/screenshots/devices.png) |

## Instalação

Baixe a versão mais recente em
[Releases](https://github.com/Dnowdd/OpenChroma/releases):

- **`OpenChroma-x.y.z-setup.exe`**: o instalador. Não pede administrador
  (instala para o seu usuário) e instala o Microsoft WebView2 se faltar.
- **`OpenChroma-x.y.z-portable.zip`**: extraia numa pasta e abra
  `openchroma.exe`. Não instala nada.

Requisitos:

- Windows 10 (1809 ou mais novo) ou Windows 11, 64 bits.
- [Microsoft WebView2](https://developer.microsoft.com/microsoft-edge/webview2/)
  para os efeitos. Já vem no Windows 11; o instalador cuida disso no
  Windows 10.
- Opcional: o driver [PawnIO](https://pawnio.eu) para ler a temperatura da
  CPU e controlar as ventoinhas da placa-mãe. Essas duas funções também
  precisam do modo administrador (tem um botão para isso no app).

Feche outros programas de RGB (iCUE, G HUB, RGB Fusion, OpenRGB…) antes de
usar: dois programas escrevendo nos mesmos LEDs fazem as cores piscarem. O
OpenChroma avisa quando encontra um deles aberto.

## Dispositivos compatíveis

Os drivers do OpenChroma vêm do código aberto do
[OpenRGB](https://gitlab.com/CalcProgrammer1/OpenRGB), compilado dentro do
próprio app: mais de mil teclados, mouses, headsets, mousepads, placas-mãe,
controladoras ARGB, water coolers, memórias RAM e placas de vídeo de dezenas
de marcas (ASUS, Corsair, Logitech, Razer, SteelSeries, HyperX, Gigabyte, MSI,
NZXT, Lian Li, Cooler Master…). Não é preciso instalar o OpenRGB nem nenhum
outro programa.

- Memórias RAM e placas de vídeo com RGB usam o SMBus, que precisa do modo
  administrador e do driver [PawnIO](https://pawnio.eu).
- Conectores ARGB da placa-mãe: informe quantos LEDs estão ligados em cada um
  na tela Dispositivos.

## Efeitos `.ocfx`

Um efeito é um arquivo JSON com camadas desenhadas de baixo para cima:

```json
{
  "openchroma": 1,
  "name": "Oceano Calmo",
  "description": "Azuis indo e vindo devagar.",
  "background": "#000814",
  "params": {
    "speed": { "label": "Velocidade", "type": "number", "min": 0, "max": 100, "default": 25 },
    "color": { "label": "Cor", "type": "color", "default": "#38BDF8" }
  },
  "layers": [
    { "type": "gradient", "colors": ["#001D3D", "#003566", "#000814"], "angle": 20, "speed": "$speed" },
    { "type": "wave", "color": "$color", "amplitude": 0.2, "thickness": 0.25, "speed": "$speed", "blend": "screen" }
  ]
}
```

Camadas: `solid`, `gradient`, `spectrum`, `pulse`, `wave`, `sweep`, `rings`,
`sparkle`, `plasma`, `noise`, `fire`, `rain`, `stars`, `heartbeat`, `strobe`
e, para áudio, `bars`, `meter`, `ripple` e `flash`. Um valor `"$nome"` usa o
parâmetro `nome`; `"@bass"`, `"@mid"`, `"@treble"`, `"@level"` e `"@beat"`
usam o som em tempo real. Os efeitos que vêm com o app estão em
[`assets/effects`](assets/effects) e servem de exemplo.

## Licença

O OpenChroma é software livre sob a GPL-2.0-or-later ([LICENSE](LICENSE)).
Os drivers vêm do OpenRGB; o código de terceiros incluído e suas licenças
estão em [THIRD_PARTY.md](THIRD_PARTY.md).

## Privacidade

- Nada é enviado a lugar nenhum por padrão. Não há telemetria.
- A chave de API do assistente fica só neste PC, criptografada para o seu
  usuário do Windows (DPAPI), e só vai para o provedor que você escolheu,
  junto com as leituras do PC usadas para responder.
- Configurações ficam em `%APPDATA%\OpenChroma`.

## Para desenvolvedores

Precisa do [Flutter](https://docs.flutter.dev/get-started/install/windows)
3.47 ou mais novo e do Visual Studio 2022 (ou mais novo) com a carga
"Desenvolvimento para desktop com C++".

```powershell
flutter pub get
flutter run -d windows        # rodar em modo debug
flutter test                  # testes
```

Para gerar o `.exe`, o instalador e publicar uma versão no GitHub, veja
[docs/BUILDING.md](docs/BUILDING.md). O que ainda falta fazer está no
[ROADMAP](ROADMAP.md).

### Como funciona

```
lib/src/
  engine/        motor: layout, amostra o efeito em cada LED e manda para os
                 drivers; perfis, luz reativa e o piscar dos avisos
  drivers/       ponte com os drivers nativos (oc_drivers.dll)
  effects/       biblioteca de efeitos, o renderizador .ocfx e o WebView2
                 que desenha o efeito num canvas de 320x200
  fans/          curvas e controle das ventoinhas
  monitor/       leituras do sistema (lado nativo em windows/runner)
  checkup/       diagnóstico e análise de telas azuis
  alerts/        avisos e notificações
  ai/            assistente: provedores, chaves (DPAPI) e contexto do PC
  ui/            as telas
windows/runner/  código nativo: monitor, ventoinhas (PawnIO/NvAPI), testes
                 de estresse, captura de áudio, bandeja e elevação
windows/drivers/ oc_drivers.dll: os drivers do OpenRGB com a API C do
                 OpenChroma (oc_drivers.cpp)
third_party/openrgb/  cópia do código do OpenRGB usada pelos drivers
```

O efeito roda numa página (WebView2) que desenha num canvas; a cada ~33 ms o
quadro volta para o app, que calcula a cor de cada LED pela posição do
dispositivo no layout e entrega para o driver, que escreve no hardware na
sua própria thread.

Os módulos PawnIO em `assets/pawnio` são distribuídos sob a LGPL 2.1 (veja
`assets/pawnio/COPYING.txt`).
