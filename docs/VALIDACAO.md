# Validação do Atmos Direct Spatial 1.1.0

A versão 1.1.0 reúne a interface WinUI no estilo do Mixer aprovado, o motor C++ e um instalador reversível. A validação distingue funcionamento do software, integridade da instalação e reprodução física no equipamento.

## Código e processamento

O controle do motor e a consulta de estado usam memória, evitando escrita de heartbeat pelo polling da interface. A persistência permanece nas mudanças de preferência. O estado possui snapshot coerente e heartbeat do worker; pedidos antigos, formato incompatível e rota sem prova mantêm o áudio direto.

O bloco DSP e a referência independente têm SHA256 `b40cb4744bde139a713aefdeda9dc5a3556fecb38242ea8f34901e0bd6d620ad`. Os testes comparam 15 cenários e 11.520.000 amostras de saída, incluindo os dez objetos, LFE, ganho, mute e transições do modo adaptativo. Igualdade de amostras não mede fidelidade percebida ou latência de ponta a ponta.

A recuperação de proprietário abandonado usa identidade de processo e prova de término. Metadados antigos, corrompidos ou ambíguos não autorizam recuperação automática. O monitor faz essa verificação fora do callback de áudio. O ABI de transporte v2 foi preservado.

Os dez conjuntos nativos também verificam limites de buffers, callbacks concorrentes, concessão de processamento, parada, calibração, estado, pré-requisitos e helper. A abertura do transporte e o reparo validam o arquivo pelo handle, recusando reparse points e hardlinks antes de mapear ou alterar bytes.

## Interface e preferências

Os testes gerenciados cobrem preferências inválidas e backups, início no login, instância única, shutdown, consulta de atualizações e argumentos do instalador. As telas reais foram verificadas em WinUI: bandeja, fechar, continuar o timer em segundo plano, reabrir a mesma janela, material, fontes e diálogos.

Os ensaios de painel usam limites de área útil de 360 × 900, 260 × 600 e 360 × 420 no monitor atual. São verificações da árvore WinUI com áreas simuladas; não representam execução física em múltiplos monitores e DPIs. Os tokens e a fonte Inter foram comparados com a referência do Mixer documentada em `VISUAL.md`.

## Instalação e recuperação

O bootstrap vincula os arquivos do pacote a um catálogo SHA256 compilado. Durante a operação elevada, mantém os arquivos e diretórios de origem abertos para impedir troca dos scripts e payloads. Aceita operações e identificadores tipados, com origem derivada de seu próprio diretório.

O ciclo de vida registra snapshots e intenção antes de alterar arquivos. O marcador de transação pendente bloqueia ativação. Configuração é comparada e escrita sob o mesmo handle exclusivo; arquivos desconhecidos e edições externas são preservados. Há testes isolados de instalação inicial, atualização schema 1, repetição, encodings/BOM, falhas de preparação, edição concorrente, recuperação interrompida e remoção seguida de reinstalação.

Recuperação se refere a uma instalação interrompida. Uma operação já confirmada não é anunciada como reversão para outra versão. Se um arquivo divergir dos estados registrados, o instalador mantém snapshots e marcador, recusando sobrescrever a alteração desconhecida.

A remoção desassocia a captura e remove registros do produto. Mantém os backups, preferências e arquivos desconhecidos, além do aplicativo e suporte de recuperação inativos com hashes registrados. Isso permite remover a integração enquanto o assistente permanece aberto e reconhecer uma reinstalação segura.

## Reproduzir a validação

```powershell
./scripts/Build.ps1
./tests/install/lifecycle_fixture_tests.ps1 -WorkRoot ./artifacts/tests/lifecycle
./tests/install/bootstrap_fixture_tests.ps1
./scripts/Test-Ui.ps1
./scripts/Package.ps1
```

O instalador e seus fixtures usam Windows PowerShell 5.1. Testes que criam hardlinks ou usam a bandeja precisam de um processo com acesso normal ao shell e ao sistema de arquivos; um sandbox que bloqueie essas operações não comprova falha do aplicativo.

Os relatórios ficam em `artifacts/native`, `artifacts/reports` e `artifacts/tests`. O pacote recusa hashes de fontes ou binários diferentes dos comprovantes. A CI compila e testa fontes e fixtures; a verificação visual ocorre na sessão interativa.

## Limites da evidência

Captura e entrega aos objetos espaciais confirmam o percurso de software. O receiver e cada caixa precisam de conferência física. Esta revisão não estabelece certificação Dolby, recuperação de objetos autorais de áudio estéreo ou ganho medido de latência de ponta a ponta.

A revisão independente examinou os componentes nativos, os serviços e ciclos de vida da interface e o instalador por fonte. A varredura formal iniciada antes da reorganização foi encerrada como inválida para a fonte atual: seu snapshot original mudou. Seus resultados não são usados como selo de segurança da versão nova.
