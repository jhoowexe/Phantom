# Phantom  - Triage & Anti-Forensics Tool

**Phantom ** é uma ferramenta avançada de triagem forense e coleta de inteligência para Linux, projetada para operações de Red Teaming e Resposta a Incidentes que exigem máxima furtividade e segurança operacional (OPSEC).

A ferramenta opera sob o conceito de "Hit-and-Run": coleta artefatos críticos, exfiltra os dados via canal seguro e executa uma limpeza anti-forense completa, sem deixar rastros recuperáveis no disco.

## 🚀 Funcionalidades Principais

* ** Ghost Mode (RAM-Only):** Opera inteiramente em `/dev/shm` (memória RAM). Nenhum dado toca o disco físico, mitigando recuperação forense tradicional.
* ** Anonimato via Tor:** Roteia todo o tráfego de exfiltração através da rede Tor (via `torsocks`) para ocultar o IP de origem.
* ** Stealth Local:** Suporte a MAC Spoofing automatizado e verificação de VPN ativa antes da execução.
* ** Exfiltração Automática:** Envia os dados coletados via **Netcat** ou **SSH/SCP** antes de iniciar a sequência de destruição.
* ** Sequência de Auto-destruição (Burn):** Utiliza algoritmos de *shredding* para sobrescrever dados na RAM e deletar o próprio script de forma irrecuperável.
* ** Coleta Profunda:**
    * Histórico e Cookies de Navegadores (Firefox, Chrome, Chromium, Brave).
    * Sessões de Mensageiros (Telegram Desktop, Discord).
    * Logs de Sistema e Autenticação (Journalctl, Auth.log).

##  Instalação e Dependências

A ferramenta verifica as dependências automaticamente, mas requer um ambiente Kali Linux ou Debian-based com:

```bash
sudo apt update
sudo apt install tor torsocks macchanger python3 sqlite3 curl
