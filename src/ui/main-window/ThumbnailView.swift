import Cocoa

class ThumbnailView: NSStackView {
    var window_: Window?
    var thumbnail = NSImageView()
    var appIcon = NSImageView()
    var label = ThumbnailTitleView(Preferences.fontHeight)
    var fullscreenIcon = ThumbnailFontIconView(.circledPlusSign)
    var minimizedIcon = ThumbnailFontIconView(.circledMinusSign)
    var hiddenIcon = ThumbnailFontIconView(.circledSlashSign)
    var spaceIcon = ThumbnailFontIconView(.circledNumber0)
    var dockLabelIcon = ThumbnailFilledFontIconView(ThumbnailFontIconView(.filledCircledNumber0, (Preferences.fontIconSize * 0.7).rounded(), NSColor(srgbRed: 1, green: 0.30, blue: 0.25, alpha: 1), nil), NSColor.white, true)
    var closeIcon = ThumbnailFilledFontIconView(ThumbnailFontIconView(.filledCircledMultiplySign, Preferences.fontIconSize, NSColor(srgbRed: 1, green: 0.35, blue: 0.32, alpha: 1), nil), NSColor(srgbRed: 0.64, green: 0.03, blue: 0.02, alpha: 1))
    var minimizeIcon = ThumbnailFilledFontIconView(ThumbnailFontIconView(.filledCircledMinusSign, Preferences.fontIconSize, NSColor(srgbRed: 0.91, green: 0.75, blue: 0.16, alpha: 1), nil), NSColor(srgbRed: 0.71, green: 0.55, blue: 0.09, alpha: 1))
    var maximizeIcon = ThumbnailFilledFontIconView(ThumbnailFontIconView(.filledCircledPlusSign, Preferences.fontIconSize, NSColor(srgbRed: 0.32, green: 0.76, blue: 0.17, alpha: 1), nil), NSColor(srgbRed: 0.04, green: 0.39, blue: 0.02, alpha: 1))
    var hStackView: NSStackView!
    var mouseUpCallback: (() -> Void)!
    var mouseMovedCallback: (() -> Void)!
    var dragAndDropTimer: Timer?
    var isHighlighted = false
    var shouldShowWindowControls = false
    var isShowingWindowControls = false

    convenience init() {
        self.init(frame: .zero)
        setupView()
        observeDragAndDrop()
    }

    private func setupView() {
        wantsLayer = true
        layer!.backgroundColor = .clear
        layer!.borderColor = .clear
        layer!.cornerRadius = Preferences.cellCornerRadius
        layer!.borderWidth = Preferences.cellBorderWidth
        edgeInsets = NSEdgeInsets(top: Preferences.intraCellPadding, left: Preferences.intraCellPadding, bottom: Preferences.intraCellPadding, right: Preferences.intraCellPadding)
        orientation = .vertical
        spacing = Preferences.intraCellPadding
        let shadow = ThumbnailView.makeShadow(.gray)
        thumbnail.shadow = shadow
        appIcon.shadow = shadow
        hStackView = NSStackView(views: [appIcon, label, hiddenIcon, fullscreenIcon, minimizedIcon, spaceIcon])
        hStackView.spacing = Preferences.intraCellPadding
        setViews([hStackView, thumbnail], in: .leading)
        addWindowControls()
        addDockLabelIcon()
    }

    private func addDockLabelIcon() {
        appIcon.addSubview(dockLabelIcon, positioned: .above, relativeTo: nil)
        dockLabelIcon.topAnchor.constraint(equalTo: appIcon.topAnchor, constant: -4).isActive = true
        dockLabelIcon.rightAnchor.constraint(equalTo: appIcon.rightAnchor, constant: 1).isActive = true
    }

    private func addWindowControls() {
        thumbnail.addSubview(closeIcon, positioned: .above, relativeTo: nil)
        thumbnail.addSubview(minimizeIcon, positioned: .above, relativeTo: nil)
        thumbnail.addSubview(maximizeIcon, positioned: .above, relativeTo: nil)
        let windowsControlSpacing = CGFloat(3)
        [closeIcon, minimizeIcon, maximizeIcon].forEach {
            $0.topAnchor.constraint(equalTo: thumbnail.topAnchor, constant: 1).isActive = true
        }
        closeIcon.leftAnchor.constraint(equalTo: thumbnail.leftAnchor).isActive = true
        minimizeIcon.leftAnchor.constraint(equalTo: closeIcon.rightAnchor, constant: windowsControlSpacing).isActive = true
        maximizeIcon.leftAnchor.constraint(equalTo: minimizeIcon.rightAnchor, constant: windowsControlSpacing).isActive = true
        [closeIcon, minimizeIcon, maximizeIcon].forEach { $0.isHidden = true }
    }

