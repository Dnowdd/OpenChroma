/// Portuguese (Brazil) texts for content that ships in English: effect
/// names, effect/plugin parameter labels, option values and descriptions.
///
/// Keys are compared case-insensitively. Anything not listed is shown as is.
library;

/// Effect names.
const effectTitles = {
  'rainbow': 'Arco-íris',
  'neon shift': 'Neon em Ciclo',
  'side to side': 'Vai e Vem',
  'solid color': 'Cor Sólida',
  'space': 'Espaço',
  'gradient': 'Degradê',
  'neon storm': 'Tempestade Neon',
  'neon sunset': 'Pôr do Sol Neon',
  'dark matter': 'Matéria Escura',
  'arctic': 'Ártico',
  'electric space': 'Espaço Elétrico',
  'rainbow tunnel': 'Túnel Arco-íris',
  'calm water': 'Águas Calmas',
  'indigo sky': 'Céu Índigo',
};

/// Short effect descriptions, keyed by the original (English) name.
const effectDescriptions = {
  'rainbow': 'O espectro completo de cores correndo pelo setup, sem parar.',
  'neon shift': 'Transição suave entre tons neon, em ciclo contínuo.',
  'side to side': 'Faixas de cor que varrem o setup de um lado ao outro.',
  'solid color': 'Uma única cor, fixa ou respirando, em todos os dispositivos.',
  'space': 'Estrelas passando devagar por um céu escuro.',
  'gradient': 'Degradê de até quatro cores, do jeito que você montar.',
  'neon storm': 'Tempestade neon com chuva, nuvens e relâmpagos.',
  'neon sunset': 'Pôr do sol em tons de rosa, roxo e laranja.',
  'dark matter': 'Formas e raios em rosa e azul sobre um fundo profundo.',
  'arctic': 'Flocos de luz gelada caindo em tons de azul e branco.',
  'electric space': 'Espaço escuro com estrelas e faíscas elétricas.',
  'rainbow tunnel': 'Um túnel de luz colorida correndo pela tela.',
  'calm water': 'Água azul, calma, se mexendo devagar.',
  'indigo sky': 'Um céu índigo ondulando sobre o teclado.',
};

/// Parameters that depend on keyboard input, which this app does not read.
const hiddenParameters = {
  'grid keypress effect',
  'ripple keypress effect',
  'keypress effects',
  'key press effect',
  'tapcolor color',
};

