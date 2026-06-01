#!/usr/bin/env bash
# =============================================================================
# setup.sh — Bootstrap do ambiente Linux (Ubuntu/Debian)
# Baseado nos dotfiles: sway, waybar, kitty, nvim, cmus, tmux, zsh
# =============================================================================
set -euo pipefail

# ─── Cores ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

# ─── Helpers ─────────────────────────────────────────────────────────────────
log_section() {
    echo -e "\n${BLUE}══════════════════════════════════════${RESET}"
    echo -e "${CYAN}  $1${RESET}"
    echo -e "${BLUE}══════════════════════════════════════${RESET}"
}
log_ok() { echo -e "  ${GREEN}✓${RESET} $1"; }
log_warn() { echo -e "  ${YELLOW}⚠${RESET}  $1"; }
log_error() { echo -e "  ${RED}✗${RESET} $1"; }
log_info() { echo -e "  ${CYAN}→${RESET} $1"; }

confirm() {
    read -r -p "$(echo -e "  ${YELLOW}?${RESET} $1 [s/N] ")" answer
    [[ "${answer,,}" == "s" || "${answer,,}" == "y" ]]
}

apt_install() {
    sudo apt-get install -y --no-install-recommends "$@" 2>/dev/null &&
        log_ok "Instalado: $*" ||
        log_warn "Não disponível ou já instalado: $*"
}

already_installed() {
    command -v "$1" &>/dev/null
}

# ─── Verificações iniciais ────────────────────────────────────────────────────
if [[ "$EUID" -eq 0 ]]; then
    log_error "Não rode como root. Use seu usuário normal."
    exit 1
fi

if ! command -v apt-get &>/dev/null; then
    log_error "Este script requer apt (Debian/Ubuntu)."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_section "Setup do Ambiente Linux — Dotfiles Bootstrap"
echo -e "  Usuário : ${GREEN}$(whoami)${RESET}"
echo -e "  Home    : ${GREEN}$HOME${RESET}"
echo -e "  Distro  : ${GREEN}$(lsb_release -ds 2>/dev/null || echo 'Desconhecida')${RESET}"
echo ""

# =============================================================================
# 1. ATUALIZAÇÃO DO SISTEMA
# =============================================================================
log_section "1. Atualização do sistema"

log_info "Atualizando listas de pacotes..."
sudo apt-get update -qq
log_info "Upgrade dos pacotes existentes..."
sudo apt-get upgrade -y -qq
log_ok "Sistema atualizado"

# =============================================================================
# 2. DEPENDÊNCIAS BASE
# =============================================================================
log_section "2. Dependências base"

BASE_PKGS=(
    curl wget git unzip zip tar
    build-essential pkg-config
    ca-certificates gnupg lsb-release software-properties-common
    xdg-utils dbus-x11 dex
    libsecret-1-0 gnome-keyring libpam-gnome-keyring
    xss-lock i3lock
)

for pkg in "${BASE_PKGS[@]}"; do
    apt_install "$pkg"
done

# =============================================================================
# 3. ZSH + OH MY ZSH + ZINIT
# =============================================================================
log_section "3. Zsh + Oh My Zsh + Zinit"

apt_install zsh

# Definir zsh como shell padrão
if [[ "$SHELL" != "$(which zsh)" ]]; then
    log_info "Definindo zsh como shell padrão..."
    chsh -s "$(which zsh)"
    log_ok "Shell padrão alterado para zsh (efetivo no próximo login)"
else
    log_ok "zsh já é o shell padrão"
fi

# Oh My Zsh
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log_info "Instalando Oh My Zsh..."
    RUNZSH=no CHSH=no sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    log_ok "Oh My Zsh instalado"
else
    log_ok "Oh My Zsh já instalado"
fi

# Plugin: zsh-syntax-highlighting (usado no .zshrc)
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
SYNTAX_HIGHLIGHT_DIR="$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

if [[ ! -d "$SYNTAX_HIGHLIGHT_DIR" ]]; then
    log_info "Instalando plugin zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "$SYNTAX_HIGHLIGHT_DIR"
    log_ok "zsh-syntax-highlighting instalado"
else
    log_ok "zsh-syntax-highlighting já instalado"
fi

# Zinit (instalado pelo próprio .zshrc na primeira execução, mas garantimos o dir)
if [[ ! -d "$HOME/.local/share/zinit/zinit.git" ]]; then
    log_info "Pré-instalando Zinit..."
    mkdir -p "$HOME/.local/share/zinit"
    chmod g-rwX "$HOME/.local/share/zinit"
    git clone https://github.com/zdharma-continuum/zinit \
        "$HOME/.local/share/zinit/zinit.git"
    log_ok "Zinit instalado"