    func showOrHideWindowControls(_ shouldShowWindowControls_: Bool? = nil) {
        if let shouldShowWindowControls = shouldShowWindowControls_ {
            self.shouldShowWindowControls = shouldShowWindowControls
        }
        let shouldShow = shouldShowWindowControls && isHighlighted && !Preferences.hideColoredCircles
        if isShowingWindowControls != shouldShow {
            isShowingWindowControls = shouldShow
            [closeIcon, minimizeIcon, maximizeIcon].forEach { $0.isHidden = !shouldShow }
        }
    }

    func highlight(_ highlight: Bool) {
        if isHighlighted != highlight {
            isHighlighted = highlight
            if frame != NSRect.zero {
                highlightOrNot()
            }
        }
        showOrHideWindowControls()
    }

    func highlightOrNot() {
        layer!.backgroundColor = isHighlighted ? Preferences.highlightBackgroundColor.cgColor : .clear
        layer!.borderColor = isHighlighted ? Preferences.highlightBorderColor.cgColor : .clear
        let frameInset: CGFloat = Preferences.intraCellPadding * (isHighlighted ? -1 : 1)
        frame = frame.insetBy(dx: frameInset, dy: frameInset)
        let edgeInsets_: CGFloat = Preferences.intraCellPadding * (isHighlighted ? 2 : 1)
        edgeInsets.top = edgeInsets_
        edgeInsets.right = edgeInsets_
        edgeInsets.bottom = edgeInsets_
        edgeInsets.left = edgeInsets_
    }

    func updateRecycledCellWithNewContent(_ element: Window, _ index: Int, _ newHeight: CGFloat, _ screen: NSScreen) {
        window_ = element
        if thumbnail.image != element.thumbnail {
            thumbnail.image = element.thumbnail
            let (thumbnailWidth, thumbnailHeight) = ThumbnailView.thumbnailSize(element.thumbnail, screen)
            let thumbnailSize = NSSize(width: thumbnailWidth.rounded(), height: thumbnailHeight.rounded())
            thumbnail.image?.size = thumbnailSize
            thumbnail.frame.size = thumbnailSize
        }
        if appIcon.image != element.icon {
            appIcon.image = element.icon
            let appIconSize = NSSize(width: Preferences.iconSize, height: Preferences.iconSize)
            appIcon.image?.size = appIconSize
            appIcon.frame.size = appIconSize
        }
        let labelChanged = label.string != element.title
        if labelChanged {
            label.string = element.title
            // workaround: setting string on NSTextView changes the font (most likely a Cocoa bug)
            label.font = Preferences.font
        }
        assignIfDifferent(&hiddenIcon.isHidden, !element.isHidden || Preferences.hideStatusIcons)
        assignIfDifferent(&fullscreenIcon.isHidden, !element.isFullscreen || Preferences.hideStatusIcons)
        assignIfDifferent(&minimizedIcon.isHidden, !element.isMinimized || Preferences.hideStatusIcons)
        assignIfDifferent(&spaceIcon.isHidden, Spaces.isSingleSpace || Preferences.hideSpaceNumberLabels)
        if !spaceIcon.isHidden {
            if element.spaceIndex > 30 || element.isOnAllSpaces {
                spaceIcon.setStar()
            } else {
                spaceIcon.setNumber(element.spaceIndex, false)
            }
        }
        assignIfDifferent(&dockLabelIcon.isHidden, element.dockLabel == nil || Preferences.hideAppBadges || Preferences.iconSize == 0)
        if !dockLabelIcon.isHidden, let dockLabel = element.dockLabel {
            let view = dockLabelIcon.subviews[1] as! ThumbnailFontIconView
            if dockLabel > 30 {
                view.setFilledStar()
            } else {
                view.setNumber(dockLabel, true)
            }
        }
        assignIfDifferent(&frame.size.width, max(thumbnail.frame.size.width + Preferences.intraCellPadding * 2, ThumbnailView.widthMin(screen)))
        assignIfDifferent(&frame.size.height, newHeight)
        let fontIconWidth = CGFloat([fullscreenIcon, minimizedIcon, hiddenIcon, spaceIcon].filter { !$0.isHidden }.count) * (Preferences.fontIconSize + Preferences.intraCellPadding)
        assignIfDifferent(&label.textContainer!.size.width, frame.width - Preferences.iconSize - Preferences.intraCellPadding * 3 - fontIconWidth)
        assignIfDifferent(&subviews.first!.frame.size, frame.size)
        self.mouseUpCallback = { () -> Void in App.app.focusSelectedWindow(element) }
        self.mouseMovedCallback = { () -> Void in Windows.updateFocusedWindowIndex(index) }
        // force a display to avoid flickering; see https://github.com/lwouis/alt-tab-macos/issues/197
        // quirk: display() should be called last as it resets thumbnail.frame.size somehow
        if labelChanged {
            label.display()
        }
    }

