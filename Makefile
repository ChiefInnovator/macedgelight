SCHEME = MacEdgeLight
APP_NAME = MacEdgeLight
BUILD_DIR = build
ARCHIVE_PATH = $(BUILD_DIR)/$(APP_NAME).xcarchive
EXPORT_PATH = $(BUILD_DIR)/export
APP_PATH = $(EXPORT_PATH)/$(APP_NAME).app
DMG_PATH = $(BUILD_DIR)/$(APP_NAME).dmg
ZIP_PATH = $(BUILD_DIR)/$(APP_NAME).zip
VERSION = $(shell grep MARKETING_VERSION MacEdgeLight.xcodeproj/project.pbxproj | head -1 | sed 's/.*= *\(.*\);/\1/' | tr -d ' ')

# Code signing
DEVELOPER_ID = Developer ID Application: MILL5, LLC (FS6453639M)
TEAM_ID = FS6453639M
APPLE_ID = rich@mill5.com
# Store app-specific password in keychain: xcrun notarytool store-credentials "MacEdgeLightNotarize" --apple-id rich@mill5.com --team-id FS6453639M
NOTARIZE_PROFILE = MacEdgeLightNotarize

.PHONY: all clean build test archive export sign notarize dmg zip release

all: build

# Debug build
build:
	xcodebuild -scheme $(SCHEME) -configuration Debug build SYMROOT=$(CURDIR)/$(BUILD_DIR)

# Run unit tests
test:
	xcodebuild test -scheme $(SCHEME) -destination 'platform=macOS'

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
	@rm -rf $(APP_PATH)
	cp -R $(ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app $(EXPORT_PATH)/
	@echo "Exported to $(APP_PATH)"

# Sign the app with Developer ID
sign: export
	@echo "Signing with Developer ID..."
	codesign --deep --force --options runtime \
		--sign "$(DEVELOPER_ID)" \
		$(APP_PATH)
	@echo "Verifying signature..."
	codesign --verify --verbose $(APP_PATH)
	@echo "Signed successfully."

# Notarize the app with Apple
notarize: sign
	@echo "Creating zip for notarization..."
	@rm -f $(BUILD_DIR)/notarize-upload.zip
	cd $(EXPORT_PATH) && zip -r -y ../../$(BUILD_DIR)/notarize-upload.zip $(APP_NAME).app
	@echo "Submitting to Apple for notarization..."
	xcrun notarytool submit $(BUILD_DIR)/notarize-upload.zip \
		--keychain-profile "$(NOTARIZE_PROFILE)" \
		--wait
	@echo "Stapling notarization ticket..."
	xcrun stapler staple $(APP_PATH)
	@echo "Notarization complete."
	@rm -f $(BUILD_DIR)/notarize-upload.zip

# Generate DMG background image
dmg-bg:
	@mkdir -p $(BUILD_DIR)
	swift generate_dmg_bg.swift

# Create a styled DMG with drag-to-Applications layout
dmg: notarize dmg-bg
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
	@echo "Signing DMG..."
	codesign --force --sign "$(DEVELOPER_ID)" $(DMG_PATH)
	@echo "Created $(DMG_PATH)"

# Create a signed zip of the .app
zip: notarize
	@rm -f $(ZIP_PATH)
	cd $(EXPORT_PATH) && zip -r -y ../../$(ZIP_PATH) $(APP_NAME).app
	@echo "Created $(ZIP_PATH)"

# Build, sign, notarize, and package for release
release: dmg zip
	@echo ""
	@echo "Release $(VERSION) ready (signed + notarized):"
	@echo "  $(DMG_PATH)"
	@echo "  $(ZIP_PATH)"
	@echo ""
	@echo "To create a GitHub release:"
	@echo "  gh release create v$(VERSION) $(DMG_PATH) $(ZIP_PATH) --title \"$(APP_NAME) v$(VERSION)\" --notes \"Release v$(VERSION)\""

# Build without signing (for testing)
release-unsigned: export dmg-bg
	@rm -f $(DMG_PATH) $(ZIP_PATH)
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
	cd $(EXPORT_PATH) && zip -r -y ../../$(ZIP_PATH) $(APP_NAME).app
	@echo ""
	@echo "Release $(VERSION) ready (UNSIGNED):"
	@echo "  $(DMG_PATH)"
	@echo "  $(ZIP_PATH)"

clean:
	@rm -rf $(BUILD_DIR)
	xcodebuild -scheme $(SCHEME) clean 2>/dev/null || true
