# Atmos Keep-Alive — releases

Repositorio PUBLICO exclusivo das releases assinadas do **Atmos Keep-Alive** (o codigo-fonte vive em repositorio privado).

## Instalar / atualizar

Baixe o `AtmosKeepAlive.exe` da release mais recente e execute — ele e o proprio instalador (copia-se para `%LOCALAPPDATA%\AtmosKeepAlive`, configura o autostart e fica na bandeja). Instalacoes v4+ se atualizam sozinhas consultando este repositorio.

## Assinatura

Cada release traz o exe e o `.sig` (RSA-3072/SHA-256). O app do campo VERIFICA a assinatura antes de instalar qualquer update e RECUSA release sem `.sig` valido (fail-closed).