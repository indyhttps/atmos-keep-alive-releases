# Atmos Direct Spatial

[Baixar a versão oficial 1.1.0](https://github.com/indyhttps/atmos-keep-alive-releases/releases/tag/ADS-v1.1.0).

O aplicativo Windows 11 x64 usa a saída física escolhida e envia dez objetos estáticos 5.1.4 ao Windows Spatial Audio. A interface traz o visual do Mixer, bandeja, reabertura, preferências, presets e início no login. O código principal é mantido no repositório privado do projeto.

1. Baixe o ZIP da release e confira `SHA256SUMS.txt`.
2. Extraia o pacote completo e abra `AtmosDirectSpatialSetup.exe`.
3. Confirme a instalação ou atualização. Abra pelo menu Iniciar e use **Upmix Atmos** depois de escolher e verificar a saída.

A captura exige Equalizer APO associado à saída física e um provedor espacial compatível. Atualizações preservam a saída registrada mesmo se o equipamento estiver desconectado; a ativação continua exigindo a saída e a rota válidas. O áudio direto permanece liberado enquanto a rota não estiver comprovada.

Consulte [o guia de uso](docs/USO.md) e [a validação](docs/VALIDACAO.md). O upmix sintetiza canais; não recupera objetos autorais de uma gravação estéreo. A entrega aos objetos por software não certifica fisicamente cada caixa ou o receiver.

As releases antigas e suas assinaturas permanecem no histórico. A linha atual usa tags `ADS-*` e `latest=false`, preservando o atualizador do Atmos Keep-Alive. A versão ADS não substitui o executável legado assinado.
