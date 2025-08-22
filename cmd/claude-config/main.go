package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

type McpServer struct {
	Command string   `json:"command"`
	Args    []string `json:"args"`
}

type ClaudeConfig struct {
	McpServers map[string]McpServer `json:"mcpServers"`
}

type ConfigState struct {
	rplsEnabled    bool
	queenitEnabled bool
}

func getClaudeConfigPath() string {
	if runtime.GOOS == "windows" {
		appData := os.Getenv("APPDATA")
		if appData == "" {
			homeDir, _ := os.UserHomeDir()
			appData = filepath.Join(homeDir, "AppData", "Roaming")
		}
		return filepath.Join(appData, "Claude", "claude_desktop_config.json")
	}
	// For other platforms (fallback)
	homeDir, _ := os.UserHomeDir()
	return filepath.Join(homeDir, "Library", "Application Support", "Claude", "claude_desktop_config.json")
}

func loadExistingConfig() (*ClaudeConfig, error) {
	configPath := getClaudeConfigPath()
	
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		return &ClaudeConfig{McpServers: make(map[string]McpServer)}, nil
	}

	data, err := ioutil.ReadFile(configPath)
	if err != nil {
		return nil, err
	}

	var config ClaudeConfig
	if err := json.Unmarshal(data, &config); err != nil {
		return nil, err
	}

	if config.McpServers == nil {
		config.McpServers = make(map[string]McpServer)
	}

	return &config, nil
}

func saveConfig(config *ClaudeConfig) error {
	configPath := getClaudeConfigPath()
	
	// Create directory if it doesn't exist
	if err := os.MkdirAll(filepath.Dir(configPath), 0755); err != nil {
		return err
	}

	data, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
	}

	return ioutil.WriteFile(configPath, data, 0644)
}

func updateConfig(state *ConfigState) error {
	config, err := loadExistingConfig()
	if err != nil {
		return fmt.Errorf("loading config: %v", err)
	}

	// Handle RPLS
	if state.rplsEnabled {
		config.McpServers["rpls"] = McpServer{
			Command: "npx",
			Args:    []string{"mcp-remote", "https://agentgateway.damoa.rapportlabs.dance/mcp"},
		}
	} else {
		delete(config.McpServers, "rpls")
	}

	// Handle Queenit
	if state.queenitEnabled {
		config.McpServers["queenit"] = McpServer{
			Command: "npx",
			Args:    []string{"mcp-remote", "https://mcp.rapportlabs.kr/mcp"},
		}
	} else {
		delete(config.McpServers, "queenit")
	}

	if err := saveConfig(config); err != nil {
		return fmt.Errorf("saving config: %v", err)
	}

	return nil
}

func loadCurrentState() (*ConfigState, error) {
	config, err := loadExistingConfig()
	if err != nil {
		return nil, fmt.Errorf("loading config: %v", err)
	}

	state := &ConfigState{}
	_, state.rplsEnabled = config.McpServers["rpls"]
	_, state.queenitEnabled = config.McpServers["queenit"]

	return state, nil
}

func main() {
	fmt.Println("Claude Desktop MCP Server Configuration")
	fmt.Println("======================================")
	
	configPath := getClaudeConfigPath()
	fmt.Printf("Configuration file: %s\n\n", configPath)

	// Load current state
	state, err := loadCurrentState()
	if err != nil {
		fmt.Printf("Warning: Could not load current config: %v\n", err)
		state = &ConfigState{}
	}

	reader := bufio.NewReader(os.Stdin)

	for {
		// Display current status
		fmt.Println("Current MCP Server Configuration:")
		fmt.Printf("1. RPLS (Rapport Labs Agent Gateway): %s\n", getStatus(state.rplsEnabled))
		fmt.Printf("2. Queenit (Rapport Labs MCP): %s\n\n", getStatus(state.queenitEnabled))

		fmt.Println("Options:")
		fmt.Println("1 - Toggle RPLS")
		fmt.Println("2 - Toggle Queenit")
		fmt.Println("s - Save configuration")
		fmt.Println("q - Quit")
		fmt.Print("\nSelect option: ")

		input, _ := reader.ReadString('\n')
		input = strings.TrimSpace(strings.ToLower(input))

		switch input {
		case "1":
			state.rplsEnabled = !state.rplsEnabled
			fmt.Printf("RPLS is now %s\n\n", getStatus(state.rplsEnabled))

		case "2":
			state.queenitEnabled = !state.queenitEnabled
			fmt.Printf("Queenit is now %s\n\n", getStatus(state.queenitEnabled))

		case "s":
			fmt.Print("Saving configuration... ")
			if err := updateConfig(state); err != nil {
				fmt.Printf("Error: %v\n\n", err)
			} else {
				fmt.Println("Success!")
				fmt.Println("Please restart Claude Desktop for changes to take effect.\n")
			}

		case "q":
			fmt.Println("Goodbye!")
			return

		default:
			fmt.Println("Invalid option. Please try again.\n")
		}
	}
}

func getStatus(enabled bool) string {
	if enabled {
		return "ENABLED"
	}
	return "DISABLED"
}