# Netsimon-bhttp

Servidor de túnel/proxy (BHTTP sobre SSH) usado pelo app **NETSIMON** para estabelecer VPN com autenticação, encapsulamento binário HTTP (BHTTP) e encaminhamento de DNS.

## 🚀 Instalação rápida

```bash
curl -fsSL https://raw.githubusercontent.com/miau4/Netsimon-bhttp/main/install.sh | sudo bash
```

O script baixa o binário, verifica o checksum, cria a configuração padrão em `/etc/netsimon-bhttp/config.json` e sobe o serviço via `systemd` (`netsimon-bhttp.service`), já habilitado para iniciar com o servidor.

---

## 📋 Sobre o projeto

Este repositório nasceu da necessidade de padronizar e automatizar a instalação do serviço que atende as configurações **SSH_BHTTP** do app NETSIMON, evitando depender de cópias manuais entre servidores.

### Como foi identificado o problema original

Durante a configuração de um novo servidor, a conexão via app falhava constantemente com o erro:

```
Erro: java.io.IOException: failed after 0/5 binary BHTTP bytes
```

O diagnóstico passou pelas seguintes etapas:

1. **Comparação de logs** entre um servidor funcional e um com falha — o servidor bom completava o handshake BHTTP, autenticação, abertura de interface `tun` e estabelecimento de VPN; o servidor com falha nunca saía do estágio de handshake.
2. **Inspeção de portas e processos** (`ss -tlnp`, `ps aux`) revelou que, no servidor com problema, a porta 80 estava sendo atendida por um script Python de estudo/laboratório sobre o protocolo OHTTP (Oblivious HTTP, RFC 9458 + RFC 9292) — um exemplo didático sem autenticação real, sem suporte a túnel e sem VPN.
3. **Teste isolado do gateway** (via cliente de teste embutido) confirmou que esse script funcionava tecnicamente (respondia ao protocolo OHTTP), mas não implementava o fluxo completo esperado pelo app (autenticação, interface `tun`, roteamento).
4. **Comparação direta com o servidor funcional** mostrou que a porta 80 lá era atendida por um binário diferente: `proto-server` (identificado nos logs como "DTunnel Protocolo Server"), responsável pelo handshake completo, autenticação do sistema, criação de interface `tun` e proxy transparente em `:80` (sem TLS) e `:443` (com TLS).
5. A causa raiz foi confirmada: **o serviço correto nunca havia sido instalado no novo servidor** — apenas o script de estudo estava rodando na mesma porta, mascarando o problema com respostas HTTP válidas, porém incompletas para o protocolo esperado pelo app.

### Solução implementada

- O binário original foi copiado do servidor funcional, executado sob systemd, e a porta 80 passou a ser atendida corretamente.
- Para eliminar a dependência de copiar o binário manualmente entre servidores a cada nova instalação, o binário foi empacotado (`.tar.gz`) e publicado como *release* neste repositório, junto com um script de instalação (`install.sh`) que automatiza todo o processo:
  - download do binário via GitHub Releases;
  - verificação de integridade via checksum SHA-256;
  - criação da configuração padrão;
  - criação e ativação do serviço `systemd`.

---

## ⚙️ Configuração

O arquivo de configuração fica em `/etc/netsimon-bhttp/config.json`:

```json
{
  "server": {
    "virtual_subnet_cidr": "10.10.0.0/16",
    "stats_file": "/etc/netsimon-bhttp/stats.json",
    "auth": {
      "system": true
    },
    "tun": {
      "name": "tun0",
      "buffer_size": 65536
    }
  },
  "proxy": {
    "enabled": true,
    "listen": [
      { "host": "0.0.0.0", "port": 443, "ssl": true },
      { "host": "0.0.0.0", "port": 80, "ssl": false }
    ]
  }
}
```

| Campo | Descrição |
|---|---|
| `virtual_subnet_cidr` | Faixa de IPs virtuais atribuída aos clientes conectados via túnel |
| `auth.system` | Usa autenticação baseada nos usuários do sistema operacional |
| `tun.name` | Nome da interface de túnel criada no servidor |
| `proxy.listen` | Portas e modos (com/sem SSL) em que o serviço escuta |

Após qualquer alteração na configuração, reinicie o serviço:

```bash
systemctl restart netsimon-bhttp.service
```

---

## 🔍 Comandos úteis

**Ver status do serviço:**
```bash
systemctl status netsimon-bhttp.service
```

**Ver logs em tempo real:**
```bash
journalctl -u netsimon-bhttp.service -f
```

**Verificar se a porta está ativa:**
```bash
ss -tlnp | grep -E ":80|:443"
```

**Reiniciar o serviço:**
```bash
systemctl restart netsimon-bhttp.service
```

---

## 🛠️ Solução de problemas

| Sintoma | Possível causa |
|---|---|
| `failed after 0/5 binary BHTTP bytes` | Porta 80/443 sendo atendida por outro processo (verifique com `ss -tlnp`) |
| Serviço não inicia | Verifique `journalctl -u netsimon-bhttp.service` para detalhes do erro |
| Conflito de porta | Outro serviço (nginx, python, etc.) já escutando na mesma porta — pare-o ou altere a config |
| Checksum inválido na instalação | Baixe novamente; pode indicar corrupção no download ou release desatualizada |

---

## 📦 Releases

Os binários compilados são publicados em [Releases](https://github.com/miau4/Netsimon-bhttp/releases), junto com o hash SHA-256 para verificação de integridade.

---

## ⚠️ Nota sobre o binário

O executável distribuído neste repositório corresponde ao serviço de proxy/túnel utilizado pela infraestrutura NETSIMON. O código-fonte do binário em si não está incluído neste repositório — apenas os artefatos de configuração, automação de instalação e documentação do processo de deploy.
