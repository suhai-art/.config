return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        intelephense = {
          settings = {
            intelephense = {
              environment = { phpVersion = "8.3" },
              files = { maxSize = 5000000 },
              stubs = {
                "bcmath",
                "Core",
                "curl",
                "date",
                "dom",
                "fileinfo",
                "filter",
                "gd",
                "hash",
                "iconv",
                "json",
                "mbstring",
                "mysqli",
                "pcre",
                "PDO",
                "pdo_mysql",
                "Phar",
                "Reflection",
                "session",
                "SimpleXML",
                "soap",
                "sockets",
                "sodium",
                "SPL",
                "standard",
                "superglobals",
                "tokenizer",
                "xml",
                "zip",
                "zlib",
                "wordpress",
                "phpunit",
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
      formatters_by_ft = { php = { "php_cs_fixer" } },
      formatters = {
        php_cs_fixer = {
          args = { "fix", "--rules=@PSR12", "$FILENAME" },
        },
      },
    },
  },
}