else
    log_ok "Zinit já instalado"
fi

# Copiar .zshrc para ~/
ZSHRC_SRC="$SCRIPT_DIR/.zshrc"
if [[ -f "$ZSHRC_SRC" ]]; then
    if [[ -f "$HOME/.zshrc" ]]; then
        log_warn "~/.zshrc já existe — fazendo backup em ~/.zshrc.bak"
        cp "$HOME/.zshrc" "$HOME/.zshrc.bak"
    fi
    cp "$ZSHRC_SRC" "$HOME/.zshrc"
    log_ok ".zshrc copiado para $HOME/.zshrc"
else
    log_warn ".zshrc não encontrado em $SCRIPT_DIR — configure manualmente"
fi

# =============================================================================
# 4. SWAY + WAYLAND
# =============================================================================
log_section "4. Sway + Wayland"

SWAY_PKGS=(
    sway swaybg swayidle
    wofi       # launcher (sway/config: wofi --show drun)
    grim slurp # screenshot (bindsym Shift+Print)
    wl-clipboard
    xwayland # compatibilidade X11
)

for pkg in "${SWAY_PKGS[@]}"; do
    apt_install "$pkg"
done

# swaylock-effects (substitui swaylock padrão — usado no alias lock do .zshrc)
# Requer compilação pois não está nos repos oficiais
install_swaylock_effects() {
    log_info "Compilando swaylock-effects..."

    local deps=(
        libwayland-dev wayland-protocols
        libxkbcommon-dev libcairo2-dev
        libgdk-pixbuf-2.0-dev libpam0g-dev
        meson ninja-build scdoc
    )
    for dep in "${deps[@]}"; do
        apt_install "$dep"
    done

    local tmp_dir
    tmp_dir=$(mktemp -d)

    git clone https://github.com/mortie/swaylock-effects.git "$tmp_dir/swaylock-effects"
    cd "$tmp_dir/swaylock-effects"
    meson setup build
    ninja -C build
    sudo ninja -C build install
    cd - >/dev/null
    rm -rf "$tmp_dir"

    log_ok "swaylock-effects instalado: $(swaylock --version 2>/dev/null || echo 'ok')"
}

if already_installed swaylock && swaylock --help 2>&1 | grep -q 'effect'; then
    log_ok "swaylock-effects já instalado"
else
    install_swaylock_effects
fi

# =============================================================================
# 5. WAYBAR
# =============================================================================
log_section "5. Waybar"

apt_install waybar

# =============================================================================
# 6. TERMINAL: Kitty + Tmux
# =============================================================================
log_section "6. Kitty + Tmux"

apt_install tmux

if ! already_installed kitty; then
    log_info "Instalando Kitty via instalador oficial..."
    curl -fsSL https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
    mkdir -p "$HOME/.local/bin"
    ln -sf "$HOME/.local/kitty.app/bin/kitty" "$HOME/.local/bin/kitty"
    ln -sf "$HOME/.local/kitty.app/bin/kitten" "$HOME/.local/bin/kitten"
    log_ok "Kitty instalado"
else
    log_ok "Kitty já instalado: $(kitty --version)"
fi

# =============================================================================
# 7. GO (via tarball oficial — versão mais recente)
# =============================================================================
log_section "7. Go"