/// Parameter labels, option values and short phrases.
const terms = {
  // Effect parameters
  'speed': 'Velocidade',
  'shift speed': 'Velocidade',
  'rainbow speed': 'Velocidade',
  'animation speed': 'Velocidade',
  'vertical': 'Vertical',
  'direction': 'Direção',
  'side to side': 'Lado a lado',
  'up and down': 'Cima e baixo',
  'all directions': 'Todas as direções',
  'color': 'Cor',
  'color 1': 'Cor 1',
  'color 2': 'Cor 2',
  'color 3': 'Cor 3',
  'color 4': 'Cor 4',
  'first color': 'Primeira cor',
  'second color': 'Segunda cor',
  'rainbow mode': 'Cores aleatórias',
  'breathing': 'Respirar',
  'breathing speed': 'Ritmo da respiração',
  'star size': 'Tamanho das estrelas',
  'star color': 'Cor das estrelas',
  'background element size': 'Tamanho dos elementos de fundo',
  'color cycle': 'Ciclo de cores',
  'color cycle speed': 'Velocidade do ciclo',
  'background color': 'Cor de fundo',
  'number of colors': 'Quantidade de cores',
  'color 1 position': 'Posição da cor 1',
  'color 2 position': 'Posição da cor 2',
  'color 3 position': 'Posição da cor 3',
  'color 4 position': 'Posição da cor 4',
  'start x position': 'Início X',
  'start y position': 'Início Y',
  'end x position': 'Fim X',
  'end y position': 'Fim Y',
  'show rain': 'Chuva',
  'raindrop size': 'Tamanho das gotas',
  'raindrop fade': 'Rastro das gotas',
  'storm intensity': 'Intensidade da tempestade',
  'show lightning': 'Relâmpagos',
  'show clouds': 'Nuvens',
  'show sweep': 'Varredura',
  'color scheme': 'Paleta',
  'neon': 'Neon',
  'sunset': 'Pôr do sol',
  'custom': 'Personalizada',
  'streak size': 'Tamanho dos rastros',
  'streak count': 'Quantidade de rastros',
  'horizontal streaks': 'Rastros horizontais',
  'vertical streaks': 'Rastros verticais',
  'rain': 'Chuva',
  'snowflake size': 'Tamanho dos flocos',
  'snowflake density': 'Densidade dos flocos',
  'snowflake fade': 'Rastro dos flocos',
  'spark color': 'Cor das faíscas',
  'stars': 'Estrelas',
  'sparks': 'Faíscas',
  'ring size': 'Tamanho dos anéis',
  'saturation': 'Saturação',
  'lightness': 'Luminosidade',
  'cube size': 'Tamanho dos blocos',

  // Device plugin parameters
  'shutdown color': 'Cor ao desligar',
  'lighting mode': 'Modo de iluminação',
  'canvas': 'Efeito',
  'forced': 'Cor fixa',
  'forced color': 'Cor fixa',
  'mainboard configuration': 'Ordem de cores da placa-mãe',
  '12v header configuration': 'Ordem de cores dos headers 12V',
  'argb channel configuration': 'Ordem de cores dos headers ARGB',
  'force enable all zones': 'Ativar todas as zonas',
  'enable dpi control': 'Controlar DPI',
  'dpi': 'DPI',
  'dpi 1': 'DPI 1',
  'dpi 2': 'DPI 2',
  'dpi 3': 'DPI 3',
  'dpi 4': 'DPI 4',
  'dpi 5': 'DPI 5',
  'number of dpi stages': 'Quantidade de estágios de DPI',
  'dpi stage rollover': 'Voltar ao primeiro estágio de DPI',
  'sniper button dpi': 'DPI do botão sniper',
  'polling rate': 'Taxa de atualização',
  'angle snapping': 'Correção de ângulo',
  'lift off distance': 'Distância de levantamento',
  'debounce (ms)': 'Debounce (ms)',
  'enable setting control': 'Controlar configurações',
  'device sleep timeout (minutes)': 'Suspender após (minutos)',
  'led timeout length (minutes)': 'Apagar LEDs após (minutos)',
  'keyboard layout': 'Layout do teclado',
  'enable mic led': 'LED do microfone',
  'sidetone': 'Retorno de voz',
  'noise canceling': 'Cancelamento de ruído',
  'shutdown mode': 'Ao desligar',
  'hardware effect': 'Efeito do hardware',
  'forced model': 'Forçar modelo',
  'fan speed mode': 'Modo das ventoinhas',
  'frame rate': 'Taxa de quadros',
  'high fps mode': 'Modo de alta taxa de quadros',

  // Plugin parameter descriptions
  'this color is applied to the device when the system, or signalrgb is shutting down':
      'Cor aplicada quando o sistema ou o OpenChroma é desligado.',
  "determines where the device's rgb comes from. canvas will pull from the active effect, while forced will override it to a specific color":
      'De onde vem a cor do dispositivo: do efeito ativo ou de uma cor fixa.',
  "the color used when 'forced' lighting mode is enabled":
      'Cor usada quando o modo de iluminação é "Cor fixa".',
  'sets all led zones to be active. this will override any motherboard specific led configurations.': 'Ativa todas as zonas de LED, ignorando a configuração específica da placa.',
  'sets the rgb color order for the motherboards rgb. if you are experiencing issues, try switching to each one of these options until you find one which works':
      'Se as cores aparecerem trocadas, teste cada opção até acertar.',
  'sets the rgb color order for the motherboards 12v rgb headers. if you are experiencing issues, try switching to each one of these options until you find one which works':
      'Se as cores aparecerem trocadas, teste cada opção até acertar.',
  'sets the rgb color order for the motherboards 5v argb headers. if you are experiencing issues, try switching to each one of these options until you find one which works':
      'Se as cores aparecerem trocadas, teste cada opção até acertar.',
  'changes the movement of the colors.': 'Como as cores se movem.',
  'changes the first color.': 'Primeira cor.',
  'changes the second color.': 'Segunda cor.',
  'this toggle makes the colors random instead.': 'Usa cores aleatórias.',
  'changes the speed of the colors.': 'Velocidade das cores.',
};

/// Translates [text] when it is a known term; otherwise returns it unchanged.
String tr(String text) => terms[text.trim().toLowerCase()] ?? text;
