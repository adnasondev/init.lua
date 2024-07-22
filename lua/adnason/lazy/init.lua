return {
    {
        "nvim-lua/plenary.nvim",       -- Plugin: planeary.nvim
        name = "plenary"               -- Alias or name for the plugin (optional)
    },
    "eandrju/cellular-automaton.nvim", -- Plugin: cellular-automation.nvim (no-alias)
    {
        "ThePrimeagen/harpoon",        -- Plugin: harpoon from ThePrimeagen
        branch = "harpoon2",           -- Specific branch to use (harpoon2)
        dependencies = {               -- Dependencies required by this plugin
            "nvim-lua/plenary.nvim"    -- Dependency: planary.nvim
        }
    }
}
