SCHEME = MacEdgeLight
APP_NAME = MacEdgeLight
BUILD_DIR = build
ARCHIVE_PATH = $(BUILD_DIR)/$(APP_NAME).xcarchive
EXPORT_PATH = $(BUILD_DIR)/export
APP_PATH = $(EXPORT_PATH)/$(APP_NAME).app
DMG_PATH = $(BUILD_DIR)/$(APP_NAME).dmg
ZIP_PATH = $(BUILD_DIR)/$(APP_NAME).zip
VERSION = $(shell grep MARKETING_VERSION MacEdgeLight.xcodeproj/project.pbxproj | head -1 | sed 's/.*= *\(.*\);/\1/' | tr -d ' ')

.PHONY: all clean build archive export dmg zip release

all: build

# Debug build
build:
	xcodebuild -scheme $(SCHEME) -configuration Debug build

# Release archive
archive:
	@mkdir -p $(BUILD_DIR)
	xcodebuild -scheme $(SCHEME) \
		-configuration Release \
		-archivePath $(ARCHIVE_PATH) \
		archive

# Export the .app from the archive
export: archive
	@mkdir -p $(EXPORT_PATH)
	@# Extract the .app directly from the archive
	cp -R $(ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app $(EXPORT_PATH)/
	@echo "Exported to $(APP_PATH)"

# Generate DMG background image
dmg-bg:
	@mkdir -p $(BUILD_DIR)
	swift generate_dmg_bg.swift

# Create a styled DMG with drag-to-Applications layout
dmg: export dmg-bg
	@rm -f $(DMG_PATH)
	create-dmg \
		--volname "$(APP_NAME)" \
		--background $(BUILD_DIR)/dmg-background.png \
		--window-pos 200 120 \
		--window-size 660 400 \
		--icon-size 100 \
		--icon "$(APP_NAME).app" 175 190 \
		--app-drop-link 485 190 \
		--text-size 14 \
		--no-internet-enable \
		$(DMG_PATH) \
		$(APP_PATH)
	@echo "Created $(DMG_PATH)"

# Create a zip of the .app
zip: export
	@rm -f $(ZIP_PATH)
	cd $(EXPORT_PATH) && zip -r -y ../../$(ZIP_PATH) $(APP_NAME).app
	@echo "Created $(ZIP_PATH)"

# Build both DMG and zip for release
release: dmg zip
	@echo ""
	@echo "Release $(VERSION) ready:"
	@echo "  $(DMG_PATH)"
	@echo "  $(ZIP_PATH)"
	@echo ""
	@echo "To create a GitHub release:"
	@echo "  gh release create v$(VERSION) $(DMG_PATH) $(ZIP_PATH) --title \"$(APP_NAME) v$(VERSION)\" --notes \"Release v$(VERSION)\""

clean:
	@rm -rf $(BUILD_DIR)
	xcodebuild -scheme $(SCHEME) clean 2>/dev/null || true
