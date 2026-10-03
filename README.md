# Atmos Direct Spatial e releases do Atmos Keep-Alive

A nova versao funciona na saida fisica escolhida, sem VB-CABLE ou outro dispositivo virtual. O upmix envia dez objetos espaciais estaticos 5.1.4 ao Windows Spatial Audio.

[Baixar Atmos Direct Spatial 1.0.0](https://github.com/indyhttps/atmos-keep-alive-releases/releases/tag/ADS-v1.0.0).

1. Baixe o ZIP Windows x64 e extraia a pasta inteira.
2. Abra `AtmosDirectSpatialSetup.exe` normalmente e selecione a saida fisica ja associada ao Equalizer APO.
3. Clique em Instalar. Depois, abra o app pelo menu Iniciar, pause as fontes e use **Verificar e ativar**.

Equalizer APO 1.4.2 x64 e um provedor espacial compativel na saida escolhida sao requisitos. Para um receiver Atmos via HDMI, habilite Dolby Atmos para home theater nessa saida. O setup oferece atualizar e desinstalar; a remocao tambem aparece nos aplicativos instalados do Windows. Os backups e as configuracoes externas sao preservados. Se o motor mantiver um arquivo ocupado, feche os aplicativos de audio e tente novamente.

Veja [o manual](AtmosDirectSpatial/LEIA-ME.txt) e [o escopo de validacao](AtmosDirectSpatial/VALIDATION.md). O codigo-fonte e mantido no repositorio privado do projeto. Este repositorio publico contem os artefatos e a documentacao para distribuicao.

O upmix gera distribuicao espacial a partir do audio de entrada. Nao recupera os objetos autorais de uma mixagem Atmos original. Nao foi medido um ganho adicional de fidelidade ou a latencia ponta a ponta nesta versao.

As releases antigas do Atmos Keep-Alive e suas assinaturas permanecem no historico. A nova linha usa nomes `AtmosDirectSpatial` e tags `ADS-*`, com `latest=false`, preservando o feed do atualizador legado e suas verificacoes RSA/SHA-256. O novo produto nao e fornecido como substituicao assinada de `AtmosKeepAlive.exe`.
