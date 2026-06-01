return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ts_ls = {
          settings = {
            typescript = {
              inlayHints = {
                includeInlayParameterNameHints = "all",
                includeInlayReturnTypeHints = true,
                includeInlayVariableTypeHints = true,
              },
            },
          },
        },
        eslint = {
          on_attach = function(_, bufnr)
            vim.api.nvim_create_autocmd("BufWritePre", {
              buffer = bufnr,
              command = "EslintFixAll",
            })
          end,
        },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        javascript = { "prettier" },
        json = { "prettier" },
      },
    },
  },
  -- typescript-tools: alternativa mais rápida ao ts_ls puro
  {
    "pmizio/typescript-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    ft = { "typescript", "typescriptreact", "javascript" },
    opts = {
      settings = {
        expose_as_code_action = "all",
        tsserver_file_preferences = {
          importModuleSpecifierPreference = "relative",
        },
      },
    },
  },
}
