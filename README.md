```text
  _____  _                 _                    
 |  __ \| |               | |                   
 | |__) | |__   __ _ _ __ | |_ ___  _ __ ___    
 |  ___/| '_ \ / _` | '_ \| __/ _ \| '_ ` _ \   
 | |    | | | | (_| | | | | || (_) | | | | | |  
 |_|    |_| |_|\__,_|_| |_|\__\___/|_| |_| |_|  
                                                
        :: Phantom Elite v1.0 ::
```

# Phantom — Linux Triage Toolkit (IR & Forensics)

**Phantom** é uma ferramenta de **triagem forense** e **coleta rápida de artefatos** em sistemas Linux, pensada para **Resposta a Incidentes (IR)**, **DFIR** e **auditorias autorizadas** — com foco em portabilidade, organização dos achados e boas práticas de evidência.

> **Nota importante:** eu posso ajudar a melhorar o README e a apresentação do projeto, mas não vou incluir instruções/funcionalidades que facilitem **evasão, anti-forense, exfiltração furtiva ou auto-destruição**. Se você estiver conduzindo um trabalho legítimo, o caminho correto é **preservação de evidências**, cadeia de custódia e transferência controlada.

---

## Sumário

- [Visão geral](#visão-geral)
- [Funcionalidades](#funcionalidades)
- [Coleta (artefatos)](#coleta-artefatos)
- [Instalação](#instalação)
- [Uso](#uso)
- [Saída e integridade](#saída-e-integridade)
- [Disclaimer](#disclaimer)
- [Tags (tópicos)](#tags-tópicos)

---

## Visão geral

O Phantom segue o conceito de **triagem rápida**: coletar evidências e indicadores relevantes **sem “investigar demais” no host**, reduzindo tempo de exposição e padronizando a coleta para facilitar análise posterior (workstation de DFIR, SIEM, sandbox etc.).

---

## Funcionalidades

- **Triage “Hit-and-Run” (coleta rápida):** empacota artefatos críticos para análise posterior.
- **Execução com foco em minimização de impacto:** coleta preferencialmente em modo leitura e registra o que foi executado.
- **Output padronizado:** organiza resultados por categoria (logs, usuários, rede, navegadores, etc.).
- **Verificação de integridade:** gera hashes (ex.: SHA-256) do pacote final e, opcionalmente, hashes por arquivo.
- **Compatível com ambientes Debian/Kali-based** (ajuste simples para outras distros).

---

## Coleta (artefatos)

Exemplos de módulos/itens normalmente coletados:

- **Sistema e identidade**
  - Kernel, distro, hostname, uptime
  - Usuários, grupos, sudoers
- **Processos e persistência**
  - Processos atuais, serviços, timers/cron, unidades systemd
- **Rede**
  - Interfaces, rotas, conexões, resolv.conf, hosts
- **Logs**
  - `journalctl` (quando disponível)
  - Logs de autenticação (ex.: `/var/log/auth.log`, quando existir)
- **Navegadores (quando aplicável)**
  - Perfis e metadados de navegadores (Firefox/Chromium/Chrome/Brave) **somente quando houver autorização explícita**, pois pode envolver dados sensíveis.

> **Recomendação:** documente *por que* cada módulo existe e *quando* deve ser ativado (ex.: “somente com consentimento formal”).

---

## Instalação

A ferramenta pode checar dependências automaticamente, mas em ambientes Debian/Kali você costuma precisar de:

```bash
sudo apt update
sudo apt install -y python3 sqlite3 curl
```
## Uso

A coleta geralmente exige privilégios administrativos para ler alguns logs e informações do sistema.

### Ajuda / flags disponíveis

```bash
sudo ./phantom.sh --help
Exemplo de coleta local (modo recomendado para DFIR)
```
```bash

sudo ./phantom.sh --i-have-legal-authorization --output ./phantom-output
Boas práticas: registre o caso, data/hora, hashes, responsável, e mantenha cadeia de custódia (quem coletou, onde armazenou, quem acessou).
```

## Saída e integridade
Sugestão de estrutura de saída:

```bash

phantom-output/
  case.json
  commands.log
  system/
  users/
  network/
  logs/
  browsers/   (quando habilitado e autorizado)
  hashes.txt
  phantom-collection.tar.gz
commands.log: lista comandos executados e erros (se houver).
```
## hashes.txt: hash do pacote final e, opcionalmente, hashes por diretório/arquivo.

## Disclaimer
Este projeto foi desenvolvido para Educação, Pesquisa de Segurança, DFIR e triagem forense autorizada.

 Use apenas em sistemas que você possui ou onde exista permissão explícita e legal.

 Respeite leis locais, políticas internas e requisitos de cadeia de custódia.

 É proibido usar para invadir, ocultar rastros, exfiltrar dados sem autorização ou prejudicar terceiros.

O autor não se responsabiliza por uso indevido.

Tags (tópicos)
bash forensics dfir incident-response triage linux digital-forensics evidence-collection opsec