install_go() {
    local go_version
    go_version=$(curl -fsSL https://go.dev/VERSION?m=text | head -1)
    local go_url="https://go.dev/dl/${go_version}.linux-amd64.tar.gz"
    local tmp_file
    tmp_file=$(mktemp /tmp/go-XXXXXX.tar.gz)

    log_info "Baixando Go ${go_version}..."
    curl -fsSL "$go_url" -o "$tmp_file"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "$tmp_file"
    rm -f "$tmp_file"

    # Garantir no PATH do zshrc se não estiver
    if ! grep -q '/usr/local/go/bin' "$HOME/.zshrc" 2>/dev/null; then
        echo 'export PATH="$PATH:/usr/local/go/bin:$HOME/go/bin"' >>"$HOME/.zshrc"
    fi

    export PATH="$PATH:/usr/local/go/bin:$HOME/go/bin"
    log_ok "Go instalado: $(go version)"
}

if already_installed go; then
    log_ok "Go já instalado: $(go version)"
else
    install_go
fi

# Go tools para Neovim (gopls, gofumpt, goimports)
if already_installed go; then
    log_info "Instalando ferramentas Go..."
    go install golang.org/x/tools/gopls@latest 2>/dev/null && log_ok "gopls" || log_warn "gopls falhou"
    go install mvdan.cc/gofumpt@latest 2>/dev/null && log_ok "gofumpt" || log_warn "gofumpt falhou"
    go install golang.org/x/tools/cmd/goimports@latest 2>/dev/null && log_ok "goimports" || log_warn "goimports falhou"
fi

# =============================================================================
# 8. DOCKER
# =============================================================================
log_section "8. Docker"

install_docker() {
    log_info "Adicionando repositório oficial do Docker..."

    # Chave GPG
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Repositório
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" |
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    sudo apt-get update -qq

    apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Adicionar usuário ao grupo docker (sem precisar de sudo)
    sudo usermod -aG docker "$USER"
    log_ok "Docker instalado — faça logout/login para usar sem sudo"
}

if already_installed docker; then
    log_ok "Docker já instalado: $(docker --version)"
else
    install_docker
fi

# =============================================================================
# 9. NEOVIM
# =============================================================================
log_section "9. Neovim"

install_neovim() {
    local tmp_dir
    tmp_dir=$(mktemp -d)

    log_info "Baixando Neovim (release estável)..."
    curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz" \
        -o "$tmp_dir/nvim.tar.gz"

    sudo rm -rf /opt/nvim-linux-x86_64
    sudo tar -C /opt -xzf "$tmp_dir/nvim.tar.gz"
    sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
    rm -rf "$tmp_dir"
    log_ok "Neovim instalado: $(nvim --version | head -1)"
}

if already_installed nvim; then
    log_ok "Neovim já instalado: $(nvim --version | head -1)"
else
    install_neovim
fi

# Dependências do Neovim / Mason / LSPs
log_info "Instalando dependências do Neovim (LSPs, formatters, tree-sitter)..."

NVIM_DEP_PKGS=(
    nodejs npm
    python3 python3-pip python3-venv
    php php-cli php-xml php-mbstring composer
    gcc g++ make
    ripgrep
    fd-find
    shellcheck shfmt
)

for pkg in "${NVIM_DEP_PKGS[@]}"; do
    apt_install "$pkg"
done

# stylua via cargo (versão apt pode ser antiga)
if ! already_installed stylua; then
    if already_installed cargo; then
        cargo install stylua && log_ok "stylua instalado via cargo"
    else
        apt_install stylua
    fi
fi

# fd symlink (Ubuntu instala como fdfind)
if command -v fdfind &>/dev/null && ! already_installed fd; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(which fdfind)" "$HOME/.local/bin/fd"
    log_ok "Symlink fd → fdfind criado"
fi

# nvm + Node LTS
if [[ ! -d "$HOME/.nvm" ]]; then
    log_info "Instalando nvm..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    nvm install --lts
    log_ok "Node LTS instalado via nvm"
else
    log_ok "nvm já instalado"
fi

# Python tools
log_info "Instalando ferramentas Python (ruff, black, debugpy)..."
pip3 install --user --quiet ruff black debugpy 2>/dev/null &&
    log_ok "ruff, black, debugpy instalados" ||
    log_warn "Falhou ao instalar ferramentas Python"

# =============================================================================
# 10. CMUS + ÁUDIO
# =============================================================================
log_section "10. cmus + Áudio"

AUDIO_PKGS=(
    cmus
    pulseaudio pulseaudio-utils
    pamixer     # binds de volume no sway
    playerctl   # teclas de mídia
    pavucontrol # GUI de áudio
)

for pkg in "${AUDIO_PKGS[@]}"; do
    apt_install "$pkg"
done

# =============================================================================
# 11. REDE + BLUETOOTH
# =============================================================================
log_section "11. Rede + Bluetooth"

NET_BT_PKGS=(
    network-manager
    network-manager-gnome
    blueman
    bluetooth bluez
)

for pkg in "${NET_BT_PKGS[@]}"; do
    apt_install "$pkg"
done

# =============================================================================
# 12. BRILHO + UTILITÁRIOS DO SISTEMA
# =============================================================================
log_section "12. Brilho + Utilitários do sistema"

SYSTEM_PKGS=(
    brightnessctl
    libnotify-bin
    dunst
    xdg-desktop-portal-wlr
    polkit-gnome
)

for pkg in "${SYSTEM_PKGS[@]}"; do
    apt_install "$pkg"
done

# =============================================================================
# 13. FONTES: JetBrainsMono Nerd Font
# =============================================================================
log_section "13. Fontes — JetBrainsMono Nerd Font"

FONTS_DIR="$HOME/.local/share/fonts"
FONT_TAG="v3.2.1"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_TAG}/JetBrainsMono.zip"

if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
    log_ok "JetBrainsMono Nerd Font já instalada"
