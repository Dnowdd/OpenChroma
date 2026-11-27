// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get aboutSection => 'Sobre';

  @override
  String aboutUpdateAvailable(String version) {
    return 'A versão $version está disponível.';
  }

  @override
  String aboutUpdateBanner(String version) {
    return 'O OpenChroma $version está disponível.';
  }

  @override
  String get aboutChecking => 'Procurando atualizações…';

  @override
  String get aboutDevBuild =>
      'Build de desenvolvimento: sem busca de atualizações.';

  @override
  String get aboutUpToDate => 'Você está na versão mais recente.';

  @override
  String get aboutDownload => 'Baixar';

  @override
  String get aboutCheckNow => 'Verificar agora';

  @override
  String get aboutDismiss => 'Dispensar';

  @override
  String get aboutAutoCheck => 'Procurar atualizações sozinho';

  @override
  String get aboutAutoCheckDescription =>
      'Uma vez por dia, o OpenChroma pergunta ao GitHub qual é a versão mais recente. Nada sobre o seu PC é enviado.';

  @override
  String get aboutReportProblem => 'Relatar um problema';

  @override
  String get aboutReportProblemDescription =>
      'Copie um resumo de diagnóstico (versão do app e do Windows, dispositivos e erros; sem números de série) e cole numa issue do GitHub.';

  @override
  String get aboutCopyDiagnostics => 'Copiar diagnóstico';

  @override
  String get aboutDiagnosticsCopied => 'Diagnóstico copiado.';

  @override
  String get aboutOpenIssue => 'Abrir uma issue';

  @override
  String get fansTitle => 'Ventoinhas';

  @override
  String get fansProfileSilent => 'Silencioso';

  @override
  String get fansProfileBalanced => 'Equilibrado';

  @override
  String get fansProfileTurbo => 'Turbo';

  @override
  String get fansProfileCustom => 'Personalizado';

  @override
  String get fansConnected => 'Conectadas';

  @override
  String get fansHideEmpty => 'Ocultar vazias';

  @override
  String fansShowEmpty(int count) {
    return 'Mostrar vazias ($count)';
  }

  @override
  String fansConflictTitle(String program) {
    return '$program está aberto.';
  }

  @override
  String get fansConflictText =>
      'Dois programas nas mesmas ventoinhas brigam pela velocidade. Feche-o, inclusive na bandeja, para controlar por aqui.';

  @override
  String get fansAdminTitle => 'Modo administrador';

  @override
  String get fansAdminText =>
      'para controlar as ventoinhas e ver as da placa-mãe.';

  @override
  String get fansRestartAsAdmin => 'Reiniciar como administrador';

  @override
  String get fansInstallPawnIoTitle => 'Instale o PawnIO';

  @override
  String get fansInstallPawnIoText => 'para ver as ventoinhas da placa-mãe.';

  @override
  String get fansDownload => 'Baixar';

  @override
  String get fansBusyTitle => 'A placa-mãe estava ocupada';

  @override
  String get fansBusyText =>
      'por outro programa. Reabra o OpenChroma para tentar de novo.';

  @override
  String get fansPumpQuestionTitle => 'Tem water cooler?';

  @override
  String get fansPumpQuestionText =>
      'Toque na bomba para protegê-la: ela nunca fica abaixo de 70% nem para.';

  @override
  String get fansPumpNone => 'Não tenho';

  @override
  String get fansCurveTitle => 'Curva';

  @override
  String get fansCpuTempNeedsAdmin =>
      'A temperatura da CPU pede o modo administrador';

  @override
  String get fansSearching => 'Procurando ventoinhas…';

  @override
  String get fansNone => 'Nenhuma ventoinha';

  @override
  String get fansNoTempDriver => 'Sem temperatura · driver no controle';

  @override
  String get fansNoTempBios => 'Sem temperatura · BIOS no controle';

  @override
  String get fansModeAuto => 'Auto';

  @override
  String get fansModeCurve => 'Curva';

  @override
  String get fansModeFixed => 'Fixo';

  @override
  String fansMotherboardDevice(String device) {
    return 'Placa-mãe · $device';
  }

  @override
  String get fansStopWhenCold => 'Parar quando frio';

  @override
  String get fansPumpToggle => 'Bomba de water cooler';

  @override
  String fansBlockedConflict(String program) {
    return '$program está aberto';
  }

  @override
  String get fansBlockedNeedsAdmin => 'Controlar pede o modo administrador';

  @override
  String get fansBlockedReadOnly => 'Somente leitura';

  @override
  String fansDefaultName(int index) {
    return 'Ventoinha $index';
  }

  @override
  String get effectsFilterAll => 'Todos';

  @override
  String get effectsFilterFavorites => 'Favoritos';

  @override
  String get effectsFilterAudio => 'Com som';

  @override
  String get effectsFilterImported => 'Importados';

  @override
  String get effectsSearchHint => 'Buscar efeitos';

  @override
  String get effectsImport => 'Importar';

  @override
  String get effectsEmptyFavoritesTitle => 'Nenhum favorito ainda';

  @override
  String get effectsEmptyFavoritesMessage =>
      'Passe o mouse sobre um efeito e clique na estrela para guardá-lo aqui.';

  @override
  String get effectsEmptyImportedTitle => 'Nenhum efeito importado';

  @override
  String get effectsEmptyImportedMessage =>
      'Crie um efeito em .ocfx ou traga um arquivo .html.';

  @override
  String get effectsImportEffect => 'Importar efeito';

  @override
  String get effectsNotFoundTitle => 'Nada encontrado';

  @override
  String get effectsNotFoundMessage => 'Tente outro termo de busca.';

  @override
  String get effectsReactsToSound => 'Reage ao som';

  @override
  String get effectsRemoveFavorite => 'Remover dos favoritos';

  @override
  String get effectsAddFavorite => 'Favoritar';

  @override
  String get effectsLive => 'Ao vivo';

  @override
  String get effectsRemoveImported => 'Remover efeito importado';

  @override
  String effectsByAuthor(String author) {
    return 'por $author';
  }

  @override
  String get effectsAdjustments => 'Ajustes';

  @override
  String get effectsReset => 'Restaurar';

  @override
  String get effectsNoAdjustments => 'Este efeito não tem ajustes.';

  @override
  String effectsRemoveTitle(String title) {
    return 'Remover \"$title\"?';
  }

  @override
  String get effectsRemoveMessage =>
      'O efeito sai da biblioteca. O arquivo original que você importou não é apagado.';

  @override
  String get effectsCancel => 'Cancelar';

  @override
  String get effectsRemove => 'Remover';

  @override
  String get effectsFileTypeEffects => 'Efeitos';

  @override
  String get effectsFileTypeOpenChroma => 'Efeito OpenChroma';

  @override
  String get effectsTemplateFileName => 'meu-efeito.ocfx';

  @override
  String get effectsTemplateName => 'Meu efeito';

  @override
  String get effectsTemplateDescription => 'Uma frase curta sobre o efeito.';

  @override
  String get effectsTemplateAuthor => 'Seu nome';

  @override
  String get effectsTemplateSpeed => 'Velocidade';

  @override
  String get effectsTemplateColor => 'Cor';

  @override
  String effectsImportFailed(String error) {
    return 'Não foi possível importar: $error';
  }

  @override
  String get effectsImportIntro =>
      'Traga um efeito .ocfx, o formato do OpenChroma, ou uma página .html que desenhe num canvas de 320×200.';

  @override
  String get effectsFormatLayers => 'Camadas';

  @override
  String get effectsFormatLayersText =>
      'gradient, spectrum, wave, pulse, sweep, rings, sparkle e solid, empilhadas com blend normal, screen, add, multiply ou overlay.';

  @override
  String get effectsFormatParams => 'Parâmetros';

  @override
  String get effectsFormatParamsText =>
      'Declare em \"params\" e use como \"\$name\" em qualquer camada. Eles viram controles no app.';

  @override
  String effectsTemplateSaved(String path) {
    return 'Modelo salvo em $path';
  }

  @override
  String get effectsSaveTemplate => 'Salvar modelo';

  @override
  String get effectsChooseFile => 'Escolher arquivo';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsLighting => 'Iluminação';

  @override
  String get settingsBrightness => 'Brilho';

  @override
  String get settingsEffectAudio => 'Áudio dos efeitos';

  @override
  String get settingsAudioUnavailable => 'Indisponível nesta build.';

  @override
  String get settingsLibrary => 'Biblioteca';

  @override
  String get settingsDevices => 'Dispositivos';

  @override
  String settingsDevicesConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conectados',
      one: '1 conectado',
    );
    return '$_temp0';
  }

  @override
  String get settingsScan => 'Procurar';

  @override
  String get settingsEffects => 'Efeitos';

  @override
  String settingsEffectsInLibrary(int count) {
    return '$count na biblioteca';
  }

  @override
  String get settingsImport => 'Importar';

  @override
  String get settingsPlugins => 'Plugins de dispositivos';

  @override
  String settingsPluginsLoaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count carregados',
      one: '1 carregado',
    );
    return '$_temp0. Arquivos .js novos ou alterados na pasta só rodam depois que você aprova.';
  }

  @override
  String get settingsReloadPlugins => 'Recarregar plugins';

  @override
  String get settingsOpenFolder => 'Abrir pasta';

  @override
  String get settingsDataFolder => 'Pasta de dados';

  @override
  String get settingsOpen => 'Abrir';

  @override
  String get settingsAlerts => 'Avisos';

  @override
  String get settingsWindowsNotifications => 'Notificações do Windows';

  @override
  String get settingsWindowsNotificationsDescription =>
      'Avisa quando algo esquenta demais, a memória ou o disco enchem ou a bomba do water cooler para, mesmo com o app na bandeja.';

  @override
  String get settingsFlashLeds => 'Piscar os LEDs em vermelho';

  @override
  String get settingsFlashLedsDescription =>
      'Os dispositivos piscam por alguns segundos junto com o aviso.';

  @override
  String get settingsAiAssistant => 'Assistente de IA';

  @override
  String get settingsAiKeyNote =>
      'A chave fica só neste PC, criptografada para o seu usuário do Windows, e só é enviada ao provedor escolhido. Quando você pergunta algo, o provedor também recebe as leituras do PC: modelo do hardware, temperaturas, uso, nomes dos dispositivos e dos processos que mais pesam.';

  @override
  String get settingsStartup => 'Inicialização e permissões';

  @override
  String get settingsAdminMode => 'Modo administrador';

  @override
  String get settingsAdminActive =>
      'Ativo. A temperatura da CPU aparece no Monitor.';

  @override
  String get settingsAdminInactive =>
      'Desativado. É preciso para ler a temperatura da CPU.';

  @override
  String get settingsAdminAlreadyActive => 'Já está ativo';

  @override
  String get settingsRestartAsAdmin => 'Reiniciar como administrador';

  @override
  String get settingsAlwaysAdmin => 'Sempre abrir como administrador';

  @override
  String get settingsAlwaysAdminDescription =>
      'O Windows pede permissão (UAC) toda vez que o OpenChroma abrir.';

  @override
  String get settingsStartWithWindows => 'Abrir ao ligar o PC';

  @override
  String get settingsStartWithWindowsAdminDescription =>
      'Abre na bandeja, como administrador, ao entrar no Windows, sem pedir permissão. Ativar ou desativar pede o UAC uma vez.';

  @override
  String get settingsStartWithWindowsDescription =>
      'Abre na bandeja junto com o Windows.';

  @override
  String get settingsRunInBackground => 'Continuar em segundo plano';

  @override
  String get settingsRunInBackgroundDescription =>
      'Ao fechar a janela, o OpenChroma fica na bandeja e segue controlando luzes e ventoinhas.';

  @override
  String get aiProviderCompatible => 'Compatível com OpenAI';

  @override
  String get aiProvider => 'Provedor';

  @override
  String get aiApiKey => 'Chave de API';

  @override
  String get aiKeyHintAnthropic => 'Crie em console.anthropic.com.';

  @override
  String get aiKeyHintOpenai => 'Crie em platform.openai.com.';

  @override
  String get aiKeyHintCompatible =>
      'Opcional para servidores locais (Ollama, LM Studio).';

  @override
  String get aiBaseUrl => 'Endereço da API';

  @override
  String get aiBaseUrlHint =>
      'Ex.: https://openrouter.ai/api/v1, http://localhost:11434/v1 (Ollama).';

  @override
  String get aiModel => 'Modelo';

  @override
  String get aiModelsLoading => 'Buscando os modelos disponíveis…';

  @override
  String get aiModelsNeedKey => 'Informe a chave para ver os modelos.';

  @override
  String get aiModelsNone => 'Nenhum modelo encontrado.';

  @override
  String aiModelsAvailable(int count) {
    return '$count disponíveis, atualizado sozinho.';
  }

  @override
  String get aiRefreshList => 'Atualizar lista';

  @override
  String get aiPasteKey => 'Cole a chave aqui';

  @override
  String get aiHide => 'Esconder';

  @override
  String get aiShow => 'Mostrar';

  @override
  String aiErrorListModels(String error) {
    return 'Não foi possível listar os modelos ($error).';
  }

  @override
  String get aiErrorTimeout => 'O servidor demorou demais para responder.';

  @override
  String aiErrorNoConnection(String host, String message) {
    return 'Sem conexão com $host ($message).';
  }

  @override
  String aiErrorSecureConnection(String host) {
    return 'Falha na conexão segura com $host.';
  }

  @override
  String get aiErrorUnexpectedResponse => 'Resposta inesperada do servidor.';

  @override
  String get aiErrorInvalidKey => 'Chave de API inválida ou sem permissão.';

  @override
  String get aiErrorNotFound => 'Endereço ou modelo não encontrado.';

  @override
  String get aiErrorRateLimit =>
      'Limite de uso atingido. Tente de novo em instantes.';

  @override
  String aiErrorProviderUnstable(int status) {
    return 'O provedor está instável agora ($status).';
  }

  @override
  String aiErrorStatus(int status) {
    return 'Erro $status.';
  }

  @override
  String get aiErrorNoKey => 'Configure uma chave de API em Configurações.';

  @override
  String get aiErrorNoModel => 'Escolha um modelo em Configurações.';

  @override
  String get aiErrorRefused => 'O modelo recusou responder a esse pedido.';

  @override
  String get aiErrorEmptyReply => 'O modelo não respondeu nada.';

  @override
  String get aiEffectDone => 'Pronto, fiz o efeito.';

  @override
  String alertsTempWarm(String what) {
    return '$what quente';
  }

  @override
  String alertsTempHot(String what) {
    return '$what muito quente';
  }

  @override
  String alertsTempNow(String temp) {
    return '$temp °C agora';
  }

  @override
  String get alertsDiskFallback => 'Disco';

  @override
  String get alertsMemoryTitle => 'Memória quase cheia';

  @override
  String alertsMemoryDetail(String percent, String free) {
    return '$percent% em uso · $free livres';
  }

  @override
  String alertsVolumeTitle(String letter) {
    return 'Disco $letter: quase cheio';
  }

  @override
  String alertsVolumeDetail(String free, String total) {
    return '$free livres de $total';
  }

  @override
  String get alertsPumpTitle => 'Bomba do water cooler parada';

  @override
  String alertsPumpDetail(String name, int rpm) {
    return '$name a $rpm RPM';
  }

  @override
  String get audioSourceOff => 'Desligado';

  @override
  String get audioSourceSystem => 'Som do PC';

  @override
  String get audioSourceMicrophone => 'Microfone';

  @override
  String get audioSourceBoth => 'Som do PC e microfone';

  @override
  String profileAppsTitle(String profile) {
    return 'Ligar \"$profile\" com programas';
  }

  @override
  String get profileAppsDescription =>
      'Quando um destes programas abrir, o perfil liga sozinho. Quando fechar, a iluminação de antes volta, a não ser que você tenha escolhido outra nesse meio-tempo.';

  @override
  String get profileAppsNone => 'Nenhum programa ainda.';

  @override
  String get profileAppsRemove => 'Remover';

  @override
  String get profileAppsNameHint => 'Nome do programa, ex.: cs2.exe';

  @override
  String get profileAppsOpenNow => 'Abertos agora';

  @override
  String get profileAppsNoOthers => 'Nenhum outro programa com janela aberta.';

  @override
  String get profileAppsBrowse => 'Procurar .exe';

  @override
  String get profileAppsCancel => 'Cancelar';

  @override
  String get profileAppsSave => 'Salvar';

  @override
  String get profileAppsFileTypeLabel => 'Programas';

  @override
  String aiErrorInsecureUrl(String host) {
    return 'Só endereços HTTPS são aceitos para $host. HTTP simples só vale para servidores neste PC (localhost).';
  }

  @override
  String get settingsManagePlugins => 'Gerenciar';

  @override
  String ocfxErrorInvalidJson(String message) {
    return 'O arquivo não é um JSON válido ($message).';
  }

  @override
  String get ocfxErrorNotObject => 'O arquivo precisa ser um objeto JSON.';

  @override
  String get ocfxErrorMissingVersion => 'Falta o campo \"openchroma\": 1.';

  @override
  String get ocfxErrorMissingName => 'Falta o campo \"name\".';

  @override
  String get ocfxErrorNoLayers =>
      'O efeito precisa de pelo menos uma camada em \"layers\".';

  @override
  String ocfxErrorLayerType(int index, String types) {
    return 'Camada $index: \"type\" deve ser um destes: $types.';
  }

  @override
  String get ocfxErrorParamsNotObject => '\"params\" precisa ser um objeto.';

  @override
  String ocfxErrorParamType(String key, String types) {
    return 'Parâmetro \"$key\": \"type\" deve ser $types.';
  }

  @override
  String get ocfxErrorI18nNotObject =>
      '\"i18n\" precisa ser um objeto com um objeto por idioma.';

  @override
  String get paramColorPickerTitle => 'Cor';

  @override
  String get paramColorPickerCancel => 'Cancelar';

  @override
  String get paramColorPickerApply => 'Aplicar';

  @override
  String get appTitle => 'OpenChroma';

  @override
  String get languageSystem => 'Padrão do sistema';

  @override
  String get languageEnglish => 'English';

  @override
  String get languagePortuguese => 'Português (Brasil)';

  @override
  String get settingsGeneral => 'Geral';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String colorOrderTitle(String header) {
    return 'Ordem das cores · $header';
  }

  @override
  String get colorOrderQuestion =>
      'Que cor as ventoinhas desse conector estão mostrando agora?';

  @override
  String get colorOrderBlueTitle => 'Ficou azul?';

  @override
  String colorOrderTesting(String order) {
    return 'Testando a ordem $order.';
  }

  @override
  String get colorOrderDoneTitle => 'Pronto';

  @override
  String get colorOrderFailedTitle => 'Não deu certo';

  @override
  String colorOrderNothingLit(String header) {
    return 'Se nada acendeu, confira a quantidade de LEDs do $header e se as ventoinhas estão nesse conector.';
  }

  @override
  String colorOrderAlreadyRight(String order) {
    return 'A ordem já estava certa ($order).';
  }

  @override
  String get colorOrderSameColors =>
      'As duas cores pareceram iguais. Tente de novo.';

  @override
  String get colorOrderCouldNotFix =>
      'Não consegui acertar sozinho. Escolha a ordem manualmente na lista.';

  @override
  String colorOrderSaved(String order, String header) {
    return 'Ordem $order salva no $header.';
  }

  @override
  String get colorOrderNothingLitButton => 'Não acendeu';

  @override
  String get colorOrderRed => 'Vermelho';

  @override
  String get colorOrderGreen => 'Verde';

  @override
  String get colorOrderBlue => 'Azul';

  @override
  String get colorOrderNo => 'Não';

  @override
  String get colorOrderYes => 'Sim';

  @override
  String get colorOrderClose => 'Fechar';

  @override
  String get devicesTitle => 'Dispositivos';

  @override
  String get devicesScanning => 'Procurando…';

  @override
  String devicesConnectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conectados',
      one: '1 conectado',
    );
    return '$_temp0';
  }

  @override
  String get devicesScan => 'Procurar';

  @override
  String get devicesOtherWireless => 'Outros sem fio';

  @override
  String get devicesScanningTitle => 'Procurando dispositivos';

  @override
  String get devicesDriversUnavailable => 'Drivers indisponíveis';

  @override
  String get devicesNone => 'Nenhum dispositivo';

  @override
  String get devicesScanTakesSeconds => 'Isso leva alguns segundos.';

  @override
  String get devicesDriversMissing =>
      'Os drivers não foram encontrados nesta instalação. Reinstale o OpenChroma.';

  @override
  String get devicesNoneHint =>
      'Conecte um dispositivo compatível. Se outro programa de RGB estiver aberto, feche-o antes. Memórias e placas de vídeo precisam do modo administrador e do PawnIO.';

  @override
  String get devicesScanAgain => 'Procurar novamente';

  @override
  String get devicesStatusConnected => 'Conectado';

  @override
  String get devicesStatusStarting => 'Iniciando';

  @override
  String get devicesStatusError => 'Erro';

  @override
  String get devicesStatusDisabled => 'Desativado';

  @override
  String get devicesStatusUnsupported => 'Não suportado';

  @override
  String get devicesStatusStopped => 'Parado';

  @override
  String get devicesKindKeyboard => 'Teclado';

  @override
  String get devicesKindMouse => 'Mouse';

  @override
  String get devicesKindHeadset => 'Headset';

  @override
  String get devicesKindMousepad => 'Mousepad';

  @override
  String get devicesKindMotherboard => 'Placa-mãe';

  @override
  String get devicesKindGpu => 'Placa de vídeo';

  @override
  String get devicesKindRam => 'Memória';

  @override
  String get devicesKindFan => 'Ventoinhas';

  @override
  String get devicesKindCooler => 'Water cooler';

  @override
  String get devicesKindController => 'Controladora';

  @override
  String get devicesKindStrip => 'Fita de LED';

  @override
  String get devicesKindSpeakers => 'Caixas de som';

  @override
  String get devicesKindMicrophone => 'Microfone';

  @override
  String get devicesKindGamepad => 'Controle';

  @override
  String get devicesKindCase => 'Gabinete';

  @override
  String get devicesKindOther => 'Dispositivo';

  @override
  String devicesLedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count LEDs',
      one: '1 LED',
    );
    return '$_temp0';
  }

  @override
  String devicesCharging(int level) {
    return 'Carregando · $level%';
  }

  @override
  String devicesBattery(int level) {
    return 'Bateria $level%';
  }

  @override
  String get devicesRestoreDefaults => 'Restaurar padrão';

  @override
  String get devicesEnable => 'Ativar';

  @override
  String get devicesDisable => 'Desativar';

  @override
  String get devicesTabLighting => 'Iluminação';

  @override
  String get devicesTabScreen => 'Tela';

  @override
  String get devicesTabDetails => 'Detalhes';

  @override
  String get devicesOff => 'Desligado';

  @override
  String get devicesModeStatic => 'Cor fixa';

  @override
  String get devicesModeBreathing => 'Respirar';

  @override
  String get devicesModeBlinking => 'Piscar';

  @override
  String get devicesModeFlashing => 'Piscar';

  @override
  String get devicesModeColorCycle => 'Ciclo de cores';

  @override
  String get devicesModeSpectrumCycle => 'Ciclo de cores';

  @override
  String get devicesModeRainbow => 'Arco-íris';

  @override
  String get devicesModeRainbowWave => 'Onda arco-íris';

  @override
  String get devicesModeWave => 'Onda';

  @override
  String get devicesModeColorWave => 'Onda de cores';

  @override
  String get devicesModeReactive => 'Ao digitar';

  @override
  String get devicesModeRipple => 'Ondulação';

  @override
  String get devicesModeStarlight => 'Estrelas';

  @override
  String get devicesModeRandomFlicker => 'Cintilar';

  @override
  String get devicesModeDoubleFlash => 'Flash duplo';

  @override
  String get devicesModeSpectrum => 'Espectro';

  @override
  String get devicesModeCustom => 'Personalizado';

  @override
  String get devicesModeRandom => 'Aleatório';

  @override
  String get devicesDirLeft => 'Para a esquerda';

  @override
  String get devicesDirRight => 'Para a direita';

  @override
  String get devicesDirUp => 'Para cima';

  @override
  String get devicesDirDown => 'Para baixo';

  @override
  String get devicesDirHorizontal => 'Horizontal';

  @override
  String get devicesDirVertical => 'Vertical';

  @override
  String get devicesDirUpLeft => 'Para cima e à esquerda';

  @override
  String get devicesDirUpRight => 'Para cima e à direita';

  @override
  String get devicesDirDownLeft => 'Para baixo e à esquerda';

  @override
  String get devicesDirDownRight => 'Para baixo e à direita';

  @override
  String get devicesSpeed => 'Velocidade';

  @override
  String get devicesBrightness => 'Brilho';

  @override
  String get devicesDirection => 'Direção';

  @override
  String get devicesRandomColors => 'Cores aleatórias';

  @override
  String get devicesColor => 'Cor';

  @override
  String get devicesColors => 'Cores';

  @override
  String get devicesRemoveColor => 'Uma cor a menos';

  @override
  String get devicesAddColor => 'Mais uma cor';

  @override
  String get devicesLighting => 'Iluminação';

  @override
  String get devicesFollowsApp => 'Segue os efeitos do OpenChroma.';

  @override
  String get devicesRunsItself => 'O próprio dispositivo faz o efeito.';

  @override
  String get devicesAppEffects => 'Efeitos do OpenChroma';

  @override
  String devicesZonesWithoutLeds(String zones) {
    return '$zones sem LEDs: o que estiver ligado nesses conectores não segue os efeitos e fica no efeito anterior. Informe a quantidade abaixo.';
  }

  @override
  String get devicesArgbHint =>
      'Nos conectores ARGB, informe quantos LEDs estão ligados. Uma ventoinha de 120 mm costuma ter entre 8 e 24. Depois posicione cada zona em Iluminação › Layout.';

  @override
  String devicesZoneN(int n) {
    return 'Zona $n';
  }

  @override
  String devicesUpToLeds(int max) {
    return 'Até $max LEDs';
  }

  @override
  String devicesMatrix(int width, int height) {
    return 'Matriz $width × $height';
  }

  @override
  String get devicesCountLeds => 'Contar';

  @override
  String devicesCountLedsTitle(String zone) {
    return 'Contar LEDs de $zone';
  }

  @override
  String get devicesCountLedsHint =>
      'Os primeiros LEDs acendem em verde. Aumente até a última ventoinha ou fita ficar toda acesa, e pare no ponto em que acender mais um não muda nada.';

  @override
  String get devicesOneLess => 'Um a menos';

  @override
  String get devicesOneMore => 'Um a mais';

  @override
  String get devicesCancel => 'Cancelar';

  @override
  String devicesUseLeds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Usar $count LEDs',
      one: 'Usar 1 LED',
    );
    return '$_temp0';
  }

  @override
  String get devicesInfoVendor => 'Fabricante';

  @override
  String get devicesInfoDescription => 'Descrição';

  @override
  String get devicesInfoVersion => 'Versão';

  @override
  String get devicesInfoSerial => 'Número de série';

  @override
  String get devicesInfoDriver => 'Driver';

  @override
  String get devicesDriverBuiltIn => 'OpenRGB (incluído)';

  @override
  String devicesDriverPluginBundled(String name) {
    return '$name · plugin incluído';
  }

  @override
  String devicesDriverPluginUser(String name) {
    return '$name · plugin seu';
  }

  @override
  String get devicesInfoConnection => 'Conexão';

  @override
  String get devicesInfoZones => 'Zonas';

  @override
  String get devicesInfoHardwareModes => 'Modos do hardware';

  @override
  String devicesColorOrderOption(String what) {
    return 'Ordem das cores · $what';
  }

  @override
  String get devicesBoardLedC => 'LED_C da placa';

  @override
  String devicesDetectGen2(String name) {
    return 'Detectar ARGB Gen2 · $name';
  }

  @override
  String get devicesPersistLighting => 'Gravar a iluminação ao fechar';

  @override
  String get devicesCalibrationHint =>
      'Se a cor sair trocada (ex.: verde no lugar de azul), use \"Descobrir\": duas perguntas e o app acha a ordem certa.';

  @override
  String get devicesDetect => 'Descobrir';

  @override
  String get devicesResetTitle => 'Restaurar padrão?';

  @override
  String get devicesResetBody =>
      'Volta as opções do dispositivo (como a ordem das cores) ao que ele tinha quando foi detectado pela primeira vez, faz ele seguir os efeitos do OpenChroma e devolve a posição dele no layout. A quantidade de LEDs dos conectores continua.';

  @override
  String get devicesRestore => 'Restaurar';

  @override
  String get engineProfileGame => 'Jogo';

  @override
  String get engineProfileWork => 'Trabalho';

  @override
  String get engineProfileNight => 'Noite';

  @override
  String get engineProfileOff => 'Desligado';

  @override
  String get engineImportBadExtension =>
      'Use um arquivo .ocfx, .json ou .html.';

  @override
  String get engineImportUnreadable => 'Não foi possível ler esse arquivo.';

  @override
  String enginePluginStopped(String error) {
    return 'O plugin parou: $error';
  }

  @override
  String get enginePluginRejected =>
      'O plugin não reconheceu este dispositivo.';

  @override
  String get engineScreenNoLiveValues =>
      'Esta tela não mostra valores ao vivo.';

  @override
  String engineScreenMaxLiveValues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Esta tela mostra até $count valores ao vivo diferentes.',
      one: 'Esta tela mostra até 1 valor ao vivo diferente.',
    );
    return '$_temp0';
  }

  @override
  String get engineScreenRejected => 'O dispositivo não aceitou a imagem.';

  @override
  String get engineScreenCannotOpen => 'Não foi possível abrir a imagem.';

  @override
  String get pluginsNoDefinition => 'o arquivo não chama plugin()';

  @override
  String get pluginsNoDevices => 'nenhum dispositivo em \"devices\"';

  @override
  String get pluginsNoPort => 'nenhuma porta escolhida';

  @override
  String get pluginsNoInterface => 'nenhuma interface escolhida';

  @override
  String pluginsCannotOpen(String path) {
    return 'não foi possível abrir $path';
  }

  @override
  String get layoutPreview => 'Prévia';

  @override
  String get layoutApply => 'Aplicar';

  @override
  String get layoutCancel => 'Cancelar';

  @override
  String get layoutAutoArrange => 'Organizar automaticamente';

  @override
  String get layoutUndo => 'Desfazer';

  @override
  String get layoutHint =>
      'Clique numa zona para identificar seus LEDs ou arraste para movê-la.';

  @override
  String get layoutDimEffect => 'Escurecer efeito';

  @override
  String get layoutNothingTitle => 'Nada para posicionar';

  @override
  String get layoutNothingMessage =>
      'Os dispositivos conectados aparecem aqui.';

  @override
  String get layoutDevice => 'Dispositivo';

  @override
  String get layoutSelectedZone => 'Zona selecionada';

  @override
  String get layoutFill => 'Preencher';

  @override
  String get layoutSwitchToApp =>
      'Mude para os efeitos do OpenChroma para identificar esta zona.';

  @override
  String get layoutRotate => 'Girar 90°';

  @override
  String get layoutFlipHorizontal => 'Espelhar horizontalmente';

  @override
  String get layoutFlipVertical => 'Espelhar verticalmente';

  @override
  String get layoutScale => 'Escala';

  @override
  String get layoutPositionX => 'Posição X';

  @override
  String get layoutPositionY => 'Posição Y';

  @override
  String get screenImageFiles => 'Imagens e GIFs';

  @override
  String get screenImageOrGif => 'Imagem ou GIF';

  @override
  String screenSending(int percent) {
    return 'Enviando… $percent%';
  }

  @override
  String get screenImageHint =>
      'Recorte, escolha o trecho e escreva por cima antes de enviar. A tela guarda o que receber, mesmo com o app fechado.';

  @override
  String get screenEdit => 'Editar';

  @override
  String get screenChooseFile => 'Escolher arquivo';

  @override
  String get screenEditorCannotOpen => 'Não foi possível abrir a imagem.';

  @override
  String get screenEditorTitle => 'Editar imagem da tela';

  @override
  String get screenEditorHintIdle =>
      'Clique num texto para selecioná-lo. Arraste a imagem para posicionar e use a roda do mouse para o zoom.';

  @override
  String get screenEditorHintSelected =>
      'Arraste para mover e puxe o canto (ou use a roda do mouse sobre o texto) para mudar o tamanho. Setas ajustam a posição, Delete remove, Ctrl+D duplica e Esc solta a seleção.';

  @override
  String get screenEditorCancel => 'Cancelar';

  @override
  String get screenEditorSend => 'Enviar para a tela';

  @override
  String get screenEditorFraming => 'Enquadramento';

  @override
  String get screenEditorFill => 'Preencher';

  @override
  String get screenEditorFit => 'Inteira';

  @override
  String get screenEditorBackgroundColor => 'Cor do fundo';

  @override
  String get screenEditorZoom => 'Zoom';

  @override
  String get screenEditorGifClip => 'Trecho do GIF';

  @override
  String screenEditorFrameRange(
    int first,
    int last,
    int total,
    String duration,
  ) {
    return 'Quadros $first a $last de $total · $duration';
  }

  @override
  String screenEditorFramesReduced(int max) {
    return ' · será reduzido a $max quadros';
  }

  @override
  String get screenEditorTexts => 'Textos';

  @override
  String get screenEditorAddText => 'Adicionar';

  @override
  String screenEditorLiveValues(int used, int total) {
    return 'Valores ao vivo: $used de $total. A tela atualiza a cada segundo enquanto o app estiver aberto.';
  }

  @override
  String get screenEditorTextHint => 'Texto';

  @override
  String get screenEditorBold => 'Negrito';

  @override
  String get screenEditorNormal => 'Normal';

  @override
  String get screenEditorTextColor => 'Cor do texto';

  @override
  String get screenEditorDuplicate => 'Duplicar';

  @override
  String get screenEditorRemove => 'Remover';

  @override
  String screenEditorLiveHint(String unit) {
    return 'Ao vivo · coloque a unidade ($unit) num texto fixo';
  }

  @override
  String get screenEditorShow => 'Mostrar';

  @override
  String get screenEditorFixedText => 'Texto fixo';

  @override
  String get screenDefaultText => 'Texto';

  @override
  String get screenSourceCpuTemp => 'Temperatura da CPU';

  @override
  String get screenSourceCpuUsage => 'Uso da CPU';

  @override
  String get screenSourceCpuClock => 'Clock da CPU';

  @override
  String get screenSourceCpuPower => 'Consumo da CPU';

  @override
  String get screenSourceGpuTemp => 'Temperatura da GPU';

  @override
  String get screenSourceGpuUsage => 'Uso da GPU';

  @override
  String get screenSourceGpuClock => 'Clock da GPU';

  @override
  String get screenSourceGpuPower => 'Consumo da GPU';

  @override
  String get screenSourceGpuFan => 'Ventoinha da GPU';

  @override
  String get screenSourceRamUsage => 'Uso da RAM';

  @override
  String get perfTitle => 'Desempenho';

  @override
  String get perfRestartAsAdmin => 'Reiniciar como administrador';

  @override
  String get perfClose => 'Fechar';

  @override
  String get monitorUnavailableTitle => 'Monitor indisponível';

  @override
  String get monitorUnavailableMessage =>
      'Esta build não inclui os sensores do sistema.';

  @override
  String get monitorReadingSensors => 'Lendo os sensores…';

  @override
  String monitorSubtitle(String uptime) {
    return 'Atualizado a cada segundo · PC ligado há $uptime';
  }

  @override
  String get monitorStalledTitle => 'Os sensores não responderam';

  @override
  String get monitorStalledMessage =>
      'Nenhuma leitura chegou do sistema. Feche e abra o OpenChroma de novo; se continuar, avise.';

  @override
  String monitorProcessesAt(String time) {
    return 'Processos às $time';
  }

  @override
  String monitorInspectSummary(String cpu, String memory) {
    return 'CPU $cpu · Memória $memory';
  }

  @override
  String get monitorProcessor => 'Processador';

  @override
  String monitorCoresThreads(int cores, int threads) {
    return '$cores núcleos · $threads threads';
  }

  @override
  String get monitorUsage => 'Uso';

  @override
  String get monitorTemperature => 'Temperatura';

  @override
  String get monitorClock => 'Clock';

  @override
  String get monitorPower => 'Consumo';

  @override
  String get monitorUsagePerThread => 'Uso por thread';

  @override
  String get monitorNeedsAdminTitle => 'Precisa de administrador';

  @override
  String get monitorNeedsAdminMessage =>
      'O sensor da CPU é lido pelo driver PawnIO, que só atende programas abertos como administrador.';

  @override
  String get monitorSensorPendingTitle => 'Lendo o sensor…';

  @override
  String get monitorSensorPendingMessage => 'Abrindo o driver PawnIO.';

  @override
  String get monitorSensorFailedTitle => 'O sensor não respondeu';

  @override
  String get monitorSensorFailedMessage =>
      'O driver PawnIO parou de responder. As outras leituras seguem normais.';

  @override
  String get monitorNoDriverTitle => 'Driver PawnIO não encontrado';

  @override
  String get monitorNoDriverMessage =>
      'Instale o PawnIO (pawnio.eu) para ver a temperatura da CPU.';

  @override
  String get monitorNoSensorTitle => 'Sem sensor';

  @override
  String get monitorNoSensorMessage =>
      'Este processador não tem um sensor de temperatura suportado.';

  @override
  String get monitorGraphicsCard => 'Placa de vídeo';

  @override
  String get monitorTemperatureUnavailable => 'Temperatura indisponível';

  @override
  String get monitorFan => 'Ventoinha';

  @override
  String get monitorVideoMemory => 'Memória de vídeo';

  @override
  String monitorUsedOfTotal(String used, String total) {
    return '$used de $total';
  }

  @override
  String monitorIntegratedGpu(String name) {
    return '$name · integrada';
  }

  @override
  String get monitorMemoryRam => 'Memória RAM';

  @override
  String monitorMemoryInstalled(String size) {
    return '$size instalados';
  }

  @override
  String get monitorMemoryAvailable => 'Disponível';

  @override
  String get monitorMemoryCached => 'Em cache';

  @override
  String get monitorMemoryCommitted => 'Confirmada';

  @override
  String get monitorStorage => 'Armazenamento';

  @override
  String monitorDiskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count discos',
      one: '1 disco',
    );
    return '$_temp0';
  }

  @override
  String monitorDiskNumber(int number) {
    return 'Disco $number';
  }

  @override
  String monitorDiskActive(String percent) {
    return 'Ativo $percent';
  }

  @override
  String get monitorVolumeRemovable => 'Removível';

  @override
  String get monitorVolumeLocal => 'Disco local';

  @override
  String monitorFreeOfTotal(String free, String total) {
    return '$free livres de $total';
  }

  @override
  String get monitorNetwork => 'Rede';

  @override
  String get monitorTraffic => 'Tráfego';

  @override
  String get monitorDownload => 'Download';

  @override
  String get monitorUpload => 'Upload';

  @override
  String get monitorProcesses => 'Processos';

  @override
  String get monitorTopMemory => 'Os que mais usam memória';

  @override
  String get monitorTopCpu => 'Os que mais usam CPU';

  @override
  String get monitorColumnName => 'Nome';

  @override
  String get monitorColumnCpu => 'CPU';

  @override
  String get monitorColumnMemory => 'Memória';

  @override
  String get monitorNoProcessData => 'Sem dados de processos nesta amostra.';

  @override
  String monitorSortTooltip(String column) {
    return 'Ordenar por $column, maior primeiro';
  }

  @override
  String get monitorTempNormal => 'Normal';

  @override
  String get monitorTempWarm => 'Quente';

  @override
  String get monitorTempHot => 'Muito quente';

  @override
  String monitorThreadTooltip(int number, String usage) {
    return 'Thread $number: $usage';
  }

  @override
  String get monitorClickToInspect => 'Clique para inspecionar';

  @override
  String get monitorNow => 'agora';

  @override
  String monitorSecondsAgo(int seconds) {
    return 'há $seconds s';
  }

  @override
  String get checkupSubtitleRunning => 'Checkup em andamento';

  @override
  String get checkupSubtitleEmpty => 'Teste a estabilidade e a saúde do PC';

  @override
  String checkupSubtitleLast(String when) {
    return 'Último checkup $when';
  }

  @override
  String checkupWhenToday(String time) {
    return 'hoje às $time';
  }

  @override
  String checkupWhenYesterday(String time) {
    return 'ontem às $time';
  }

  @override
  String checkupWhenDate(String date, String time) {
    return 'em $date às $time';
  }

  @override
  String get checkupTests => 'Testes';

  @override
  String checkupSelectedCount(int selected, int total) {
    return '$selected de $total';
  }

  @override
  String get checkupPlanQuick => 'Rápido';

  @override
  String get checkupPlanStandard => 'Padrão';

  @override
  String get checkupPlanLong => 'Longo';

  @override
  String get checkupTestCpuSingle => 'Processador · 1 núcleo';

  @override
  String get checkupTestCpuAll => 'Processador · todos';

  @override
  String get checkupTestMemory => 'Memória RAM';

  @override
  String get checkupTestGpu => 'Placa de vídeo';

  @override
  String get checkupTestCpuGpu => 'CPU + GPU juntos';

  @override
  String get checkupTestDisk => 'Armazenamento';

  @override
  String checkupThousands(String value) {
    return '$value mil';
  }

  @override
  String checkupMemoryMetricRead(String read) {
    return 'Lê $read GB/s';
  }

  @override
  String checkupMemoryMetricWrite(String write) {
    return 'grava $write';
  }

  @override
  String checkupDiskMetricWrite(String write) {
    return 'Grava $write GB/s';
  }

  @override
  String checkupDiskMetricRead(String read) {
    return 'lê $read';
  }

  @override
  String get checkupTitle => 'Checkup';

  @override
  String get checkupCancel => 'Cancelar';

  @override
  String get checkupPreparing => 'Preparando…';

  @override
  String get checkupStart => 'Iniciar checkup';

  @override
  String get checkupRunAgain => 'Rodar de novo';

  @override
  String get checkupNoAdminNote =>
      'Sem administrador, a temperatura da CPU e a causa das telas azuis ficam de fora.';

  @override
  String checkupProblemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problemas',
      one: '1 problema',
    );
    return '$_temp0';
  }

  @override
  String checkupWarningCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count avisos',
      one: '1 aviso',
    );
    return '$_temp0';
  }

  @override
  String get checkupAllGood => 'Tudo certo';

  @override
  String checkupCalcErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count erros de cálculo',
      one: '1 erro de cálculo',
      zero: 'Nenhum erro de cálculo',
    );
    return '$_temp0';
  }

  @override
  String checkupNext(String plan, int minutes) {
    return 'Próximo: $plan · ≈ $minutes min';
  }

  @override
  String checkupTestCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count testes',
      one: '1 teste',
    );
    return '$_temp0';
  }

  @override
  String get checkupFinishing => 'Finalizando…';

  @override
  String checkupTestProgress(int index, int total) {
    return 'Teste $index de $total';
  }

  @override
  String checkupProgressRemaining(int percent, String time) {
    return '$percent% · $time restantes';
  }

  @override
  String get checkupStatusQueued => 'Na fila';

  @override
  String get checkupStatusStable => 'Estável';

  @override
  String checkupStatusErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count erros',
      one: '1 erro',
    );
    return '$_temp0';
  }

  @override
  String get checkupStatusStopped => 'Interrompido';

  @override
  String get checkupStatusDidNotRun => 'Não rodou';

  @override
  String get checkupStatusCancelled => 'Cancelado';

  @override
  String get systemCardTitle => 'Sistema';

  @override
  String get systemAfterFirstCheckup => 'Aparece depois do primeiro checkup';

  @override
  String get systemMotherboard => 'Placa-mãe';

  @override
  String get systemProcessor => 'Processador';

  @override
  String get systemGraphicsCard => 'Placa de vídeo';

  @override
  String get systemMemory => 'Memória';

  @override
  String systemModuleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pentes',
      one: '1 pente',
    );
    return '$_temp0';
  }

  @override
  String systemSlotCount(int count) {
    return '$count slots';
  }

  @override
  String get systemMemoryInUse => 'Memória em uso';

  @override
  String systemMemoryUsedOfTotal(String used, String total) {
    return '$used de $total GB';
  }

  @override
  String get systemDrive => 'Disco do sistema';

  @override
  String systemDriveFree(String free, String total) {
    return '$free GB livres de $total GB';
  }

  @override
  String get systemBlueScreens => 'Telas azuis · 30 dias';

  @override
  String get systemBlueScreensNone => 'Nenhuma';

  @override
  String get systemStartupApps => 'Abrem com o Windows';

  @override
  String systemStartupAppsValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count programas',
      one: '1 programa',
    );
    return '$_temp0';
  }

  @override
  String get systemIdleCpu => 'CPU em repouso';

  @override
  String systemIdleCpuValue(int temp, int usage) {
    return '$temp °C · $usage% de uso';
  }

  @override
  String get checkupRecommendations => 'Recomendações';

  @override
  String get checkupRecommendationsEmpty =>
      'Termine um checkup para ver as recomendações';

  @override
  String get checkupAiTitle => 'Análise com IA';

  @override
  String get checkupAiNotReady => 'Conecte uma IA em Configurações para usar.';

  @override
  String get checkupAiRunFirst =>
      'Rode um checkup para analisar os resultados.';

  @override
  String get checkupAiHint =>
      'Explica os resultados e sugere ajustes para o seu PC.';

  @override
  String get checkupAiAnalyze => 'Analisar';

  @override
  String get checkupAiAnalyzeAgain => 'Analisar de novo';

  @override
  String get checkupAiSystemPrompt =>
      'Você é um técnico de hardware experiente analisando o checkup de um PC com Windows feito pelo app OpenChroma. Responda em português do Brasil, em texto simples (sem tabelas), com: um veredito de uma linha; os problemas reais em ordem de importância, cada um com a causa provável e o que fazer; e o que está bom. Seja específico com os números do relatório e não invente dados que não estão nele. No máximo 250 palavras.';

  @override
  String checkupAbortCpuTemp(int temp) {
    return 'A CPU passou de $temp °C';
  }

  @override
  String checkupAbortGpuTemp(int temp) {
    return 'A placa de vídeo passou de $temp °C';
  }

  @override
  String get checkupAbortPump => 'A bomba do water cooler parou';

  @override
  String checkupAdviceAbortedTitle(String reason) {
    return 'Teste interrompido: $reason';
  }

  @override
  String get checkupAdviceAbortedDetail =>
      'O resfriamento não deu conta da carga. Confira o cooler (montagem, pasta térmica, ventoinhas e bomba) antes de usar o PC em carga pesada.';

  @override
  String get checkupAdviceCpuErrorsTitle => 'A CPU errou cálculos sob carga';

  @override
  String get checkupAdviceCpuErrorsDetail =>
      'Sinal de instabilidade. Desfaça overclock ou undervolt (PBO, Curve Optimizer) e atualize o BIOS; se continuar, pode ser defeito.';

  @override
  String get checkupAdviceGpuErrorsTitle => 'A placa de vídeo calculou errado';

  @override
  String get checkupAdviceGpuErrorsDetail =>
      'Remova overclock da GPU e atualize o driver de vídeo.';

  @override
  String get checkupAdviceMemoryErrorsTitle =>
      'A memória devolveu dados errados';

  @override
  String get checkupAdviceMemoryErrorsDetail =>
      'Desative o EXPO/XMP no BIOS e teste de novo. Se continuar, teste um pente por vez para achar o defeituoso.';

  @override
  String get checkupAdviceDiskErrorsTitle =>
      'O disco devolveu dados diferentes dos gravados';

  @override
  String get checkupAdviceDiskErrorsDetail =>
      'Faça backup agora e verifique a saúde do disco.';

  @override
  String checkupAdviceBlueScreensTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count telas azuis nos últimos 30 dias',
      one: '1 tela azul nos últimos 30 dias',
    );
    return '$_temp0';
  }

  @override
  String checkupAdviceBlueScreensSuspect(String driver, int count, int total) {
    return 'O driver $driver aparece em $count de $total registros de falha. Atualize ou desinstale o programa dono dele.';
  }

  @override
  String get checkupAdviceBlueScreensNoSuspect =>
      'Os registros não apontam um driver de terceiros. Atualize o BIOS, o chipset e o driver de vídeo, e teste a memória.';

  @override
  String get checkupAdviceBlueScreensNeedAdmin =>
      'Rode o checkup como administrador para descobrir o driver responsável.';

  @override
  String checkupAdviceCpuHotTitle(int temp) {
    return 'A CPU chega a $temp °C em carga total';
  }

  @override
  String get checkupAdviceCpuHotDetail =>
      'Está no limite térmico e perde desempenho. Melhore o resfriamento ou limite a temperatura/potência no BIOS (Eco Mode na AMD, PL1/PL2 na Intel).';

  @override
  String checkupAdviceGpuHotTitle(int temp) {
    return 'A placa de vídeo chega a $temp °C';
  }

  @override
  String get checkupAdviceGpuHotDetail =>
      'Melhore a ventilação do gabinete ou ajuste a curva das ventoinhas da GPU.';

  @override
  String get checkupAdviceSingleChannelTitle => 'Memória em single channel';

  @override
  String get checkupAdviceSingleChannelDetail =>
      'Um pente só usa metade da largura de banda. Adicionar outro igual (mesmo modelo) ativa o dual channel.';

  @override
  String get checkupAdviceSameChannelTitle => 'Os pentes estão no mesmo canal';

  @override
  String get checkupAdviceSameChannelDetail =>
      'Mude para os slots indicados no manual da placa (geralmente A2 e B2).';

  @override
  String get checkupAdviceSlowMemoryTitle =>
      'A memória roda abaixo do que suporta';

  @override
  String checkupAdviceSlowMemoryDetail(int configured, int speed) {
    return '$configured de $speed MT/s. Ative o EXPO (AMD) ou XMP (Intel) no BIOS.';
  }

  @override
  String get checkupAdviceProfileOffTitle => 'EXPO/XMP provavelmente desligado';

  @override
  String checkupAdviceProfileOffDetail(int configured) {
    return 'A memória está na velocidade básica ($configured MT/s). Se o pente for de velocidade maior, ative o EXPO/XMP no BIOS.';
  }

  @override
  String get checkupAdviceMemoryFullTitle => 'Memória no limite';

  @override
  String checkupAdviceMemoryFullDetail(
    String used,
    String total,
    String committed,
  ) {
    return '$used de $total GB em uso e $committed GB pedidos pelos programas; o excesso vai para o disco e deixa tudo lento. Feche apps pesados ou adicione RAM.';
  }

  @override
  String get checkupAdviceDriveFullTitle => 'Disco do sistema quase cheio';

  @override
  String checkupAdviceDriveFullDetail(String free) {
    return 'Só $free GB livres. Abaixo de 10% o Windows fica lento, perde espaço para memória virtual e apaga registros de falhas.';
  }

  @override
  String checkupAdviceStartupTitle(int count) {
    return '$count programas abrem com o Windows';
  }

  @override
  String get checkupAdviceStartupDetail =>
      'Desative os que não usa todo dia em Gerenciador de Tarefas > Aplicativos de inicialização.';

  @override
  String get checkupAdviceBusyTitle => 'O PC estava ocupado antes dos testes';

  @override
  String checkupAdviceBusyDetail(int usage) {
    return '$usage% de uso da CPU em repouso: programas em segundo plano esquentam o PC e afetam os resultados.';
  }

  @override
  String get checkupAdviceNoCpuTempTitle => 'Sem temperatura da CPU';

  @override
  String get checkupAdviceNoCpuTempDetail =>
      'Rode o checkup como administrador para medir a temperatura e proteger a CPU durante os testes.';

  @override
  String get checkupAdviceAllGoodDetail =>
      'Nenhum erro nos testes e nada fora do normal no sistema.';

  @override
  String get systemErrorWindowsSetting =>
      'Não foi possível alterar a configuração do Windows.';

  @override
  String get systemErrorSaveSetting =>
      'Não foi possível salvar a configuração.';

  @override
  String get systemErrorEnableStartup =>
      'Não foi possível ativar a inicialização com o Windows.';

  @override
  String get systemErrorTaskNotCreated =>
      'A tarefa de inicialização não foi criada. É preciso aceitar a permissão do Windows.';

  @override
  String get systemErrorTaskNotRemoved =>
      'A tarefa de inicialização não foi removida. É preciso aceitar a permissão do Windows.';

  @override
  String get systemTaskDescription =>
      'Abre o OpenChroma como administrador ao entrar no Windows.';

  @override
  String get pluginTrustTimedOut =>
      'O plugin demorou demais para iniciar e foi interrompido.';

  @override
  String get pluginTrustLoadFailed => 'O plugin parou durante o carregamento.';

  @override
  String get pluginTrustTooLarge => 'O arquivo tem mais de 1 MB.';

  @override
  String get pluginTrustUnresponsive => 'O plugin parou de responder.';

  @override
  String pluginTrustBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plugins novos precisam da sua aprovação',
      one: '1 plugin novo precisa da sua aprovação',
    );
    return '$_temp0';
  }

  @override
  String get pluginTrustReview => 'Revisar';

  @override
  String get pluginTrustTitle => 'Plugins de dispositivos';

  @override
  String get pluginTrustIntro =>
      'Um plugin é um programa que roda dentro do OpenChroma e pode enviar qualquer comando aos seus dispositivos USB. Aprove apenas plugins de uma fonte em que você confia.';

  @override
  String get pluginTrustElevated =>
      'O OpenChroma está rodando como administrador, então um plugin aprovado roda com direitos de administrador.';

  @override
  String get pluginTrustPending => 'Aguardando aprovação';

  @override
  String get pluginTrustApproved => 'Aprovado';

  @override
  String get pluginTrustDenied => 'Não permitido';

  @override
  String get pluginTrustApprove => 'Aprovar';

  @override
  String get pluginTrustDeny => 'Não permitir';

  @override
  String get pluginTrustRevoke => 'Revogar';

  @override
  String get pluginTrustClose => 'Fechar';

  @override
  String get pluginTrustPath => 'Caminho';

  @override
  String get pluginTrustSize => 'Tamanho';

  @override
  String get pluginTrustModified => 'Modificado';

  @override
  String get pluginTrustHash => 'SHA-256';

  @override
  String get pluginTrustChanged => 'Alterado desde que você aprovou';

  @override
  String get pluginTrustReplaces =>
      'Substitui o plugin integrado com o mesmo nome de arquivo';

  @override
  String pluginTrustOverrides(String names) {
    return 'Substitui o plugin integrado: $names';
  }

  @override
  String get pluginTrustEmpty =>
      'Não há plugins na sua pasta de plugins. Os plugins incluídos no app não precisam de aprovação.';

  @override
  String get securityStartupAdminDescription =>
      'Abre na bandeja, como administrador, ao entrar no Windows, sem pedir permissão. Para alterar, o OpenChroma precisa estar rodando como administrador.';

  @override
  String get securityStartupInstallUnsafe =>
      'Para iniciar como administrador automaticamente, instale o OpenChroma para todos os usuários (em Arquivos de Programas). Esta cópia pode ser modificada sem direitos de administrador, então não é seguro executá-la com acesso total ao entrar no Windows.';

  @override
  String get securityStartupInstallUnsafeRemove =>
      'Esta cópia pode ser modificada sem direitos de administrador, então iniciá-la como administrador não é seguro. Desative esta opção para remover o início automático como administrador.';

  @override
  String get securityStartupNeedsAdmin =>
      'Reinicie o OpenChroma como administrador para alterar o início automático como administrador.';

  @override
  String get securityErrorNeedsAdmin =>
      'Reinicie o OpenChroma como administrador para alterar esta configuração.';

  @override
  String get securityErrorInstallNotTrusted =>
      'Para iniciar como administrador automaticamente, instale o OpenChroma para todos os usuários (em Arquivos de Programas).';

  @override
  String get securityErrorTaskNotCreated =>
      'A tarefa de inicialização não foi criada.';

  @override
  String get securityErrorTaskNotRemoved =>
      'A tarefa de inicialização não foi removida.';

  @override
  String get commonSearch => 'Buscar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Salvar';

  @override
  String get commonOff => 'Desligado';

  @override
  String get commonPaused => 'Pausado';

  @override
  String get commonLive => 'Ao vivo';

  @override
  String get commonNoEffect => 'Nenhum efeito';

  @override
  String get windowMinimize => 'Minimizar';

  @override
  String get windowMaximize => 'Maximizar';

  @override
  String get windowRestore => 'Restaurar';

  @override
  String get windowClose => 'Fechar';

  @override
  String get shellNavHome => 'Início';

  @override
  String get shellNavLighting => 'Iluminação';

  @override
  String get shellNavDevices => 'Dispositivos';

  @override
  String get shellNavFans => 'Ventoinhas';

  @override
  String get shellNavPerformance => 'Desempenho';

  @override
  String get shellNavSettings => 'Configurações';

  @override
  String get shellAdminActive => 'Modo administrador ativo';

  @override
  String get shellRestartAsAdmin => 'Reiniciar como administrador';

  @override
  String get shellTabEffects => 'Efeitos';

  @override
  String get shellTabLayout => 'Layout';

  @override
  String get shellTabMonitor => 'Monitor';

  @override
  String get shellTabDiagnostics => 'Diagnóstico';

  @override
  String shellConflictOpen(String names, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names está aberto.',
      one: '$names está aberto.',
    );
    return '$_temp0';
  }

  @override
  String get shellConflictAdvice =>
      'Dois programas nos mesmos LEDs fazem as cores piscarem. Feche-o, inclusive na bandeja.';

  @override
  String get shellWebviewMissing =>
      'Os efeitos precisam do Microsoft WebView2, que não está instalado neste PC.';

  @override
  String get shellWebviewDownload => 'Baixar o WebView2';

  @override
  String get shellPlayerOffPaused => 'Desligado · efeito pausado';

  @override
  String shellPlayerLiveOnDevices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ao vivo em $count dispositivos',
      one: 'Ao vivo em 1 dispositivo',
    );
    return '$_temp0';
  }

  @override
  String get lightingTitle => 'Iluminação';

  @override
  String get lightingBrightnessPerDevice => 'Brilho de cada dispositivo';

  @override
  String get lightingBrightnessTitle => 'Brilho';

  @override
  String get lightingAll => 'Tudo';

  @override
  String get lightingLights => 'Luzes';

  @override
  String get lightingScreens => 'Telas';

  @override
  String get lightingNoDevices => 'Nenhum dispositivo conectado.';

  @override
  String get lightingBrightnessNote =>
      '\"Tudo\" vale para todos os dispositivos, por cima do brilho de cada um. Em 0%, o efeito pausa e nada é enviado.';

  @override
  String get lightingPausedAtZero => 'Pausado: o brilho está em 0%';

  @override
  String get lightingResumeEffect => 'Continuar o efeito';

  @override
  String get lightingPauseEffect => 'Pausar o efeito';

  @override
  String get homeGreetingNight => 'Boa noite';

  @override
  String get homeGreetingMorning => 'Bom dia';

  @override
  String get homeGreetingAfternoon => 'Boa tarde';

  @override
  String get homeGreetingEvening => 'Boa noite';

  @override
  String get homeStatusReading => 'Lendo os sensores…';

  @override
  String get homeStatusAllGood => 'Tudo certo com o seu PC.';

  @override
  String homeStatusAlerts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count avisos pedem atenção.',
      one: '1 aviso pede atenção.',
    );
    return '$_temp0';
  }

  @override
  String homeWeekday(String day) {
    String _temp0 = intl.Intl.selectLogic(day, {
      'mon': 'segunda',
      'tue': 'terça',
      'wed': 'quarta',
      'thu': 'quinta',
      'fri': 'sexta',
      'sat': 'sábado',
      'other': 'domingo',
    });
    return '$_temp0';
  }

  @override
  String homeMonth(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      'jan': 'janeiro',
      'feb': 'fevereiro',
      'mar': 'março',
      'apr': 'abril',
      'may': 'maio',
      'jun': 'junho',
      'jul': 'julho',
      'aug': 'agosto',
      'sep': 'setembro',
      'oct': 'outubro',
      'nov': 'novembro',
      'other': 'dezembro',
    });
    return '$_temp0';
  }

  @override
  String homeDate(String weekday, String month, int day) {
    return '$weekday, $day de $month';
  }

  @override
  String get homeOpenLighting => 'Abrir iluminação';

  @override
  String homeOnDevices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Em $count dispositivos',
      one: 'Em 1 dispositivo',
    );
    return '$_temp0';
  }

  @override
  String get homeProfilesTitle => 'Perfis';

  @override
  String get homeProfilesHint =>
      'Clique com o botão direito num perfil para salvar nele a iluminação atual ou ligá-lo junto com um programa';

  @override
  String homeProfileWithApp(String app) {
    return 'Com $app';
  }

  @override
  String get homeProfileLightsOff => 'Luzes apagadas';

  @override
  String get homeProfileCurrentEffect => 'Efeito atual';

  @override
  String homeProfileAutoOn(String apps) {
    return 'Liga sozinho com $apps';
  }

  @override
  String get homeProfileSaveHere => 'Salvar a iluminação atual aqui';

  @override
  String get homeProfileRename => 'Renomear';

  @override
  String get homeProfileLinkApps => 'Ligar com programas…';

  @override
  String get homeProfileReset => 'Restaurar perfis padrão';

  @override
  String get homeProfileNameTitle => 'Nome do perfil';

  @override
  String get homeLevelNormal => 'Normal';

  @override
  String get homeLevelWarm => 'Quente';

  @override
  String get homeLevelHot => 'Muito quente';

  @override
  String homeVitalUsage(String value) {
    return 'Uso $value%';
  }

  @override
  String get homeVitalUsageNeedsAdmin => 'Uso · temperatura pede admin';

  @override
  String get homeVitalMemory => 'Memória';

  @override
  String get homeVitalStorage => 'Armazenamento';

  @override
  String get homeVitalFreeUnit => 'GB livres';

  @override
  String homeVitalMemoryUsed(String used, String total) {
    return '$used de $total';
  }

  @override
  String homeVitalDiskUsed(String letter, String percent) {
    return '$letter: · $percent% usado';
  }

  @override
  String get homeAlertsTitle => 'Avisos';

  @override
  String get homeAlertsAllGood => 'Tudo certo';

  @override
  String get homeFansTitle => 'Ventoinhas';

  @override
  String get homeFanSilent => 'Silencioso';

  @override
  String get homeFanBalanced => 'Equilibrado';

  @override
  String get homeFanTurbo => 'Turbo';

  @override
  String homeFanCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ventoinhas',
      one: '1 ventoinha',
    );
    return '$_temp0';
  }

  @override
  String homeFanUpTo(int rpm) {
    return 'até $rpm RPM';
  }

  @override
  String get homeReactiveTitle => 'Luz reativa';

  @override
  String get homeReactiveNoGpu => 'Sem leitura da GPU neste PC.';

  @override
  String get homeReactiveCpuNeedsAdmin =>
      'A temperatura da CPU precisa do modo administrador.';

  @override
  String get homeReactiveOn =>
      'Os LEDs mostram a temperatura no lugar do efeito.';

  @override
  String get homeReactiveOff => 'A cor dos LEDs segue a temperatura.';

  @override
  String homeScreenSending(int percent) {
    return 'Enviando… $percent%';
  }

  @override
  String get homeScreenOff => 'Tela desligada';

  @override
  String homeScreenBrightness(int percent) {
    return 'Brilho $percent%';
  }

  @override
  String get homeScreenOn => 'Tela ligada';

  @override
  String get homeScreenTurnOff => 'Desligar a tela';

  @override
  String get homeScreenTurnOn => 'Ligar a tela';

  @override
  String get homeDevicesTitle => 'Dispositivos';

  @override
  String get homeDevicesSearching => 'Procurando…';

  @override
  String get homeDevicesNone => 'Nenhum dispositivo';

  @override
  String get homeDeviceConnected => 'Conectado';

  @override
  String get homeDeviceStarting => 'Iniciando';

  @override
  String get homeDeviceProblem => 'Com problema';

  @override
  String get homeAssistantTitle => 'Assistente';

  @override
  String get homeAssistantNewChat => 'Nova conversa';

  @override
  String get homeAssistantSuggestionSlow => 'Por que meu PC tá lento?';

  @override
  String get homeAssistantSuggestionGpu => 'O que tá esquentando a GPU?';

  @override
  String get homeAssistantSuggestionEffect => 'Cria um efeito azul calmo';

  @override
  String get homeAssistantConnect =>
      'Conecte uma IA para perguntar sobre o seu PC.';

  @override
  String get homeAssistantConnectHint =>
      'Use sua chave da Anthropic, da OpenAI ou de um serviço compatível.';

  @override
  String get homeAssistantSetUp => 'Configurar IA';

  @override
  String get homeAssistantAskAnything =>
      'Pergunte qualquer coisa sobre o seu PC.';

  @override
  String get homeAssistantThinking => 'Pensando…';

  @override
  String get homeAssistantApplyEffect => 'Aplicar efeito';

  @override
  String get homeAssistantHint => 'Pergunte algo…';

  @override
  String homeAssistantEffectOn(String title) {
    return '\"$title\" está ligado.';
  }
}
