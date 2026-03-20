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

# Create a DMG with drag-to-Applications layout
dmg: export
	@rm -f $(DMG_PATH)
	@mkdir -p $(BUILD_DIR)/dmg-staging
	cp -R $(APP_PATH) $(BUILD_DIR)/dmg-staging/
	ln -sf /Applications $(BUILD_DIR)/dmg-staging/Applications
	hdiutil create -volname "$(APP_NAME)" \
		-srcfolder $(BUILD_DIR)/dmg-staging \
		-ov -format UDZO \
		$(DMG_PATH)
	@rm -rf $(BUILD_DIR)/dmg-staging
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