else
    log_info "Baixando JetBrainsMono Nerd Font ${FONT_TAG}..."
    mkdir -p "$FONTS_DIR"
    local_zip=$(mktemp /tmp/JetBrainsMono-XXXXXX.zip)
    curl -fsSL "$FONT_URL" -o "$local_zip"
    unzip -q "$local_zip" -d "$FONTS_DIR/JetBrainsMono"
    fc-cache -f "$FONTS_DIR"
    rm -f "$local_zip"
    log_ok "JetBrainsMono Nerd Font instalada"
fi

# =============================================================================
# 14. DOTFILES
# =============================================================================
log_section "14. Dotfiles"

DOTFILES_REPO="https://github.com/suhai/dotfiles.git" # ← ajuste se necessário
DOTFILES_DIR="$HOME/.dotfiles"

if confirm "Clonar e aplicar dotfiles de '$DOTFILES_REPO'?"; then
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
        log_ok "Dotfiles clonados em $DOTFILES_DIR"
    else
        log_warn "Diretório $DOTFILES_DIR já existe, pulando clone"
    fi

    declare -A LINKS=(
        ["$DOTFILES_DIR/sway"]="$HOME/.config/sway"
        ["$DOTFILES_DIR/waybar"]="$HOME/.config/waybar"
        ["$DOTFILES_DIR/kitty"]="$HOME/.config/kitty"
        ["$DOTFILES_DIR/nvim"]="$HOME/.config/nvim"
        ["$DOTFILES_DIR/cmus"]="$HOME/.config/cmus"
        ["$DOTFILES_DIR/i3"]="$HOME/.config/i3"
    )

    for src in "${!LINKS[@]}"; do
        dst="${LINKS[$src]}"
        if [[ -d "$src" ]]; then
            mkdir -p "$(dirname "$dst")"
            if [[ -L "$dst" ]]; then
                log_warn "Symlink já existe: $dst"
            elif [[ -d "$dst" ]]; then
                log_warn "Diretório já existe (não sobrescrito): $dst"
            else
                ln -s "$src" "$dst"
                log_ok "Symlink: $dst → $src"
            fi
        fi
    done
else
    log_warn "Dotfiles pulados. Configure manualmente em ~/.config/"
fi

# =============================================================================
# 15. PATH — ~/.local/bin e Go
# =============================================================================
log_section "15. Configuração de PATH"

ZSHRC="$HOME/.zshrc"

add_to_zshrc() {
    local line="$1"
    local label="$2"
    if ! grep -qF "$line" "$ZSHRC" 2>/dev/null; then
        echo "$line" >>"$ZSHRC"
        log_ok "$label adicionado ao .zshrc"
    else
        log_ok "$label já presente no .zshrc"
    fi
}

add_to_zshrc 'export PATH="$HOME/.local/bin:$PATH"' "~/.local/bin"
add_to_zshrc 'export PATH="$PATH:/usr/local/go/bin"' "/usr/local/go/bin"
add_to_zshrc 'export PATH="$PATH:$HOME/go/bin"' "~/go/bin"
add_to_zshrc 'export PATH="$PATH:/opt/nvim-linux-x86_64/bin"' "nvim PATH"

# =============================================================================
# RESUMO FINAL
# =============================================================================
log_section "✓ Setup concluído"

echo -e "  ${GREEN}Instalado:${RESET}"
echo -e "    • Zsh + Oh My Zsh + Zinit + zsh-syntax-highlighting"
echo -e "    • .zshrc copiado para ~/"
echo -e "    • Sway + Wayland (wofi, grim, slurp)"
echo -e "    • swaylock-effects (alias lock com blur)"
echo -e "    • Waybar"
echo -e "    • Kitty + Tmux"
echo -e "    • Go (tarball oficial + gopls, gofumpt, goimports)"
echo -e "    • Docker CE + Compose plugin"
echo -e "    • Neovim (+ LSP deps: node, python, php, ripgrep, fd)"
echo -e "    • cmus + pamixer + playerctl + pavucontrol"
echo -e "    • NetworkManager + Blueman"
echo -e "    • brightnessctl + dunst"
echo -e "    • JetBrainsMono Nerd Font"
echo ""
echo -e "  ${YELLOW}Próximos passos:${RESET}"
echo -e "    1. Faça logout/login (zsh como padrão + grupo docker)"
echo -e "    2. Abra o Neovim — LazyVim instalará os plugins automaticamente"
echo -e "    3. No Neovim: :MasonInstall debugpy gopls intelephense ts_ls"
echo -e "    4. Coloque a wallpaper em ~/.config/sway/WallPaper.png"
echo -e "    5. Ajuste DOTFILES_REPO no script para seu repositório real"
echo ""
