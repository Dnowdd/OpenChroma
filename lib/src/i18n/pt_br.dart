/// Portuguese (Brazil) texts for common parameter names of imported HTML
/// effects, which usually ship in English.
///
/// Keys are compared case-insensitively. Anything not listed is shown as is.
library;

/// Parameters that depend on keyboard input, which this app does not read.
const hiddenParameters = {'keypress effects', 'key press effect'};

/// Parameter labels and option values.
const terms = {
  'speed': 'Velocidade',
  'animation speed': 'Velocidade',
  'direction': 'Direção',
  'vertical': 'Vertical',
  'horizontal': 'Horizontal',
  'color': 'Cor',
  'color 1': 'Cor 1',
  'color 2': 'Cor 2',
  'color 3': 'Cor 3',
  'color 4': 'Cor 4',
  'first color': 'Primeira cor',
  'second color': 'Segunda cor',
  'background color': 'Cor de fundo',
  'number of colors': 'Quantidade de cores',
  'brightness': 'Brilho',
  'saturation': 'Saturação',
  'lightness': 'Luminosidade',
  'size': 'Tamanho',
  'custom': 'Personalizada',
};

/// Translates [text] when it is a known term; otherwise returns it unchanged.
String tr(String text) => terms[text.trim().toLowerCase()] ?? text;
