# Como gerar o .exe e publicar uma versão

## Uma vez só: preparar o PC

1. **Flutter** 3.47 ou mais novo:
   <https://docs.flutter.dev/get-started/install/windows>. Confira com
   `flutter doctor`.
2. **Visual Studio 2022 ou mais novo** (o Community é grátis) com a carga
   **"Desenvolvimento para desktop com C++"**.
3. **Inno Setup 6**, que monta o instalador:

   ```powershell
   winget install JRSoftware.InnoSetup
   ```

   Sem ele o script ainda gera o `.zip` portátil, só não gera o instalador.

## Rodar durante o desenvolvimento

```powershell
flutter pub get
flutter run -d windows
```

## Gerar o .exe (a versão para publicar)

1. Escolha o número da versão no `pubspec.yaml`, na linha `version:`. O
   formato é `1.2.3+4`: o `1.2.3` é a versão que aparece para o usuário e o
   `+4` é um contador interno que sobe a cada build.
2. No PowerShell, na pasta do projeto:

   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\build-release.ps1
   ```

   O script:
   - roda `flutter analyze` e `flutter test` e para se algo falhar;
   - compila o app em modo release com a versão do `pubspec.yaml`;
   - junta o `.exe`, as DLLs (inclusive as do Visual C++, para rodar em PCs
     que não têm) e os dados em `dist\OpenChroma-<versão>\`;
   - cria o `.zip` portátil e o instalador;
   - escreve os checksums SHA-256.

   Opções: `-Version 1.2.3` usa outra versão sem mexer no `pubspec.yaml`;
   `-NoInstaller` gera só o `.zip`; `-SkipBuild` reaproveita o último build.

3. O resultado fica em `dist\`:

   | Arquivo | Para quê |
   |---|---|
   | `OpenChroma-<versão>-setup.exe` | Instalador. Não pede administrador, cria atalho no menu Iniciar e instala o WebView2 se faltar. É o que a maioria deve baixar. |
   | `OpenChroma-<versão>-portable.zip` | Versão portátil: extrair e abrir o `openchroma.exe`. |
   | `SHA256SUMS.txt` | Os checksums, para quem quiser conferir o download. |

   A pasta `dist\` não vai para o git.

Avisos que podem aparecer e são normais: `Nuget is not installed` e um aviso
do CMake sobre `CMP0175` no `webview_windows`.

## Publicar no GitHub

1. Faça commit da mudança de versão e envie: `git push`.
2. No GitHub, abra o repositório e vá em **Releases → Draft a new release**.
3. Em **Choose a tag**, digite `v1.2.3` (a mesma versão) e clique em
   **Create new tag: v1.2.3 on publish**.
4. Título: `OpenChroma 1.2.3`. Na descrição, liste o que mudou. O botão
   **Generate release notes** monta uma lista a partir dos commits.
5. Arraste os três arquivos de `dist\` para a área de anexos.
6. Clique em **Publish release**.

O link `https://github.com/Dnowdd/OpenChroma/releases/latest` sempre aponta
para a versão mais nova.

## Testar antes de publicar

- **Portátil:** extraia o `.zip` em outra pasta e abra o `openchroma.exe`.
- **Instalador, sem mexer no seu sistema:**

  ```powershell
  dist\OpenChroma-1.2.3-setup.exe /VERYSILENT /CURRENTUSER /DIR="$env:TEMP\oc-teste"
  & "$env:TEMP\oc-teste\unins000.exe" /VERYSILENT
  ```

  Atenção: desinstalar apaga as opções "abrir com o Windows" e "continuar em
  segundo plano" (`HKCU\Software\OpenChroma`), que são as mesmas da sua
  cópia de desenvolvimento. As configurações em `%APPDATA%\OpenChroma`
  continuam.
- **PC "limpo":** o melhor teste é a Área Restrita do Windows (Windows
  Sandbox, no Windows Pro). Ela não tem Visual C++ nem nada instalado, como o
  PC de quem vai baixar.

## Sobre o aviso do SmartScreen

Como o `.exe` não é assinado digitalmente, na primeira vez o Windows mostra
"O Windows protegeu o computador". A pessoa clica em **Mais informações →
Executar assim mesmo**. Para sumir com o aviso é preciso um certificado de
assinatura de código (veja o [ROADMAP](../ROADMAP.md)).
