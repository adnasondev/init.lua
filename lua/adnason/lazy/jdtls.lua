local home = os.getenv('HOME')
local jdtls_path = home .. '/.local/share/nvim/mason/packages/jdtls'

local function extend_or_override(defaults, user_config)
    if user_config then
        for k, v in pairs(user_config) do
            if type(v) == "table" and type(defaults[k]) == "table" then
                extend_or_override(defaults[k], v)
            else
                defaults[k] = v
            end
        end
    end
    return defaults
end

return {
    "mfussenegger/nvim-jdtls",
    dependencies = {
        "folke/which-key.nvim",
    },
    ft = "java",
    opts = function()
        local lombok_jar = jdtls_path .. "/lombok.jar"
        return {
            -- How to find the root dir for a given filename. The default comes from
            -- lspconfig which provides a function specifically for java projects.
            root_dir = require("lspconfig.server_configurations.jdtls").default_config.root_dir,

            -- How to find the project name for a given root dir.
            project_name = function(root_dir)
                return root_dir and vim.fs.basename(root_dir)
            end,

            -- Where are the config and workspace dirs for a project?
            jdtls_config_dir = function(project_name)
                return vim.fn.stdpath("cache") .. "/jdtls/" .. project_name .. "/config"
            end,
            jdtls_workspace_dir = function(project_name)
                return vim.fn.stdpath("cache") .. "/jdtls/" .. project_name .. "/workspace"
            end,

            -- How to run jdtls. This can be overridden to a full java command-line
            -- if the Python wrapper script doesn't suffice.
            cmd = {
                vim.fn.exepath("jdtls"),
                string.format("--jvm-arg=-javaagent:%s", lombok_jar),
            },
            full_cmd = function(opts)
                local fname = vim.api.nvim_buf_get_name(0)
                local root_dir = opts.root_dir(fname)
                local project_name = opts.project_name(root_dir)
                local cmd = vim.deepcopy(opts.cmd)
                if project_name then
                    vim.list_extend(cmd, {
                        "-configuration",
                        opts.jdtls_config_dir(project_name),
                        "-data",
                        opts.jdtls_workspace_dir(project_name),
                    })
                end
                return cmd
            end,
            -- These depend on nvim-dap, but can additionally be disabled by setting false here.
            dap = { hotcodereplace = "auto", config_overrides = {} },
            dap_main = {},
            test = true,
            settings = {
                java = {
                    format = {
                        enabled = true,
                    },
                    signatureHelp = { enabled = true },
                    contentProvider = { preferred = 'fernflower' },
                    completion = {
                        favoriteStaticMembers = {
                            "org.hamcrest.MatcherAssert.assertThat",
                            "org.hamcrest.Matchers.*",
                            "org.hamcrest.CoreMatchers.*",
                            "org.junit.jupiter.api.Assertions.*",
                            "java.util.Objects.requireNonNull",
                            "java.util.Objects.requireNonNullElse",
                            "org.mockito.Mockito.*"
                        },
                        filteredTypes = {
                            "com.sun.*",
                            "io.micrometer.shaded.*",
                            "java.awt.*",
                            "jdk.*", "sun.*",
                        },
                        importOrder = {
                            "java",
                            "javax",
                            "com",
                            "org"
                        }
                    },
                    sources = {
                        organizeImports = {
                            starThreshold = 9999,
                            staticStarThreshold = 9999,
                        },
                    },
                    codeGeneration = {
                        toString = {
                            template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}"
                        },
                        hashCodeEquals = {
                            useJava7Objects = true,
                        },
                        useBlocks = true,
                    },
                    inlayHints = {
                        parameterNames = {
                            enabled = "all",
                        },
                    },
                },
            },
        }
    end,
    config = function(_, opts)
        -- Find the extra bundles that should be passed on the jdtls command-line
        -- if nvim-dap is enabled with java debug/test.
        local mason_registry = require("mason-registry")
        local bundles = {} ---@type string[]

        if opts.dap and mason_registry.is_installed("java-debug-adapter") then
            local java_dbg_pkg = mason_registry.get_package("java-debug-adapter")
            local java_dbg_path = java_dbg_pkg:get_install_path()
            local jar_patterns = {
                java_dbg_path .. "/extension/server/com.microsoft.java.debug.plugin-*.jar",
            }
            -- java-test also depends on java-debug-adapter.
            if opts.test and mason_registry.is_installed("java-test") then
                local java_test_pkg = mason_registry.get_package("java-test")
                local java_test_path = java_test_pkg:get_install_path()
                vim.list_extend(jar_patterns, {
                    java_test_path .. "/extension/server/*.jar",
                })
            end
            for _, jar_pattern in ipairs(jar_patterns) do
                for _, bundle in ipairs(vim.split(vim.fn.glob(jar_pattern), "\n")) do
                    table.insert(bundles, bundle)
                end
            end
        end

        --- Attaches the Java Development Tools Language Server (JDTLS) to the current buffer.
        -- This function configures and starts or attaches JDTLS for the current buffer in Neovim.
        -- It determines the root directory, command, initial options, settings, and capabilities,
        -- and combines them with any additional options provided in opts.jdtls.
        --
        -- @param opts table: A table of options used to configure JDTLS.
        -- @param opts.full_cmd function: A function that returns the command to start the language server.
        -- @param opts.root_dir function: A function that determines the root directory for the project.
        -- @param opts.settings table: A table of settings for the language server.
        -- @param opts.jdtls table: A table of additional options to override or extend the default configuration.
        -- @param bundles table: A table of bundles to include in the initial options.
        local function attach_jdtls()
            local fname = vim.api.nvim_buf_get_name(0)
            -- Configuration can be augmented and overridden by opts.jdtls
            local config = extend_or_override({
                cmd = opts.full_cmd(opts),
                root_dir = opts.root_dir(fname),
                init_options = {
                    bundles = bundles,
                },
                settings = opts.settings,
                -- enable CMP capabilities
                capabilities = vim.tbl_deep_extend("force", {}, vim.lsp.protocol.make_client_capabilities(),
                    require("cmp_nvim_lsp").default_capabilities())
            }, opts.jdtls)
            -- Existing server will be reused if the root_dir matches.
            require("jdtls").start_or_attach(config)
        end

        -- Attach the jdtls for each java buffer. HOWEVER, this plugin loads
        -- depending on filetype, so this autocmd doesn't run for the first file.
        -- For that, we call directly below.
        vim.api.nvim_create_autocmd("FileType", {
            pattern = "java",
            callback = attach_jdtls,
        })

        -- Setup keymap and dap after the lsp is fully attached.
        -- https://github.com/mfussenegger/nvim-jdtls#nvim-dap-configuration
        -- https://neovim.io/doc/user/lsp.html#LspAttach
        vim.api.nvim_create_autocmd("LspAttach", {
            callback = function(args)
                local client = vim.lsp.get_client_by_id(args.data.client_id)
                if client and client.name == "jdtls" then
                    local jdtls = require('jdtls')
                    local wk = require("which-key")
                    wk.register({
                        ["<leader>cx"] = { name = "+extract" },
                        ["<leader>cxv"] = { jdtls.extract_variable_all, "Extract Variable" },
                        ["<leader>cxc"] = { jdtls.extract_constant, "Extract Constant" },
                        ["gs"] = { jdtls.super_implementation, "Super Implementation" },
                        ["gS"] = { jdtls.goto_subjects, "Goto Subjects" },
                        ["<leader>co"] = { jdtls.organize_imports, "Organize Imports" },
                    }, { mode = "n", buffer = args.buf })
                    wk.register({
                        ["<leader>c"] = { name = "+code" },
                        ["<leader>cx"] = { name = "+extract" },
                        ["<leader>cxm"] = {
                            [[<ESC><CMD>lua require('jdtls').extract_method(true)<CR>]],
                            "Extract Method",
                        },
                        ["<leader>cxv"] = {
                            [[<ESC><CMD>lua require('jdtls').extract_variable_all(true)<CR>]],
                            "Extract Variable",
                        },
                        ["<leader>cxc"] = {
                            [[<ESC><CMD>lua require('jdtls').extract_constant(true)<CR>]],
                            "Extract Constant",
                        },
                    }, { mode = "v", buffer = args.buf })

                    if opts.dap and mason_registry.is_installed("java-debug-adapter") then
                        -- custom init for Java debugger
                        require("jdtls").setup_dap(opts.dap)
                        require("jdtls.dap").setup_dap_main_class_configs(opts.dap_main)

                        -- Java Test require Java debugger to work
                        if opts.test and mason_registry.is_installed("java-test") then
                            -- custom keymaps for Java test runner (not yet compatible with neotest)
                            wk.register({
                                ["<leader>t"] = { name = "+test" },
                                ["<leader>tt"] = { require("jdtls.dap").test_class, "Run All Test" },
                                ["<leader>tr"] = { require("jdtls.dap").test_nearest_method, "Run Nearest Test" },
                                ["<leader>tT"] = { require("jdtls.dap").pick_test, "Run Test" },
                            }, { mode = "n", buffer = args.buf })
                        end
                    end

                    -- User can set additional keymaps in opts.on_attach
                    if opts.on_attach then
                        opts.on_attach(args)
                    end
                end
            end,
        })

        -- Avoid race condition by calling attach the first time, since the autocmd won't fire.
        attach_jdtls()
    end,
}
