return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = {
          settings = {
            python = {
              analysis = {
                typeCheckingMode = "off",
                autoImportCompletions = true,
                useLibraryCodeForTypes = true,
                autoSearchPaths = true,
              },
            },
          },
        },
        ruff_lsp = {
          on_attach = function(client, _)
            -- pyright fica com o hover; ruff só faz lint/fix
            client.server_capabilities.hoverProvider = false
          end,
        },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = { python = { "ruff_format", "black" } },
    },
  },
  -- Seletor de virtualenv
  {
    "linux-cultist/venv-selector.nvim",
    cmd = "VenvSelect",
    opts = { name = { "venv", ".venv", "env" } },
    keys = { { "<leader>vs", "<cmd>VenvSelect<cr>", desc = "Select venv" } },
  },
}
