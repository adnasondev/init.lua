return {
    "nvim-telescope/telescope.nvim", -- Specifies the plugin name or repository

    tag = "0.1.5", -- Specifies the version tag of the plugin

    dependencies = {
        "nvim-lua/plenary.nvim" -- Specifies a dependency plugin
    },

    config = function()

        -- Configures the setup of the 'telescope' plugin
        require('telescope').setup({})

        -- Defines key mappings for various Telescope commands
        local builtin = require('telescope.builtin')

        -- Key mapping to search for project files using '<leader>pf'
        vim.keymap.set('n', '<leader>pf', builtin.find_files, {})

        -- Key mapping to search for files in git using '<C-p>'
        vim.keymap.set('n', '<C-p>', builtin.git_files, {})

        -- Key mapping to grep for the current word under the cursor
        vim.keymap.set('n', '<leader>pws', function()
            local word = vim.fn.expand("<cword>")
            builtin.grep_string({ search = word })
        end)

        -- Key mapping to grep for the current WORD under the cursor
        vim.keymap.set('n', '<leader>pWs', function()
            local word = vim.fn.expand("<cWORD>")
            builtin.grep_string({ search = word })
        end)

        -- Key mapping to prompt the user for a search term and grep it
        vim.keymap.set('n', '<leader>ps', function()
            builtin.grep_string({ search = vim.fn.input("Grep > ") })
        end)

        -- Key mapping to use Telescope to search through help tags
        vim.keymap.set('n', '<leader>vh', builtin.help_tags, {})
    end
}
