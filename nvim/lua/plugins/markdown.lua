return {
  -- Renderização inline do markdown direto no buffer (estilo Obsidian)
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    ft = { "markdown" },
    opts = {
      heading = {
        enabled = true,
        sign = true,
        icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
      },
      code = {
        enabled = true,
        sign = true,
        style = "full", -- "full" | "normal" | "language" | "none"
        border = "thin",
      },
      bullet = {
        enabled = true,
        icons = { "●", "○", "◆", "◇" },
      },
      checkbox = {
        enabled = true,
        unchecked = { icon = "󰄱 " },
        checked = { icon = "󰱒 " },
      },
      quote = {
        enabled = true,
        icon = "▋",
      },
      table = {
        enabled = true,
        style = "full",
      },
      win_options = {
        conceallevel = { default = 0, rendered = 3 },
      },
    },
  },

  -- Preview no navegador
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    build = function()
      vim.fn.system("cd app && npm install")
    end,
    ft = { "markdown" },
    init = function()
      vim.g.mkdp_auto_start = 0 -- não abrir preview automaticamente
      vim.g.mkdp_auto_close = 1 -- fechar aba ao sair do buffer
      vim.g.mkdp_refresh_slow = 0 -- atualizar em tempo real
      vim.g.mkdp_browser = "" -- "" usa o navegador padrão do sistema
      vim.g.mkdp_theme = "dark" -- "dark" | "light"
    end,
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown Preview" },
    },
  },

  -- Preview no terminal (split flutuante)
  {
    "ellisonleao/glow.nvim",
    cmd = "Glow",
    ft = { "markdown" },
    opts = {
      style = "dark", -- "dark" | "light" | "auto"
      width = 120,
      height = 100,
      width_ratio = 0.8,
      height_ratio = 0.8,
    },
    keys = {
      { "<leader>mg", "<cmd>Glow<cr>", desc = "Glow Preview" },
    },
  },
}
