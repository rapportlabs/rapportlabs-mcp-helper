package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"runtime"

	"github.com/lxn/walk"
	. "github.com/lxn/walk/declarative"
)

type McpServer struct {
	Command string   `json:"command"`
	Args    []string `json:"args"`
}

type ClaudeConfig struct {
	McpServers map[string]McpServer `json:"mcpServers"`
}

type AppMainWindow struct {
	*walk.MainWindow
	rplsCheckBox    *walk.CheckBox
	queenitCheckBox *walk.CheckBox
	statusLabel     *walk.Label
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

func (mw *AppMainWindow) updateConfig() {
	config, err := loadExistingConfig()
	if err != nil {
		mw.statusLabel.SetText(fmt.Sprintf("Error loading config: %v", err))
		return
	}

	// Handle RPLS checkbox
	if mw.rplsCheckBox.Checked() {
		config.McpServers["rpls"] = McpServer{
			Command: "npx",
			Args:    []string{"mcp-remote", "https://agentgateway.damoa.rapportlabs.dance/mcp"},
		}
	} else {
		delete(config.McpServers, "rpls")
	}

	// Handle Queenit checkbox
	if mw.queenitCheckBox.Checked() {
		config.McpServers["queenit"] = McpServer{
			Command: "npx",
			Args:    []string{"mcp-remote", "https://mcp.rapportlabs.kr/mcp"},
		}
	} else {
		delete(config.McpServers, "queenit")
	}

	if err := saveConfig(config); err != nil {
		mw.statusLabel.SetText(fmt.Sprintf("Error saving config: %v", err))
		return
	}

	mw.statusLabel.SetText("Configuration updated successfully! Please restart Claude Desktop.")
}

func (mw *AppMainWindow) loadCurrentState() {
	config, err := loadExistingConfig()
	if err != nil {
		mw.statusLabel.SetText(fmt.Sprintf("Error loading current config: %v", err))
		return
	}

	// Set checkbox states based on current config
	_, rplsExists := config.McpServers["rpls"]
	mw.rplsCheckBox.SetChecked(rplsExists)

	_, queenitExists := config.McpServers["queenit"]
	mw.queenitCheckBox.SetChecked(queenitExists)

	configPath := getClaudeConfigPath()
	mw.statusLabel.SetText(fmt.Sprintf("Config file: %s", configPath))
}

func main() {
	// Ensure we show errors in message boxes on Windows
	defer func() {
		if r := recover(); r != nil {
			walk.MsgBox(nil, "Error", fmt.Sprintf("Application error: %v", r), walk.MsgBoxIconError)
		}
	}()

	var mw AppMainWindow

	if err := (MainWindow{
		AssignTo: &mw.MainWindow,
		Title:    "Claude Desktop MCP Server Configuration",
		MinSize:  Size{400, 300},
		Size:     Size{500, 350},
		Layout:   VBox{},
		Children: []Widget{
			Composite{
				Layout: VBox{Margins: Margins{20, 20, 20, 20}},
				Children: []Widget{
					Label{
						Text: "Select MCP Servers to configure in Claude Desktop:",
						Font: Font{PointSize: 11, Bold: true},
					},
					VSeparator{},
					CheckBox{
						AssignTo: &mw.rplsCheckBox,
						Text:     "RPLS (Rapport Labs Agent Gateway)",
						Font:     Font{PointSize: 10},
					},
					Label{
						Text: "  → https://agentgateway.damoa.rapportlabs.dance/mcp",
						Font: Font{PointSize: 8},
					},
					VSpacer{Size: 10},
					CheckBox{
						AssignTo: &mw.queenitCheckBox,
						Text:     "Queenit (Rapport Labs MCP)",
						Font:     Font{PointSize: 10},
					},
					Label{
						Text: "  → https://mcp.rapportlabs.kr/mcp",
						Font: Font{PointSize: 8},
					},
					VSpacer{Size: 20},
					PushButton{
						Text: "Apply Configuration",
						Font: Font{PointSize: 11, Bold: true},
						OnClicked: func() {
							mw.updateConfig()
						},
					},
					VSpacer{Size: 10},
					Label{
						AssignTo: &mw.statusLabel,
						Text:     "Ready to configure...",
						Font:     Font{PointSize: 9},
					},
				},
			},
		},
	}.Create()); err != nil {
		walk.MsgBox(nil, "Error", fmt.Sprintf("Failed to create window: %v", err), walk.MsgBoxIconError)
		return
	}

	// Load current state when the window opens
	mw.loadCurrentState()

	mw.Run()
}