    private func observeDragAndDrop() {
        // NSImageView instances are registered to drag-and-drop by default
        thumbnail.unregisterDraggedTypes()
        appIcon.unregisterDraggedTypes()
        // we only handle URLs (i.e. not text, image, or other draggable things)
        registerForDraggedTypes([NSPasteboard.PasteboardType(kUTTypeURL as String)])
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        mouseMovedCallback()
        return .link
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        dragAndDropTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false, block: { _ in
            self.mouseUpCallback()
        })
        dragAndDropTimer?.tolerance = 0.2
        return .link
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        dragAndDropTimer?.invalidate()
        dragAndDropTimer = nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as! [URL]
        let appUrl = window_!.application.runningApplication.bundleURL!
        let open = try? NSWorkspace.shared.open(urls, withApplicationAt: appUrl, options: [], configuration: [:])
        App.app.hideUi()
        return open != nil
    }

    func mouseMoved() {
        showOrHideWindowControls(true)
        if !isHighlighted {
            mouseMovedCallback()
        }
    }

    override func mouseUp(with event: NSEvent) {
        if event.clickCount >= 1 {
            let target = thumbnail.hitTest(convert(event.locationInWindow, from: nil))?.superview
            if target == closeIcon {
                window_!.close()
            } else if target == minimizeIcon {
                window_!.minDemin()
            } else if target == maximizeIcon {
                window_!.toggleFullscreen()
            } else {
                mouseUpCallback()
            }
        }
    }

    static func makeShadow(_ color: NSColor) -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = color
        shadow.shadowOffset = .zero
        shadow.shadowBlurRadius = 1
        return shadow
    }

    static func widthMax(_ screen: NSScreen) -> CGFloat {
        return (ThumbnailsPanel.widthMax(screen) - Preferences.interCellPadding) / Preferences.minCellsPerRow - Preferences.interCellPadding
    }

    static func widthMin(_ screen: NSScreen) -> CGFloat {
        return (ThumbnailsPanel.widthMax(screen) - Preferences.interCellPadding) / Preferences.maxCellsPerRow - Preferences.interCellPadding
    }

    static func height(_ screen: NSScreen) -> CGFloat {
        return (ThumbnailsPanel.heightMax(screen) - Preferences.interCellPadding) / Preferences.rowsCount - Preferences.interCellPadding
    }

    static func thumbnailSize(_ image: NSImage?, _ screen: NSScreen) -> (CGFloat, CGFloat) {
        guard let image = image else { return (0, 0) }
        let thumbnailHeightMax = ThumbnailView.height(screen) - Preferences.intraCellPadding * 3 - Preferences.iconSize
        let thumbnailWidthMax = ThumbnailView.widthMax(screen) - Preferences.intraCellPadding * 2
        let thumbnailHeight = min(image.size.height, thumbnailHeightMax)
        let thumbnailWidth = min(image.size.width, thumbnailWidthMax)
        let imageRatio = image.size.width / image.size.height
        let thumbnailRatio = thumbnailWidth / thumbnailHeight
        if thumbnailRatio > imageRatio {
            return (image.size.width * thumbnailHeight / image.size.height, thumbnailHeight)
        }
        return (thumbnailWidth, image.size.height * thumbnailWidth / image.size.width)
    }
}
