# BigLinuxCleaner

Script Bash para limpeza e manutenção do **Big Linux** (e outros sistemas baseados em Arch com KDE Plasma). Ele realiza as seguintes tarefas automaticamente:

- **Remove pacotes órfãos** via `pacman` (pacotes instalados como dependência que não são mais necessários).
- **Limpa atalhos quebrados** (`.desktop`) no menu de aplicativos — verifica entradas inválidas nos diretórios do sistema, do usuário, do Flatpak e do Snap.
- **Corrige ícones da Steam** — detecta atalhos da Steam com ícones faltando ou com resolução insuficiente e baixa o ícone correto automaticamente a partir do ID do jogo na CDN da Steam.
- **Remove atalhos de apps Flatpak desinstalados** cruzando os arquivos `.desktop` com a lista de aplicativos instalados.
- **Remove atalhos de apps Snap desinstalados** de forma semelhante.
- **Limpa o cache do Flatpak** (cache local do usuário e cache global) e remove runtimes/pacotes sem uso.
- **Limpa revisões desabilitadas do Snap** e o cache do daemon.
- **Atualiza o menu e o cache do KDE Plasma** (`kbuildsycoca`, `krunner`, `plasmashell`) para refletir as mudanças imediatamente.
 
 ---

Execute o script diretamente no terminal sem precisar clonar o repositório:

```bash
curl -fsSL https://raw.githubusercontent.com/zonaro/BigLinuxCleaner/main/cleaner.sh | bash
```

> **Atenção:** sempre inspecione scripts antes de executá-los com privilégios. Você pode visualizar o conteúdo completo em [`cleaner.sh`](./cleaner.sh).

## Instalação como atalho (.desktop)

Crie um atalho no seu ambiente (área de trabalho e/ou menu de aplicativos) que executa o `cleaner.sh` direto do GitHub — sem precisar clonar o repositório. O atalho abre no **seu terminal padrão** (detectado automaticamente na instalação — konsole, kitty, gnome-terminal, wezterm e outros), roda a limpeza e fica aberto até você pressionar Enter.

```bash
# A partir do repositório clonado
./install.sh

# Ou diretamente do GitHub
curl -fsSL https://raw.githubusercontent.com/zonaro/BigLinuxCleaner/main/install.sh | bash
```

O instalador pergunta onde você quer o atalho (**Área de trabalho**, **Menu de aplicativos** ou **ambos**), instala o ícone oficial (PNG em múltiplos tamanhos: 256/128/64 px) e atualiza o menu do KDE Plasma automaticamente.

Para remover o atalho e o ícone (também direto do GitHub):

```bash
curl -fsSL https://raw.githubusercontent.com/zonaro/BigLinuxCleaner/main/install.sh | bash -s -- --uninstall
```

## Uso manual

```bash
# Clone o repositório
git clone https://github.com/zonaro/BigLinuxCleaner.git
cd BigLinuxCleaner

# Torne o script executável e execute
chmod +x cleaner.sh
./cleaner.sh
```

## Requisitos

| Ferramenta          | Obrigatória | Observação                               |
| ------------------- | ----------- | ---------------------------------------- |
| `bash` ≥ 4          | ✅           | Necessário para arrays associativos      |
| `pacman`            | ✅           | Limpeza de órfãos (Arch/BigLinux)        |
| `sudo`              | ✅           | Remoção de arquivos em `/usr` e `/var`   |
| `curl`              | ✅           | Download de ícones da Steam              |
| `flatpak`           | ⬜           | Ignorado se não encontrado               |
| `snap`              | ⬜           | Ignorado se não encontrado               |
| `kbuildsycoca5`/`6` | ⬜           | Atualização do KDE (ignorado se ausente) |
| `convert`           | ⬜           | ImageMagick — converte ícones para PNG   |

## Licença

Distribuído sob a licença MIT. Consulte o arquivo [LICENSE](./LICENSE) para mais detalhes.
