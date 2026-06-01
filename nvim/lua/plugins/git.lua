return {
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      current_line_blame = true, -- blame inline na linha atual
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol", -- aparece no final da linha
        delay = 300,
      },
      current_line_blame_formatter = "<author>, <author_time:%d/%m/%Y> - <summary>",
      on_attach = function(bufnr)
        local gs = require("gitsigns")

        vim.keymap.set("n", "<leader>gb", gs.blame_line, {
          buffer = bufnr,
          desc = "Git Blame linha atual",
        })

        vim.keymap.set("n", "<leader>gB", function()
          gs.blame_line({ full = true })
        end, {
          buffer = bufnr,
          desc = "Git Blame completo",
        })

        vim.keymap.set("n", "<leader>tb", gs.toggle_current_line_blame, {
          buffer = bufnr,
          desc = "Toggle blame inline",
        })
      end,
    },
  },
}
