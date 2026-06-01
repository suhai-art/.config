return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      {
        "rcarriga/nvim-dap-ui",
        dependencies = { "nvim-neotest/nvim-nio" },
        opts = {},
        config = function(_, opts)
          local dap = require("dap")
          local dapui = require("dapui")

          dapui.setup(opts)

          dap.listeners.after.event_initialized["dapui_config"] = function()
            dapui.open()
          end
          dap.listeners.before.event_terminated["dapui_config"] = function()
            dapui.close()
          end
          dap.listeners.before.event_exited["dapui_config"] = function()
            dapui.close()
          end
        end,
      },

      {
        "theHamsta/nvim-dap-virtual-text",
        opts = { commented = true },
      },
    },

    config = function()
      local dap = require("dap")

      require("dap.ext.vscode").load_launchjs(nil, {
        python = { "python" },
        debugpy = { "python" },
      })
    end,

    keys = {
      {
        "<leader>db",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "Toggle Breakpoint",
      },
      {
        "<leader>dB",
        function()
          require("dap").set_breakpoint(vim.fn.input("Condition: "))
        end,
        desc = "Breakpoint Condicional",
      },
      {
        "<leader>dc",
        function()
          require("dap").continue()
        end,
        desc = "Continue / Start",
      },
      {
        "<leader>dC",
        function()
          require("dap.ext.vscode").load_launchjs(nil, { python = { "python" } })
          require("dap").continue()
        end,
        desc = "Continue (recarrega launch.json)",
      },
      {
        "<leader>di",
        function()
          require("dap").step_into()
        end,
        desc = "Step Into",
      },
      {
        "<leader>do",
        function()
          require("dap").step_over()
        end,
        desc = "Step Over",
      },
      {
        "<leader>dO",
        function()
          require("dap").step_out()
        end,
        desc = "Step Out",
      },
      {
        "<leader>dr",
        function()
          require("dap").repl.open()
        end,
        desc = "REPL",
      },
      {
        "<leader>du",
        function()
          require("dapui").toggle()
        end,
        desc = "Toggle UI",
      },
      {
        "<leader>dx",
        function()
          require("dap").terminate()
        end,
        desc = "Terminate",
      },
    },
  },

  {
    "mfussenegger/nvim-dap-python",
    ft = "python",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      local mason_path = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
      local dap_python = require("dap-python")

      dap_python.setup(mason_path)

      local ok, vscode = pcall(require, "dap.ext.vscode")
      if ok then
        vscode.load_launchjs(nil, { python = { "python" } })
      end
    end,
  },

  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "debugpy" })
    end,
  },
}
