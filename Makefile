APP_NAME := ClaudeToggle
APP_DISPLAY_NAME := Claude Toggle
BUILD_DIR := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_BUNDLE)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
SCRIPTS_DIR := $(RESOURCES_DIR)/Scripts
SOURCE := Sources/ClaudeToggle/main.swift
SCRIPTS := status-claude.sh login-claude.sh cliproxy-claude.sh apikeyfun-claude.sh antigravity-claude.sh
LAUNCH_AGENT_LABEL := com.admiraldata.ClaudeToggle
LAUNCH_AGENT_SOURCE := LaunchAgents/$(LAUNCH_AGENT_LABEL).plist
LAUNCH_AGENT_TARGET := $(HOME)/Library/LaunchAgents/$(LAUNCH_AGENT_LABEL).plist
LAUNCHD_DOMAIN := gui/$(shell id -u)

.PHONY: all app clean run install install-autostart uninstall-autostart

all: app

app: $(MACOS_DIR)/$(APP_NAME)

$(MACOS_DIR)/$(APP_NAME): $(SOURCE) Info.plist $(SCRIPTS)
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(MACOS_DIR)" "$(SCRIPTS_DIR)"
	cp Info.plist "$(CONTENTS_DIR)/Info.plist"
	cp $(SCRIPTS) "$(SCRIPTS_DIR)/"
	chmod 755 "$(SCRIPTS_DIR)"/*.sh
	swiftc -swift-version 5 -O -framework Cocoa "$(SOURCE)" -o "$(MACOS_DIR)/$(APP_NAME)"
	chmod 755 "$(MACOS_DIR)/$(APP_NAME)"
	plutil -lint "$(CONTENTS_DIR)/Info.plist"
	codesign --force --deep --sign - "$(APP_BUNDLE)"
	codesign --verify --deep --strict "$(APP_BUNDLE)"

run: app
	open "$(APP_BUNDLE)"

install: app
	rm -rf "/Applications/$(APP_DISPLAY_NAME).app"
	ditto "$(APP_BUNDLE)" "/Applications/$(APP_DISPLAY_NAME).app"

install-autostart: install
	mkdir -p "$(HOME)/Library/LaunchAgents"
	cp "$(LAUNCH_AGENT_SOURCE)" "$(LAUNCH_AGENT_TARGET)"
	plutil -lint "$(LAUNCH_AGENT_TARGET)"
	launchctl bootout "$(LAUNCHD_DOMAIN)" "$(LAUNCH_AGENT_TARGET)" 2>/dev/null || true
	launchctl bootstrap "$(LAUNCHD_DOMAIN)" "$(LAUNCH_AGENT_TARGET)"
	launchctl enable "$(LAUNCHD_DOMAIN)/$(LAUNCH_AGENT_LABEL)"

uninstall-autostart:
	launchctl bootout "$(LAUNCHD_DOMAIN)" "$(LAUNCH_AGENT_TARGET)" 2>/dev/null || true
	rm -f "$(LAUNCH_AGENT_TARGET)"

clean:
	rm -rf "$(BUILD_DIR)"
