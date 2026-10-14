# Usar o Atmos Direct Spatial 1.1.0

## Instalar ou atualizar

Extraia o pacote completo em uma pasta e abra **AtmosDirectSpatialSetup.exe**, na raiz. O assistente usa o mesmo visual do aplicativo. Confira a operação e clique em **Instalar** ou **Atualizar**; o Windows solicita a autorização necessária.

Na atualização, a saída já configurada é preservada. Em instalação inicial, escolha explicitamente a saída física. A integração exige Equalizer APO associado a essa saída e Windows Spatial Audio configurado no equipamento compatível. O assistente e o controlador conferem os requisitos; a interface não instala um dispositivo virtual.

## Abrir e ativar

Abra o Atmos pelo atalho instalado. Escolha a saída física, pause músicas, vídeos e jogos por alguns segundos e clique em **Upmix Atmos**. A ativação depende da verificação da captura e da rota. **Pronto sem sinal** indica que a rota foi validada sem sinal útil naquele momento. **Processando áudio** indica captura e entrega de áudio pelo software.

Esses estados não substituem a conferência física do receiver e das caixas. O upmix sintetiza canais 5.1.4; não recupera objetos autorais de uma gravação estéreo.

## Controles

| Controle | O que faz |
|---|---|
| Saída de som | Seleciona o destino físico do controlador; não muda a saída de outros apps |
| Volume da saída | Ajusta o volume dessa saída no Windows |
| Silenciar saída | Alterna o mute do dispositivo selecionado |
| Upmix Atmos | Verifica a rota e solicita ativação |
| Áudio direto | Pausa o upmix e libera o som original |
| Surround adaptativo | Alterna o modo dinâmico do processamento preservado |
| Iniciar com o Windows | Abre na bandeja no login; a ativação permanece manual |
| Reconectar | Atualiza as saídas e pausa para uma nova verificação |
| Fechar | Oculta a janela e mantém o programa funcionando |
| Sair | Encerra o programa e libera o áudio direto |
| Diagnóstico | Mostra o estado e permite copiar o relatório |
| Desinstalar | Abre o assistente da instalação para conferir e remover |

Clique nos três pontos do cartão de estado para abrir preferências, presets e instruções. O modo incógnito oculta o ícone da bandeja; abra o atalho do Atmos para voltar. A consulta de atualizações acontece quando você escolhe **Verificar atualizações**.

## Se a ativação for bloqueada

Leia a mensagem do cartão e os detalhes da rota. Confirme que os apps reproduzem na mesma saída, que o efeito de captura está associado a ela e que o modo espacial compatível está habilitado. Alterações de saída, formato, volume ou configuração de captura podem exigir nova verificação. O aplicativo preserva o áudio direto enquanto a rota não estiver validada.

## Onde ficam os arquivos

A instalação protegida fica em `%PROGRAMDATA%/AtmosDirectSpatial`. A interface usa uma pasta própria de versão em `app/`. Preferências e presets ficam em `%LOCALAPPDATA%/AtmosDirectSpatial`. Backups e registros do instalador são separados dos dados da interface. Não copie ou edite arquivos do efeito de captura manualmente durante o funcionamento.

O pacote extraído é a origem da instalação; o aplicativo instalado é acessado pelo atalho. O projeto de desenvolvimento tem seu mapa em `README.md` e `docs/ESTRUTURA.md`.
