SCHEME = MacEdgeLight
APP_NAME = MacEdgeLight
BUILD_DIR = build
ARCHIVE_PATH = $(BUILD_DIR)/$(APP_NAME).xcarchive
EXPORT_PATH = $(BUILD_DIR)/export
APP_PATH = $(EXPORT_PATH)/$(APP_NAME).app
DMG_PATH = $(BUILD_DIR)/$(APP_NAME).dmg
ZIP_PATH = $(BUILD_DIR)/$(APP_NAME).zip
VERSION = $(shell grep MARKETING_VERSION MacEdgeLight.xcodeproj/project.pbxproj | head -1 | sed 's/.*= *\(.*\);/\1/' | tr -d ' ')

# Developer ID distribution uses the Apple account configured in Xcode Settings.
DEVELOPER_ID = Developer ID Application: MILL5, LLC (FS6453639M)
EXPORT_OPTIONS = scripts/ExportOptions-export.plist
UPLOAD_OPTIONS = scripts/ExportOptions-upload.plist

.PHONY: all clean build test archive export export-unsigned sign notarize dmg-bg dmg zip release package verify-release release-unsigned sync-site-version check-site-version

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
		-allowProvisioningUpdates archive

# Export using Xcode automatic Developer ID signing.
export: archive
	xcodebuild -exportArchive -archivePath $(ARCHIVE_PATH) \
		-exportOptionsPlist $(EXPORT_OPTIONS) -exportPath $(EXPORT_PATH) \
		-allowProvisioningUpdates

sign: export
	codesign --verify --deep --strict --verbose $(APP_PATH)

# Xcode submits with its signed-in account; no notarytool password profile needed.
notarize: archive
	xcodebuild -exportArchive -archivePath $(ARCHIVE_PATH) \
		-exportOptionsPlist $(UPLOAD_OPTIONS) -exportPath $(BUILD_DIR)/xcode-distribution \
		-allowProvisioningUpdates
	bash scripts/export-notarized.sh $(ARCHIVE_PATH) $(EXPORT_PATH)
	xcrun stapler validate $(APP_PATH)

# Refuse to package an old, unsigned, or unnotarized app.
verify-release: check-site-version
	@test "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' $(APP_PATH)/Contents/Info.plist)" = "$(VERSION)" || (echo "Exported app version does not match $(VERSION)"; exit 1)
	codesign --verify --deep --strict --verbose $(APP_PATH)
	xcrun stapler validate $(APP_PATH)
	spctl --assess --type execute --verbose=2 $(APP_PATH)

# Generate DMG background image
dmg-bg:
	@mkdir -p $(BUILD_DIR)
	swift generate_dmg_bg.swift

# Create a styled DMG with drag-to-Applications layout
dmg: verify-release dmg-bg
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
zip: verify-release
	@rm -f $(ZIP_PATH)
	cd $(EXPORT_PATH) && zip -r -y ../../$(ZIP_PATH) $(APP_NAME).app
	@echo "Created $(ZIP_PATH)"

# Build, sign, notarize, and package for release
release: check-site-version notarize
	$(MAKE) package

# Package an app already exported by Xcode Organizer without rebuilding it.
package: dmg zip
	@echo ""
	@echo "Release $(VERSION) ready (signed + notarized):"
	@echo "  $(DMG_PATH)"
	@echo "  $(ZIP_PATH)"
	@echo ""
	@echo "To create a GitHub release:"
	@echo "  gh release create v$(VERSION) $(DMG_PATH) $(ZIP_PATH) --title \"$(APP_NAME) v$(VERSION)\" --notes \"Release v$(VERSION)\""

# Copy the development archive without distribution signing (local testing only).
export-unsigned: archive
	@mkdir -p $(EXPORT_PATH)
	@rm -rf $(APP_PATH)
	cp -R $(ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app $(EXPORT_PATH)/

# Build without distribution signing (for testing)
release-unsigned: export-unsigned dmg-bg
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

# Use Xcode's full marketing version for website/README labels and download URLs.
sync-site-version:
	python3 scripts/sync-site-version.py

check-site-version:
	python3 scripts/sync-site-version.py --check
