return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        gopls = {
          settings = {
            gopls = {
              analyses = {
                unusedparams = true,
                shadow = true,
                fieldalignment = true,
              },
              staticcheck = true,
              gofumpt = true,
              usePlaceholders = true,
              hints = {
                assignVariableTypes = true,
                compositeLiteralFields = true,
                functionTypeParameters = true,
                parameterNames = true,
                rangeVariableTypes = true,
              },
            },
          },
        },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = { go = { "gofumpt", "goimports" } },
    },
  },
  -- Plugin extra com comandos Go (test, run, tags...)
  {
    "ray-x/go.nvim",
    dependencies = { "ray-x/guihua.lua" },
    ft = { "go", "gomod" },
    build = ':lua require("go.install").update_all_sync()',
    opts = {},
  },
}
